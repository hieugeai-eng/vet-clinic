/// Data Migration Service - migrate local data to tenant schema
///
/// Handles one-time migration of existing data from local SQLite
/// to the new tenant schema on Supabase.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../config/supabase_config.dart';
import 'supabase_rest_client.dart';
import 'auth_service.dart';
import '../../data/providers/local/database_provider.dart';

/// Migration status for tracking progress
enum MigrationStatus { notStarted, inProgress, completed, failed }

/// Migration result for a single table
class TableMigrationResult {
  final String tableName;
  final int totalRecords;
  final int successCount;
  final int failCount;
  final List<String> errors;
  final Duration duration;

  TableMigrationResult({
    required this.tableName,
    required this.totalRecords,
    required this.successCount,
    required this.failCount,
    required this.errors,
    required this.duration,
  });

  bool get isSuccess => failCount == 0;
  double get successRate =>
      totalRecords > 0 ? successCount / totalRecords : 1.0;
}

/// Data Migration Service
class DataMigrationService extends GetxService {
  static DataMigrationService get to => Get.find();

  // Migration state
  final Rx<MigrationStatus> status = MigrationStatus.notStarted.obs;
  final RxString currentTable = ''.obs;
  final RxDouble progress = 0.0.obs;
  final RxList<TableMigrationResult> results = <TableMigrationResult>[].obs;
  final RxList<String> logs = <String>[].obs;

  /// Tables to migrate in order (respecting foreign key dependencies)
  static const List<String> migrationOrder = [
    // Independent tables first
    'customers',
    'medicines',
    'products',
    'services',
    // Dependent tables
    'pets',
    'appointments',
    'medical_cases',
    'prescriptions',
    'prescription_items',
    'invoices',
    'invoice_items',
    'medicine_transactions',
    'cages',
    'hospitalizations',
  ];

  /// Field mapping: local table → remote table/fields
  static const Map<String, String> tableMapping = {
    'medicines': 'product_services',
    'products': 'product_services',
    'services': 'product_services',
    // Direct mappings (same name)
    'customers': 'customers',
    'pets': 'pets',
    'appointments': 'appointments',
    'medical_cases': 'medical_cases',
    'prescriptions': 'prescriptions',
    'prescription_items': 'prescription_items',
    'invoices': 'invoices',
    'invoice_items': 'invoice_items',
    'medicine_transactions': 'medicine_transactions',
    'cages': 'cages',
    'hospitalizations': 'hospitalizations',
  };

  void _log(String message) {
    final timestamp = DateTime.now().toUtc().toIso8601String().substring(
      11,
      19,
    );
    logs.add('[$timestamp] $message');
    debugPrint('Migration: $message');
  }

  /// Run full migration
  Future<bool> runMigration() async {
    if (!SupabaseConfig.isConfigured || !SupabaseConfig.hasTenant) {
      _log('❌ Supabase or tenant not configured');
      return false;
    }

    status.value = MigrationStatus.inProgress;
    progress.value = 0.0;
    results.clear();
    logs.clear();

    _log('🚀 Starting data migration to ${SupabaseConfig.tenantSchema}');

    final db = await DatabaseProvider.instance.database;
    int completedTables = 0;

    for (final table in migrationOrder) {
      currentTable.value = table;

      try {
        final result = await _migrateTable(db, table);
        results.add(result);

        if (result.isSuccess) {
          _log(
            '✅ $table: ${result.successCount}/${result.totalRecords} records',
          );
        } else {
          _log(
            '⚠️ $table: ${result.successCount}/${result.totalRecords} (${result.failCount} failed)',
          );
        }
      } catch (e) {
        _log('❌ $table: Error - $e');
        results.add(
          TableMigrationResult(
            tableName: table,
            totalRecords: 0,
            successCount: 0,
            failCount: 1,
            errors: [e.toString()],
            duration: Duration.zero,
          ),
        );
      }

      completedTables++;
      progress.value = completedTables / migrationOrder.length;
    }

    currentTable.value = '';

    // Check overall status
    final hasFailures = results.any((r) => !r.isSuccess);
    status.value = hasFailures
        ? MigrationStatus.failed
        : MigrationStatus.completed;

    final totalRecords = results.fold<int>(0, (sum, r) => sum + r.totalRecords);
    final totalSuccess = results.fold<int>(0, (sum, r) => sum + r.successCount);

    _log('📊 Migration complete: $totalSuccess/$totalRecords records');

    return !hasFailures;
  }

