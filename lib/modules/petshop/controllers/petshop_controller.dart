import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/services/permission_service.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../services/excel_service.dart';
import '../../../data/providers/local/database_provider.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_rest_client.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../services/return_service.dart';
import '../../../data/models/expense_model.dart';
import 'package:uuid/uuid.dart';

class PetshopController extends GetxController {
  final ProductRepository _productRepository = ProductRepository();
  final ExcelService _excelService = Get.put(ExcelService());

  // actually DatabaseProvider.instance is static

  final staffList = <Map<String, dynamic>>[].obs;
  final selectedStaffId = ''.obs;

  final isLoading = false.obs;
  final products = <ProductModel>[].obs;
  final sales = <ProductSaleModel>[].obs;
  final searchQuery = ''.obs;
  final selectedCategory = ''.obs;
  final viewTab = 0.obs; // 0: products, 1: sales, 2: pos
  final currentPage = 0.obs;

  // Pagination (UI-based)
  final scrollController = ScrollController();
  final int _limit = 9999; // Load all for UI pagination
  int _offset = 0;
  final hasMore = true.obs;

  // POS (Point of Sale) cart
  final cartItems = <CartItem>[].obs;

  // Categories
  final categories = [
    'Thuc an',
    'Phu kien',
    'Do choi',
    'Cham soc',
    'Thuoc',
    'Khac',
  ];

  // Form controllers
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final brandController = TextEditingController();
  final salePriceController = TextEditingController();
  final costPriceController = TextEditingController();
  final stockController = TextEditingController();
  final categoryValue = ''.obs;

  // Current editing
  final editingProduct = Rxn<ProductModel>();

  @override
  void onInit() {
    super.onInit();
    loadProducts();
    loadSales();
    loadStaff();
  }

  Future<void> loadStaff() async {
    try {
      final db = await DatabaseProvider.instance.database;

      // Try fetching from Supabase and sync to local
      bool synced = false;
      if (SupabaseConfig.isConfigured &&
          Get.isRegistered<AuthService>() &&
          AuthService.to.isLoggedIn.value) {
        try {
          final clinicId = AuthService.to.currentClinic.value?.id;
          if (clinicId != null && Get.isRegistered<SupabaseRestClient>()) {
            // Fetch profiles (same query as StaffManagementController)
            final profiles = await SupabaseRestClient.to.get(
              'profiles',
              query: {
                'clinic_id': 'eq.$clinicId',
                'select': 'id,full_name,role,is_active',
              },
            );

            // Fetch clinic_staff
            List<dynamic> clinicStaff = [];
            try {
              clinicStaff = await SupabaseRestClient.to.get(
                'clinic_staff',
                query: {'clinic_id': 'eq.$clinicId', 'select': '*'},
              );
            } catch (_) {}

            // Wipe ALL old staff and re-insert fresh data
            await db.delete('staff');

            final now = DateTime.now().toUtc().toIso8601String();

            final insertedIds = <String>{};
            for (final p in profiles) {
              final id = p['id']?.toString() ?? '';
              if (id.isEmpty || insertedIds.contains(id)) continue;
              insertedIds.add(id);
              await db.rawInsert(
                'INSERT OR REPLACE INTO staff (id, name, role, phone, email, is_active, clinic_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, 1, ?, ?, ?)',
                [
                  id,
                  p['full_name'] ?? 'N/A',
                  p['role'] ?? 'staff',
                  p['phone'],
                  p['email'],
                  clinicId,
                  now,
                  now,
                ],
              );
            }
            for (final s in clinicStaff) {
              final id = s['id']?.toString() ?? '';
              if (id.isEmpty || insertedIds.contains(id)) continue;
              insertedIds.add(id);
              await db.rawInsert(
                'INSERT OR REPLACE INTO staff (id, name, role, phone, email, is_active, clinic_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, 1, ?, ?, ?)',
                [
                  id,
                  s['full_name'] ?? 'N/A',
                  s['role'] ?? 'staff',
                  s['phone'],
                  s['email'],
                  clinicId,
                  now,
                  now,
                ],
              );
            }

            synced = true;
            print(
              '[PetshopStaff] Synced ${insertedIds.length} staff from cloud',
            );
          }
        } catch (e) {
          print('[PetshopStaff] Cloud sync failed, using local: $e');
        }
      }

      // Query local staff table
      final result = await db.query('staff', orderBy: 'name ASC');
      staffList.value = result;
      print(
        '[PetshopStaff] Loaded ${result.length} staff: ${result.map((r) => r['name']).toList()}',
      );

      // Auto-assign current staff
      if (selectedStaffId.value.isEmpty &&
          Get.isRegistered<PermissionService>()) {
        final currentId = PermissionService.to.currentStaffId.value ?? '';
        if (currentId.isNotEmpty &&
            staffList.any((s) => s['id'] == currentId)) {
          selectedStaffId.value = currentId;
        }
      }
    } catch (e) {
      print('[PetshopStaff] Error loading staff: $e');
    }
  }

