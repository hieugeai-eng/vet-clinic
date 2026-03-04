/// Sync Engine - Central orchestrator for bidirectional sync
///
/// Single unified sync system for offline-first architecture.
/// Uses flat public schema with clinic_id filtering + RLS.
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'change_tracker.dart';

// Re-export for convenience
export 'change_tracker.dart' show ChangeRecord, ChangeOperation;
export 'sync_config.dart' show SyncConfig;
import 'conflict_merger.dart';
import 'sync_queue.dart';
import 'sync_config.dart';
import '../config/supabase_config.dart';
import '../services/attachment_service.dart';
import '../services/supabase_rest_client.dart';
import '../services/realtime_service.dart';
import '../services/auth_service.dart';
import '../../data/providers/local/database_provider.dart';
import '../../data/models/case_attachment_model.dart';

/// Sync status for UI display
enum SyncStatus { idle, syncing, error, offline, upToDate }

/// Sync Engine - manages all sync operations
class SyncEngine extends GetxService {
  static SyncEngine get to => Get.find();

  // Dependencies
  late final ChangeTracker _changeTracker;
  late final ConflictMerger _conflictMerger;
  late final SyncQueue _syncQueue;

  // Observable state
  final Rx<SyncStatus> status = SyncStatus.idle.obs;
  final RxString statusMessage = ''.obs;
  final RxInt pendingChanges = 0.obs;
  final RxInt syncVersion = 0.obs;

  // Timers
  Timer? _autoSyncTimer;
  Timer? _debounceTimer;

  // Config
  static const Duration autoSyncInterval = Duration(seconds: 30);
  static const Duration debounceDelay = Duration(milliseconds: 500);

  @override
  void onInit() {
    super.onInit();
    _initializeEngine();
  }

  Future<void> _initializeEngine() async {
    // Initialize components
    _changeTracker = ChangeTracker();
    _conflictMerger = ConflictMerger();
    _syncQueue = SyncQueue();

    await _changeTracker.initialize();
    await _syncQueue.initialize();

    if (!SupabaseConfig.isConfigured) {
      status.value = SyncStatus.offline;
      statusMessage.value = 'Chế độ offline';
      debugPrint('SyncEngine: Running in offline mode');
      return;
    }

    // One-time fix: Clear corrupted local-timezone last_sync strings.
    // Local toIso8601String lacks 'Z' at the end, while UTC has it.
    try {
      final db = await DatabaseProvider.instance.database;
      final affected = await db.rawUpdate(
        "UPDATE _sync_meta SET last_sync_time = '' WHERE last_sync_time NOT LIKE '%Z' AND last_sync_time != ''",
      );
      if (affected > 0) {
        debugPrint(
          'SyncEngine: Forcing full sync reset on $affected tables due to UTC migration bug',
        );
      }
    } catch (_) {}

    // Subscribe to realtime changes
    _subscribeToRealtimeChanges();

    // Start auto-sync
    _startAutoSync();

    // Initial sync
    await syncAll();

    debugPrint('SyncEngine: Initialized successfully');
  }

  /// Subscribe to realtime changes from Supabase
  void _subscribeToRealtimeChanges() {
    if (!Get.isRegistered<RealtimeService>()) return;
    for (final table in SyncConfig.syncableTables) {
      RealtimeService.to.subscribe(table, _handleRemoteChange);
    }
  }

