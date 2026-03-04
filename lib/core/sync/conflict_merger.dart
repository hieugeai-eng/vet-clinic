/// Conflict Merger - CRDT-based smart merge for sync conflicts
///
/// Implements field-level merge strategies to handle concurrent edits
/// from multiple devices without data loss.
library;

import 'package:flutter/foundation.dart';
import 'merge_strategies.dart';

/// Configuration for merge behavior per table
class MergeConfig {
  final Map<String, MergeStrategy> fieldStrategies;
  final MergeStrategy defaultStrategy;

  const MergeConfig({
    this.fieldStrategies = const {},
    this.defaultStrategy = const LastWriteWinsMerge(),
  });
}

/// Conflict Merger - handles merge logic for sync conflicts
class ConflictMerger {
  /// Table-specific merge configurations
  static final Map<String, MergeConfig> _tableConfigs = {
    'customers': const MergeConfig(fieldStrategies: {'notes': AppendMerge()}),
    'pets': const MergeConfig(fieldStrategies: {'notes': AppendMerge()}),
    'medicines': const MergeConfig(
      fieldStrategies: {
        'stock': SumDeltaMerge(), // Sum changes, don't overwrite
        'notes': AppendMerge(),
      },
    ),
    'products': const MergeConfig(
      fieldStrategies: {'stock': SumDeltaMerge(), 'notes': AppendMerge()},
    ),
    'medical_cases': const MergeConfig(
      fieldStrategies: {
        'notes': AppendMerge(),
        'diagnosis': AppendMerge(),
        'treatment_plan': AppendMerge(),
        'total_estimate': MaxValueMerge(), // Keep highest estimate
        'advance_payment': MaxValueMerge(), // Keep highest payment
      },
    ),
    'appointments': const MergeConfig(
      fieldStrategies: {'notes': AppendMerge()},
    ),
    'hospitalizations': const MergeConfig(
      fieldStrategies: {'notes': AppendMerge()},
    ),
  };

  /// Merge local and remote records
  /// Returns the merged record
  Map<String, dynamic> merge({
    required String table,
    required Map<String, dynamic> local,
    required Map<String, dynamic> remote,
  }) {
    final config = _tableConfigs[table] ?? const MergeConfig();
    final result = <String, dynamic>{};

    // Get all keys from both records
    final allKeys = {...local.keys, ...remote.keys};

    for (final key in allKeys) {
      // Skip internal sync fields
      if (key.startsWith('_') || key == 'synced' || key == 'sync_status') {
        continue;
      }

      final localValue = local[key];
      final remoteValue = remote[key];

      // If only one side has the value, use it
      if (!local.containsKey(key)) {
        result[key] = remoteValue;
        continue;
      }
      if (!remote.containsKey(key)) {
        result[key] = localValue;
        continue;
      }

      // Both have the value - need to merge
      if (localValue == remoteValue) {
        result[key] = localValue;
        continue;
      }

      // Get merge strategy for this field
      final strategy = config.fieldStrategies[key] ?? config.defaultStrategy;

      // Get timestamps for LWW comparison
      final localTime =
          DateTime.tryParse(local['updated_at']?.toString() ?? '') ??
          DateTime(1970);
      final remoteTime =
          DateTime.tryParse(remote['updated_at']?.toString() ?? '') ??
          DateTime(1970);

      // Merge with context
      final context = MergeContext(
        fieldName: key,
        localTimestamp: localTime,
        remoteTimestamp: remoteTime,
        localRecord: local,
        remoteRecord: remote,
      );

      result[key] = strategy.merge(localValue, remoteValue, context);

      debugPrint(
        'ConflictMerger: Merged $table.$key using ${strategy.runtimeType}',
      );
    }

    // Always use remote's updated_at after merge
    result['updated_at'] = DateTime.now().toUtc().toIso8601String();

    return result;
  }

  /// Check if there's a conflict between local and remote
  bool hasConflict({
    required Map<String, dynamic> local,
    required Map<String, dynamic> remote,
  }) {
    final localUpdated = DateTime.tryParse(
      local['updated_at']?.toString() ?? '',
    );
    final remoteUpdated = DateTime.tryParse(
      remote['updated_at']?.toString() ?? '',
    );

    if (localUpdated == null || remoteUpdated == null) {
      return false;
    }

    // Conflict if both modified after last sync
    final localPending = local['_sync_status'] == 'pending';
    final remoteDifferent =
        local['id'] == remote['id'] &&
        remoteUpdated.isAfter(
          localUpdated.subtract(const Duration(seconds: 1)),
        );

    return localPending && remoteDifferent;
  }
}
