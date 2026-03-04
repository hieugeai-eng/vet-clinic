import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide openDatabase;
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:get_storage/get_storage.dart';

/// Database provider - SQLite local database
class DatabaseProvider {
  static DatabaseProvider? _instance;
  static Database? _database;

  static const _secureStorage = FlutterSecureStorage();
  static const _dbKeyAlias = 'okada_vet_db_encryption_key';

  DatabaseProvider._();

  static DatabaseProvider get instance {
    _instance ??= DatabaseProvider._();
    return _instance!;
  }

  static Completer<Database>? _dbOpenCompleter;

  /// Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;

    if (_dbOpenCompleter != null) {
      return _dbOpenCompleter!.future;
    }

    _dbOpenCompleter = Completer<Database>();

    try {
      _database = await _initDatabase();
      _dbOpenCompleter!.complete(_database);
    } catch (e) {
      _dbOpenCompleter!.completeError(e);
      _dbOpenCompleter = null; // Allow retry on failure
      rethrow;
    }

    return _database!;
  }

  /// Đóng kết nối database hiện tại (Dùng khi đăng xuất / chuyển tài khoản)
  Future<void> closeDatabase() async {
    _logDb('Starting closeDatabase...');
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    _dbOpenCompleter = null;
    _logDb('Database closed successfully.');
  }

  /// Initialize database
  Future<Database> _initDatabase() async {
    _logDb('Starting _initDatabase');
    // Initialize FFI for desktop is now handled in main.dart

    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();

    // Tạo tên DB riêng biệt cho mỗi tài khoản dựa trên user_id
    final box = GetStorage();
    final userData = box.read('user_data');
    String dbName = 'okada_vet_clinic.db'; // Mặc định nếu chưa có session
    if (userData != null && userData['id'] != null) {
      final userId = userData['id'].toString().replaceAll('-', '');
      dbName = 'okada_vet_$userId.db';
    }

    final String path = join(documentsDirectory.path, dbName);
    _logDb('Database path: $path');

    try {
      // 1. Lấy hoặc tạo DB Encryption Key
      String? dbKey = await _secureStorage.read(key: _dbKeyAlias);
      if (dbKey == null) {
        // Lần đầu chạy app, sinh key bảo mật bằng UUID
        dbKey = const Uuid().v4() + const Uuid().v4();
        await _secureStorage.write(key: _dbKeyAlias, value: dbKey);
        _logDb('Generated new DB encryption key');
      }

      Database db;
      try {
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          db = await databaseFactoryFfi.openDatabase(
            path,
            options: OpenDatabaseOptions(
              version: 30,
              onConfigure: (db) async {
                await db.execute("PRAGMA key = '$dbKey'");
                await db.execute('PRAGMA foreign_keys = OFF');
                await db.execute('PRAGMA journal_mode = WAL');
                await db.execute('PRAGMA busy_timeout = 5000');
              },
              onCreate: _onCreate,
              onUpgrade: _onUpgrade,
            ),
          );
        } else {
          db = await openDatabase(
            path,
            password: dbKey, // Sử dụng SQLCipher password
            version: 30,
            onConfigure: (db) async {
              // Disable foreign keys so we can insert draft attachments before their parent case is saved
              await db.execute('PRAGMA foreign_keys = OFF');
              await db.execute('PRAGMA journal_mode = WAL');
              await db.execute('PRAGMA busy_timeout = 5000');
            },
            onCreate: _onCreate,
            onUpgrade: _onUpgrade,
          );
        }
        _logDb('openDatabase success with FK enabled');
      } catch (e) {
        _logDb('Lỗi mở database (có thể do DB cũ chưa mã hóa): $e');
        _logDb('Tiến hành xóa database cũ và tạo lại phiên bản mã hóa');
        try {
          if (File(path).existsSync()) {
            File(path).deleteSync();
            final shmFile = File('$path-shm');
            if (shmFile.existsSync()) shmFile.deleteSync();
            final walFile = File('$path-wal');
            if (walFile.existsSync()) walFile.deleteSync();
          }
        } catch (_) {}

        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          db = await databaseFactoryFfi.openDatabase(
            path,
            options: OpenDatabaseOptions(
              version: 26,
              onConfigure: (db) async {
                await db.execute("PRAGMA key = '$dbKey'");
                await db.execute('PRAGMA foreign_keys = OFF');
              },
              onCreate: _onCreate,
              onUpgrade: _onUpgrade,
            ),
          );
        } else {
          db = await openDatabase(
            path,
            password: dbKey, // Sử dụng SQLCipher password
            version: 26,
            onConfigure: (db) async {
              await db.execute('PRAGMA foreign_keys = OFF');
            },
            onCreate: _onCreate,
            onUpgrade: _onUpgrade,
          );
        }
        _logDb('Re-created openDatabase success with FK enabled');
      }

      // Safety check: Ensure sync columns exist on ALL syncable tables
      final syncTables = [
        'customers',
        'pets',
        'medicines',
        'products',
        'medical_cases',
        'case_services',
        'services',
        'staff',
        'appointments',
        'medicine_transactions',
        'hospitalizations',
        'cages',
        'hospitalization_treatments',
        'vital_sign_logs',
        'hospitalization_regimens',
        'product_sales',
        'expenses',
        'case_attachments',
        'hospitalization_dailies',
        'case_logs',
      ];
      for (final table in syncTables) {
        try {
          await db.query(table, columns: ['_sync_status'], limit: 1);
        } catch (_) {
          _logDb('Safety: Adding _sync_status to $table');
          try {
            await db.execute(
              "ALTER TABLE $table ADD COLUMN _sync_status TEXT DEFAULT 'synced'",
            );
          } catch (_) {}
        }
        try {
          await db.query(table, columns: ['_is_deleted'], limit: 1);
        } catch (_) {
          _logDb('Safety: Adding _is_deleted to $table');
          try {
            await db.execute(
              "ALTER TABLE $table ADD COLUMN _is_deleted INTEGER DEFAULT 0",
            );
          } catch (_) {}
        }
        try {
          await db.query(table, columns: ['_version'], limit: 1);
        } catch (_) {
          _logDb('Safety: Adding _version to $table');
          try {
            await db.execute(
              "ALTER TABLE $table ADD COLUMN _version INTEGER DEFAULT 1",
            );
          } catch (_) {}
        }
        // Also ensure synced and sync_status exist (some repos use both)
        try {
          await db.query(table, columns: ['sync_status'], limit: 1);
        } catch (_) {
          try {
            await db.execute(
              "ALTER TABLE $table ADD COLUMN sync_status TEXT DEFAULT 'synced'",
            );
          } catch (_) {}
        }
        try {
          await db.query(table, columns: ['synced'], limit: 1);
        } catch (_) {
          try {
            await db.execute(
              "ALTER TABLE $table ADD COLUMN synced INTEGER DEFAULT 0",
            );
          } catch (_) {}
        }
        try {
          await db.query(table, columns: ['clinic_id'], limit: 1);
        } catch (_) {
          try {
            await db.execute("ALTER TABLE $table ADD COLUMN clinic_id TEXT");
          } catch (_) {}
        }
        try {
          await db.query(table, columns: ['created_at'], limit: 1);
        } catch (_) {
          _logDb('Safety: Adding created_at to $table');
          try {
            await db.execute("ALTER TABLE $table ADD COLUMN created_at TEXT");
          } catch (_) {}
        }
        try {
          await db.query(table, columns: ['updated_at'], limit: 1);
        } catch (_) {
          _logDb('Safety: Adding updated_at to $table');
          try {
            await db.execute("ALTER TABLE $table ADD COLUMN updated_at TEXT");
          } catch (_) {}
        }
        try {
          await db.query(table, columns: ['is_active'], limit: 1);
        } catch (_) {
          _logDb('Safety: Adding is_active to $table');
          try {
            await db.execute(
              "ALTER TABLE $table ADD COLUMN is_active INTEGER DEFAULT 1",
            );
          } catch (_) {}
        }
      }

      // ----------------------------------------------------
      // Migration: Add snapshot columns to medical_cases
      // ----------------------------------------------------
      try {
        await db.query('medical_cases', columns: ['customer_name'], limit: 1);
      } catch (_) {
        _logDb('Migration: Adding snapshot columns to medical_cases');
        try {
          await db.execute(
            "ALTER TABLE medical_cases ADD COLUMN customer_name TEXT",
          );
          await db.execute(
            "ALTER TABLE medical_cases ADD COLUMN customer_phone TEXT",
          );
          await db.execute(
            "ALTER TABLE medical_cases ADD COLUMN pet_name TEXT",
          );
          await db.execute(
            "ALTER TABLE medical_cases ADD COLUMN pet_species TEXT",
          );
        } catch (_) {}
      }

      // Migration: Add type and payment_method to expenses
      // ----------------------------------------------------
      try {
        await db.query('expenses', columns: ['type'], limit: 1);
      } catch (_) {
        _logDb('Migration: Adding type and payment_method to expenses');
        try {
          await db.execute(
            "ALTER TABLE expenses ADD COLUMN type TEXT DEFAULT 'expense'",
          );
          await db.execute(
            "ALTER TABLE expenses ADD COLUMN payment_method TEXT DEFAULT 'cash'",
          );
        } catch (_) {}
      }

      // ONE-TIME FIX: Migrate non-UUID IDs in staff, cages, expenses, services
      await _fixNonUuidIds(db);

      // Ensure seed data (services, staff) is marked for sync push
      await _ensureSeedDataSynced(db);

      return db;
    } catch (e) {
      _logDb('openDatabase error: $e');
      rethrow;
    }
  }

  void _logDb(String message) {
    try {
      final file = File('db_log.txt');
      final timestamp = DateTime.now().toUtc().toIso8601String();
      file.writeAsStringSync('[$timestamp] $message\n', mode: FileMode.append);
    } catch (e) {
      // Ignore
    }
  }

  /// One-time migration: fix non-UUID primary keys in certain tables
  Future<void> _fixNonUuidIds(Database db) async {
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );

    // Define tables and their FK references
    // Format: table → list of (referencing_table, referencing_column)
    final tablesWithFKs = <String, List<List<String>>>{
      'staff': [
        ['appointments', 'staff_id'],
        ['medical_cases', 'staff_id'],
        ['medicine_transactions', 'staff_id'],
        ['product_sales', 'staff_id'],
        ['hospitalization_treatments', 'performer_id'],
        ['vital_sign_logs', 'observer_id'],
        ['expenses', 'staff_id'],
      ],
      'services': [
        ['case_services', 'service_id'],
      ],
      'cages': [
        ['hospitalizations', 'cage_id'],
      ],
      'expenses': [], // No FK references to expenses
    };

    for (final entry in tablesWithFKs.entries) {
      final table = entry.key;
      final fkRefs = entry.value;

      try {
        final rows = await db.query(table, columns: ['id']);
        final nonUuids = rows
            .where(
              (r) =>
                  r['id'] is String &&
                  !(uuidPattern.hasMatch(r['id'] as String)),
            )
            .toList();

        if (nonUuids.isEmpty) continue;

        _logDb('UUID-FIX: Found ${nonUuids.length} non-UUID IDs in $table');
        debugPrint('UUID-FIX: Found ${nonUuids.length} non-UUID IDs in $table');

        for (final row in nonUuids) {
          final oldId = row['id'] as String;
          final newId = _generateUuidV4();

          // Use a batch for atomicity
          final batch = db.batch();

          // Update all FK references first
          for (final ref in fkRefs) {
            final refTable = ref[0];
            final refColumn = ref[1];
            try {
              batch.rawUpdate(
                'UPDATE $refTable SET $refColumn = ? WHERE $refColumn = ?',
                [newId, oldId],
              );
            } catch (_) {} // Ignore if table doesn't exist
          }

          // Update the primary key itself
          batch.rawUpdate('UPDATE $table SET id = ? WHERE id = ?', [
            newId,
            oldId,
          ]);

          await batch.commit(noResult: true);
          _logDb('UUID-FIX: $table/$oldId → $newId');
          debugPrint('UUID-FIX: $table/$oldId → $newId');
        }
      } catch (e) {
        _logDb('UUID-FIX: Error on $table: $e');
        debugPrint('UUID-FIX: Error on $table: $e');
      }
    }
  }

  /// One-time: Ensure seed data (services, staff) is marked for sync push
  /// so other devices can pull them from Supabase
  Future<void> _ensureSeedDataSynced(Database db) async {
    try {
      final count1 = await db.rawUpdate(
        "UPDATE services SET _sync_status = 'pending' WHERE _sync_status IS NULL OR _sync_status NOT IN ('pending', 'queued', 'synced')",
      );
      if (count1 > 0)
        debugPrint('SEED-SYNC: Marked $count1 services as pending sync');

      final count2 = await db.rawUpdate(
        "UPDATE staff SET _sync_status = 'pending' WHERE _sync_status IS NULL OR _sync_status NOT IN ('pending', 'queued', 'synced')",
      );
      if (count2 > 0)
        debugPrint('SEED-SYNC: Marked $count2 staff as pending sync');

      final count3 = await db.rawUpdate(
        "UPDATE cages SET _sync_status = 'pending' WHERE _sync_status IS NULL OR _sync_status NOT IN ('pending', 'queued', 'synced')",
      );
      if (count3 > 0)
        debugPrint('SEED-SYNC: Marked $count3 cages as pending sync');
    } catch (e) {
      debugPrint('SEED-SYNC: Error: $e');
    }
  }

  /// Simple UUID v4 generator using secure random
  String _generateUuidV4() {
    final random = List.generate(16, (_) => _uuidRng.nextInt(256));
    // Set version (4) and variant (RFC 4122)
    random[6] = (random[6] & 0x0f) | 0x40; // version 4
    random[8] = (random[8] & 0x3f) | 0x80; // variant
    final hex = random.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  static final _uuidRng = _createRng();
  static dynamic _createRng() {
    try {
      return Random.secure();
    } catch (_) {
      return Random(DateTime.now().microsecondsSinceEpoch);
    }
  }

  /// Initialize in-memory database for testing
  @visibleForTesting
  Future<Database> initInMemory() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      _database = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 6,
          onConfigure: (db) async {
            await db.execute("PRAGMA key = 'test_password'");
          },
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        ),
      );
    } else {
      _database = await openDatabase(
        inMemoryDatabasePath,
        password: 'test_password',
        version: 6,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    }
    return _database!;
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    // Customers table
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        clinic_id TEXT,
        phone TEXT NOT NULL,
        name TEXT NOT NULL,
        address TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        sync_status TEXT DEFAULT 'synced',
        _sync_status TEXT DEFAULT 'synced',
        _is_deleted INTEGER DEFAULT 0,
        _version INTEGER DEFAULT 1
      )
    ''');
    await db.execute('CREATE INDEX idx_customers_phone ON customers(phone)');
    await db.execute('CREATE INDEX idx_customers_name ON customers(name)');

    // Pets table
    await db.execute('''
      CREATE TABLE pets (
        id TEXT PRIMARY KEY,
        clinic_id TEXT,
        customer_id TEXT NOT NULL,
        name TEXT NOT NULL,
        species TEXT NOT NULL,
        breed TEXT,
        age INTEGER,
        date_of_birth TEXT,
        gender TEXT,
        weight REAL,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        sync_status TEXT DEFAULT 'synced',
        _sync_status TEXT DEFAULT 'synced',
        _is_deleted INTEGER DEFAULT 0,
        _version INTEGER DEFAULT 1,
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      )
    ''');
    await db.execute('CREATE INDEX idx_pets_customer ON pets(customer_id)');

    // Medical cases table
    await db.execute('''
      CREATE TABLE medical_cases (
        id TEXT PRIMARY KEY,
        clinic_id TEXT,
        case_code TEXT NOT NULL UNIQUE,
        customer_id TEXT NOT NULL,
        customer_name TEXT,
        customer_phone TEXT,
        pet_id TEXT NOT NULL,
        pet_name TEXT,
        pet_species TEXT,
        admission_date TEXT NOT NULL,
        discharge_date TEXT,
        visit_reasons TEXT,
        reason_notes TEXT,
        vital_signs TEXT,
        diagnosis TEXT,
        prognosis TEXT DEFAULT 'uncertain',
        treatment_plan TEXT,
        total_estimate REAL DEFAULT 0,
        advance_payment REAL DEFAULT 0,
        advance_payment_method TEXT,
        advance_payment_history TEXT, -- Mảng JSON ghi vết ứng tiền
        payment_method TEXT DEFAULT 'cash',
        customer_signature TEXT,
        clinic_signature TEXT,
        agree_treatment INTEGER DEFAULT 0,
        agree_no_complaint INTEGER DEFAULT 0,
        status TEXT DEFAULT 'active',
        result TEXT,
        notes TEXT,
        staff_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        sync_status TEXT DEFAULT 'synced',
        _sync_status TEXT DEFAULT 'synced',
        _is_deleted INTEGER DEFAULT 0,
        _version INTEGER DEFAULT 1,
        FOREIGN KEY (customer_id) REFERENCES customers(id),
        FOREIGN KEY (pet_id) REFERENCES pets(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_cases_customer ON medical_cases(customer_id)',
    );
    await db.execute(
      'CREATE INDEX idx_cases_date ON medical_cases(admission_date)',
    );
    await db.execute('CREATE INDEX idx_cases_status ON medical_cases(status)');

    // Services table
    await db.execute('''
      CREATE TABLE services (
        id TEXT PRIMARY KEY,
        clinic_id TEXT,
        name TEXT NOT NULL,
        category TEXT,
        base_price REAL NOT NULL,
        unit TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        sync_status TEXT DEFAULT 'synced',
        _sync_status TEXT DEFAULT 'synced',
        _is_deleted INTEGER DEFAULT 0,
        _version INTEGER DEFAULT 1
      )
    ''');

    // Case services table (junction)
    await db.execute('''
        CREATE TABLE case_services (
          id TEXT PRIMARY KEY,
          clinic_id TEXT,
          case_id TEXT NOT NULL,
          service_id TEXT,
          service_name TEXT,
          quantity INTEGER DEFAULT 1,
          unit_price REAL NOT NULL,
          discount REAL DEFAULT 0,
          total REAL NOT NULL,
          notes TEXT,
          medicines_json TEXT, -- Added in v8 for attached medicines
          created_at TEXT,
          updated_at TEXT,
          synced INTEGER DEFAULT 0,
          _sync_status TEXT DEFAULT 'synced',
          _is_deleted INTEGER DEFAULT 0,
          _version INTEGER DEFAULT 1,
          FOREIGN KEY (case_id) REFERENCES medical_cases(id),
          FOREIGN KEY (service_id) REFERENCES services(id)
        )
      ''');
    await db.execute(
      'CREATE INDEX idx_case_services_case ON case_services(case_id)',
    );

    // Medicines table
    await db.execute('''
      CREATE TABLE medicines (
        id TEXT PRIMARY KEY,
        clinic_id TEXT,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        unit TEXT,
        avg_price REAL DEFAULT 0,
        stock REAL DEFAULT 0,
        min_stock REAL,
        lot_number TEXT,
        expiry_date TEXT,
        supplier TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        sync_status TEXT DEFAULT 'synced',
        _sync_status TEXT DEFAULT 'synced',
        _is_deleted INTEGER DEFAULT 0,
        _version INTEGER DEFAULT 1
      )
    ''');
    await db.execute('CREATE INDEX idx_medicines_code ON medicines(code)');

    // Case logs (Audit trail / Timeline)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS case_logs (
        id TEXT PRIMARY KEY,
        clinic_id TEXT NOT NULL,
        case_id TEXT NOT NULL,
        staff_id TEXT,
        action TEXT NOT NULL,
        notes TEXT,
        metadata TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        _sync_status TEXT DEFAULT 'synced',
        _is_deleted INTEGER DEFAULT 0,
        _version INTEGER DEFAULT 1,
        FOREIGN KEY (case_id) REFERENCES medical_cases(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_case_logs_case ON case_logs(case_id)',
    );

    // Medicine transactions table
    await db.execute('''
      CREATE TABLE medicine_transactions (
        id TEXT PRIMARY KEY,
        clinic_id TEXT,
        medicine_id TEXT NOT NULL,
        type TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL,
        case_id TEXT,
        lot_number TEXT,
        purpose TEXT,
        staff_id TEXT,
        notes TEXT,
        transaction_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        synced INTEGER DEFAULT 0,
        _sync_status TEXT DEFAULT 'synced',
        _is_deleted INTEGER DEFAULT 0,
        _version INTEGER DEFAULT 1,
        FOREIGN KEY (medicine_id) REFERENCES medicines(id),
        FOREIGN KEY (case_id) REFERENCES medical_cases(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_med_trans_medicine ON medicine_transactions(medicine_id)',
    );
    await db.execute(
      'CREATE INDEX idx_med_trans_date ON medicine_transactions(transaction_date)',
    );

    // Products table (Petshop)
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        clinic_id TEXT,
        name TEXT NOT NULL,
        brand TEXT,
        sale_price REAL NOT NULL,
        cost_price REAL NOT NULL,
        stock INTEGER DEFAULT 0,
        category TEXT,
        image_url TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        sync_status TEXT DEFAULT 'synced',
        _sync_status TEXT DEFAULT 'synced',
        _is_deleted INTEGER DEFAULT 0,
        _version INTEGER DEFAULT 1
      )
    ''');

    // Product sales table
    await db.execute('''
      CREATE TABLE product_sales (
        id TEXT PRIMARY KEY,
        clinic_id TEXT,
        product_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        total REAL NOT NULL,
        customer_id TEXT,
        staff_id TEXT,
        payment_method TEXT DEFAULT 'cash',
        case_id TEXT,
        case_code TEXT,
        returned_quantity INTEGER DEFAULT 0,
        is_returned INTEGER DEFAULT 0,
        sale_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        synced INTEGER DEFAULT 0,
        _sync_status TEXT DEFAULT 'synced',
        _is_deleted INTEGER DEFAULT 0,
        _version INTEGER DEFAULT 1,
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_product_sales_date ON product_sales(sale_date)',
    );

    // Appointments table
    await db.execute('''
      CREATE TABLE appointments (
        id TEXT PRIMARY KEY,
        clinic_id TEXT,
        customer_id TEXT NOT NULL,
        pet_id TEXT,
        appointment_date TEXT NOT NULL,
        time TEXT,
        reason TEXT,
        status TEXT DEFAULT 'pending',
        notes TEXT,
        staff_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        sync_status TEXT DEFAULT 'synced',
        _sync_status TEXT DEFAULT 'synced',
        _is_deleted INTEGER DEFAULT 0,
        _version INTEGER DEFAULT 1,
        FOREIGN KEY (customer_id) REFERENCES customers(id),
        FOREIGN KEY (pet_id) REFERENCES pets(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_appointments_date ON appointments(appointment_date)',
    );

    // Expenses table
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        clinic_id TEXT,
        date TEXT NOT NULL,
        content TEXT NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        quantity INTEGER,
        unit TEXT,
        unit_price REAL,
        staff_id TEXT,
        type TEXT DEFAULT 'expense',
        payment_method TEXT DEFAULT 'cash',
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        synced INTEGER DEFAULT 0,
        _sync_status TEXT DEFAULT 'synced',
        _is_deleted INTEGER DEFAULT 0,
        _version INTEGER DEFAULT 1
      )
    ''');
    await db.execute('CREATE INDEX idx_expenses_date ON expenses(date)');
    await db.execute(
      'CREATE INDEX idx_expenses_category ON expenses(category)',
    );

    // Staff table
    await db.execute('''
      CREATE TABLE staff (
        id TEXT PRIMARY KEY,
        clinic_id TEXT,
        name TEXT NOT NULL,
        phone TEXT,
        role TEXT NOT NULL,
        email TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        sync_status TEXT DEFAULT 'synced',
        _sync_status TEXT DEFAULT 'synced',
        _is_deleted INTEGER DEFAULT 0,
        _version INTEGER DEFAULT 1
      )
    ''');

    // Cages table (Added in v4)
    await db.execute('''
      CREATE TABLE cages (
        id TEXT PRIMARY KEY,
        clinic_id TEXT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        status TEXT DEFAULT 'available',
        price REAL DEFAULT 0,
        order_index INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT,
        synced INTEGER DEFAULT 0,
        _sync_status TEXT DEFAULT 'synced',
        _is_deleted INTEGER DEFAULT 0,
        _version INTEGER DEFAULT 1
      )
    ''');

    // Treatment Days (Added in v5)
    await db.execute('''
      CREATE TABLE treatment_days (
        id TEXT PRIMARY KEY,
        hospitalization_id TEXT NOT NULL,
        date TEXT NOT NULL,
        notes TEXT,
        synced INTEGER DEFAULT 0,
        sync_status TEXT DEFAULT 'synced',
        _sync_status TEXT DEFAULT 'synced',
        _is_deleted INTEGER DEFAULT 0,
        _version INTEGER DEFAULT 1,
        FOREIGN KEY (hospitalization_id) REFERENCES hospitalizations(id)
      )
    ''');

    // Treatment Activities (Added in v5)
    await db.execute('''
      CREATE TABLE treatment_activities (
        id TEXT PRIMARY KEY,
        day_id TEXT NOT NULL,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        value TEXT NOT NULL,
        time TEXT NOT NULL,
        performer_id TEXT,
        synced INTEGER DEFAULT 0,
        sync_status TEXT DEFAULT 'synced',
        _sync_status TEXT DEFAULT 'synced',
        _is_deleted INTEGER DEFAULT 0,
        _version INTEGER DEFAULT 1,
        FOREIGN KEY (day_id) REFERENCES treatment_days(id)
      )
    ''');

    // Hospitalization 2.0 Tables (v15) ---------

    // Regimens (Templates)
    await db.execute('''
      CREATE TABLE hospitalization_regimens (
        id TEXT PRIMARY KEY,
        clinic_id TEXT,
        name TEXT NOT NULL,
        description TEXT,
        items_json TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        _sync_status TEXT DEFAULT 'synced',
        _is_deleted INTEGER DEFAULT 0,
        _version INTEGER DEFAULT 1
      )
    ''');

    // Hospitalization Dailies
    await db.execute('''
      CREATE TABLE hospitalization_dailies (
        id TEXT PRIMARY KEY,
        clinic_id TEXT,
        hospitalization_id TEXT NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        _sync_status TEXT DEFAULT 'synced',
        _is_deleted INTEGER DEFAULT 0,
        _version INTEGER DEFAULT 1,
        FOREIGN KEY (hospitalization_id) REFERENCES hospitalizations(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_hosp_dailies_date ON hospitalization_dailies(date)',
    );

    // Treatment Execution Logs
    await db.execute('''
      CREATE TABLE hospitalization_treatments (
        id TEXT PRIMARY KEY,
        clinic_id TEXT,
        daily_id TEXT NOT NULL,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        ref_id TEXT,
        time_scheduled TEXT,
        time_performed TEXT,
        quantity REAL DEFAULT 1,
        unit TEXT,
        dosage TEXT,
        status TEXT DEFAULT 'pending',
        performer_id TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        _sync_status TEXT DEFAULT 'synced',
        _is_deleted INTEGER DEFAULT 0,
        _version INTEGER DEFAULT 1,
        FOREIGN KEY (daily_id) REFERENCES hospitalization_dailies(id)
      )
    ''');

    // Vital Sign Logs
    await db.execute('''
      CREATE TABLE vital_sign_logs (
        id TEXT PRIMARY KEY,
        clinic_id TEXT,
        daily_id TEXT NOT NULL,
        time TEXT NOT NULL,
        temperature REAL,
        weight REAL,
        heart_rate REAL,
        respiratory_rate REAL,
        crt TEXT,
        mucous_membrane TEXT,
        faeces TEXT,
        urine TEXT,
        observer_id TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        _sync_status TEXT DEFAULT 'synced',
        _is_deleted INTEGER DEFAULT 0,
        _version INTEGER DEFAULT 1,
        FOREIGN KEY (daily_id) REFERENCES hospitalization_dailies(id)
      )
    ''');

    // ------------------------------------------

    // Settings table
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // Sync queue table (for offline sync)
    await db.execute('''
      CREATE TABLE sync_queue (
        id TEXT PRIMARY KEY,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        action TEXT NOT NULL,
        data TEXT,
        created_at TEXT NOT NULL,
        attempts INTEGER DEFAULT 0
      )
    ''');

    // Clinics table (Tenants)
    await db.execute('''
      CREATE TABLE clinics (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        address TEXT,
        phone TEXT,
        license_key TEXT UNIQUE,
        is_active INTEGER DEFAULT 1,
        owner_id TEXT,
        settings TEXT DEFAULT '{}',
        subscription_tier TEXT DEFAULT 'free',
        subscription_plan TEXT DEFAULT 'free',
        subscription_end_at TEXT,
        logo_url TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        _sync_status TEXT DEFAULT 'synced',
        _is_deleted INTEGER DEFAULT 0,
        _version INTEGER DEFAULT 1
      )
    ''');

    // Profiles table (Users)
    await db.execute('''
      CREATE TABLE profiles (
        id TEXT PRIMARY KEY,
        clinic_id TEXT,
        role TEXT DEFAULT 'staff',
        full_name TEXT,
        avatar_url TEXT,
        is_active INTEGER DEFAULT 1,
        preferences TEXT DEFAULT '{}',
        specialization TEXT,
        pin_hash TEXT,
        staff_code TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        _sync_status TEXT DEFAULT 'synced',
        _is_deleted INTEGER DEFAULT 0,
        _version INTEGER DEFAULT 1,
        FOREIGN KEY (clinic_id) REFERENCES clinics(id)
      )
    ''');

    // Hospitalizations table
    await db.execute('''
      CREATE TABLE hospitalizations (
        id TEXT PRIMARY KEY,
        clinic_id TEXT,
        case_id TEXT NOT NULL,
        pet_id TEXT NOT NULL,
        staff_id TEXT,
        admission_date TEXT NOT NULL,
        discharge_date TEXT,
        cage_number TEXT,
        cage_id TEXT,
        price REAL DEFAULT 0,
        status TEXT DEFAULT 'active',
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        sync_status TEXT DEFAULT 'synced',
        _sync_status TEXT DEFAULT 'synced',
        _is_deleted INTEGER DEFAULT 0,
        _version INTEGER DEFAULT 1,
        FOREIGN KEY (case_id) REFERENCES medical_cases(id),
        FOREIGN KEY (pet_id) REFERENCES pets(id),
        FOREIGN KEY (cage_id) REFERENCES cages(id)
      )
    ''');

    // Case Attachments table (v19)
    await db.execute('''
      CREATE TABLE case_attachments (
        id TEXT PRIMARY KEY,
        clinic_id TEXT,
        case_id TEXT NOT NULL,
        case_service_id TEXT,
        file_name TEXT NOT NULL,
        file_type TEXT,
        category TEXT DEFAULT 'other',
        local_path TEXT NOT NULL,
        remote_url TEXT,
        thumbnail_path TEXT,
        note TEXT,
        file_size INTEGER,
        uploaded_by TEXT,
        sync_status TEXT DEFAULT 'local_only',
        is_active INTEGER DEFAULT 1,
        _sync_status TEXT DEFAULT 'pending',
        _is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (case_id) REFERENCES medical_cases(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_case_attachments_case ON case_attachments(case_id)',
    );
    await db.execute(
      'CREATE INDEX idx_case_attachments_service ON case_attachments(case_service_id)',
    );

    // Clinic Invites table (v13)
    await db.execute('''
      CREATE TABLE clinic_invites (
        id TEXT PRIMARY KEY,
        clinic_id TEXT NOT NULL,
        email TEXT NOT NULL,
        role TEXT NOT NULL,
        code TEXT NOT NULL,
        invited_by TEXT,
        expired_at TEXT NOT NULL,
        status TEXT DEFAULT 'pending',
        created_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        _sync_status TEXT DEFAULT 'synced',
        _is_deleted INTEGER DEFAULT 0,
        _version INTEGER DEFAULT 1,
        FOREIGN KEY (clinic_id) REFERENCES clinics(id)
      )
    ''');

    // Clinic Devices table (v13)
    await db.execute('''
      CREATE TABLE clinic_devices (
        id TEXT PRIMARY KEY,
        clinic_id TEXT NOT NULL,
        device_id TEXT NOT NULL,
        device_name TEXT,
        license_key_used TEXT,
        is_approved INTEGER DEFAULT 0,
        last_ip TEXT,
        last_active_at TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        _sync_status TEXT DEFAULT 'synced',
        _is_deleted INTEGER DEFAULT 0,
        _version INTEGER DEFAULT 1,
        FOREIGN KEY (clinic_id) REFERENCES clinics(id),
        UNIQUE(clinic_id, device_id)
      )
    ''');

    // Hospitalization Reservations table (v17)
    await db.execute('''
      CREATE TABLE hospitalization_reservations (
        id TEXT PRIMARY KEY,
        clinic_id TEXT,
        cage_id TEXT NOT NULL,
        pet_id TEXT NOT NULL,
        customer_id TEXT,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        note TEXT,
        status TEXT DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        _sync_status TEXT DEFAULT 'synced',
        _is_deleted INTEGER DEFAULT 0,
        _version INTEGER DEFAULT 1,
        FOREIGN KEY (cage_id) REFERENCES cages(id),
        FOREIGN KEY (pet_id) REFERENCES pets(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_reservations_cage ON hospitalization_reservations(cage_id)',
    );
    await db.execute(
      'CREATE INDEX idx_reservations_dates ON hospitalization_reservations(start_date)',
    );

    // Case Logs table (Timeline)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS case_logs (
        id TEXT PRIMARY KEY,
        clinic_id TEXT NOT NULL,
        case_id TEXT NOT NULL,
        staff_id TEXT,
        action TEXT NOT NULL,
        notes TEXT,
        metadata TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        _sync_status TEXT DEFAULT 'synced',
        _is_deleted INTEGER DEFAULT 0,
        _version INTEGER DEFAULT 1,
        FOREIGN KEY (case_id) REFERENCES medical_cases(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_case_logs_case ON case_logs(case_id)',
    );

    // NOTE: Seed data disabled — data comes from cloud sync or user import
    // Previously these seed records (svc_xxx, staff_xxx) were pushed to cloud
    // and couldn't be deleted. If you need seed data, import via Excel instead.
    // await _insertDefaultServices(db);
    // await _insertDefaultStaff(db);
  }

  /// Insert default services
  Future<void> _insertDefaultServices(Database db) async {
    final services = [
      {
        'id': 'svc_emergency',
        'name': 'Cấp cứu',
        'category': 'emergency',
        'base_price': 200000,
        'unit': 'lần',
      },
      {
        'id': 'svc_ultrasound',
        'name': 'Siêu âm',
        'category': 'exam',
        'base_price': 160000,
        'unit': 'lần',
      },
      {
        'id': 'svc_xray',
        'name': 'X-quang',
        'category': 'exam',
        'base_price': 150000,
        'unit': 'tấm',
      },
      {
        'id': 'svc_hospital',
        'name': 'Lưu viện',
        'category': 'treatment',
        'base_price': 160000,
        'unit': 'ngày',
      },
      {
        'id': 'svc_surgery',
        'name': 'Phẫu thuật',
        'category': 'surgery',
        'base_price': 2000000,
        'unit': 'lần',
      },
      {
        'id': 'svc_anesthesia',
        'name': 'Gây mê (Zoletil)',
        'category': 'surgery',
        'base_price': 50000,
        'unit': 'ml',
      },
      {
        'id': 'svc_medication',
        'name': 'Thuốc',
        'category': 'treatment',
        'base_price': 200000,
        'unit': 'đơn',
      },
      {
        'id': 'svc_vaccine',
        'name': 'Tiêm vaccine',
        'category': 'prevention',
        'base_price': 150000,
        'unit': 'mũi',
      },
      {
        'id': 'svc_checkup',
        'name': 'Khám tổng quát',
        'category': 'exam',
        'base_price': 50000,
        'unit': 'lần',
      },
      {
        'id': 'svc_microchip',
        'name': 'Bắn microchip',
        'category': 'other',
        'base_price': 100000,
        'unit': 'lần',
      },
    ];

    final now = DateTime.now().toUtc().toIso8601String();
    for (final service in services) {
      await db.insert('services', {
        ...service,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  /// Insert default staff
  Future<void> _insertDefaultStaff(Database db) async {
    final staff = [
      {'id': 'staff_thay', 'name': 'Thầy', 'role': 'doctor'},
      {'id': 'staff_tuan', 'name': 'Tuấn', 'role': 'nurse'},
      {'id': 'staff_tra', 'name': 'Trà', 'role': 'nurse'},
      {'id': 'staff_anh', 'name': 'Ánh', 'role': 'receptionist'},
      {'id': 'staff_linh', 'name': 'Linh', 'role': 'receptionist'},
      {'id': 'staff_nhung', 'name': 'Nhung', 'role': 'nurse'},
      {'id': 'staff_duc', 'name': 'Đức', 'role': 'nurse'},
    ];

    final now = DateTime.now().toUtc().toIso8601String();
    for (final s in staff) {
      await db.insert('staff', {
        ...s,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  /// Upgrade database
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle migrations for future versions
    if (oldVersion < 2) {
      // Add hospitalizations table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS hospitalizations (
          id TEXT PRIMARY KEY,
          case_id TEXT NOT NULL,
          pet_id TEXT NOT NULL,
          admission_date TEXT NOT NULL,
        discharge_date TEXT,
        cage_number TEXT,
        cage_id TEXT, -- Added in v10
        status TEXT DEFAULT 'active',
        created_at TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          FOREIGN KEY (case_id) REFERENCES medical_cases(id),
          FOREIGN KEY (pet_id) REFERENCES pets(id)
        )
      ''');
    }

    if (oldVersion < 3) {
      // Add discount column to case_services
      try {
        await db.execute(
          'ALTER TABLE case_services ADD COLUMN discount REAL DEFAULT 0',
        );
      } catch (e) {
        // Ignore if column already exists
        print('Column discount might already exist: $e');
      }
    }

    if (oldVersion < 4) {
      // Add cages table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cages (
          id TEXT PRIMARY KEY,
          clinic_id TEXT,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          status TEXT DEFAULT 'available',
          price REAL DEFAULT 0,
          order_index INTEGER DEFAULT 0,
          created_at TEXT,
          updated_at TEXT,
          _sync_status TEXT DEFAULT 'synced',
          _is_deleted INTEGER DEFAULT 0,
          _version INTEGER DEFAULT 1
        )
      ''');

      // Migrate existing cages table if missing columns
      for (final col in [
        "clinic_id TEXT",
        "created_at TEXT",
        "updated_at TEXT",
        "_sync_status TEXT DEFAULT 'synced'",
        "_is_deleted INTEGER DEFAULT 0",
        "_version INTEGER DEFAULT 1",
      ]) {
        try {
          await db.execute('ALTER TABLE cages ADD COLUMN $col');
        } catch (_) {}
      }

      // Add cage_id to hospitalizations
      try {
        await db.execute(
          'ALTER TABLE hospitalizations ADD COLUMN cage_id TEXT',
        );
      } catch (e) {
        print('Column cage_id might already exist: $e');
      }

      // Populate default cages if empty
      final result = await db.rawQuery('SELECT COUNT(*) FROM cages');
      final count = result.first.values.first as int? ?? 0;
      if (count == 0) {
        final cages = [
          {
            'id': 'cage_d1',
            'name': 'D1',
            'type': 'dog',
            'status': 'available',
            'price': 100000,
            'order_index': 1,
          },
          {
            'id': 'cage_d2',
            'name': 'D2',
            'type': 'dog',
            'status': 'available',
            'price': 100000,
            'order_index': 2,
          },
          {
            'id': 'cage_c1',
            'name': 'C1',
            'type': 'cat',
            'status': 'available',
            'price': 80000,
            'order_index': 3,
          },
          {
            'id': 'cage_c2',
            'name': 'C2',
            'type': 'cat',
            'status': 'available',
            'price': 80000,
            'order_index': 4,
          },
          {
            'id': 'cage_iso',
            'name': 'ISO',
            'type': 'isolation',
            'status': 'available',
            'price': 150000,
            'order_index': 5,
          },
        ];
        for (final cage in cages) {
          await db.insert('cages', cage);
        }
      }
    }

    if (oldVersion < 5) {
      // Add treatment_days
      await db.execute('''
        CREATE TABLE IF NOT EXISTS treatment_days (
          id TEXT PRIMARY KEY,
          hospitalization_id TEXT NOT NULL,
          date TEXT NOT NULL,
          notes TEXT,
          FOREIGN KEY (hospitalization_id) REFERENCES hospitalizations(id)
        )
      ''');

      // Add treatment_activities
      await db.execute('''
        CREATE TABLE IF NOT EXISTS treatment_activities (
          id TEXT PRIMARY KEY,
          day_id TEXT NOT NULL,
          type TEXT NOT NULL,
          name TEXT NOT NULL,
          value TEXT NOT NULL,
          time TEXT NOT NULL,
          FOREIGN KEY (day_id) REFERENCES treatment_days(id)
        )
      ''');
    }

    if (oldVersion < 8) {
      // Add medicines_json to case_services
      try {
        await db.execute(
          'ALTER TABLE case_services ADD COLUMN medicines_json TEXT',
        );
      } catch (e) {
        print('Column medicines_json might already exist: $e');
      }
    }

    if (oldVersion < 9) {
      // Add advance_payment_method
      try {
        await db.execute(
          'ALTER TABLE medical_cases ADD COLUMN advance_payment_method TEXT',
        );
      } catch (e) {
        print('Column advance_payment_method might already exist: $e');
      }
    }

    if (oldVersion < 10) {
      // Add cage_id to hospitalizations
      try {
        await db.execute(
          'ALTER TABLE hospitalizations ADD COLUMN cage_id TEXT',
        );
      } catch (e) {
        print('Column cage_id might already exist: $e');
      }
    }

    if (oldVersion < 11) {
      // Add sync_status column to all syncable tables for cloud sync
      final tablesToUpdate = [
        'customers',
        'pets',
        'medicines',
        'products',
        'appointments',
        'medical_cases',
      ];

      for (final table in tablesToUpdate) {
        try {
          await db.execute(
            "ALTER TABLE $table ADD COLUMN sync_status TEXT DEFAULT 'synced'",
          );
        } catch (e) {
          print('Column sync_status might already exist in $table: $e');
        }
      }
    }

    if (oldVersion < 12) {
      // Add clinic_id to all tables for multi-tenancy
      final tables = [
        'customers',
        'pets',
        'medical_cases',
        'medicines',
        'products',
        'appointments',
        'product_sales',
        'medicine_transactions',
        'expenses',
        'services',
        'staff',
        'cages',
        'hospitalizations',
      ];

      for (final table in tables) {
        try {
          await db.execute("ALTER TABLE $table ADD COLUMN clinic_id TEXT");
          await db.execute(
            "CREATE INDEX IF NOT EXISTS idx_${table}_clinic ON $table(clinic_id)",
          );
        } catch (e) {
          print('Error adding clinic_id to $table: $e');
        }
      }

      // Add new tables
      await db.execute('''
        CREATE TABLE IF NOT EXISTS clinics (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          address TEXT,
          phone TEXT,
          license_key TEXT UNIQUE,
          is_active INTEGER DEFAULT 1,
          owner_id TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS profiles (
          id TEXT PRIMARY KEY,
          clinic_id TEXT,
          role TEXT DEFAULT 'staff',
          full_name TEXT,
          avatar_url TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          FOREIGN KEY (clinic_id) REFERENCES clinics(id)
        )
      ''');
    }

    if (oldVersion < 13) {
      // V3 Schema Updates: Invites, Devices, JSON Settings

      // 1. Clinic Invites
      await db.execute('''
        CREATE TABLE IF NOT EXISTS clinic_invites (
          id TEXT PRIMARY KEY,
          clinic_id TEXT NOT NULL,
          email TEXT NOT NULL,
          role TEXT NOT NULL,
          code TEXT NOT NULL,
          invited_by TEXT,
          expired_at TEXT NOT NULL,
          status TEXT DEFAULT 'pending',
          created_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          FOREIGN KEY (clinic_id) REFERENCES clinics(id)
        )
      ''');

      // 2. Clinic Devices (Security)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS clinic_devices (
          id TEXT PRIMARY KEY,
          clinic_id TEXT NOT NULL,
          device_id TEXT NOT NULL,
          device_name TEXT,
          license_key_used TEXT,
          is_approved INTEGER DEFAULT 0,
          last_ip TEXT,
          last_active_at TEXT,
          created_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          FOREIGN KEY (clinic_id) REFERENCES clinics(id),
          UNIQUE(clinic_id, device_id)
        )
      ''');

      // 3. Update Profiles with JSON settings & active status
      try {
        await db.execute(
          'ALTER TABLE profiles ADD COLUMN is_active INTEGER DEFAULT 1',
        );
        await db.execute(
          "ALTER TABLE profiles ADD COLUMN preferences TEXT DEFAULT '{}'",
        );
        await db.execute("ALTER TABLE profiles ADD COLUMN specialization TEXT");
      } catch (e) {
        print('Profile columns update error (ignored if exists): $e');
      }

      // 4. Update Clinics with Settings & Tier
      try {
        await db.execute(
          "ALTER TABLE clinics ADD COLUMN settings TEXT DEFAULT '{}'",
        );
        await db.execute(
          "ALTER TABLE clinics ADD COLUMN subscription_tier TEXT DEFAULT 'free'",
        );
        await db.execute(
          "ALTER TABLE clinics ADD COLUMN subscription_end_at TEXT",
        );
        await db.execute("ALTER TABLE clinics ADD COLUMN logo_url TEXT");
      } catch (e) {
        print('Clinic columns update error (ignored if exists): $e');
      }
    }

    if (oldVersion < 14) {
      // Add sync_status to services and staff
      try {
        await db.execute(
          "ALTER TABLE services ADD COLUMN sync_status TEXT DEFAULT 'synced'",
        );
        await db.execute(
          "ALTER TABLE services ADD COLUMN synced INTEGER DEFAULT 0",
        );
        await db.execute(
          "ALTER TABLE services ADD COLUMN clinic_id TEXT",
        ); // Ensure clinic_id exists
      } catch (e) {
        print('Error updating services table: $e');
      }

      try {
        await db.execute(
          "ALTER TABLE staff ADD COLUMN sync_status TEXT DEFAULT 'synced'",
        );
        await db.execute(
          "ALTER TABLE staff ADD COLUMN synced INTEGER DEFAULT 0",
        );
        // Staff already got clinic_id in v12, but checking won't hurt
      } catch (e) {
        print('Error updating staff table: $e');
      }
    }

    if (oldVersion < 15) {
      // V15: Hospitalization 2.0

      // Regimens (Templates)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS hospitalization_regimens (
          id TEXT PRIMARY KEY,
          clinic_id TEXT,
          name TEXT NOT NULL,
          description TEXT,
          items_json TEXT, 
          is_active INTEGER DEFAULT 1,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0
        )
      ''');

      // Hospitalization Dailies
      await db.execute('''
        CREATE TABLE IF NOT EXISTS hospitalization_dailies (
          id TEXT PRIMARY KEY,
          clinic_id TEXT,
          hospitalization_id TEXT NOT NULL,
          date TEXT NOT NULL,
          note TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          FOREIGN KEY (hospitalization_id) REFERENCES hospitalizations(id)
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_hosp_dailies_date ON hospitalization_dailies(date)',
      );

      // Treatment Execution Logs
      await db.execute('''
        CREATE TABLE IF NOT EXISTS hospitalization_treatments (
          id TEXT PRIMARY KEY,
          clinic_id TEXT,
          daily_id TEXT NOT NULL,
          type TEXT NOT NULL,
          name TEXT NOT NULL,
          ref_id TEXT,
          time_scheduled TEXT,
          time_performed TEXT,
          quantity REAL DEFAULT 1,
          unit TEXT,
          dosage TEXT,
          status TEXT DEFAULT 'pending',
          performer_id TEXT,
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          FOREIGN KEY (daily_id) REFERENCES hospitalization_dailies(id)
        )
      ''');

      // Vital Sign Logs
      await db.execute('''
        CREATE TABLE IF NOT EXISTS vital_sign_logs (
          id TEXT PRIMARY KEY,
          clinic_id TEXT,
          daily_id TEXT NOT NULL,
          time TEXT NOT NULL,
          temperature REAL,
          weight REAL,
          heart_rate REAL,
          respiratory_rate REAL,
          crt TEXT,
          mucous_membrane TEXT,
          faeces TEXT,
          urine TEXT,
          observer_id TEXT,
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          FOREIGN KEY (daily_id) REFERENCES hospitalization_dailies(id)
        )
      ''');
    }

    if (oldVersion < 17) {
      // Phase 3: Reservations & Pricing

      // Add price to hospitalizations
      try {
        await db.execute(
          'ALTER TABLE hospitalizations ADD COLUMN price REAL DEFAULT 0',
        );
      } catch (e) {
        print('Column price might already exist: $e');
      }

      // Create reservations table
      await db.execute('''
        CREATE TABLE hospitalization_reservations (
          id TEXT PRIMARY KEY,
          clinic_id TEXT,
          cage_id TEXT NOT NULL,
          pet_id TEXT NOT NULL,
          customer_id TEXT, 
          start_date TEXT NOT NULL,
          end_date TEXT NOT NULL,
          note TEXT,
          status TEXT DEFAULT 'pending', -- pending, confirmed, cancelled, completed
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          FOREIGN KEY (cage_id) REFERENCES cages(id),
          FOREIGN KEY (pet_id) REFERENCES pets(id)
        )
      ''');
      // Indices
      await db.execute(
        'CREATE INDEX idx_reservations_cage ON hospitalization_reservations(cage_id)',
      );
      await db.execute(
        'CREATE INDEX idx_reservations_dates ON hospitalization_reservations(start_date)',
      );
    }

    if (oldVersion < 18) {
      // V18: Add sync_status to cages, treatment_days, treatment_activities for SyncService compatibility
      final tablesNeedingSyncStatus = [
        'cages',
        'treatment_days',
        'treatment_activities',
        'hospitalizations',
        'case_services',
        'expenses',
        'medicine_transactions',
        'product_sales',
      ];

      for (final table in tablesNeedingSyncStatus) {
        try {
          await db.execute(
            "ALTER TABLE $table ADD COLUMN sync_status TEXT DEFAULT 'synced'",
          );
        } catch (e) {
          print('Column sync_status might already exist in $table: $e');
        }
      }
    }

    if (oldVersion < 19) {
      // V19: Add case_attachments table for CLS results (images, PDFs)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS case_attachments (
          id TEXT PRIMARY KEY,
          clinic_id TEXT,
          case_id TEXT NOT NULL,
          case_service_id TEXT,
          file_name TEXT NOT NULL,
          file_type TEXT,
          category TEXT DEFAULT 'other',
          local_path TEXT NOT NULL,
          remote_url TEXT,
          thumbnail_path TEXT,
          note TEXT,
          file_size INTEGER,
          uploaded_by TEXT,
          sync_status TEXT DEFAULT 'local_only',
          is_active INTEGER DEFAULT 1,
          _sync_status TEXT DEFAULT 'pending',
          _is_deleted INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (case_id) REFERENCES medical_cases(id)
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_case_attachments_case ON case_attachments(case_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_case_attachments_service ON case_attachments(case_service_id)',
      );
    }

    if (oldVersion < 20) {
      // V20: RBAC - Add pin_hash and staff_code to profiles
      try {
        await db.execute('ALTER TABLE profiles ADD COLUMN pin_hash TEXT');
      } catch (e) {
        print('Column pin_hash might already exist: $e');
      }
      try {
        await db.execute('ALTER TABLE profiles ADD COLUMN staff_code TEXT');
      } catch (e) {
        print('Column staff_code might already exist: $e');
      }
    }

    if (oldVersion < 21) {
      // V21: Make service_id nullable in case_services (fix sync pull errors)
      try {
        await db.execute(
          'ALTER TABLE case_services RENAME TO case_services_old',
        );
        await db.execute('''
          CREATE TABLE case_services (
            id TEXT PRIMARY KEY,
            clinic_id TEXT,
            case_id TEXT NOT NULL,
            service_id TEXT,
            service_name TEXT,
            quantity INTEGER DEFAULT 1,
            unit_price REAL NOT NULL,
            discount REAL DEFAULT 0,
            total REAL NOT NULL,
            notes TEXT,
            medicines_json TEXT,
            created_at TEXT,
            updated_at TEXT,
            synced INTEGER DEFAULT 0,
            _sync_status TEXT DEFAULT 'synced',
            _is_deleted INTEGER DEFAULT 0,
            _version INTEGER DEFAULT 1,
            FOREIGN KEY (case_id) REFERENCES medical_cases(id)
          )
        ''');
        await db.execute('''
          INSERT INTO case_services 
          SELECT id, clinic_id, case_id, service_id, service_name, quantity, 
                 unit_price, discount, total, notes, medicines_json, 
                 created_at, updated_at, synced, _sync_status, _is_deleted, _version
          FROM case_services_old
        ''');
        await db.execute('DROP TABLE case_services_old');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_case_services_case ON case_services(case_id)',
        );
        print('V21: Recreated case_services with nullable service_id');
      } catch (e) {
        print('V21 migration error: $e');
      }
    }

    if (oldVersion < 22) {
      // V22: Add staff_id to hospitalizations (person who admitted/caretaker)
      try {
        await db.execute(
          "ALTER TABLE hospitalizations ADD COLUMN staff_id TEXT",
        );
        print('V22: Added staff_id to hospitalizations');
      } catch (e) {
        print('V22 migration error: $e');
      }
    }

    if (oldVersion < 23) {
      // V23: Add date_of_birth to pets
      try {
        await db.execute("ALTER TABLE pets ADD COLUMN date_of_birth TEXT");
        print('V23: Added date_of_birth to pets');
      } catch (e) {
        print('V23 migration error: $e');
      }
    }
    if (oldVersion < 24) {
      // V24: Add case_logs table for medical case timeline history
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS case_logs (
            id TEXT PRIMARY KEY,
            clinic_id TEXT NOT NULL,
            case_id TEXT NOT NULL,
            staff_id TEXT,
            action TEXT NOT NULL,
            notes TEXT,
            metadata TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            synced INTEGER DEFAULT 0,
            _sync_status TEXT DEFAULT 'synced',
            _is_deleted INTEGER DEFAULT 0,
            _version INTEGER DEFAULT 1,
            FOREIGN KEY (case_id) REFERENCES medical_cases(id)
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_case_logs_case ON case_logs(case_id)',
        );
        print('V24: Created case_logs table');
      } catch (e) {
        print('V24 migration error: $e');
      }
    }
    if (oldVersion < 26) {
      // V26: Add case_logs table for medical case timeline history if missed during 24
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS case_logs (
            id TEXT PRIMARY KEY,
            clinic_id TEXT NOT NULL,
            case_id TEXT NOT NULL,
            staff_id TEXT,
            action TEXT NOT NULL,
            notes TEXT,
            metadata TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            synced INTEGER DEFAULT 0,
            _sync_status TEXT DEFAULT 'synced',
            _is_deleted INTEGER DEFAULT 0,
            _version INTEGER DEFAULT 1,
            FOREIGN KEY (case_id) REFERENCES medical_cases(id)
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_case_logs_case ON case_logs(case_id)',
        );
        print('V26: Created case_logs table');
      } catch (e) {
        print('V26 migration error: $e');
      }
    }

    if (oldVersion < 28) {
      // V28: Add advance_payment_history to medical_cases
      try {
        await db.execute(
          'ALTER TABLE medical_cases ADD COLUMN advance_payment_history TEXT',
        );
        print('V28: Added advance_payment_history to medical_cases');
      } catch (e) {
        print('V28 migration error: $e');
      }
    }

    if (oldVersion < 29) {
      // V29: Add case_id and case_code to product_sales
      try {
        await db.execute('ALTER TABLE product_sales ADD COLUMN case_id TEXT');
        await db.execute('ALTER TABLE product_sales ADD COLUMN case_code TEXT');
        print('V29: Added case_id and case_code to product_sales');
      } catch (e) {
        print('V29 migration error: $e');
      }
    }

    if (oldVersion < 30) {
      // V30: Add returned_quantity and is_returned to product_sales
      try {
        await db.execute(
          'ALTER TABLE product_sales ADD COLUMN returned_quantity INTEGER DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE product_sales ADD COLUMN is_returned INTEGER DEFAULT 0',
        );
        print('V30: Added returned_quantity and is_returned to product_sales');
      } catch (e) {
        print('V30 migration error: $e');
      }
    }
  }

  /// Close database
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Clear all data (for testing)
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('sync_queue');
    await db.delete('case_services');
    await db.delete('medicine_transactions');
    await db.delete('product_sales');
    await db.delete('appointments');
    await db.delete('expenses');
    await db.delete('medical_cases');
    await db.delete('pets');
    await db.delete('customers');
    await db.delete('medicines');
    await db.delete('products');
  }

  /// Get next case code (Format: MM/yyyy-XXX)
  Future<String> getNextCaseCode() async {
    final db = await database;
    final now = DateTime.now();
    final monthStr = now.month.toString().padLeft(2, '0');
    final prefix = '$monthStr/${now.year}-';

    // Find the highest existing case_code for this month
    final result = await db.rawQuery(
      '''
      SELECT case_code FROM medical_cases 
      WHERE case_code LIKE ?
      ORDER BY case_code DESC
      LIMIT 1
    ''',
      ['$prefix%'],
    );

    int nextNumber = 1;
    if (result.isNotEmpty) {
      final lastCode = result.first['case_code'] as String? ?? '';
      // Extract the number part after the prefix (e.g., "02/2026-004" → "004" → 4)
      final parts = lastCode.split('-');
      if (parts.length == 2) {
        nextNumber = (int.tryParse(parts.last) ?? 0) + 1;
      }
    }

    // Generate and verify uniqueness (loop in case of edge cases)
    String code;
    do {
      code = '$prefix${nextNumber.toString().padLeft(3, '0')}';
      final exists = await db.rawQuery(
        'SELECT 1 FROM medical_cases WHERE case_code = ? LIMIT 1',
        [code],
      );
      if (exists.isEmpty) break;
      nextNumber++;
    } while (true);

    return code;
  }

  /// Get services for a case
  Future<List<Map<String, dynamic>>> getCaseServices(String caseId) async {
    final db = await database;
    return await db.query(
      'case_services',
      where: 'case_id = ? AND _is_deleted = 0',
      whereArgs: [caseId],
    );
  }

  /// Get active hospitalizations with pet and customer info
  Future<List<Map<String, dynamic>>> getActiveHospitalizations() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT h.*, p.name as pet_name, p.species, c.name as customer_name, c.phone as customer_phone
      FROM hospitalizations h
      JOIN pets p ON h.pet_id = p.id
      JOIN medical_cases mc ON h.case_id = mc.id
      JOIN customers c ON mc.customer_id = c.id
      WHERE h.status = 'active'
      ORDER BY h.admission_date DESC
    ''');
  }
}