  void _onScroll() {
    if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent * 0.9 &&
        !isLoading.value &&
        hasMore.value) {
      loadProducts();
    }
  }

  @override
  void onClose() {
    scrollController.dispose();
    nameController.dispose();
    brandController.dispose();
    salePriceController.dispose();
    costPriceController.dispose();
    stockController.dispose();
    super.onClose();
  }

  bool _isReloading = false;

  Future<void> loadProducts({bool refresh = false}) async {
    if (refresh) {
      if (_isReloading) return;
      _isReloading = true;
      _offset = 0;
      hasMore.value = true;
      // Do NOT products.clear() here to prevent UI flash
      currentPage.value = 0;
    }

    if (!refresh && (isLoading.value || !hasMore.value)) return;

    if (_offset == 0) isLoading.value = true;

    try {
      final newItems = await _productRepository.getAll(
        limit: _limit,
        offset: _offset,
      );

      if (newItems.length < _limit) {
        hasMore.value = false;
      }

      if (refresh) {
        products.value = newItems;
      } else {
        final existingIds = products.map((e) => e.id).toSet();
        final filteredNew = newItems
            .where((e) => !existingIds.contains(e.id))
            .toList();
        products.addAll(filteredNew);
      }
      _offset += newItems.length;
    } catch (e) {
      Get.snackbar(
        'Loi',
        'Khong the tai danh sach san pham: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    } finally {
      isLoading.value = false;
      if (refresh) _isReloading = false;
    }
  }

  Future<void> loadSales() async {
    try {
      sales.value = await _productRepository.getSales(limit: 100);
    } catch (e) {
      debugPrint('Error loading sales: $e');
    }
  }

  List<ProductModel> get filteredProducts {
    var result = products.toList();

    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      result = result.where((p) {
        return p.name.toLowerCase().contains(query) ||
            (p.brand?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    if (selectedCategory.value.isNotEmpty) {
      result = result
          .where((p) => p.category == selectedCategory.value)
          .toList();
    }

    return result;
  }

  void setSearchQuery(String query) {
    searchQuery.value = query;
    currentPage.value = 0;
  }

  void setCategory(String category) {
    selectedCategory.value = category;
    currentPage.value = 0;
  }

  void clearFilters() {
    searchQuery.value = '';
    selectedCategory.value = '';
    currentPage.value = 0;
  }

  void setViewTab(int tab) {
    viewTab.value = tab;
  }

  // Form operations
  void resetForm() {
    editingProduct.value = null;
    nameController.clear();
    brandController.clear();
    salePriceController.clear();
    costPriceController.clear();
    stockController.clear();
    categoryValue.value = '';
  }

  void setupFormForEdit(ProductModel product) {
    editingProduct.value = product;
    nameController.text = product.name;
    brandController.text = product.brand ?? '';
    salePriceController.text = product.salePrice.toString();
    costPriceController.text = product.costPrice.toString();
    stockController.text = product.stock.toString();
    categoryValue.value = product.category ?? '';
  }

  Future<bool> saveProduct() async {
    if (!formKey.currentState!.validate()) return false;

    isLoading.value = true;
    try {
      final product = ProductModel(
        id: editingProduct.value?.id ?? '',
        name: nameController.text.trim(),
        brand: brandController.text.trim().isEmpty
            ? null
            : brandController.text.trim(),
        salePrice: double.tryParse(salePriceController.text) ?? 0,
        costPrice: double.tryParse(costPriceController.text) ?? 0,
        stock: int.tryParse(stockController.text) ?? 0,
        category: categoryValue.value.isEmpty ? null : categoryValue.value,
      );

      if (editingProduct.value != null) {
        await _productRepository.update(product);
      } else {
        await _productRepository.create(product);
      }

      final isEditing = editingProduct.value != null;

      // Close dialog and reset form first
      isLoading.value = false;
      Get.back();
      resetForm();

      // Show success message
      Get.snackbar(
        'Thanh cong',
        isEditing ? 'Da cap nhat san pham' : 'Da them san pham moi',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
      );

      // Reload products after dialog is closed
      await loadProducts(refresh: true);
      return true;
    } catch (e) {
      isLoading.value = false;
      Get.snackbar(
        'Loi',
        'Khong the luu san pham: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
      return false;
    }
  }

  Future<void> deleteProduct(ProductModel product) async {
    if (!PermissionService.to.can(AppPermission.petshopDelete)) {
      Get.snackbar(
        'Không có quyền',
        'Bạn không được phép xóa sản phẩm',
        backgroundColor: Colors.orange.shade100,
      );
      return;
    }
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Xac nhan xoa'),
        content: Text('Ban co chac muon xoa san pham "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Huy'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xoa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _productRepository.delete(product.id);
        await loadProducts(refresh: true);
        Get.snackbar(
          'Thanh cong',
          'Da xoa san pham',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
        );
      } catch (e) {
        Get.snackbar(
          'Loi',
          'Khong the xoa san pham: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
        );
      }
    }
  }

  // POS Cart operations
  void addToCart(ProductModel product) {
    if (product.stock <= 0) {
      Get.snackbar(
        'Het hang',
        'San pham ${product.name} da het hang',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade100,
      );
      return;
    }

    final existingIndex = cartItems.indexWhere(
      (item) => item.product.id == product.id,
    );
    if (existingIndex >= 0) {
      final existing = cartItems[existingIndex];
      if (existing.quantity < product.stock) {
        cartItems[existingIndex] = existing.copyWith(
          quantity: existing.quantity + 1,
        );
      } else {
        Get.snackbar(
          'Khong du hang',
          'Chi con ${product.stock} san pham',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.shade100,
        );
      }
    } else {
      cartItems.add(CartItem(product: product, quantity: 1));
    }
  }

  void removeFromCart(String productId) {
    cartItems.removeWhere((item) => item.product.id == productId);
  }

  void updateCartItemQuantity(String productId, int quantity) {
    final index = cartItems.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      if (quantity <= 0) {
        removeFromCart(productId);
      } else if (quantity <= cartItems[index].product.stock) {
        cartItems[index] = cartItems[index].copyWith(quantity: quantity);
      }
    }
  }

  void clearCart() {
    cartItems.clear();
    // Default back to cash
    selectedPaymentMethod.value = 'cash';
  }

  double get cartTotal {
    return cartItems.fold(0, (sum, item) => sum + item.total);
  }

  int get cartItemCount {
    return cartItems.fold(0, (sum, item) => sum + item.quantity);
  }

  // Payment method selection ('cash' or 'transfer')
  final selectedPaymentMethod = 'cash'.obs;

  Future<bool> completeSale() async {
    if (cartItems.isEmpty) {
      Get.snackbar(
        'Gio hang trong',
        'Vui long them san pham vao gio hang',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade100,
      );
      return false;
    }

    isLoading.value = true;
    try {
      final sName = selectedStaffId.value.isEmpty
          ? null
          : staffList.firstWhere(
                  (s) => s['id'] == selectedStaffId.value,
                  orElse: () => {'name': ''},
                )['name']
                as String?;

      for (final item in cartItems) {
        await _productRepository.createSale(
          ProductSaleModel(
            id: '',
            productId: item.product.id,
            productName: item.product.name,
            quantity: item.quantity,
            unitPrice: item.product.salePrice,
            staffId: sName,
            paymentMethod: selectedPaymentMethod.value,
          ),
        );
      }

      Get.snackbar(
        'Thanh cong',
        'Da hoan thanh don hang: ${formatCurrency(cartTotal)}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
      );

      clearCart();
      await loadProducts(refresh: true);
      await loadSales();
      return true;
    } catch (e) {
      Get.snackbar(
        'Loi',
        'Khong the hoan thanh don hang: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Excel operations
  Future<void> importFromExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null && result.files.single.path != null) {
        isLoading.value = true;
        final filePath = result.files.single.path;
        if (filePath == null) return;

        final imported = await _excelService.importProducts(filePath);

        if (imported.isNotEmpty) {
          final count = await _excelService.saveProductsToDb(imported);
          await loadProducts();
          Get.snackbar(
            'Thanh cong',
            'Da nhap $count san pham tu Excel',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green.shade100,
          );
        } else {
          Get.snackbar(
            'Thong bao',
            'Khong tim thay du lieu san pham trong file',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange.shade100,
          );
        }
      }
    } catch (e) {
      Get.snackbar(
        'Loi',
        'Khong the nhap file: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
      isLoading.value = false;
    }
  }

  Future<void> clearAllProducts() async {
    if (!PermissionService.to.can(AppPermission.petshopDelete)) {
      Get.snackbar(
        'Không có quyền',
        'Bạn không được phép xóa sản phẩm',
        backgroundColor: Colors.orange.shade100,
      );
      return;
    }
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Xác nhận xóa tất cả'),
        content: const Text(
          'Bạn có chắc muốn xóa TOÀN BỘ dữ liệu sản phẩm trong Petshop? Hành động này không thể khôi phục!',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Xóa Sạch',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      isLoading.value = true;
      try {
        await _productRepository.deleteAll();
        await loadProducts(refresh: true);
        Get.snackbar(
          'Thành công',
          'Đã xóa sạch dữ liệu Petshop',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
        );
      } catch (e) {
        Get.snackbar(
          'Lỗi',
          'Không thể xóa dữ liệu: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
        );
      } finally {
        isLoading.value = false;
      }
    }
  }

  Future<void> exportToExcel() async {
    if (products.isEmpty) {
      Get.snackbar(
        'Thong bao',
        'Danh sach trong',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade100,
      );
      return;
    }

    isLoading.value = true;
    try {
      await _excelService.exportProducts(products);
    } finally {
      isLoading.value = false;
    }
  }

  // Statistics
  int get totalProducts => products.length;
  int get lowStockCount => products.where((p) => p.stock <= 5).length;
  int get outOfStockCount => products.where((p) => p.isOutOfStock).length;

  double get todayRevenue {
    final today = DateTime.now();
    return sales
        .where(
          (s) =>
              s.saleDate.year == today.year &&
              s.saleDate.month == today.month &&
              s.saleDate.day == today.day,
        )
        .fold(0, (sum, s) => sum + s.total);
  }

  double get totalStockValue {
    return products.fold(0, (sum, p) => sum + (p.costPrice * p.stock));
  }

  String formatCurrency(double value) {
    final formatter = NumberFormat('#,###', 'vi');
    return '${formatter.format(value)} VND';
  }

  final isReturning = false.obs;

  Future<void> returnSaleItem(
    ProductSaleModel sale,
    int returnQty,
    double refundAmount,
  ) async {
    if (isReturning.value) return; // Prevent double-submit
    isReturning.value = true;
    try {
      if (sale.caseId != null && sale.caseId!.isNotEmpty) {
        if (!Get.isRegistered<ReturnService>()) {
          Get.put(ReturnService());
        }
        await ReturnService.to.returnCaseServiceItem(
          caseId: sale.caseId!,
          caseServiceId: sale.id, // mapped id
          productId: sale.productId,
          productName: sale.productName,
          returnQty: returnQty,
          refundAmount: refundAmount,
          caseCode: sale.caseCode ?? 'N/A',
        );
      } else {
        // Direct petshop return
        final staffName = Get.isRegistered<PermissionService>()
            ? PermissionService.to.currentStaffName.value ??
                  PermissionService.to.currentStaffId.value
            : null;
        final db = await DatabaseProvider.instance.database;
        final clinicId = Get.isRegistered<AuthService>()
            ? AuthService.to.currentProfile.value?.clinicId
            : null;
        final now = DateTime.now().toUtc().toIso8601String();

        final expense = ExpenseModel(
          id: const Uuid().v4(),
          clinicId: clinicId,
          date: DateTime.now(),
          content: 'Hoàn trả hàng: ${sale.productName} (Trả $returnQty)',
          category: 'Chi khác',
          amount: refundAmount,
          type: 'expense',
          paymentMethod: 'cash',
          staffId: staffName,
          notes:
              'Hoàn trả tại Petshop | Sản phẩm: ${sale.productName} | SL trả: $returnQty/${sale.quantity} | Ngày bán gốc: ${DateFormat('dd/MM/yyyy HH:mm').format(sale.saleDate.toLocal())}',
          synced: false,
        );

        await db.transaction((txn) async {
          final prodRes = await txn.query(
            'products',
            columns: ['stock'],
            where: 'id = ?',
            whereArgs: [sale.productId],
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
              whereArgs: [sale.productId],
            );
          }
          final expenseJson = expense.toJson();
          expenseJson['_sync_status'] = 'pending';
          await txn.insert('expenses', expenseJson);

          final newReturnedQty = sale.returnedQuantity + returnQty;
          final newIsReturned = newReturnedQty >= sale.quantity ? 1 : 0;
          await txn.update(
            'product_sales',
            {
              'returned_quantity': newReturnedQty,
              'is_returned': newIsReturned,
              'updated_at': now,
              '_sync_status': 'pending',
            },
            where: 'id = ?',
            whereArgs: [sale.id],
          );
        });

        if (Get.isRegistered<SyncEngine>()) {
          SyncEngine.to.trackChange(
            table: 'products',
            recordId: sale.productId,
            operation: ChangeOperation.update,
            newData: {'id': sale.productId},
          );
          SyncEngine.to.trackChange(
            table: 'expenses',
            recordId: expense.id,
            operation: ChangeOperation.insert,
            newData: expense.toJson(),
          );
          SyncEngine.to.trackChange(
            table: 'product_sales',
            recordId: sale.id,
            operation: ChangeOperation.update,
            newData: {'id': sale.id},
          );
        }
      }

      Get.snackbar(
        'Thành công',
        'Đã hoàn trả $returnQty ${sale.productName}',
        backgroundColor: Colors.green.shade100,
      );
      await loadProducts(refresh: true);
      await loadSales(); // Refresh the sales view
      // Auto-refresh Expense module if it is currently open
      try {
        final expenseCtrl = Get.find(tag: 'expense');
        // ignore: avoid_dynamic_calls
        (expenseCtrl as dynamic).loadExpenses();
      } catch (_) {}
    } catch (e) {
      Get.snackbar(
        'Lỗi',
        'Không thể hoàn trả: $e',
        backgroundColor: Colors.red.shade100,
      );
    } finally {
      isReturning.value = false;
    }
  }
}

// Cart item model
class CartItem {
  final ProductModel product;
  final int quantity;

  CartItem({required this.product, required this.quantity});

  double get total => product.salePrice * quantity;

  CartItem copyWith({ProductModel? product, int? quantity}) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}
