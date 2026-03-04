import '../../../data/models/expense_model.dart';
import '../../../data/providers/local/database_provider.dart';
import '../../../data/repositories/base_sync_repository.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/services/auth_service.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

class ExpenseRepository with SyncCapable {
  static const _uuid = Uuid();

  String? get _clinicId {
    if (Get.isRegistered<AuthService>()) {
      return AuthService.to.currentProfile.value?.clinicId;
    }
    return null;
  }

  /// Get expenses by month
  Future<List<ExpenseModel>> getExpensesByMonth(int year, int month) async {
    final database = await db;
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 1);

    String where =
        'date >= ? AND date < ? AND (_is_deleted = 0 OR _is_deleted IS NULL)';
    List<dynamic> args = [
      startOfMonth.toUtc().toIso8601String(),
      endOfMonth.toUtc().toIso8601String(),
    ];

    final clinicId = _clinicId;
    if (clinicId != null) {
      where += ' AND clinic_id = ?';
      args.add(clinicId);
    }

    final results = await database.query(
      'expenses',
      where: where,
      whereArgs: args,
      orderBy: 'date DESC',
    );

    return results.map((e) => ExpenseModel.fromJson(e)).toList();
  }

  /// Add expense
  Future<String> addExpense(ExpenseModel expense) async {
    final id = expense.id.isEmpty ? _uuid.v4() : expense.id;

    var data = expense.copyWith(id: id).toJson();

    // Inject clinic_id
    final clinicId = _clinicId;
    if (clinicId != null && data['clinic_id'] == null) {
      data['clinic_id'] = clinicId;
    }

    await insertWithSync(table: 'expenses', data: data, id: id);
    return id;
  }

  /// Update expense
  Future<void> updateExpense(ExpenseModel expense) async {
    var data = expense.toJson();

    final clinicId = _clinicId;
    if (clinicId != null && data['clinic_id'] == null) {
      data['clinic_id'] = clinicId;
    }

    await updateWithSync(table: 'expenses', recordId: expense.id, data: data);
  }

  /// Delete expense
  Future<void> deleteExpense(String id) async {
    await deleteWithSync(table: 'expenses', recordId: id, softDelete: true);
  }
}