  /// Handle incoming remote change — also pulls linked child tables
  void _handleRemoteChange(Map<String, dynamic> payload) {
    final table = payload['table'] as String?;
    final eventType = payload['type'] as String?;

    debugPrint('SyncEngine: Remote change - $table ($eventType)');

    // Debounce to avoid too many syncs
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDelay, () async {
      if (table != null) {
        await _pullTableChanges(table);
        // Also pull child tables that depend on this table
        final childTables = _getChildTables(table);
        for (final child in childTables) {
          await _pullTableChanges(child);
        }
      }
    });
  }

  /// Get tables that have a foreign key dependency on the given table
  static List<String> _getChildTables(String parentTable) {
    final children = <String>[];
    SyncConfig.dependencies.forEach((child, deps) {
      if (deps.contains(parentTable)) {
        children.add(child);
      }
    });
    return children;
  }

  /// Start auto-sync timer
  void _startAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(autoSyncInterval, (_) {
      if (status.value != SyncStatus.syncing) {
        debugPrint('[SYNC-DEBUG] Auto-sync timer fired, starting syncAll...');
        syncAll();
      } else {
        debugPrint('[SYNC-DEBUG] Auto-sync skipped — already syncing');
      }
    });
    debugPrint(
      '[SYNC-DEBUG] Auto-sync timer started (every ${autoSyncInterval.inSeconds}s)',
    );
  }

  /// Sync all tables
  Future<void> syncAll() async {
    if (!SupabaseConfig.isConfigured) {
      debugPrint(
        '[SYNC-DEBUG] syncAll ABORTED — SupabaseConfig.isConfigured=false',
      );
      status.value = SyncStatus.offline;
      return;
    }

    if (status.value == SyncStatus.syncing) {
      debugPrint('[SYNC-DEBUG] syncAll SKIPPED — already syncing');
      return;
    }

    status.value = SyncStatus.syncing;
    statusMessage.value = 'Đang đồng bộ...';
    debugPrint('[SYNC-DEBUG] syncAll STARTED — pushing then pulling...');

    try {
      // 0. Discover records marked 'pending' but not in change queue (e.g. seed data)
      await _queueOrphanedPendingRecords();

      // 1. Push local changes first
      await _pushPendingChanges();
      debugPrint(
        '[SYNC-DEBUG] syncAll — push done, now pulling ${SyncConfig.syncableTables.length} tables...',
      );

      // 2. Pull remote changes
      for (final table in SyncConfig.syncableTables) {
        await _pullTableChanges(table);
      }

      // 3. Sync pending file uploads (retry failed attachment uploads)
      try {
        if (Get.isRegistered<AttachmentService>()) {
          final uploaded = await AttachmentService.to.syncPendingUploads();
          if (uploaded > 0) {
            debugPrint(
              '[SYNC-DEBUG] syncAll — synced $uploaded pending file uploads',
            );
          }
        }
      } catch (e) {
        debugPrint('[SYNC-DEBUG] syncAll — attachment sync error: $e');
      }

      // 3. Update status
      final pending = await _syncQueue.getPendingCount();
      pendingChanges.value = pending;

      if (pending == 0) {
        status.value = SyncStatus.upToDate;
        statusMessage.value = 'Đã đồng bộ lúc ${_formatTime(DateTime.now())}';
      } else {
        status.value = SyncStatus.idle;
        statusMessage.value = '$pending thay đổi chờ đồng bộ';
      }

      debugPrint(
        '[SYNC-DEBUG] syncAll COMPLETED — pending=$pending, syncVersion=${syncVersion.value}',
      );
    } catch (e, stack) {
      status.value = SyncStatus.error;
      final msg = e.toString();
      statusMessage.value =
          'Lỗi đồng bộ: ${msg.substring(0, msg.length > 50 ? 50 : msg.length)}';
      debugPrint('[SYNC-DEBUG] syncAll ERROR: $e');
      debugPrint('[SYNC-DEBUG] syncAll STACK: $stack');
    }
  }

  /// Discover records with _sync_status='pending' but not in change queue
  /// This handles seed data (services, staff, cages) that was marked as pending
  /// by database migration but never had change queue entries created
  Future<void> _queueOrphanedPendingRecords() async {
    try {
      final db = await DatabaseProvider.instance.database;
      // Only check tables where seed data exists
      const seedTables = ['services', 'staff', 'cages'];

      for (final table in seedTables) {
        try {
          final pendingRows = await db.query(
            table,
            columns: ['id', '_is_deleted'],
            where: "_sync_status = 'pending'",
          );

          if (pendingRows.isEmpty) continue;

          // Check which ones are already in the sync queue
          final queuedIds = <String>{};
          final queueRows = await _syncQueue.getPendingChanges();
          for (final qr in queueRows) {
            if (qr.tableName == table) queuedIds.add(qr.recordId);
          }

          int queued = 0;
          for (final row in pendingRows) {
            final id = row['id'] as String;
            if (!queuedIds.contains(id)) {
              // Check if record is soft-deleted → use delete operation
              final isDeleted = row['_is_deleted'];
              final op = (isDeleted == 1 || isDeleted == true)
                  ? ChangeOperation.delete
                  : ChangeOperation.insert;
              await trackChange(table: table, recordId: id, operation: op);
              // Prevent re-queueing by updating status to 'queued' instead of 'pending'
              await db.update(
                table,
                {'_sync_status': 'queued'},
                where: 'id = ?',
                whereArgs: [id],
              );
              queued++;
            }
          }

          if (queued > 0) {
            debugPrint(
              '[SYNC-DEBUG] Queued $queued orphaned $table records for push',
            );
          }
        } catch (e) {
          debugPrint('[SYNC-DEBUG] Error scanning $table for orphans: $e');
        }
      }
    } catch (e) {
      debugPrint('[SYNC-DEBUG] _queueOrphanedPendingRecords error: $e');
    }
  }

  /// Push pending local changes to cloud
  Future<void> _pushPendingChanges() async {
    final changes = await _syncQueue.getPendingChanges();
    debugPrint('[SYNC-DEBUG] Push: ${changes.length} pending changes in queue');

    for (final change in changes) {
      try {
        await _pushChange(change);
        await _syncQueue.markAsCompleted(change.id);
      } catch (e) {
        debugPrint(
          '[SYNC-DEBUG] Push FAILED: ${change.tableName}/${change.recordId} - $e',
        );
        await _syncQueue.incrementRetry(change.id);

        // Skip permanently failed records (e.g. non-UUID seed data, FK violations)
        // After 3 retries, mark as completed to stop infinite retry loops
        if (change.retryCount >= 3 ||
            e.toString().contains('non-UUID primary key') ||
            e.toString().contains('22P02')) {
          debugPrint(
            '[SYNC-DEBUG] Push: marking ${change.tableName}/${change.recordId} as permanently skipped (retries=${change.retryCount})',
          );
          await _syncQueue.markAsCompleted(change.id);
        }

        // Log FK errors but CONTINUE processing remaining changes
        if (e.toString().contains('foreign key') ||
            e.toString().contains('violates')) {
          debugPrint(
            'SyncEngine: FK error on ${change.tableName}/${change.recordId}, continuing...',
          );
        }
      }
    }
  }

  /// Push a single change to cloud
  /// Uses flat public schema - no tenant prefix needed.
  /// RLS + clinic_id automatic filtering handles data isolation.
  Future<void> _pushChange(ChangeRecord change) async {
    final db = await DatabaseProvider.instance.database;
    switch (change.operation) {
      case ChangeOperation.insert:
      case ChangeOperation.update:
        // Always fetch full record from local DB to avoid missing NOT NULL columns
        final rows = await db.query(
          change.tableName,
          where: 'id = ?',
          whereArgs: [change.recordId],
        );
        if (rows.isEmpty) {
          debugPrint(
            'SyncEngine: Record ${change.recordId} not found locally in ${change.tableName}, skipping',
          );
          return;
        }
        final fullRecord = Map<String, dynamic>.from(rows.first);
        final data = _sanitizeForCloud(change.tableName, fullRecord);
        await SupabaseRestClient.to.upsert(change.tableName, data);

        // Mark as synced locally so it doesn't get repeatedly queued as an orphan
        try {
          await db.update(
            change.tableName,
            {'_sync_status': 'synced'},
            where: 'id = ?',
            whereArgs: [change.recordId],
          );
        } catch (_) {}
        break;
      case ChangeOperation.delete:
        // Soft delete CASCADE FIRST to children on cloud
        await _cascadeDeleteToCloud(db, change.tableName, change.recordId);

        // Soft delete the parent record from cloud
        try {
          final now = DateTime.now().toUtc().toIso8601String();
          await SupabaseRestClient.to.patch(
            change.tableName,
            {'is_deleted': true, 'updated_at': now},
            query: {'id': 'eq.${change.recordId}'},
          );
        } catch (e) {
          // Ignore 404 — record might already be hard deleted
          if (!e.toString().contains('404')) rethrow;
        }

        // Leave it soft-deleted locally, just update sync_status so we know it's pushed
        try {
          await db.update(
            change.tableName,
            {'_sync_status': 'synced'},
            where: 'id = ?',
            whereArgs: [change.recordId],
          );
        } catch (_) {} // table might not exist in sqlite edge cases

        debugPrint(
          'SyncEngine: Soft-deleted ${change.tableName}/${change.recordId} on cloud',
        );
        break;
    }

    debugPrint(
      'SyncEngine: Pushed ${change.operation.name} ${change.tableName}/${change.recordId}',
    );
  }

  /// Cascade hard-delete to child tables on cloud
  /// When a parent record is deleted, find and delete all children
  Future<void> _cascadeDeleteToCloud(
    dynamic db,
    String parentTable,
    String parentId,
  ) async {
    // Define parent → child FK relationships
    const cascadeMap = <String, List<Map<String, String>>>{
      'medical_cases': [
        {'table': 'case_services', 'fk': 'case_id'},
        {'table': 'case_attachments', 'fk': 'case_id'},
        {'table': 'hospitalizations', 'fk': 'case_id'},
        {'table': 'medicine_transactions', 'fk': 'case_id'},
      ],
      'hospitalizations': [
        {'table': 'hospitalization_dailies', 'fk': 'hospitalization_id'},
      ],
      'hospitalization_dailies': [
        {'table': 'hospitalization_treatments', 'fk': 'daily_id'},
        {'table': 'vital_sign_logs', 'fk': 'daily_id'},
      ],
      'customers': [
        {'table': 'pets', 'fk': 'customer_id'},
      ],
    };

    final children = cascadeMap[parentTable];
    if (children == null) return;

    for (final child in children) {
      final childTable = child['table']!;
      final fkCol = child['fk']!;

      // Find local child records
      final childRows = await db.query(
        childTable,
        where: '$fkCol = ?',
        whereArgs: [parentId],
      );

      for (final row in childRows) {
        final childId = row['id'] as String;

        // Recursively cascade (e.g., hospitalization → dailies → treatments)
        await _cascadeDeleteToCloud(db, childTable, childId);

        // Delete storage files for case_attachments
        if (childTable == 'case_attachments') {
          try {
            final remoteUrl = row['remote_url'] as String?;
            if (remoteUrl != null &&
                remoteUrl.isNotEmpty &&
                Get.isRegistered<AttachmentService>()) {
              final localPath = row['local_path'] as String? ?? '';
              final attachment = CaseAttachmentModel.fromJson(
                Map<String, dynamic>.from(row),
              );
              await AttachmentService.to.deleteAttachment(attachment);
              debugPrint(
                'SyncEngine: Deleted storage file for attachment $childId',
              );
            }
          } catch (e) {
            debugPrint(
              'SyncEngine: Failed to delete storage file for $childId: $e',
            );
          }
        }

        // Soft-delete from cloud
        try {
          final now = DateTime.now().toUtc().toIso8601String();
          await SupabaseRestClient.to.patch(
            childTable,
            {'is_deleted': true, 'updated_at': now},
            query: {'id': 'eq.$childId'},
          );
        } catch (e) {
          if (!e.toString().contains('404')) {
            debugPrint(
              'SyncEngine: Failed to soft-delete $childTable/$childId from cloud: $e',
            );
          }
        }

        // Mark synced locally if soft-deleted
        try {
          await db.update(
            childTable,
            {'_sync_status': 'synced'},
            where: 'id = ?',
            whereArgs: [childId],
          );
        } catch (_) {}
      }

      if (childRows.isNotEmpty) {
        debugPrint(
          'SyncEngine: Cascade soft-deleted ${childRows.length} $childTable records for $parentTable/$parentId',
        );
      }
    }
  }

  /// Get the timestamp column name used for sync ordering on a given table
  /// All tables now have updated_at in the new schema
  String _syncTimestampColumn(String table) {
    return 'updated_at';
  }

  /// Pull changes from remote table
  /// Queries public schema directly - RLS filters by clinic_id automatically.
  Future<void> _pullTableChanges(String table) async {
    try {
      statusMessage.value = 'Đồng bộ $table...';

      // Get last sync timestamp for this table
      final lastSyncTime = await _getLastSyncTime(table);
      final tsCol = _syncTimestampColumn(table);

      // Fetch changes since last sync using the appropriate timestamp column
      // RLS auto-filters by clinic_id — no tenant prefix needed
      final Map<String, String> query = lastSyncTime.isNotEmpty
          ? {tsCol: 'gt.$lastSyncTime', 'order': '$tsCol.asc'}
          : {'order': '$tsCol.asc'};

      final remoteRecords = await SupabaseRestClient.to.get(
        table,
        query: query,
      );

      debugPrint(
        '[SYNC-DEBUG] Pull $table: ${remoteRecords.length} records (lastSync: ${lastSyncTime.isEmpty ? 'NONE' : lastSyncTime}, col: $tsCol)',
      );

      if (remoteRecords.isEmpty) {
        return;
      }

      final db = await DatabaseProvider.instance.database;

      for (final remoteRecord in remoteRecords) {
        await _mergeRemoteRecord(db, table, remoteRecord);
      }

      // Update last sync timestamp
      final maxTimestamp = remoteRecords
          .map(
            (r) =>
                (r[tsCol] ?? r['updated_at'] ?? r['created_at']) as String? ??
                '',
          )
          .where((s) => s.isNotEmpty)
          .fold<String>('', (a, b) => a.compareTo(b) > 0 ? a : b);
      if (maxTimestamp.isNotEmpty) {
        await _setLastSyncTime(table, maxTimestamp);
      }

      debugPrint(
        'SyncEngine: Pulled ${remoteRecords.length} records from $table',
      );

      // Notify UI controllers about remote data changes ONLY if we actually got changes
      if (remoteRecords.isNotEmpty) {
        syncVersion.value++;
      }
    } catch (e) {
      debugPrint('SyncEngine: Failed to pull $table - $e');
    }
  }

  /// Merge a remote record with local data
  Future<void> _mergeRemoteRecord(
    dynamic db,
    String table,
    Map<String, dynamic> remoteRecord,
  ) async {
    final id = remoteRecord['id'];
    if (id == null) return;

    // Check if the remote record is deleted
    final isRemoteDeleted =
        remoteRecord['is_deleted'] == true ||
        remoteRecord['is_deleted'] == 1 ||
        remoteRecord['is_deleted'] == '1';

    // Get local record
    final localRecords = await db.query(
      table,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (localRecords.isEmpty) {
      // No local record — skip inserting if it's already deleted on cloud
      if (isRemoteDeleted) {
        debugPrint(
          '[SYNC-DEBUG] Merge: Skipping insert of deleted record $table/$id',
        );
        return;
      }
      final sanitized = _sanitizeForLocal(table, remoteRecord);
      sanitized['_sync_status'] = 'synced';
      await db.insert(table, sanitized);
    } else {
      final localRecord = localRecords.first as Map<String, dynamic>;

      // Sanitize the remote data
      Map<String, dynamic> sanitized;

      // Check if local has pending changes
      if (localRecord['_sync_status'] == 'pending' && !isRemoteDeleted) {
        // Merge conflict (but remote delete always wins)
        final merged = _conflictMerger.merge(
          table: table,
          local: localRecord,
          remote: remoteRecord,
        );
        // MUST sanitize merged result for SQLite (bool→int etc.)
        sanitized = _sanitizeForLocal(table, merged);
      } else {
        // No conflict - just update (or remote is deleted → overwrite)
        sanitized = _sanitizeForLocal(table, remoteRecord);
      }

      sanitized['_sync_status'] = 'synced';

      // CRITICAL: When cloud says is_deleted=true, also set is_active=0 locally!
      // Many queries filter by is_active=1, so without this, deleted records still show up.
      if (isRemoteDeleted) {
        sanitized['_is_deleted'] = 1;
        sanitized['is_active'] = 0;
      }

      await db.update(table, sanitized, where: 'id = ?', whereArgs: [id]);
    }
  }

  /// Track a local change for sync
  Future<void> trackChange({
    required String table,
    required String recordId,
    required ChangeOperation operation,
    Map<String, dynamic>? oldData,
    Map<String, dynamic>? newData,
  }) async {
    final change = ChangeRecord(
      id: '${table}_${recordId}_${DateTime.now().millisecondsSinceEpoch}',
      tableName: table,
      recordId: recordId,
      operation: operation,
      oldData: oldData,
      newData: newData,
      localVersion: syncVersion.value,
      timestamp: DateTime.now(),
      deviceId: await _getDeviceId(),
    );

    await _syncQueue.enqueue(change);
    pendingChanges.value++;

    // Mark as queued locally to distinguish from pending orphaned elements
    try {
      final db = await DatabaseProvider.instance.database;
      await db.update(
        table,
        {'_sync_status': 'queued'},
        where: 'id = ?',
        whereArgs: [recordId],
      );
    } catch (_) {}

    // Immediately notify UI that local database changed
    syncVersion.value++;

    // Try immediate sync if online
    if (SupabaseConfig.isConfigured && status.value != SyncStatus.syncing) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(debounceDelay, syncAll);
    }
  }

  /// Clear all pending sync queue entries (for fixing stuck sync)
  Future<void> clearPendingQueue() async {
    final db = await DatabaseProvider.instance.database;
    await db.delete('_sync_queue', where: "status = 'pending'");
    pendingChanges.value = 0;
    status.value = SyncStatus.upToDate;
    statusMessage.value = 'Đã xóa hàng đợi đồng bộ';
    debugPrint('SyncEngine: Cleared pending sync queue');
  }

  /// Diagnose sync push - test 1 record per table and report errors
  Future<Map<String, String>> diagnosePush() async {
    final results = <String, String>{};
    final db = await DatabaseProvider.instance.database;

    // Check auth first
    final hasToken =
        Get.isRegistered<AuthService>() &&
        AuthService.to.accessToken.value.isNotEmpty;
    results['_auth'] = hasToken
        ? 'OK (JWT present)'
        : 'FAIL: No JWT token - not logged in?';

    // Check clinic_id
    final clinicId = Get.isRegistered<AuthService>()
        ? AuthService.to.currentProfile.value?.clinicId
        : null;
    results['_clinic'] = clinicId != null
        ? 'OK ($clinicId)'
        : 'FAIL: No clinic_id';

    if (!SupabaseConfig.isConfigured) {
      results['_config'] = 'FAIL: Supabase not configured';
      return results;
    }
    results['_config'] = 'OK (${SupabaseConfig.projectUrl})';

    for (final table in SyncConfig.syncableTables) {
      try {
        final rows = await db.query(table, limit: 1);
        if (rows.isEmpty) {
          results[table] = 'SKIP: no local data';
          continue;
        }
        final record = Map<String, dynamic>.from(rows.first);
        final sanitized = _sanitizeForCloud(table, record);

        // Log FULL sanitized data for debugging
        debugPrint('SyncDiag[$table]: === SANITIZED DATA ===');
        sanitized.forEach((k, v) => debugPrint('  $k (${v.runtimeType}): $v'));

        await SupabaseRestClient.to.upsert(table, sanitized);
        results[table] = 'OK ✅';
      } catch (e) {
        final err = e.toString();
        results[table] =
            'FAIL: ${err.length > 500 ? err.substring(0, 500) : err}';
        debugPrint('SyncDiag[$table] ERROR: $err');
      }
    }

    return results;
  }

  /// Push ALL local data to cloud (for initial sync when cloud is empty)
  Future<Map<String, Map<String, int>>> pushAllData() async {
    if (!SupabaseConfig.isConfigured) return {};

    final db = await DatabaseProvider.instance.database;
    final report = <String, Map<String, int>>{};

    status.value = SyncStatus.syncing;

    final tables = SyncConfig.sortByDependency(SyncConfig.syncableTables);

    // Required non-null fields per table (for validation before push)
    const requiredFields = <String, List<String>>{
      'pets': ['customer_id'],
      'medical_cases': ['customer_id', 'pet_id'],
      'case_services': ['case_id'],
      'hospitalizations': ['case_id', 'pet_id'],
      'hospitalization_dailies': ['hospitalization_id'],
      'hospitalization_treatments': ['daily_id'],
      'vital_sign_logs': ['daily_id'],
      'case_attachments': ['case_id'],
    };

    for (final table in tables) {
      int success = 0;
      int fail = 0;
      int skip = 0;

      try {
        statusMessage.value = 'Đẩy dữ liệu $table...';

        // Push ACTIVE records only (skip soft-deleted)
        // Filter out _is_deleted=1 and is_active=0 records
        List<Map<String, dynamic>> rows;
        try {
          rows = await db.query(
            table,
            where:
                'COALESCE(_is_deleted, 0) = 0 AND COALESCE(is_active, 1) = 1',
          );
        } catch (_) {
          // Fallback if columns don't exist
          rows = await db.query(table);
        }

        debugPrint('SyncEngine.pushAll: $table has ${rows.length} records');

        for (final row in rows) {
          try {
            final sanitized = _sanitizeForCloud(
              table,
              Map<String, dynamic>.from(row),
            );

            // Validate ID exists
            final id = sanitized['id']?.toString() ?? '';
            if (id.isEmpty) {
              skip++;
              continue;
            }

            // Validate required fields are not null
            final required = requiredFields[table] ?? [];
            bool hasAllRequired = true;
            for (final field in required) {
              if (sanitized[field] == null) {
                debugPrint(
                  'SyncEngine.pushAll: $table/$id skipped - $field is null',
                );
                hasAllRequired = false;
                break;
              }
            }
            if (!hasAllRequired) {
              skip++;
              continue;
            }

            await SupabaseRestClient.to.upsert(table, sanitized);
            success++;
          } catch (e) {
            fail++;
            debugPrint('SyncEngine.pushAll: $table/${row['id']} failed - $e');
          }
        }
      } catch (e) {
        debugPrint('SyncEngine.pushAll: $table query failed - $e');
      }

      report[table] = {'success': success, 'fail': fail, 'skip': skip};
      debugPrint(
        'SyncEngine.pushAll: $table → ok=$success fail=$fail skip=$skip',
      );
    }

    status.value = SyncStatus.upToDate;
    statusMessage.value = 'Hoàn tất đẩy dữ liệu';

    return report;
  }

  /// Cleanup: Delete records LOCALLY that were soft-deleted, preventing storage bloat.
  /// We DO NOT hard-delete from the cloud here to preserve the sync capability for offline devices.
  Future<Map<String, int>> cleanupLocal() async {
    if (!SupabaseConfig.isConfigured) return {};

    final db = await DatabaseProvider.instance.database;
    final report = <String, int>{};

    status.value = SyncStatus.syncing;
    statusMessage.value = 'Đang dọn dẹp bộ nhớ cục bộ...';

    for (final table in SyncConfig.syncableTables) {
      int deleted = 0;

      try {
        // Delete records locally if they are marked as deleted AND have been fully synced to cloud
        try {
          deleted = await db.delete(
            table,
            where: '(_is_deleted = 1 OR is_active = 0) AND _sync_status = ?',
            whereArgs: ['synced'],
          );
        } catch (_) {
          // Column might not exist
          try {
            deleted = await db.delete(
              table,
              where: 'is_active = 0 AND _sync_status = ?',
              whereArgs: ['synced'],
            );
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('SyncCleanup: $table local delete failed - $e');
      }

      if (deleted > 0) {
        report[table] = deleted;
        debugPrint('SyncCleanup: $table → deleted $deleted locally');
      }
    }

    status.value = SyncStatus.upToDate;
    statusMessage.value = 'Hoàn tất dọn dẹp bộ nhớ';

    return report;
  }

  /// Instant push - for critical data that needs immediate sync
  Future<bool> pushImmediate({
    required String table,
    required Map<String, dynamic> data,
  }) async {
    if (!SupabaseConfig.isConfigured) return false;

    try {
      final sanitized = _sanitizeForCloud(table, data);
      await SupabaseRestClient.to.upsert(table, sanitized);
      return true;
    } catch (e) {
      debugPrint('SyncEngine: Immediate push failed - $e');
      return false;
    }
  }

  /// Force sync now
  Future<void> forceSync() => syncAll();

  // Helper methods

  Future<int> _getLastSyncVersion(String table) async {
    final db = await DatabaseProvider.instance.database;
    final result = await db.query(
      '_sync_meta',
      where: 'table_name = ?',
      whereArgs: [table],
    );
    if (result.isEmpty) return 0;
    return result.first['last_version'] as int? ?? 0;
  }

  Future<void> _setLastSyncVersion(String table, int version) async {
    final db = await DatabaseProvider.instance.database;
    await db.insert('_sync_meta', {
      'table_name': table,
      'last_version': version,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String> _getLastSyncTime(String table) async {
    final db = await DatabaseProvider.instance.database;
    final result = await db.query(
      '_sync_meta',
      where: 'table_name = ?',
      whereArgs: [table],
    );
    if (result.isEmpty) return '';
    return result.first['last_sync_time'] as String? ?? '';
  }

  Future<void> _setLastSyncTime(String table, String timestamp) async {
    final db = await DatabaseProvider.instance.database;
    // Ensure last_sync_time column exists
    try {
      await db.execute("ALTER TABLE _sync_meta ADD COLUMN last_sync_time TEXT");
    } catch (_) {}
    await db.insert('_sync_meta', {
      'table_name': table,
      'last_sync_time': timestamp,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String> _getDeviceId() async {
    // TODO: Implement proper device ID (use device_info_plus)
    return 'device_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Supabase column whitelist per table — ONLY these columns are sent
  /// NOTE: is_deleted is included on ALL tables for unified soft-delete sync
  static const _supabaseColumns = <String, List<String>>{
    'customers': [
      'id',
      'clinic_id',
      'phone',
      'name',
      'address',
      'email',
      'notes',
      'is_active',
      'is_deleted',
      'created_at',
      'updated_at',
    ],
    'pets': [
      'id',
      'clinic_id',
      'customer_id',
      'name',
      'species',
      'breed',
      'gender',
      'date_of_birth',
      'color',
      'microchip_id',
      'notes',
      'is_active',
      'is_deleted',
      'created_at',
      'updated_at',
    ],
    'medicines': [
      'id',
      'clinic_id',
      'code',
      'name',
      'unit',
      'base_price',
      'cost_price',
      'current_stock',
      'min_stock_alert',
      'category',
      'is_active',
      'is_deleted',
      'created_at',
      'updated_at',
    ],
    'products': [
      'id',
      'clinic_id',
      'name',
      'brand',
      'category',
      'sale_price',
      'cost_price',
      'current_stock',
      'image_url',
      'is_active',
      'is_deleted',
      'created_at',
      'updated_at',
    ],
    'services': [
      'id',
      'clinic_id',
      'name',
      'category',
      'base_price',
      'unit',
      'is_active',
      'is_deleted',
      'created_at',
      'updated_at',
    ],
    'staff': [
      'id',
      'clinic_id',
      'name',
      'phone',
      'role',
      'email',
      'is_active',
      'is_deleted',
      'created_at',
      'updated_at',
    ],
    'appointments': [
      'id',
      'clinic_id',
      'customer_id',
      'pet_id',
      'appointment_date',
      'time',
      'reason',
      'status',
      'notes',
      'staff_id',
      'is_active',
      'is_deleted',
      'created_at',
      'updated_at',
    ],
    'medical_cases': [
      'id',
      'clinic_id',
      'case_code',
      'customer_id',
      'customer_name',
      'customer_phone',
      'pet_id',
      'pet_name',
      'pet_species',
      'admission_date',
      'discharge_date',
      'visit_reasons',
      'reason_notes',
      'vital_signs',
      'diagnosis',
      'prognosis',
      'treatment_plan',
      'total_estimate',
      'advance_payment',
      'advance_payment_method',
      'payment_method',
      'status',
      'result',
      'notes',
      'staff_id',
      'customer_signature',
      'clinic_signature',
      'agree_treatment',
      'agree_no_complaint',
      'is_active',
      'is_deleted',
      'created_at',
      'updated_at',
    ],
    'case_services': [
      'id',
      'clinic_id',
      'case_id',
      'service_id',
      'service_name',
      'quantity',
      'unit_price',
      'discount',
      'total',
      'notes',
      'medicines_json',
      'is_deleted',
      'created_at',
      'updated_at',
    ],
    'medicine_transactions': [
      'id',
      'clinic_id',
      'medicine_id',
      'type',
      'quantity',
      'unit_price',
      'case_id',
      'lot_number',
      'purpose',
      'staff_id',
      'notes',
      'transaction_date',
      'is_deleted',
      'created_at',
      'updated_at',
    ],
    'product_sales': [
      'id',
      'clinic_id',
      'product_id',
      'product_name',
      'quantity',
      'unit_price',
      'total',
      'customer_id',
      'staff_id',
      'payment_method',
      'sale_date',
      'is_deleted',
      'created_at',
      'updated_at',
    ],
    'cages': [
      'id',
      'clinic_id',
      'name',
      'type',
      'status',
      'price',
      'order_index',
      'is_active',
      'is_deleted',
      'created_at',
      'updated_at',
    ],
    'hospitalizations': [
      'id',
      'clinic_id',
      'case_id',
      'pet_id',
      'cage_id',
      'staff_id',
      'admission_date',
      'discharge_date',
      'cage_number',
      'status',
      'price',
      'notes',
      'is_active',
      'is_deleted',
      'created_at',
      'updated_at',
    ],
    'hospitalization_dailies': [
      'id',
      'clinic_id',
      'hospitalization_id',
      'date',
      'note',
      'is_deleted',
      'created_at',
      'updated_at',
    ],
    'hospitalization_treatments': [
      'id',
      'clinic_id',
      'daily_id',
      'type',
      'name',
      'ref_id',
      'time_scheduled',
      'time_performed',
      'quantity',
      'unit',
      'dosage',
      'status',
      'performer_id',
      'notes',
      'is_deleted',
      'created_at',
      'updated_at',
    ],
    'vital_sign_logs': [
      'id',
      'clinic_id',
      'daily_id',
      'time',
      'temperature',
      'weight',
      'heart_rate',
      'respiratory_rate',
      'crt',
      'mucous_membrane',
      'faeces',
      'urine',
      'observer_id',
      'notes',
      'is_deleted',
      'created_at',
      'updated_at',
    ],
    'expenses': [
      'id',
      'clinic_id',
      'date',
      'content',
      'category',
      'amount',
      'quantity',
      'unit',
      'unit_price',
      'staff_id',
      'type',
      'payment_method',
      'notes',
      'is_active',
      'is_deleted',
      'created_at',
      'updated_at',
    ],
    'hospitalization_regimens': [
      'id',
      'clinic_id',
      'name',
      'description',
      'items_json',
      'is_active',
      'is_deleted',
      'created_at',
      'updated_at',
    ],
    'case_attachments': [
      'id',
      'clinic_id',
      'case_id',
      'case_service_id',
      'file_name',
      'file_type',
      'category',
      'local_path',
      'remote_url',
      'thumbnail_path',
      'storage_path',
      'note',
      'file_size',
      'uploaded_by',
      'sync_status',
      'is_active',
      'is_deleted',
      'created_at',
      'updated_at',
    ],
    'hospitalization_reservations': [
      'id',
      'clinic_id',
      'cage_id',
      'pet_id',
      'customer_id',
      'start_date',
      'end_date',
      'note',
      'status',
      'is_deleted',
      'created_at',
      'updated_at',
    ],
    'case_logs': [
      'id',
      'clinic_id',
      'case_id',
      'staff_id',
      'action',
      'notes',
      'metadata',
      'is_deleted',
      'created_at',
      'updated_at',
    ],
  };

  /// Boolean columns in Supabase that SQLite might store as 0/1
  static const _booleanColumns = {
    'is_active',
    'agree_treatment',
    'agree_no_complaint',
  };

  /// Tables where is_active is INTEGER (not BOOLEAN) in Supabase
  /// NONE — new schema uses BOOLEAN for all boolean columns
  static const _integerBoolTables = <String>{};

  Map<String, dynamic> _sanitizeForCloud(
    String table,
    Map<String, dynamic> data,
  ) {
    final clean = Map<String, dynamic>.from(data);

    // Step 1: Column renames (local → cloud) BEFORE whitelist filtering
    if (table == 'medicines') {
      if (clean.containsKey('avg_price')) {
        clean['base_price'] = clean.remove('avg_price');
      }
      if (clean.containsKey('stock')) {
        clean['current_stock'] = clean.remove('stock');
      }
      if (clean.containsKey('min_stock')) {
        clean['min_stock_alert'] = clean.remove('min_stock');
      }
    }

    if (table == 'products') {
      if (clean.containsKey('stock')) {
        clean['current_stock'] = clean.remove('stock');
      }
    }

    if (table == 'pets') {
      // Normalize gender
      if (clean['gender'] is String) {
        final g = (clean['gender'] as String).toLowerCase();
        if (g.contains('đực') || g.contains('duc') || g.contains('nam')) {
          clean['gender'] = 'male';
        } else if (g.contains('cái') || g.contains('cai') || g.contains('nữ')) {
          clean['gender'] = 'female';
        }
      }
    }

    // Step 1b: Map _is_deleted (SQLite INTEGER) → is_deleted (Supabase BOOLEAN)
    if (clean.containsKey('_is_deleted')) {
      final val = clean.remove('_is_deleted');
      clean['is_deleted'] = (val == 1 || val == true || val == '1');
    }

    // Step 2: ALWAYS set clinic_id from auth context (ensures RLS compliance)
    if (Get.isRegistered<AuthService>()) {
      final authClinicId = AuthService.to.currentProfile.value?.clinicId;
      if (authClinicId != null) {
        clean['clinic_id'] = authClinicId;
      }
    }

    // Step 3: Type conversions
    // Convert boolean columns from int/String to bool for Supabase
    // Skip for tables that use INTEGER instead of BOOLEAN
    if (!_integerBoolTables.contains(table)) {
      for (final col in _booleanColumns) {
        if (clean.containsKey(col)) {
          final v = clean[col];
          if (v is int) {
            clean[col] = v == 1;
          } else if (v is String) {
            clean[col] = v == '1' || v.toLowerCase() == 'true';
          }
        }
      }
    } else {
      // For INTEGER boolean tables, ensure is_active is int
      for (final col in _booleanColumns) {
        if (clean.containsKey(col)) {
          final v = clean[col];
          if (v is bool) {
            clean[col] = v ? 1 : 0;
          } else if (v is String) {
            clean[col] = (v == '1' || v.toLowerCase() == 'true') ? 1 : 0;
          }
        }
      }
    }

    // Convert double to int for Supabase BIGINT columns
    // SQLite stores as REAL (80000.0) → Supabase needs integer (80000)
    const intColumns = {
      // Currency (BIGINT in new schema)
      'price', 'base_price', 'cost_price', 'sale_price', 'unit_price',
      'total', 'amount', 'total_estimate', 'advance_payment',
      // Other integer columns
      'heart_rate', 'respiratory_rate', 'order_index', 'file_size',
    };
    for (final col in intColumns) {
      if (clean.containsKey(col) && clean[col] is double) {
        clean[col] = (clean[col] as double).toInt();
      }
    }

    // Validate UUID fields — both primary key 'id' and foreign keys '_id'
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );

    // Tables where id is TEXT (not UUID) in Supabase
    const textIdTables = {'case_attachments'};

    // Validate main 'id' field — must be UUID for most tables
    if (!textIdTables.contains(table) && clean['id'] is String) {
      final id = clean['id'] as String;
      if (!uuidPattern.hasMatch(id)) {
        // Non-UUID primary key — generate deterministic UUID from old ID
        // Uses UUID v5 namespace approach: consistent mapping old→new
        debugPrint(
          'SyncSanitize: $table.id has non-UUID value "$id", skipping record',
        );
        throw Exception(
          'Record $table/$id has non-UUID primary key, cannot sync',
        );
      }
    }

    // Validate foreign key fields — ALL must be UUID (Supabase uses UUID for all FK)
    final keysToFix = <String, dynamic>{};
    clean.forEach((key, value) {
      if (key.endsWith('_id') && key != 'clinic_id' && key != 'id') {
        if (value is String) {
          if (value.isEmpty) {
            keysToFix[key] = null;
          } else if (!uuidPattern.hasMatch(value)) {
            debugPrint(
              'SyncSanitize: $table.$key has non-UUID value "$value", nullifying',
            );
            keysToFix[key] = null;
          }
        }
      }
    });
    clean.addAll(keysToFix);

    // Decode JSON strings for JSONB columns before pushing to Supabase
    // SQLite stores these as TEXT, but Supabase API expects actual JSON arrays/objects
    const jsonbColumns = {
      'medicines_json',
      'items_json',
      'preferences',
      'settings',
    };
    for (final col in jsonbColumns) {
      if (clean.containsKey(col) && clean[col] is String) {
        try {
          // Only decode if it starts with valid JSON characters
          final str = clean[col] as String;
          if (str.startsWith('[') || str.startsWith('{')) {
            clean[col] = jsonDecode(str);
          }
        } catch (e) {
          debugPrint(
            'SyncSanitize: Failed to decode JSON for $table.$col - $e',
          );
        }
      }
    }

    // Step 4: WHITELIST FILTER — only send columns that exist in Supabase
    // This replaces universal stripping of _sync_status, synced, _is_deleted, _version
    // Each table's whitelist defines exactly what columns are allowed
    final allowedColumns = _supabaseColumns[table];
    if (allowedColumns != null) {
      clean.removeWhere((key, _) => !allowedColumns.contains(key));
    }

    return clean;
  }

  /// Local SQLite column whitelist per table — ONLY these columns exist locally
  /// This prevents "no such column" errors when cloud returns extra fields
  static const _localColumns = <String, List<String>>{
    'customers': [
      'id',
      'clinic_id',
      'phone',
      'name',
      'address',
      'created_at',
      'updated_at',
      'synced',
      'sync_status',
      '_sync_status',
      '_is_deleted',
      '_version',
    ],
    'pets': [
      'id',
      'clinic_id',
      'customer_id',
      'name',
      'species',
      'breed',
      'age',
      'gender',
      'weight',
      'notes',
      'created_at',
      'updated_at',
      'synced',
      'sync_status',
      '_sync_status',
      '_is_deleted',
      '_version',
    ],
    'medical_cases': [
      'id',
      'clinic_id',
      'case_code',
      'customer_id',
      'customer_name',
      'customer_phone',
      'pet_id',
      'pet_name',
      'pet_species',
      'admission_date',
      'discharge_date',
      'visit_reasons',
      'reason_notes',
      'vital_signs',
      'diagnosis',
      'prognosis',
      'treatment_plan',
      'total_estimate',
      'advance_payment',
      'advance_payment_method',
      'payment_method',
      'customer_signature',
      'clinic_signature',
      'agree_treatment',
      'agree_no_complaint',
      'status',
      'result',
      'notes',
      'staff_id',
      'created_at',
      'updated_at',
      'synced',
      'sync_status',
      '_sync_status',
      '_is_deleted',
      '_version',
    ],
    'services': [
      'id',
      'clinic_id',
      'name',
      'category',
      'base_price',
      'unit',
      'is_active',
      'created_at',
      'updated_at',
      'synced',
      'sync_status',
      '_sync_status',
      '_is_deleted',
      '_version',
    ],
    'case_services': [
      'id',
      'clinic_id',
      'case_id',
      'service_id',
      'service_name',
      'quantity',
      'unit_price',
      'discount',
      'total',
      'notes',
      'medicines_json',
      'created_at',
      'updated_at',
      'synced',
      '_sync_status',
      '_is_deleted',
      '_version',
    ],
    'medicines': [
      'id',
      'clinic_id',
      'code',
      'name',
      'unit',
      'avg_price',
      'stock',
      'min_stock',
      'lot_number',
      'expiry_date',
      'supplier',
      'is_active',
      'created_at',
      'updated_at',
      'synced',
      'sync_status',
      '_sync_status',
      '_is_deleted',
      '_version',
    ],
    'medicine_transactions': [
      'id',
      'clinic_id',
      'medicine_id',
      'type',
      'quantity',
      'unit_price',
      'case_id',
      'lot_number',
      'purpose',
      'staff_id',
      'notes',
      'transaction_date',
      'created_at',
      'updated_at',
      'synced',
      '_sync_status',
      '_is_deleted',
      '_version',
    ],
    'products': [
      'id',
      'clinic_id',
      'name',
      'brand',
      'sale_price',
      'cost_price',
      'stock',
      'category',
      'image_url',
      'is_active',
      'created_at',
      'updated_at',
      'synced',
      'sync_status',
      '_sync_status',
      '_is_deleted',
      '_version',
    ],
    'product_sales': [
      'id',
      'clinic_id',
      'product_id',
      'product_name',
      'quantity',
      'unit_price',
      'total',
      'customer_id',
      'staff_id',
      'payment_method',
      'sale_date',
      'created_at',
      'updated_at',
      'synced',
      '_sync_status',
      '_is_deleted',
      '_version',
    ],
    'appointments': [
      'id',
      'clinic_id',
      'customer_id',
      'pet_id',
      'appointment_date',
      'time',
      'reason',
      'status',
      'notes',
      'staff_id',
      'created_at',
      'updated_at',
      'synced',
      'sync_status',
      '_sync_status',
      '_is_deleted',
      '_version',
    ],
    'staff': [
      'id',
      'clinic_id',
      'name',
      'phone',
      'role',
      'email',
      'is_active',
      'created_at',
      'updated_at',
      'synced',
      'sync_status',
      '_sync_status',
      '_is_deleted',
      '_version',
    ],
    'cages': [
      'id',
      'clinic_id',
      'name',
      'type',
      'status',
      'price',
      'order_index',
      'created_at',
      'updated_at',
      'synced',
      '_sync_status',
      '_is_deleted',
      '_version',
    ],
    'hospitalizations': [
      'id',
      'clinic_id',
      'case_id',
      'pet_id',
      'staff_id',
      'admission_date',
      'discharge_date',
      'cage_number',
      'cage_id',
      'price',
      'status',
      'notes',
      'created_at',
      'updated_at',
      'synced',
      'sync_status',
      '_sync_status',
      '_is_deleted',
      '_version',
    ],
    'hospitalization_dailies': [
      'id',
      'clinic_id',
      'hospitalization_id',
      'date',
      'note',
      'created_at',
      'updated_at',
      'synced',
      '_sync_status',
      '_is_deleted',
      '_version',
    ],
    'hospitalization_treatments': [
      'id',
      'clinic_id',
      'daily_id',
      'type',
      'name',
      'ref_id',
      'time_scheduled',
      'time_performed',
      'quantity',
      'unit',
      'dosage',
      'status',
      'performer_id',
      'notes',
      'created_at',
      'updated_at',
      'synced',
      '_sync_status',
      '_is_deleted',
      '_version',
    ],
    'vital_sign_logs': [
      'id',
      'clinic_id',
      'daily_id',
      'time',
      'temperature',
      'weight',
      'heart_rate',
      'respiratory_rate',
      'crt',
      'mucous_membrane',
      'faeces',
      'urine',
      'observer_id',
      'notes',
      'created_at',
      'updated_at',
      'synced',
      '_sync_status',
      '_is_deleted',
      '_version',
    ],
    'expenses': [
      'id',
      'clinic_id',
      'date',
      'content',
      'category',
      'amount',
      'quantity',
      'unit',
      'unit_price',
      'staff_id',
      'type',
      'payment_method',
      'notes',
      'created_at',
      'updated_at',
      'synced',
      '_sync_status',
      '_is_deleted',
      '_version',
    ],
    'hospitalization_regimens': [
      'id',
      'clinic_id',
      'name',
      'description',
      'items_json',
      'is_active',
      'created_at',
      'updated_at',
      'synced',
      '_sync_status',
      '_is_deleted',
      '_version',
    ],
    'case_attachments': [
      'id',
      'clinic_id',
      'case_id',
      'case_service_id',
      'file_name',
      'file_type',
      'category',
      'local_path',
      'remote_url',
      'thumbnail_path',
      'note',
      'file_size',
      'uploaded_by',
      'sync_status',
      'is_active',
      '_sync_status',
      '_is_deleted',
      'created_at',
      'updated_at',
    ],
    'hospitalization_reservations': [
      'id',
      'clinic_id',
      'cage_id',
      'pet_id',
      'customer_id',
      'start_date',
      'end_date',
      'note',
      'status',
      '_sync_status',
      '_is_deleted',
      '_version',
      'created_at',
      'updated_at',
    ],
    'case_logs': [
      'id',
      'clinic_id',
      'case_id',
      'staff_id',
      'action',
      'notes',
      'metadata',
      'created_at',
      'updated_at',
      'synced',
      '_sync_status',
      '_is_deleted',
      '_version',
    ],
  };

  Map<String, dynamic> _sanitizeForLocal(
    String table,
    Map<String, dynamic> data,
  ) {
    final clean = Map<String, dynamic>.from(data);

    // Remove cloud-only fields
    clean.remove('_version');

    // Map is_deleted (Supabase BOOLEAN) → _is_deleted (SQLite INTEGER)
    if (clean.containsKey('is_deleted')) {
      final val = clean.remove('is_deleted');
      clean['_is_deleted'] = (val == true || val == 1 || val == '1') ? 1 : 0;
    }

    // Table-specific reverse mapping (cloud → local)
    if (table == 'medicines') {
      if (clean.containsKey('base_price')) {
        clean['avg_price'] = clean.remove('base_price');
      }
      if (clean.containsKey('cost_price') && !clean.containsKey('avg_price')) {
        clean['avg_price'] = clean.remove('cost_price');
      }
      if (clean.containsKey('current_stock')) {
        clean['stock'] = clean.remove('current_stock');
      }
      if (clean.containsKey('min_stock_alert')) {
        clean['min_stock'] = clean.remove('min_stock_alert');
      }
    }

    if (table == 'products') {
      if (clean.containsKey('current_stock')) {
        clean['stock'] = clean.remove('current_stock');
      }
    }

    // Convert booleans to integers for SQLite (SQLite has no bool type)
    for (final key in clean.keys.toList()) {
      final value = clean[key];
      if (value is bool) {
        clean[key] = value ? 1 : 0;
      } else if (value is List || value is Map) {
        // Encode JSON arrays/objects to strings for SQLite TEXT columns
        // (medicines_json, items_json, preferences, settings, etc.)
        clean[key] = jsonEncode(value);
      }
    }

    // WHITELIST FILTER — only keep columns that exist in local SQLite schema
    // This prevents "no such column" errors when cloud has extra fields
    final allowedColumns = _localColumns[table];
    if (allowedColumns != null) {
      clean.removeWhere((key, _) => !allowedColumns.contains(key));
    }

    return clean;
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  void onClose() {
    _autoSyncTimer?.cancel();
    _debounceTimer?.cancel();
    super.onClose();
  }
}
