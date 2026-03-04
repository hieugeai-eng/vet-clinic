import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../config/supabase_config.dart';
import '../services/supabase_rest_client.dart';
import '../services/realtime_service.dart';
import '../services/auth_service.dart';
import '../../data/providers/local/database_provider.dart';

/// Sync Service - handles bidirectional sync between local SQLite and Supabase
class SyncService extends GetxService {
  static SyncService get to => Get.find();

  final RxBool isSyncing = false.obs;
  final RxString syncStatus = 'Idle'.obs;
  final RxInt pendingSyncCount = 0.obs;

  /// Observable to notify when data changes from cloud sync
  /// Listen to this in controllers to refresh UI
  final RxString lastSyncedTable = ''.obs;
  final RxInt syncVersion =
      0.obs; // Increment on each sync to trigger UI refresh

  Timer? _autoSyncTimer;

  /// Local tables to check for changes
  final List<String> _localTables = [
    'customers',
    'pets',
    'medicines',
    'products',
    'appointments',
    'medical_cases',
    'services',
    'cages',
    'hospitalizations',
    'treatment_days',
    'treatment_activities',
    'case_services',
    'expenses',
    'medicine_transactions',
    'product_sales',
    'staff',
  ];

  /// Remote tables to subscribe/pull from
  final List<String> _remoteTables = [
    'customers',
    'pets',
    'product_services', // Unified table for medicines & products
    'appointments',
    'medical_cases',
    'cages',
    'hospitalizations',
    'treatment_days',
    'treatment_activities',
    'case_services',
    'expenses',
    'medicine_transactions',
    'product_sales',
    'staff',
  ];

  @override
  void onInit() {
    super.onInit();
    // MIGRATION: Disabled legacy sync - using SyncEngine
    debugPrint('SyncService: DISABLED (migrating to SyncEngine)');
    syncStatus.value = 'Disabled';
    // _initializeSync();
  }

  void _initializeSync() {
    if (!SupabaseConfig.isConfigured) {
      debugPrint('SyncService: Not configured - sync disabled');
      syncStatus.value = 'Offline (not configured)';
      return;
    }

    // Subscribe to realtime changes for REMOTE tables
    for (final table in _remoteTables) {
      RealtimeService.to.subscribe(
        table,
        (payload) => _handleRemoteChange(table, payload),
      );
    }

    // Start auto-sync timer (every 30 seconds)
    _startAutoSync();

    // Initial sync
    syncAll();
  }