  /// Migrate a single table
  Future<TableMigrationResult> _migrateTable(dynamic db, String table) async {
    final stopwatch = Stopwatch()..start();
    final errors = <String>[];

    // Check if table exists locally
    final tableExists = await _tableExists(db, table);
    if (!tableExists) {
      return TableMigrationResult(
        tableName: table,
        totalRecords: 0,
        successCount: 0,
        failCount: 0,
        errors: [],
        duration: stopwatch.elapsed,
      );
    }

    // Get all records from local
    final records = await db.query(table);
    if (records.isEmpty) {
      return TableMigrationResult(
        tableName: table,
        totalRecords: 0,
        successCount: 0,
        failCount: 0,
        errors: [],
        duration: stopwatch.elapsed,
      );
    }

    int successCount = 0;
    int failCount = 0;

    // Determine remote table
    final remoteTable = tableMapping[table] ?? table;
    final tenantTable = '${SupabaseConfig.tenantSchema}.$remoteTable';

    for (final record in records) {
      try {
        final payload = _preparePayload(table, record);

        // Skip if no valid payload
        if (payload.isEmpty) continue;

        // Upsert to remote
        await SupabaseRestClient.to.upsert(tenantTable, payload);
        successCount++;

        // Mark as synced locally
        await db.update(
          table,
          {'sync_status': 'synced'},
          where: 'id = ?',
          whereArgs: [record['id']],
        );
      } catch (e) {
        failCount++;
        errors.add('${record['id']}: $e');
      }
    }

    stopwatch.stop();

    return TableMigrationResult(
      tableName: table,
      totalRecords: records.length,
      successCount: successCount,
      failCount: failCount,
      errors: errors,
      duration: stopwatch.elapsed,
    );
  }

  /// Check if table exists
  Future<bool> _tableExists(dynamic db, String table) async {
    try {
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [table],
      );
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Prepare payload for remote (handle field mapping)
  Map<String, dynamic> _preparePayload(
    String table,
    Map<String, dynamic> record,
  ) {
    final payload = Map<String, dynamic>.from(record);

    // Remove local-only fields
    payload.remove('sync_status');
    payload.remove('_sync_status');

    // Add clinic_id if missing
    if (!payload.containsKey('clinic_id') || payload['clinic_id'] == null) {
      payload['clinic_id'] = SupabaseConfig.clinicId;
    }

    // Handle unified product_services table
    if (table == 'medicines' || table == 'products' || table == 'services') {
      payload['type'] = table == 'medicines'
          ? 'medicine'
          : table == 'products'
          ? 'product'
          : 'service';
    }

    // Sanitize UUIDs (empty string → null)
    for (final key in payload.keys.toList()) {
      if (payload[key] == '') {
        payload[key] = null;
      }
    }

    return payload;
  }

  /// Export local data to JSON (backup before migration)
  Future<String> exportToJson() async {
    final db = await DatabaseProvider.instance.database;
    final export = <String, List<Map<String, dynamic>>>{};

    for (final table in migrationOrder) {
      if (await _tableExists(db, table)) {
        final records = await db.query(table);
        export[table] = List<Map<String, dynamic>>.from(records);
      }
    }

    return jsonEncode(export);
  }

  /// Get migration summary
  Map<String, dynamic> getSummary() {
    return {
      'status': status.value.name,
      'progress': progress.value,
      'tablesCompleted': results.length,
      'totalTables': migrationOrder.length,
      'totalRecords': results.fold<int>(0, (sum, r) => sum + r.totalRecords),
      'successRecords': results.fold<int>(0, (sum, r) => sum + r.successCount),
      'failedRecords': results.fold<int>(0, (sum, r) => sum + r.failCount),
      'results': results
          .map(
            (r) => {
              'table': r.tableName,
              'total': r.totalRecords,
              'success': r.successCount,
              'failed': r.failCount,
            },
          )
          .toList(),
    };
  }
}
