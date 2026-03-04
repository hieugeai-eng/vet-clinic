import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:get/get.dart';
import '../models/case_log_model.dart';
import '../providers/local/database_provider.dart';
import 'base_sync_repository.dart';

class CaseLogRepository with SyncCapable {
  @override
  Future<Database> get db async => await DatabaseProvider.instance.database;

  // Retrieve logs for a specific medical case
  Future<List<CaseLogModel>> getLogsForCase(String caseId) async {
    final database = await db;
    final results = await database.rawQuery(
      '''
      SELECT cl.*, s.name as staff_name
      FROM case_logs cl
      LEFT JOIN staff s ON cl.staff_id = s.id
      WHERE cl.case_id = ? AND cl._is_deleted = 0
      ORDER BY cl.created_at DESC
    ''',
      [caseId],
    );

    return results.map((e) => CaseLogModel.fromJson(e)).toList();
  }

  // Create a new log entry
  Future<void> create(CaseLogModel log) async {
    await insertWithSync(table: 'case_logs', data: log.toJson(), id: log.id);
  }

  // Clean logs if deleting case cascade fails, although DB is handled via cascade
  Future<void> deleteByCaseId(String caseId) async {
    final database = await db;
    final results = await database.query(
      'case_logs',
      where: 'case_id = ?',
      whereArgs: [caseId],
    );
    for (var r in results) {
      final id = r['id'] as String;
      await deleteWithSync(table: 'case_logs', recordId: id, softDelete: true);
    }
  }
}