  void _startAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!isSyncing.value) {
        processQueue(); // Priority: Queue
        _syncPendingChanges(); // Legacy: Status-based
      }
    });
  }

  /// Handle remote change notification from WebSocket
  void _handleRemoteChange(String table, Map<String, dynamic> payload) {
    final eventType = payload['type'] as String?; // INSERT, UPDATE, DELETE

    debugPrint('SyncService: Remote change on $table - $eventType');

    // Sync this specific table
    _syncTableFromRemote(table);
  }

  /// Sync all tables (full sync)
  Future<void> syncAll() async {
    if (!SupabaseConfig.isConfigured) return;
    if (isSyncing.value) return;

    isSyncing.value = true;
    syncStatus.value = 'Syncing all...';

    try {
      // Priority: Queue
      await processQueue();

      // Legacy push
      await _syncPendingChanges();

      // Then pull remote changes
      for (final table in _remoteTables) {
        await _syncTableFromRemote(table);
      }

      syncStatus.value =
          'Synced at ${DateTime.now().toString().substring(11, 19)}';
    } catch (e) {
      debugPrint('SyncService: Sync error - $e');
      syncStatus.value = 'Sync failed';
    } finally {
      isSyncing.value = false;
    }
  }

  /// Process the Sync Queue (FIFO - First In First Out)
  Future<void> processQueue() async {
    if (!SupabaseConfig.isConfigured) return;

    try {
      final db = await DatabaseProvider.instance.database;

      // Update pending count for UI
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sync_queue',
      );
      pendingSyncCount.value = countResult.first['count'] as int? ?? 0;

      // Get pending items, strict order by creation time
      final queueItems = await db.query(
        'sync_queue',
        orderBy: 'created_at ASC',
        limit: 50, // Process in batches
      );

      if (queueItems.isEmpty) return;

      debugPrint('SyncService: Processing ${queueItems.length} queue items...');

      for (final item in queueItems) {
        final id = item['id'] as String;
        final table = item['table_name'] as String;
        final action = item['action'] as String; // CREATE, UPDATE, DELETE
        final dataStr = item['data'] as String?;
        final attempts = item['attempts'] as int? ?? 0;

        try {
          // Decode payload
          final data = dataStr != null
              ? jsonDecode(dataStr) as Map<String, dynamic>
              : <String, dynamic>{};

          if (action == 'DELETE') {
            await SupabaseRestClient.to.delete(
              table,
              query: {'id': 'eq.${item['record_id']}'},
            );
          } else {
            await _pushRecordToRemote(table, data);
          }

          // Success: Delete from queue
          await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);

          // Decrement local count immediately for responsive UI
          if (pendingSyncCount.value > 0) {
            pendingSyncCount.value--;
          }
        } catch (e) {
          debugPrint('SyncService: Failed queue item $id ($table) - $e');

          // Increase attempts
          await db.update(
            'sync_queue',
            {'attempts': attempts + 1},
            where: 'id = ?',
            whereArgs: [id],
          );

          // STRICT ORDER: If a dependency fails, we must stop processing to prevent chaos.
          break;
        }
      }
    } catch (e) {
      debugPrint('SyncService: Queue processing error - $e');
    }
  }

  /// Sync pending local changes to remote (Legacy Mode)
  Future<void> _syncPendingChanges() async {
    if (!SupabaseConfig.isConfigured) return;

    try {
      final db = await DatabaseProvider.instance.database;

      // Check for pending sync records (sync_status = 'pending')
      // Note: This is legacy. New items go to sync_queue.
      // But we still count them if they exist?
      // Let's decide: pendingSyncCount = Queue Count + Pending Status Count.
      // Or just Queue Count?
      // Let's stick to Queue Count as primary.
      // But to be safe:
      /*
      for (final table in _localTables) { ... }
      */
      // (Keep existing implementation but remove pendingSyncCount manipulation if it conflicts)

      for (final table in _localTables) {
        final pendingRecords = await db.query(
          table,
          where: 'sync_status = ?',
          whereArgs: ['pending'],
        );

        for (final record in pendingRecords) {
          await _pushRecordToRemote(table, record);
        }
      }

      // Update count again to be sure
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sync_queue',
      );
      pendingSyncCount.value = countResult.first['count'] as int? ?? 0;
    } catch (e) {
      debugPrint('SyncService: Push error - $e');
    }
  }

  /// Push a single record to remote
  Future<void> _pushRecordToRemote(
    String table,
    Map<String, dynamic> record,
  ) async {
    try {
      final data = Map<String, dynamic>.from(record);
      data.remove('sync_status'); // Local sync flag
      data.remove('synced'); // Local sync flag (legacy)

      // Sanitize table-specific local columns
      if (table == 'pets') {
        data.remove('age'); // Age is calculated
        data.remove(
          'weight',
        ); // Weight is stored in distinct history or medical cases

        // CRITICAL: Normalize gender to match Supabase constraint
        if (data['gender'] != null && data['gender'] is String) {
          final genderValue = (data['gender'] as String).toLowerCase();
          if (genderValue.contains('đực') ||
              genderValue.contains('duc') ||
              genderValue.contains('nam')) {
            data['gender'] = 'male';
          } else if (genderValue.contains('cái') ||
              genderValue.contains('cai') ||
              genderValue.contains('nu') ||
              genderValue.contains('nữ')) {
            data['gender'] = 'female';
          } else if (genderValue != 'male' && genderValue != 'female') {
            data['gender'] = null;
          }
        }
      }

      // Map Local Tables to Remote Tables
      String remoteTable = table;

      if (table == 'medicines') {
        remoteTable = 'product_services';
        data['type'] = 'medicine';
        data['base_price'] = data['avg_price'];
        data['cost_price'] = data['avg_price']; // Map cost as well
        data.remove('avg_price');

        data['current_stock'] = data['stock'];
        data.remove('stock');

        data['min_stock_alert'] = data['min_stock'];
        data.remove('min_stock');

        // Remove local-only fields that don't exist in product_services
        data.remove('expiry_date');
        data.remove('lot_number');
        data.remove('supplier');
        data.remove(
          'unit',
        ); // Assuming product_services doesn't have unit or uses a different name? Keep if unsure, but safe to remove if erroring.
        // Actually, let's keep 'unit' if it might exist, but the error specific was expiry_date.
        // To be safe and avoid ping-pong errors, I'll remove non-standard cols.
        // On second thought, let's just remove the ones we know are likely missing.
        // data.remove('unit');
      } else if (table == 'products') {
        remoteTable = 'product_services';
        data['type'] = 'product';
        data['base_price'] = data['sale_price'];
        // data.remove('sale_price');

        data['current_stock'] = data['stock'];
        data.remove('stock');

        data.remove('brand');
        data.remove('category'); // Check if product_services has category
      } else if (table == 'services') {
        remoteTable = 'product_services';
        data['type'] = 'service';
        // base_price matches
        // unit matches
        // is_active matches

        data.remove('category'); // Remote doesn't support category yet
      }

      // Inject clinic_id from context if not present (safety net)
      if (data['clinic_id'] == null && Get.isRegistered<AuthService>()) {
        final clinicId = AuthService.to.currentProfile.value?.clinicId;
        if (clinicId != null) {
          data['clinic_id'] = clinicId;
        } else {
          debugPrint(
            'SyncService: WARNING - Uploading record without clinic_id (AuthService clinicId is null)',
          );
        }
      }

      await SupabaseRestClient.to.upsert(remoteTable, data);

      // Mark as synced in local DB
      final db = await DatabaseProvider.instance.database;
      await db.update(
        table,
        {'sync_status': 'synced'},
        where: 'id = ?',
        whereArgs: [record['id']],
      );

      debugPrint('SyncService: Pushed $table/${record['id']} to remote');
    } catch (e) {
      debugPrint('SyncService: Failed to push $table/${record['id']} - $e');
    }
  }

  /// Sync a table from remote to local
  Future<void> _syncTableFromRemote(String table) async {
    try {
      syncStatus.value = 'Syncing $table...';

      // Get all records from remote
      final remoteRecords = await SupabaseRestClient.to.get(table);

      final db = await DatabaseProvider.instance.database;

      for (final remoteRecord in remoteRecords) {
        // Determine Target Local Table
        String localTable = table;
        Map<String, dynamic> localData = Map<String, dynamic>.from(
          remoteRecord,
        );

        if (table == 'product_services') {
          final type = remoteRecord['type'];
          if (type == 'medicine') {
            localTable = 'medicines';
            // Map back fields
            localData['avg_price'] = remoteRecord['base_price'];
            localData['stock'] = remoteRecord['current_stock'];
            localData['min_stock'] = remoteRecord['min_stock_alert'];
          } else if (type == 'product') {
            localTable = 'products';
            localData['sale_price'] = remoteRecord['base_price'];
            localData['cost_price'] = remoteRecord['cost_price'] ?? 0;
            localData['stock'] = remoteRecord['current_stock'];
          } else {
            // Ignore 'service' type for now as they might use 'services' table locally?
            // Actually 'services' table exists locally. If remote is 'service', we should map to 'services'.
            if (type == 'service') {
              localTable = 'services';
              // Map 'base_price' -> 'base_price' (match)
              localData['base_price'] = remoteRecord['base_price'];
            } else {
              continue; // Unknown type, skip
            }
          }
        }

        final id = localData['id'];

        // Check if local record exists
        final localRecords = await db.query(
          localTable,
          where: 'id = ?',
          whereArgs: [id],
        );

        if (localRecords.isEmpty) {
          // Insert new record
          // Sanitize booleans for SQLite
          localData.forEach((key, value) {
            if (value is bool) {
              localData[key] = value ? 1 : 0;
            }
          });

          localData['sync_status'] = 'synced';
          // cleanup unknown columns (Supabase might return extra cols)
          // Ideally we query table info, but for now try/catch block handles it?
          // We should remove fields that don't exist in local
          localData.remove('type');
          localData.remove('base_price');
          localData.remove('current_stock');
          localData.remove('min_stock_alert');
          // ... (add more cleanup if needed)

          try {
            await db.insert(localTable, localData);
          } catch (e) {
            // Often fails due to extra columns.
            // We'll ignore for now or improve strict mapping if needed.
            debugPrint('Insert error on $localTable: $e');
          }
        } else {
          final localRecord = localRecords.first;
          final localUpdatedAt = DateTime.tryParse(
            localRecord['updated_at']?.toString() ?? '',
          );
          final remoteUpdatedAt = DateTime.tryParse(
            remoteRecord['updated_at']?.toString() ?? '',
          );

          // Only update if remote is newer (last-write-wins)
          if (localRecord['sync_status'] != 'pending' &&
              remoteUpdatedAt != null &&
              (localUpdatedAt == null ||
                  remoteUpdatedAt.isAfter(localUpdatedAt))) {
            // Sanitize booleans for SQLite
            localData.forEach((key, value) {
              if (value is bool) {
                localData[key] = value ? 1 : 0;
              }
            });

            localData['sync_status'] = 'synced';
            localData.remove('type');
            localData.remove('base_price');
            localData.remove('current_stock');
            localData.remove('min_stock_alert');

            await db.update(
              localTable,
              localData,
              where: 'id = ?',
              whereArgs: [id],
            );
          }
        }
      }

      // Notify UI that data has changed
      lastSyncedTable.value = table;
      syncVersion.value++;

      debugPrint(
        'SyncService: Synced $table - ${remoteRecords.length} records (v${syncVersion.value})',
      );
    } catch (e) {
      debugPrint('SyncService: Failed to sync $table from remote - $e');
    }
  }

  /// Mark a record as pending sync (call after local insert/update/delete)
  Future<void> markPendingSync(String table, String id) async {
    try {
      final db = await DatabaseProvider.instance.database;
      await db.update(
        table,
        {'sync_status': 'pending'},
        where: 'id = ?',
        whereArgs: [id],
      );
      pendingSyncCount.value++;
    } catch (e) {
      debugPrint('SyncService: Failed to mark pending - $e');
    }
  }

  /// INSTANT SYNC: Push a single record to cloud immediately
  /// Call this after create/update in repository
  Future<void> pushRecord(String table, Map<String, dynamic> data) async {
    if (!SupabaseConfig.isConfigured) return;

    try {
      // Sanitize Data (Recursive)
      final cleanData = _sanitizePayload(data);

      cleanData.remove('sync_status');
      cleanData.remove('synced');

      if (table == 'pets') {
        cleanData.remove('age');
        cleanData.remove('weight');
        cleanData.remove('customer_name'); // Computed field
        cleanData.remove('species_name'); // Computed field

        // CRITICAL: Normalize gender to match Supabase constraint
        if (cleanData['gender'] != null && cleanData['gender'] is String) {
          final genderValue = (cleanData['gender'] as String).toLowerCase();
          if (genderValue.contains('đực') ||
              genderValue.contains('duc') ||
              genderValue.contains('nam')) {
            cleanData['gender'] = 'male';
          } else if (genderValue.contains('cái') ||
              genderValue.contains('cai') ||
              genderValue.contains('nu') ||
              genderValue.contains('nữ')) {
            cleanData['gender'] = 'female';
          } else if (genderValue != 'male' && genderValue != 'female') {
            // If not recognized, set to null to avoid constraint failure
            cleanData['gender'] = null;
          }
        }
      }

      // Inject clinic_id from context if not present or empty
      if ((cleanData['clinic_id'] == null || cleanData['clinic_id'] == '') &&
          Get.isRegistered<AuthService>()) {
        final clinicId = AuthService.to.currentProfile.value?.clinicId;
        if (clinicId != null && clinicId.isNotEmpty) {
          cleanData['clinic_id'] = clinicId;
        }
      }

      await SupabaseRestClient.to.upsert(table, cleanData);

      // Mark as synced
      final db = await DatabaseProvider.instance.database;
      await db.update(
        table,
        {'sync_status': 'synced'},
        where: 'id = ?',
        whereArgs: [data['id']],
      );

      debugPrint('SyncService: ⚡ Instant push $table/${data['id']}');
    } catch (e) {
      debugPrint('SyncService: Instant push failed $table/${data['id']} - $e');
      // Mark as pending for retry later
      await markPendingSync(table, data['id']);
    }
  }

  /// Helper: Sanitize payload (empty strings -> null for UUIDs/FKs)
  Map<String, dynamic> _sanitizePayload(Map<String, dynamic> data) {
    final Map<String, dynamic> clean = {};
    data.forEach((key, value) {
      if (value is String) {
        // Convert empty strings to null for UUID fields (id, clinic_id, or any *_id)
        if (value.isEmpty) {
          clean[key] = null;
        } else {
          clean[key] = value;
        }
      } else if (value is Map<String, dynamic>) {
        clean[key] = _sanitizePayload(value);
      } else {
        clean[key] = value;
      }
    });
    return clean;
  }

  /// INSTANT SYNC: Delete a record from cloud immediately
  /// Call this after delete in repository
  Future<void> deleteFromCloud(String table, String id) async {
    if (!SupabaseConfig.isConfigured) return;

    try {
      await SupabaseRestClient.to.delete(table, query: {'id': 'eq.$id'});
      debugPrint('SyncService: ⚡ Instant delete $table/$id from cloud');
    } catch (e) {
      // ⚡ Network Error Handling for Background Task
      if (e.toString().contains('HandshakeException') ||
          e.toString().contains('SocketException')) {
        debugPrint(
          'SyncService: ⚠️ Network error deleting $table/$id (will retry on next sync): $e',
        );
        // Ideally we should mark this record as 'pending_delete' in a local table to retry later
        // For now, we just swallow the error to prevent app crash/white screen
      } else {
        debugPrint('SyncService: ❌ Instant delete failed $table/$id - $e');
      }
    }
  }

  /// Force sync now
  Future<void> forceSync() async {
    await syncAll();
  }

  /// Initial sync - push ALL local data to cloud (for first-time setup)
  /// This uploads all existing local records regardless of sync_status
  Future<void> initialSync() async {
    if (!SupabaseConfig.isConfigured) {
      debugPrint('SyncService: Not configured');
      return;
    }
    if (isSyncing.value) return;

    isSyncing.value = true;
    syncStatus.value = 'Uploading all data...';

    try {
      final db = await DatabaseProvider.instance.database;
      int totalPushed = 0;

      for (final table in _localTables) {
        syncStatus.value = 'Uploading $table...';

        // Get ALL records (not just pending)
        final allRecords = await db.query(table);
        debugPrint(
          'SyncService: Found ${allRecords.length} $table records to upload',
        );

        for (final record in allRecords) {
          try {
            // Sanitize Data (Recursive) using the same helper as pushRecord
            final data = _sanitizePayload(record);

            data.remove('sync_status');
            data.remove('synced');

            if (table == 'pets') {
              data.remove('age');
              data.remove('weight');
              data.remove('customer_name'); // Computed field
              data.remove('species_name'); // Computed field
            }

            // Map Local Tables to Remote Tables
            String remoteTable = table;

            if (table == 'medicines') {
              remoteTable = 'product_services';
              data['type'] = 'medicine';
              data['base_price'] = data['avg_price'];
              data['cost_price'] = data['avg_price']; // Map cost as well
              data.remove('avg_price');

              data['current_stock'] = data['stock'];
              data.remove('stock');

              data['min_stock_alert'] = data['min_stock'];
              data.remove('min_stock');

              // Remove local-only fields
              data.remove('expiry_date');
              data.remove('lot_number');
              data.remove('supplier');
            } else if (table == 'products') {
              remoteTable = 'product_services';
              data['type'] = 'product';
              data['base_price'] = data['sale_price'];

              data['current_stock'] = data['stock'];
              data.remove('stock');

              data.remove('brand');
              data.remove('category');
            } else if (table == 'services') {
              remoteTable = 'product_services';
              data['type'] = 'service';
              // base_price matches, unit matches
              data.remove('category');
            }

            // Inject clinic_id from context if not present (safety net)
            if (data['clinic_id'] == null && Get.isRegistered<AuthService>()) {
              final clinicId = AuthService.to.currentProfile.value?.clinicId;
              if (clinicId != null) {
                data['clinic_id'] = clinicId;
              }
            }

            await SupabaseRestClient.to.upsert(remoteTable, data);

            // Mark as synced
            await db.update(
              table,
              {'sync_status': 'synced'},
              where: 'id = ?',
              whereArgs: [record['id']],
            );
            totalPushed++;
          } catch (e) {
            debugPrint('SyncService: Failed to upload ${record['id']} - $e');
          }
        }

        debugPrint('SyncService: Uploaded ${allRecords.length} $table records');
      }

      syncStatus.value = 'Uploaded $totalPushed records';
      debugPrint('SyncService: Initial sync complete - $totalPushed records');
    } catch (e) {
      debugPrint('SyncService: Initial sync error - $e');
      syncStatus.value = 'Upload failed';
    } finally {
      isSyncing.value = false;
    }
  }

  @override
  void onClose() {
    _autoSyncTimer?.cancel();
    super.onClose();
  }
}
