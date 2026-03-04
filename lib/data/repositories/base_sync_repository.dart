/// Base Sync Repository - provides sync integration for all repositories
///
/// All repositories should either extend this class or use its mixin
/// for automatic sync tracking with the new SyncEngine.
library;

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/sync/sync_engine.dart';
import '../../core/services/auth_service.dart';
import '../providers/local/database_provider.dart';

/// Mixin that adds sync capabilities to any repository
mixin SyncCapable {
  static const _uuid = Uuid();

  /// Get database instance
  Future<Database> get db async => await DatabaseProvider.instance.database;

  /// Track a change for sync
  Future<void> trackChange({
    required String table,
    required String recordId,
    required ChangeOperation operation,
    Map<String, dynamic>? oldData,
    Map<String, dynamic>? newData,
  }) async {
    if (!Get.isRegistered<SyncEngine>()) {
      debugPrint('SyncCapable: SyncEngine not registered, skipping sync');
      return;
    }

    await SyncEngine.to.trackChange(
      table: table,
      recordId: recordId,
      operation: operation,
      oldData: oldData,
      newData: newData,
    );
  }

  /// Insert record and track for sync
  Future<String> insertWithSync({
    required String table,
    required Map<String, dynamic> data,
    String? id,
  }) async {
    final database = await db;
    final recordId = id ?? (data['id'] as String?) ?? _uuid.v4();

    final insertData = Map<String, dynamic>.from(data);
    insertData['id'] = recordId;
    insertData['_sync_status'] = 'pending';
    insertData['created_at'] ??= DateTime.now().toUtc().toIso8601String();
    insertData['updated_at'] = DateTime.now().toUtc().toIso8601String();

    await database.insert(table, insertData);

    await trackChange(
      table: table,
      recordId: recordId,
      operation: ChangeOperation.insert,
      newData: insertData,
    );

    return recordId;
  }

  /// Update record and track for sync
  Future<void> updateWithSync({
    required String table,
    required String recordId,
    required Map<String, dynamic> data,
    Map<String, dynamic>? oldData,
  }) async {
    final database = await db;

    // Get old data if not provided (for conflict resolution)
    Map<String, dynamic>? previousData = oldData;
    if (previousData == null) {
      final existing = await database.query(
        table,
        where: 'id = ?',
        whereArgs: [recordId],
      );
      if (existing.isNotEmpty) {
        previousData = existing.first;
      }
    }

    final updateData = Map<String, dynamic>.from(data);
    updateData['_sync_status'] = 'pending';
    updateData['updated_at'] = DateTime.now().toUtc().toIso8601String();

    await database.update(
      table,
      updateData,
      where: 'id = ?',
      whereArgs: [recordId],
    );

    await trackChange(
      table: table,
      recordId: recordId,
      operation: ChangeOperation.update,
      oldData: previousData,
      newData: updateData,
    );
  }

  /// Delete record and track for sync
  Future<void> deleteWithSync({
    required String table,
    required String recordId,
    bool softDelete = true,
  }) async {
    final database = await db;

    // Get old data before delete
    final existing = await database.query(
      table,
      where: 'id = ?',
      whereArgs: [recordId],
    );
    final oldData = existing.isNotEmpty ? existing.first : null;

    if (softDelete) {
      // Check which soft-delete column the table supports
      final tableInfo = await database.rawQuery("PRAGMA table_info($table)");
      final hasIsActive = tableInfo.any((col) => col['name'] == 'is_active');
      final hasIsDeleted = tableInfo.any((col) => col['name'] == '_is_deleted');

      final updateData = <String, dynamic>{
        '_sync_status': 'pending',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (hasIsActive) {
        updateData['is_active'] = 0;
      }
      if (hasIsDeleted) {
        updateData['_is_deleted'] = 1;
      }

      await database.update(
        table,
        updateData,
        where: 'id = ?',
        whereArgs: [recordId],
      );
    } else {
      // Hard delete
      await database.delete(table, where: 'id = ?', whereArgs: [recordId]);
    }

    await trackChange(
      table: table,
      recordId: recordId,
      operation: ChangeOperation.delete,
      oldData: oldData,
    );
  }

  /// Batch insert with sync
  Future<List<String>> batchInsertWithSync({
    required String table,
    required List<Map<String, dynamic>> records,
  }) async {
    final database = await db;
    final ids = <String>[];

    await database.transaction((txn) async {
      for (final record in records) {
        final recordId = (record['id'] as String?) ?? _uuid.v4();
        final insertData = Map<String, dynamic>.from(record);
        insertData['id'] = recordId;
        insertData['_sync_status'] = 'pending';
        insertData['created_at'] ??= DateTime.now().toUtc().toIso8601String();
        insertData['updated_at'] = DateTime.now().toUtc().toIso8601String();

        await txn.insert(table, insertData);
        ids.add(recordId);
      }
    });

    // Track changes after transaction
    for (int i = 0; i < ids.length; i++) {
      await trackChange(
        table: table,
        recordId: ids[i],
        operation: ChangeOperation.insert,
        newData: records[i],
      );
    }

    return ids;
  }

  /// Get current clinic_id for data isolation
  String? get currentClinicId {
    if (!Get.isRegistered<AuthService>()) return null;
    return AuthService.to.currentProfile.value?.clinicId;
  }

  /// Query with automatic sync status and clinic_id filtering
  Future<List<Map<String, dynamic>>> queryActive({
    required String table,
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final database = await db;

    String? finalWhere = where;
    List<dynamic> finalArgs = whereArgs != null ? List.from(whereArgs) : [];

    // Filter by clinic_id for data isolation
    final clinicId = currentClinicId;
    final tableInfo = await database.rawQuery("PRAGMA table_info($table)");
    final hasClinicId = tableInfo.any((col) => col['name'] == 'clinic_id');
    final hasIsActive = tableInfo.any((col) => col['name'] == 'is_active');
    final hasIsDeleted = tableInfo.any((col) => col['name'] == '_is_deleted');

    if (hasClinicId && clinicId != null) {
      if (finalWhere == null) {
        finalWhere = 'clinic_id = ?';
      } else {
        finalWhere = '($finalWhere) AND clinic_id = ?';
      }
      finalArgs.add(clinicId);
    }

    if (hasIsActive) {
      if (finalWhere == null) {
        finalWhere = 'is_active = 1';
      } else {
        finalWhere = '($finalWhere) AND is_active = 1';
      }
    }

    if (hasIsDeleted) {
      if (finalWhere == null) {
        finalWhere = '_is_deleted = 0';
      } else {
        finalWhere = '($finalWhere) AND _is_deleted = 0';
      }
    }

    return await database.query(
      table,
      where: finalWhere,
      whereArgs: finalArgs.isNotEmpty ? finalArgs : null,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }
}

/// Base repository class with sync support
abstract class BaseSyncRepository with SyncCapable {
  /// Table name for this repository
  String get tableName;

  /// Get all active records
  Future<List<Map<String, dynamic>>> getAll({
    int? limit,
    int? offset,
    String? orderBy,
  }) async {
    return await queryActive(
      table: tableName,
      orderBy: orderBy ?? 'created_at DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// Get record by ID
  Future<Map<String, dynamic>?> getById(String id) async {
    final database = await db;
    final results = await database.query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Create a new record
  Future<String> create(Map<String, dynamic> data) async {
    return await insertWithSync(table: tableName, data: data);
  }

  /// Update an existing record
  Future<void> update(String id, Map<String, dynamic> data) async {
    await updateWithSync(table: tableName, recordId: id, data: data);
  }

  /// Delete a record (soft delete by default)
  Future<void> delete(String id, {bool hard = false}) async {
    await deleteWithSync(table: tableName, recordId: id, softDelete: !hard);
  }

  /// Count active records for current clinic
  Future<int> count() async {
    final database = await db;
    final clinicId = currentClinicId;
    String query =
        'SELECT COUNT(*) as count FROM $tableName WHERE (is_active IS NULL OR is_active = 1)';
    List<dynamic> args = [];
    if (clinicId != null) {
      query += ' AND clinic_id = ?';
      args.add(clinicId);
    }
    final result = await database.rawQuery(query, args);
    return result.first['count'] as int? ?? 0;
  }
}
