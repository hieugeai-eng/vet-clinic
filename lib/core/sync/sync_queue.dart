/// Sync Queue - offline buffer for pending sync operations
///
/// FIFO queue that stores changes when offline and processes
/// them in order when connection is restored.
library;

import 'package:flutter/foundation.dart';
import 'change_tracker.dart';
import '../../data/providers/local/database_provider.dart';

/// Sync Queue - manages pending sync operations
class SyncQueue {
  static const int maxRetries = 5;
  static const int batchSize = 50;

  /// Initialize the sync queue
  Future<void> initialize() async {
    await _ensureQueueTable();
    debugPrint('SyncQueue: Initialized');
  }

  /// Ensure the queue table exists
  Future<void> _ensureQueueTable() async {
    final db = await DatabaseProvider.instance.database;

    await db.execute('''
      CREATE TABLE IF NOT EXISTS _sync_queue (
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
        status TEXT DEFAULT 'pending',
        error_message TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sync_queue_status 
      ON _sync_queue(status)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sync_queue_timestamp 
      ON _sync_queue(timestamp)
    ''');

    // Also ensure _sync_meta table exists
    await db.execute('''
      CREATE TABLE IF NOT EXISTS _sync_meta (
        table_name TEXT PRIMARY KEY,
        last_version INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  /// Add a change to the queue
  Future<void> enqueue(ChangeRecord change) async {
    final db = await DatabaseProvider.instance.database;

    // Check for duplicate (same table+record with pending status)
    final existing = await db.query(
      '_sync_queue',
      where: "table_name = ? AND record_id = ? AND status = 'pending'",
      whereArgs: [change.tableName, change.recordId],
    );

    if (existing.isNotEmpty) {
      // Update existing entry instead of creating duplicate
      final existingId = existing.first['id'] as String;
      await db.update(
        '_sync_queue',
        {
          'operation': _mergeOperations(
            existing.first['operation'] as String,
            change.operation.name,
          ),
          'new_data': change.newData != null
              ? change.toMap()['new_data']
              : null,
          'timestamp': change.timestamp.toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [existingId],
      );
      debugPrint(
        'SyncQueue: Updated existing entry for ${change.tableName}/${change.recordId}',
      );
    } else {
      // Insert new entry
      await db.insert('_sync_queue', {...change.toMap(), 'status': 'pending'});
      debugPrint(
        'SyncQueue: Enqueued ${change.operation.name} ${change.tableName}/${change.recordId}',
      );
    }
  }

  /// Merge operations when updating existing queue entry
  String _mergeOperations(String existing, String incoming) {
    // INSERT + UPDATE = INSERT (with new data)
    // INSERT + DELETE = nothing (remove from queue)
    // UPDATE + UPDATE = UPDATE (with new data)
    // UPDATE + DELETE = DELETE
    // DELETE + anything = DELETE

    if (existing == 'delete') return 'delete';
    if (incoming == 'delete') return 'delete';
    if (existing == 'insert') return 'insert';
    return 'update';
  }

  /// Get pending changes in order
  Future<List<ChangeRecord>> getPendingChanges({int? limit}) async {
    final db = await DatabaseProvider.instance.database;
    final results = await db.query(
      '_sync_queue',
      where: "status = 'pending' AND retry_count < ?",
      whereArgs: [maxRetries],
      orderBy: 'timestamp ASC',
      limit: limit ?? batchSize,
    );
    return results.map((r) => ChangeRecord.fromMap(r)).toList();
  }

  /// Get count of pending changes
  Future<int> getPendingCount() async {
    final db = await DatabaseProvider.instance.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM _sync_queue WHERE status = 'pending'",
    );
    return result.first['count'] as int? ?? 0;
  }

  /// Mark a change as completed
  Future<void> markAsCompleted(String changeId) async {
    final db = await DatabaseProvider.instance.database;
    await db.update(
      '_sync_queue',
      {'status': 'completed'},
      where: 'id = ?',
      whereArgs: [changeId],
    );
  }

  /// Increment retry count for a failed change
  Future<void> incrementRetry(String changeId, {String? errorMessage}) async {
    final db = await DatabaseProvider.instance.database;
    await db.rawUpdate(
      '''
      UPDATE _sync_queue 
      SET retry_count = retry_count + 1, 
          error_message = ?
      WHERE id = ?
      ''',
      [errorMessage, changeId],
    );

    // Check if max retries exceeded
    final result = await db.query(
      '_sync_queue',
      where: 'id = ?',
      whereArgs: [changeId],
    );

    if (result.isNotEmpty) {
      final retryCount = result.first['retry_count'] as int? ?? 0;
      if (retryCount >= maxRetries) {
        await db.update(
          '_sync_queue',
          {'status': 'failed'},
          where: 'id = ?',
          whereArgs: [changeId],
        );
        debugPrint(
          'SyncQueue: Change $changeId exceeded max retries, marked as failed',
        );
      }
    }
  }

  /// Get failed changes for manual review
  Future<List<ChangeRecord>> getFailedChanges() async {
    final db = await DatabaseProvider.instance.database;
    final results = await db.query(
      '_sync_queue',
      where: "status = 'failed'",
      orderBy: 'timestamp ASC',
    );
    return results.map((r) => ChangeRecord.fromMap(r)).toList();
  }

  /// Retry a failed change
  Future<void> retryFailed(String changeId) async {
    final db = await DatabaseProvider.instance.database;
    await db.update(
      '_sync_queue',
      {'status': 'pending', 'retry_count': 0},
      where: 'id = ?',
      whereArgs: [changeId],
    );
  }

  /// Delete a change from queue
  Future<void> remove(String changeId) async {
    final db = await DatabaseProvider.instance.database;
    await db.delete('_sync_queue', where: 'id = ?', whereArgs: [changeId]);
  }

  /// Cleanup old completed changes
  Future<void> cleanup({Duration maxAge = const Duration(days: 7)}) async {
    final db = await DatabaseProvider.instance.database;
    final cutoff = DateTime.now().subtract(maxAge).toUtc().toIso8601String();

    final deleted = await db.delete(
      '_sync_queue',
      where: "status = 'completed' AND timestamp < ?",
      whereArgs: [cutoff],
    );

    if (deleted > 0) {
      debugPrint('SyncQueue: Cleaned up $deleted old entries');
    }
  }

  /// Clear all pending changes (use with caution!)
  Future<void> clearAll() async {
    final db = await DatabaseProvider.instance.database;
    await db.delete('_sync_queue');
    debugPrint('SyncQueue: Cleared all entries');
  }
}
