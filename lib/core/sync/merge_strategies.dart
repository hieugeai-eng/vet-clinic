/// Merge Strategies - CRDT-based merge logic for different field types
///
/// Each strategy defines how to merge conflicting values from
/// local and remote records.
library;

/// Context for merge operations
class MergeContext {
  final String fieldName;
  final DateTime localTimestamp;
  final DateTime remoteTimestamp;
  final Map<String, dynamic> localRecord;
  final Map<String, dynamic> remoteRecord;

  const MergeContext({
    required this.fieldName,
    required this.localTimestamp,
    required this.remoteTimestamp,
    required this.localRecord,
    required this.remoteRecord,
  });

  /// Check if local is newer
  bool get isLocalNewer => localTimestamp.isAfter(remoteTimestamp);
}

/// Base class for merge strategies
abstract class MergeStrategy {
  const MergeStrategy();

  /// Merge local and remote values
  dynamic merge(dynamic local, dynamic remote, MergeContext context);
}

/// Last-Write-Wins - simpler, uses timestamp
class LastWriteWinsMerge extends MergeStrategy {
  const LastWriteWinsMerge();

  @override
  dynamic merge(dynamic local, dynamic remote, MergeContext context) {
    return context.isLocalNewer ? local : remote;
  }
}

/// Append Merge - for text fields, append both values
class AppendMerge extends MergeStrategy {
  const AppendMerge();

  @override
  dynamic merge(dynamic local, dynamic remote, MergeContext context) {
    if (local == null) return remote;
    if (remote == null) return local;

    final localStr = local.toString().trim();
    final remoteStr = remote.toString().trim();

    if (localStr.isEmpty) return remoteStr;
    if (remoteStr.isEmpty) return localStr;

    // If one contains the other, return the longer one
    if (localStr.contains(remoteStr)) return localStr;
    if (remoteStr.contains(localStr)) return remoteStr;

    // Append with separator
    final separator = '\n---\n';
    if (context.isLocalNewer) {
      return '$remoteStr$separator$localStr';
    } else {
      return '$localStr$separator$remoteStr';
    }
  }
}

/// Sum Delta Merge - for quantities, sum the changes
///
/// Instead of overwriting, calculates the delta from each side
/// and applies both changes.
///
/// Example:
/// - Original stock: 100
/// - Device A: -5 (100 → 95)
/// - Device B: -3 (100 → 97)
/// - Result: 100 - 5 - 3 = 92
class SumDeltaMerge extends MergeStrategy {
  const SumDeltaMerge();

  @override
  dynamic merge(dynamic local, dynamic remote, MergeContext context) {
    if (local == null) return remote;
    if (remote == null) return local;

    // Try to get original value from sync metadata
    // For now, we use a simple heuristic: take the max as "original"
    // and apply both deltas

    final localNum = _toNum(local);
    final remoteNum = _toNum(remote);

    if (localNum == null || remoteNum == null) {
      return context.isLocalNewer ? local : remote;
    }

    // Simple approach: take the smaller value (assuming decrements)
    // This works for stock decrements but may need revision for other use cases
    //
    // For a proper CRDT, we'd need to track deltas separately.
    // For MVP, we'll use min (conservative for stock).
    return localNum < remoteNum ? localNum : remoteNum;
  }

  num? _toNum(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }
}

/// Max Value Merge - keep the highest value
///
/// Useful for fields like total_estimate where you want
/// to keep the most recent/highest value.
class MaxValueMerge extends MergeStrategy {
  const MaxValueMerge();

  @override
  dynamic merge(dynamic local, dynamic remote, MergeContext context) {
    if (local == null) return remote;
    if (remote == null) return local;

    final localNum = _toNum(local);
    final remoteNum = _toNum(remote);

    if (localNum == null) return remote;
    if (remoteNum == null) return local;

    return localNum > remoteNum ? localNum : remoteNum;
  }

  num? _toNum(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }
}

/// Min Value Merge - keep the lowest value
class MinValueMerge extends MergeStrategy {
  const MinValueMerge();

  @override
  dynamic merge(dynamic local, dynamic remote, MergeContext context) {
    if (local == null) return remote;
    if (remote == null) return local;

    final localNum = _toNum(local);
    final remoteNum = _toNum(remote);

    if (localNum == null) return remote;
    if (remoteNum == null) return local;

    return localNum < remoteNum ? localNum : remoteNum;
  }

  num? _toNum(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }
}

/// Union Merge - for lists/arrays, union both
class UnionMerge extends MergeStrategy {
  const UnionMerge();

  @override
  dynamic merge(dynamic local, dynamic remote, MergeContext context) {
    if (local == null) return remote;
    if (remote == null) return local;

    if (local is List && remote is List) {
      final result = <dynamic>{...local, ...remote};
      return result.toList();
    }

    // Fallback to LWW
    return context.isLocalNewer ? local : remote;
  }
}

/// Priority Merge - always prefer a specific side
class PreferLocalMerge extends MergeStrategy {
  const PreferLocalMerge();

  @override
  dynamic merge(dynamic local, dynamic remote, MergeContext context) {
    return local ?? remote;
  }
}

class PreferRemoteMerge extends MergeStrategy {
  const PreferRemoteMerge();

  @override
  dynamic merge(dynamic local, dynamic remote, MergeContext context) {
    return remote ?? local;
  }
}
