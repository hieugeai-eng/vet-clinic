import 'package:sqflite_sqlcipher/sqflite.dart';
import '../providers/local/database_provider.dart';
import '../models/case_attachment_model.dart';
import 'base_sync_repository.dart';

/// Repository for case attachments — CRUD with sync tracking
class CaseAttachmentRepository with SyncCapable {
  static const _table = 'case_attachments';

  @override
  Future<Database> get db async => await DatabaseProvider.instance.database;

  /// Get all attachments for a case
  Future<List<CaseAttachmentModel>> getByCase(String caseId) async {
    final database = await db;
    final results = await database.query(
      _table,
      where: 'case_id = ? AND is_active = 1 AND _is_deleted = 0',
      whereArgs: [caseId],
      orderBy: 'created_at DESC',
    );
    return results.map((r) => CaseAttachmentModel.fromJson(r)).toList();
  }

  /// Get attachments for a specific service
  Future<List<CaseAttachmentModel>> getByService(String caseServiceId) async {
    final database = await db;
    final results = await database.query(
      _table,
      where: 'case_service_id = ? AND is_active = 1 AND _is_deleted = 0',
      whereArgs: [caseServiceId],
      orderBy: 'created_at DESC',
    );
    return results.map((r) => CaseAttachmentModel.fromJson(r)).toList();
  }

  /// Add a new attachment
  Future<String> addAttachment(CaseAttachmentModel model) async {
    return await insertWithSync(
      table: _table,
      data: model.toJson(),
      id: model.id,
    );
  }

  /// Update attachment (e.g. after upload to cloud)
  Future<void> updateAttachment(String id, Map<String, dynamic> data) async {
    await updateWithSync(table: _table, recordId: id, data: data);
  }

  /// Update sync status after cloud upload
  Future<void> updateSyncStatus(
    String id,
    String status, {
    String? remoteUrl,
  }) async {
    final data = <String, dynamic>{
      'sync_status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (remoteUrl != null) data['remote_url'] = remoteUrl;

    // Use updateWithSync to propagate the remote_url to the cloud!
    await updateWithSync(table: _table, recordId: id, data: data);
  }

  /// Delete attachment (soft delete)
  Future<void> deleteAttachment(String id) async {
    await deleteWithSync(table: _table, recordId: id, softDelete: true);
  }

  /// Get all pending uploads (for background sync)
  Future<List<CaseAttachmentModel>> getPendingUploads() async {
    final database = await db;
    final results = await database.query(
      _table,
      where: "sync_status = 'local_only' AND is_active = 1 AND _is_deleted = 0",
      orderBy: 'created_at ASC',
    );
    return results.map((r) => CaseAttachmentModel.fromJson(r)).toList();
  }

  /// Count attachments for a service
  Future<int> countByService(String caseServiceId) async {
    final database = await db;
    final result = await database.rawQuery(
      'SELECT COUNT(*) as count FROM $_table WHERE case_service_id = ? AND is_active = 1 AND _is_deleted = 0',
      [caseServiceId],
    );
    return result.first['count'] as int? ?? 0;
  }
}
