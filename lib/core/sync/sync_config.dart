/// Sync Configuration - defines which tables to sync and their relationships
///
/// Central configuration for the sync engine.
library;

/// Sync configuration
class SyncConfig {
  /// Tables that should be synced with cloud
  /// Order matters! Dependencies should come first.
  static const List<String> syncableTables = [
    // Core entities (no dependencies)
    // Note: 'clinics' and 'profiles' are system tables managed via AuthService
    // They don't have _version columns and shouldn't be synced by SyncEngine
    'staff',

    // Customer domain
    'customers',
    'pets',

    // Inventory domain
    'medicines',
    'products',
    'services',

    // Operations domain
    'appointments',
    'medical_cases',
    'case_services',
    'medicine_transactions',
    'product_sales',

    // Hospitalization domain
    'cages',
    'hospitalizations',
    'hospitalization_dailies',
    'hospitalization_treatments',
    'vital_sign_logs',
    'hospitalization_regimens',

    // Attachments & Logs domain
    'case_attachments',
    'case_logs',

    // Finance domain
    'expenses',
  ];

  /// Tables that require immediate sync (critical data)
  static const List<String> criticalTables = [
    'medical_cases',
    'medicine_transactions',
    'hospitalizations',
  ];

  /// Tables that can use lazy sync (less critical)
  static const List<String> lazyTables = ['expenses', 'product_sales'];

  /// Foreign key dependencies for sync ordering
  static const Map<String, List<String>> dependencies = {
    'pets': ['customers'],
    'appointments': ['customers', 'pets'],
    'medical_cases': ['customers', 'pets'],
    'case_services': ['medical_cases', 'services'],
    'case_logs': ['medical_cases', 'staff'],
    'medicine_transactions': ['medicines', 'medical_cases'],
    'product_sales': ['products', 'customers'],
    'hospitalizations': ['medical_cases', 'pets', 'cages'],
    'hospitalization_dailies': ['hospitalizations'],
    'hospitalization_treatments': ['hospitalization_dailies'],
    'vital_sign_logs': ['hospitalization_dailies'],
  };

  /// Get sync priority for a table (lower = higher priority)
  static int getSyncPriority(String table) {
    return syncableTables.indexOf(table);
  }

  /// Check if a table is syncable
  static bool isSyncable(String table) {
    return syncableTables.contains(table);
  }

  /// Check if a table requires immediate sync
  static bool isCritical(String table) {
    return criticalTables.contains(table);
  }

  /// Get dependencies for a table
  static List<String> getDependencies(String table) {
    return dependencies[table] ?? [];
  }

  /// Sort tables by dependency order for sync
  static List<String> sortByDependency(List<String> tables) {
    final sorted = <String>[];
    final visited = <String>{};

    void visit(String table) {
      if (visited.contains(table)) return;
      visited.add(table);

      for (final dep in getDependencies(table)) {
        if (tables.contains(dep)) {
          visit(dep);
        }
      }
      sorted.add(table);
    }

    for (final table in tables) {
      visit(table);
    }

    return sorted;
  }
}

/// Sync direction
enum SyncDirection {
  push, // Local → Cloud
  pull, // Cloud → Local
  both, // Bidirectional
}

/// Sync mode
enum SyncMode {
  auto, // Automatic background sync
  manual, // User-triggered sync
  immediate, // Critical data, sync now
}
