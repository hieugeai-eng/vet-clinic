import 'package:uuid/uuid.dart';
import 'package:get/get.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/product_model.dart';
import '../providers/local/database_provider.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/services/auth_service.dart';
import 'base_sync_repository.dart';

/// Repository for Product (Petshop) operations with cloud sync
class ProductRepository with SyncCapable {
  static const _uuid = Uuid();

  @override
  Future<Database> get db async => await DatabaseProvider.instance.database;

  Future<List<ProductModel>> getAll({int? limit, int? offset}) async {
    final results = await queryActive(
      table: 'products',
      orderBy: 'name ASC',
      limit: limit,
      offset: offset,
    );
    return results.map((p) => ProductModel.fromJson(p)).toList();
  }

  Future<ProductModel?> getById(String id) async {
    final database = await db;
    final results = await database.query(
      'products',
      where: 'id = ? AND _is_deleted = 0',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;
    return ProductModel.fromJson(results.first);
  }

  Future<List<ProductModel>> search(String query) async {
    final database = await db;
    String where =
        '(name LIKE ? OR brand LIKE ?) AND is_active = 1 AND _is_deleted = 0';
    List<dynamic> args = ['%$query%', '%$query%'];
    final clinicId = currentClinicId;
    if (clinicId != null) {
      where += ' AND clinic_id = ?';
      args.add(clinicId);
    }
    final results = await database.query(
      'products',
      where: where,
      whereArgs: args,
      orderBy: 'name ASC',
      limit: 50,
    );
    return results.map((p) => ProductModel.fromJson(p)).toList();
  }

  Future<List<ProductModel>> getByCategory(String category) async {
    final database = await db;
    String where = 'category = ? AND is_active = 1 AND _is_deleted = 0';
    List<dynamic> args = [category];
    final clinicId = currentClinicId;
    if (clinicId != null) {
      where += ' AND clinic_id = ?';
      args.add(clinicId);
    }
    final results = await database.query(
      'products',
      where: where,
      whereArgs: args,
      orderBy: 'name ASC',
    );
    return results.map((p) => ProductModel.fromJson(p)).toList();
  }

  Future<List<ProductModel>> getLowStock({int threshold = 5}) async {
    final database = await db;
    String where = 'stock <= ? AND is_active = 1 AND _is_deleted = 0';
    List<dynamic> args = [threshold];
    final clinicId = currentClinicId;
    if (clinicId != null) {
      where += ' AND clinic_id = ?';
      args.add(clinicId);
    }
    final results = await database.query(
      'products',
      where: where,
      whereArgs: args,
      orderBy: 'stock ASC',
    );
    return results.map((p) => ProductModel.fromJson(p)).toList();
  }

  Future<ProductModel> create(ProductModel product) async {
    var newProduct = product.copyWith(
      id: product.id.isEmpty ? _uuid.v4() : product.id,
    );

    if (newProduct.clinicId == null && Get.isRegistered<AuthService>()) {
      newProduct = newProduct.copyWith(
        clinicId: AuthService.to.currentProfile.value?.clinicId,
      );
    }

    final data = newProduct.toJson();
    await insertWithSync(table: 'products', data: data, id: newProduct.id);

    // Also try immediate push
    if (Get.isRegistered<SyncEngine>()) {
      SyncEngine.to.pushImmediate(table: 'products', data: data);
    }

    return newProduct;
  }

  Future<ProductModel> update(ProductModel product) async {
    var updated = product.copyWith();

    if (updated.clinicId == null && Get.isRegistered<AuthService>()) {
      updated = updated.copyWith(
        clinicId: AuthService.to.currentProfile.value?.clinicId,
      );
    }

    final data = updated.toJson();
    await updateWithSync(table: 'products', recordId: product.id, data: data);

    // Also try immediate push
    if (Get.isRegistered<SyncEngine>()) {
      SyncEngine.to.pushImmediate(table: 'products', data: data);
    }

    return updated;
  }

  Future<void> updateStock(String id, int newStock) async {
    await updateWithSync(
      table: 'products',
      recordId: id,
      data: {'stock': newStock},
    );
  }

  Future<void> delete(String id) async {
    await deleteWithSync(table: 'products', recordId: id, softDelete: true);
  }

  Future<int> count() async {
    final database = await db;
    final clinicId = currentClinicId;
    String query =
        'SELECT COUNT(*) as count FROM products WHERE is_active = 1 AND _is_deleted = 0';
    List<dynamic> args = [];
    if (clinicId != null) {
      query += ' AND clinic_id = ?';
      args.add(clinicId);
    }
    final result = await database.rawQuery(query, args);
    return result.first['count'] as int? ?? 0;
  }

  // Sales
  Future<ProductSaleModel> createSale(ProductSaleModel sale) async {
    final clinicId =
        sale.clinicId ??
        (Get.isRegistered<AuthService>()
            ? AuthService.to.currentProfile.value?.clinicId
            : null);

    final newSale = ProductSaleModel(
      id: sale.id.isEmpty ? _uuid.v4() : sale.id,
      clinicId: clinicId,
      productId: sale.productId,
      productName: sale.productName,
      quantity: sale.quantity,
      unitPrice: sale.unitPrice,
      customerId: sale.customerId,
      staffId: sale.staffId,
      paymentMethod: sale.paymentMethod,
    );

    final data = newSale.toJson();
    await insertWithSync(table: 'product_sales', data: data, id: newSale.id);

    // Update stock
    final product = await getById(sale.productId);
    if (product != null) {
      await updateStock(product.id, product.stock - sale.quantity);
    }

    return newSale;
  }

  Future<List<ProductSaleModel>> getSales({
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
  }) async {
    final database = await db;
    final where = <String>[];
    final args = <dynamic>[];

    if (fromDate != null) {
      where.add('s.sale_date >= ?');
      args.add(fromDate.toUtc().toIso8601String());
    }
    if (toDate != null) {
      where.add('s.sale_date <= ?');
      args.add(toDate.toUtc().toIso8601String());
    }

    final whereClause = where.isNotEmpty ? 'WHERE ${where.join(' AND ')}' : '';
    final limitClause = limit != null ? 'LIMIT $limit' : '';

    final results = await database.rawQuery('''
      SELECT 
        s.*,
        c.customer_name as case_customer_name,
        c.pet_name as case_pet_name,
        c.visit_reasons as case_visit_reasons,
        st.name as mapped_staff_name
      FROM product_sales s
      LEFT JOIN medical_cases c ON s.case_id = c.id
      LEFT JOIN staff st ON s.staff_id = st.id
      $whereClause
      ORDER BY s.sale_date DESC
      $limitClause
    ''', args);
    return results.map((s) => ProductSaleModel.fromJson(s)).toList();
  }

  Future<Map<String, double>> getSalesStats({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final database = await db;
    final result = await database.rawQuery(
      '''
      SELECT 
        COALESCE(SUM(total), 0) as revenue,
        COALESCE(SUM(quantity), 0) as quantity
      FROM product_sales
      WHERE sale_date >= ? AND sale_date <= ?
    ''',
      [fromDate.toUtc().toIso8601String(), toDate.toUtc().toIso8601String()],
    );

    return {
      'revenue': (result.first['revenue'] as num?)?.toDouble() ?? 0,
      'quantity': (result.first['quantity'] as num?)?.toDouble() ?? 0,
    };
  }

  /// Delete all products from local AND cloud
  Future<void> deleteAll() async {
    final database = await db;
    final products = await database.query('products', columns: ['id']);

    for (final product in products) {
      await deleteWithSync(
        table: 'products',
        recordId: product['id'] as String,
        softDelete: true,
      );
    }
  }
}
