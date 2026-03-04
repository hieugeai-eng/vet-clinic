/// Change Tracker - tracks all local changes for sync
///
/// Records INSERT, UPDATE, DELETE operations with before/after data
/// for conflict resolution and sync queue management.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../data/providers/local/database_provider.dart';

/// Type of change operation
enum ChangeOperation { insert, update, delete }

/// Record of a single change
class ChangeRecord {
  final String id;
  final String tableName;
  final String recordId;
  final ChangeOperation operation;
  final Map<String, dynamic>? oldData;
  final Map<String, dynamic>? newData;
  final int localVersion;
  final DateTime timestamp;
  final String deviceId;
  int retryCount;

  ChangeRecord({
    required this.id,
    required this.tableName,
    required this.recordId,
    required this.operation,
    this.oldData,
    this.newData,
    required this.localVersion,
    required this.timestamp,
    required this.deviceId,
    this.retryCount = 0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'table_name': tableName,
    'record_id': recordId,
    'operation': operation.name,
    'old_data': oldData != null ? jsonEncode(oldData) : null,
    'new_data': newData != null ? jsonEncode(newData) : null,
    'local_version': localVersion,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'device_id': deviceId,
    'retry_count': retryCount,
  };

  factory ChangeRecord.fromMap(Map<String, dynamic> map) {
    return ChangeRecord(
      id: map['id'] as String,
      tableName: map['table_name'] as String,
      recordId: map['record_id'] as String,
      operation: ChangeOperation.values.firstWhere(
        (e) => e.name == map['operation'],
        orElse: () => ChangeOperation.update,
      ),
      oldData: map['old_data'] != null
          ? jsonDecode(map['old_data'] as String) as Map<String, dynamic>
          : null,
      newData: map['new_data'] != null
          ? jsonDecode(map['new_data'] as String) as Map<String, dynamic>
          : null,
      localVersion: map['local_version'] as int? ?? 0,
      timestamp: DateTime.parse(map['timestamp'] as String),
      deviceId: map['device_id'] as String,
      retryCount: map['retry_count'] as int? ?? 0,
    );
  }

  @override
  String toString() => 'ChangeRecord($operation $tableName/$recordId)';
}

/// Tracks changes to local database
class ChangeTracker {
  /// Initialize the change tracker
  Future<void> initialize() async {
    await _ensureChangeLogTable();
    debugPrint('ChangeTracker: Initialized');
  }

  /// Ensure the change log table exists
  Future<void> _ensureChangeLogTable() async {
    final db = await DatabaseProvider.instance.database;

    await db.execute('''
      CREATE TABLE IF NOT EXISTS _change_log (
        id TEXT PRIMARY KEY,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        old_data TEXT,
        new_data TEXT,
        local_version INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        device_id TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        status TEXT DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_change_log_status 
      ON _change_log(status)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_change_log_timestamp 
      ON _change_log(timestamp)
    ''');
  }

  /// Record a change
  Future<void> recordChange(ChangeRecord change) async {
    final db = await DatabaseProvider.instance.database;
    await db.insert('_change_log', {...change.toMap(), 'status': 'pending'});
    debugPrint(
      'ChangeTracker: Recorded ${change.operation.name} on ${change.tableName}/${change.recordId}',
    );
  }

  /// Get all pending changes
  Future<List<ChangeRecord>> getPendingChanges() async {
    final db = await DatabaseProvider.instance.database;
    final results = await db.query(
      '_change_log',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'timestamp ASC',
    );
    return results.map((r) => ChangeRecord.fromMap(r)).toList();
  }

  /// Get pending changes for a specific table
  Future<List<ChangeRecord>> getPendingChangesForTable(String table) async {
    final db = await DatabaseProvider.instance.database;
    final results = await db.query(
      '_change_log',
      where: 'status = ? AND table_name = ?',
      whereArgs: ['pending', table],
      orderBy: 'timestamp ASC',
    );
    return results.map((r) => ChangeRecord.fromMap(r)).toList();
  }

  /// Mark a change as completed
  Future<void> markCompleted(String changeId) async {
    final db = await DatabaseProvider.instance.database;
    await db.update(
      '_change_log',
      {'status': 'completed'},
      where: 'id = ?',
      whereArgs: [changeId],
    );
  }

  /// Mark a change as failed
  Future<void> markFailed(String changeId, String error) async {
    final db = await DatabaseProvider.instance.database;
    await db.update(
      '_change_log',
      {
        'status': 'failed',
        'retry_count': 0, // Will be incremented in next query
      },
      where: 'id = ?',
      whereArgs: [changeId],
    );

    // Increment retry count
    await db.rawUpdate(
      'UPDATE _change_log SET retry_count = retry_count + 1 WHERE id = ?',
      [changeId],
    );
  }

  /// Get count of pending changes
  Future<int> getPendingCount() async {
    final db = await DatabaseProvider.instance.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM _change_log WHERE status = 'pending'",
    );
    return result.first['count'] as int? ?? 0;
  }

  /// Clear old completed changes (cleanup)
  Future<void> cleanupOldChanges({
    Duration maxAge = const Duration(days: 7),
  }) async {
    final db = await DatabaseProvider.instance.database;
    final cutoff = DateTime.now().subtract(maxAge).toUtc().toIso8601String();
    await db.delete(
      '_change_log',
      where: "status = 'completed' AND timestamp < ?",
      whereArgs: [cutoff],
    );
  }
}
