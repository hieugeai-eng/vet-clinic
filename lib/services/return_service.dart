import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/permission_service.dart';
import '../../core/sync/sync_engine.dart';
import '../../data/models/expense_model.dart';
import '../../data/providers/local/database_provider.dart';

class ReturnService extends GetxService {
  static ReturnService get to => Get.find();
  final DatabaseProvider _dbProvider = DatabaseProvider.instance;
  final _uuid = const Uuid();

  /// Thục hiện hoàn hàng cho một dịch vụ/sản phẩm trong bệnh án
  Future<void> returnCaseServiceItem({
    required String caseId,
    required String caseServiceId,
    required String productId,
    required String productName,
    required int returnQty,
    required double refundAmount,
    required String caseCode,
  }) async {
    final db = await _dbProvider.database;
    final now = DateTime.now().toUtc().toIso8601String();

    // Tạo ID cho expense
    final expenseId = _uuid.v4();
    final currentStaffName = Get.isRegistered<PermissionService>()
        ? PermissionService.to.currentStaffName.value ??
              PermissionService.to.currentStaffId.value
        : null;
    final clinicId = Get.isRegistered<AuthService>()
        ? AuthService.to.currentProfile.value?.clinicId
        : null;

    final expense = ExpenseModel(
      id: expenseId,
      clinicId: clinicId,
      date: DateTime.now(),
      content:
          'Hoàn trả hàng: $productName (Trả $returnQty) - Bệnh án: $caseCode',
      category:
          'Chi khác', // Hoặc có thể thêm category 'Hoàn trả hàng' vào data
      amount: refundAmount,
      type: 'expense',
      paymentMethod: 'cash',
      staffId: currentStaffName,
      notes:
          'Hoàn trả từ Bệnh án | Mã BA: $caseCode | Sản phẩm: $productName | SL trả: $returnQty | Hoàn tiền: ${refundAmount.toStringAsFixed(0)}₫',
      synced: false,
    );

    await db.transaction((txn) async {
      // 1. Cập nhật tồn kho (Cộng lại)
      final prodRes = await txn.query(
        'products',
        columns: ['stock', 'name'],
        where: 'id = ?',
        whereArgs: [productId],
      );
      if (prodRes.isNotEmpty) {
        final currentStock = (prodRes.first['stock'] as num?)?.toInt() ?? 0;
        await txn.update(
          'products',
          {
            'stock': currentStock + returnQty,
            'updated_at': now,
            '_sync_status': 'pending',
          },
          where: 'id = ?',
          whereArgs: [productId],
        );
      }

      // 2. Tạo phiếu chi hoàn tiền
      final expenseJson = expense.toJson();
      expenseJson['_sync_status'] = 'pending';
      await txn.insert('expenses', expenseJson);

      // 3. Mark the case_service as returned so we don't return it again (optional but recommended)
      // We can store the returned quantity in the `notes` field or we can check via expenses notes
      // For safety, we will append to `notes` field of `case_services`
      final serviceRes = await txn.query(
        'case_services',
        columns: ['notes'],
        where: 'id = ?',
        whereArgs: [caseServiceId],
      );
      if (serviceRes.isNotEmpty) {
        final oldNotes = serviceRes.first['notes'] as String? ?? '';
        final returnNoteMarker = '[Đã trả $returnQty]';
        final newNotes = oldNotes.isEmpty
            ? returnNoteMarker
            : '$oldNotes\n$returnNoteMarker';
        await txn.update(
          'case_services',
          {'notes': newNotes, 'updated_at': now, '_sync_status': 'pending'},
          where: 'id = ?',
          whereArgs: [caseServiceId],
        );
      }

      final saleRes = await txn.query(
        'product_sales',
        columns: ['returned_quantity', 'quantity'],
        where: 'id = ?',
        whereArgs: [caseServiceId],
      );
      if (saleRes.isNotEmpty) {
        final baseReturnQty =
            (saleRes.first['returned_quantity'] as num?)?.toInt() ?? 0;
        final baseQty = (saleRes.first['quantity'] as num?)?.toInt() ?? 0;
        final newReturnedQty = baseReturnQty + returnQty;
        final newIsReturned = newReturnedQty >= baseQty ? 1 : 0;
        await txn.update(
          'product_sales',
          {
            'returned_quantity': newReturnedQty,
            'is_returned': newIsReturned,
            'updated_at': now,
            '_sync_status': 'pending',
          },
          where: 'id = ?',
          whereArgs: [caseServiceId],
        );
      }
    });

    // 4. Đồng bộ
    if (Get.isRegistered<SyncEngine>()) {
      final engine = SyncEngine.to;
      await engine.trackChange(
        table: 'products',
        recordId: productId,
        operation: ChangeOperation.update,
        newData: {
          'id': productId,
        }, // Full fetch happens during sync based on id
      );

      await engine.trackChange(
        table: 'expenses',
        recordId: expense.id,
        operation: ChangeOperation.insert,
        newData: expense.toJson(),
      );

      await engine.trackChange(
        table: 'product_sales',
        recordId: caseServiceId,
        operation: ChangeOperation.update,
        newData: {'id': caseServiceId},
      );
      await engine.trackChange(
        table: 'case_services',
        recordId: caseServiceId,
        operation: ChangeOperation.update,
        newData: {'id': caseServiceId},
      );
    }
  }

  /// Kiểm tra xem item này đã từng bị hoàn trả chưa bằng cách đếm chữ "Đã trả" trong notes
  /// (hoặc do query expense tương ứng)
  Future<bool> hasAlreadyReturned(String caseServiceId) async {
    final db = await _dbProvider.database;
    final res = await db.query(
      'expenses',
      where: 'notes LIKE ?',
      whereArgs: ['%ID Dịch vụ/Sản phẩm gốc: $caseServiceId%'],
    );
    return res.isNotEmpty;
  }
}
