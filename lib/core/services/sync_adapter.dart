/// Sync Service Adapter - Bridge between legacy SyncService and new SyncEngine
///
/// This adapter allows gradual migration from the old sync system
/// to the new enterprise-grade SyncEngine.
///
/// @deprecated Use SyncEngine directly for new code
library;

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../sync/sync_engine.dart';
import '../sync/change_tracker.dart';
import '../config/supabase_config.dart';
import 'sync_service.dart';

/// Adapter that delegates to either legacy SyncService or new SyncEngine
/// based on feature flags
class SyncAdapter extends GetxService {
  static SyncAdapter get to => Get.find();

  /// Feature flag: Use new SyncEngine
  /// Set to true to enable new sync architecture
  static const bool useNewEngine = true; // ENABLED for testing

  /// Check if currently syncing
  bool get isSyncing {
    if (useNewEngine && Get.isRegistered<SyncEngine>()) {
      return SyncEngine.to.status.value == SyncStatus.syncing;
    }
    if (Get.isRegistered<SyncService>()) {
      return SyncService.to.isSyncing.value;
    }
    return false;
  }

  /// Track a change for sync
  Future<void> trackChange({
    required String table,
    required String recordId,
    required String operation, // 'insert', 'update', 'delete'
    Map<String, dynamic>? oldData,
    Map<String, dynamic>? newData,
  }) async {
    if (useNewEngine && Get.isRegistered<SyncEngine>()) {
      final op = switch (operation) {
        'insert' => ChangeOperation.insert,
        'update' => ChangeOperation.update,
        'delete' => ChangeOperation.delete,
        _ => ChangeOperation.update,
      };

      await SyncEngine.to.trackChange(
        table: table,
        recordId: recordId,
        operation: op,
        oldData: oldData,
        newData: newData,
      );
    }
    // Legacy mode: sync_queue is handled directly in repositories
  }

  /// Push a record to cloud
  Future<void> pushRecord(String table, Map<String, dynamic> data) async {
    if (useNewEngine && Get.isRegistered<SyncEngine>()) {
      // New engine handles this via change tracking
      await trackChange(
        table: table,
        recordId: data['id'] as String,
        operation: 'update',
        newData: data,
      );
      return;
    }

    // Legacy mode
    if (Get.isRegistered<SyncService>()) {
      SyncService.to.pushRecord(table, data);
    }
  }

  /// Delete from cloud
  Future<void> deleteFromCloud(String table, String id) async {
    if (useNewEngine && Get.isRegistered<SyncEngine>()) {
      await trackChange(table: table, recordId: id, operation: 'delete');
      return;
    }

    // Legacy mode
    if (Get.isRegistered<SyncService>()) {
      SyncService.to.deleteFromCloud(table, id);
    }
  }

  /// Process sync queue
  Future<void> processQueue() async {
    if (useNewEngine && Get.isRegistered<SyncEngine>()) {
      await SyncEngine.to.syncAll();
      return;
    }

    // Legacy mode
    if (Get.isRegistered<SyncService>()) {
      SyncService.to.processQueue();
    }
  }

  /// Force full sync
  Future<void> forceSync() async {
    if (useNewEngine && Get.isRegistered<SyncEngine>()) {
      await SyncEngine.to.syncAll();
      return;
    }

    // Legacy mode
    if (Get.isRegistered<SyncService>()) {
      SyncService.to.forceSync();
    }
  }

  /// Check if cloud sync is available
  bool get isCloudEnabled {
    return SupabaseConfig.isConfigured;
  }
}
