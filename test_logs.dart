import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  var defaultDbFactory = databaseFactoryFfi;
  final dbPath = 'D:\\okada\\thu y\\okada_vet_clinic\\.dart_tool\\sqflite_common_ffi\\databases\\app_database.db';
  print('Path: \$dbPath');
  try {
    var db = await defaultDbFactory.openDatabase(dbPath);
    var logs = await db.query('case_logs');
    print('Logs count: \${logs.length}');
    for (var log in logs) {
      print(log);
    }
  } catch (e) {
    print('Failed: \$e');
  }
}
