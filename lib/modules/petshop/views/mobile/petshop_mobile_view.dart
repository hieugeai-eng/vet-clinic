import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:okada_vet_clinic/core/constants/app_colors.dart';
import 'package:okada_vet_clinic/data/models/product_model.dart';
import 'package:okada_vet_clinic/modules/petshop/controllers/petshop_controller.dart';

class PetshopMobileView extends GetView<PetshopController> {
  const PetshopMobileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildStats(),
        const SizedBox(height: 4),
        _buildTabsAndSearch(),
        const SizedBox(height: 6),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildStats() {
    return Obx(() {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFBFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            _buildStatChip(
              'SP',
              controller.totalProducts.toString(),
              Icons.inventory_2_outlined,
              AppColors.primary,
            ),
            _buildStatChip(
              'Doanh Thu',
              controller.formatCurrency(controller.todayRevenue),
              Icons.attach_money,
              Colors.green,
            ),
            _buildStatChip(
              'Giá Trị',
              controller.formatCurrency(controller.totalStockValue),
              Icons.account_balance_wallet,
              Colors.blue,
            ),
            _buildStatChip(
              'Sắp Hết',
              controller.lowStockCount.toString(),
              Icons.warning_amber_rounded,
              Colors.orange,
            ),
          ],
        ),
      );
    });
  }

  Widget _buildStatChip(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 7,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTabsAndSearch() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Obx(
            () => Container(
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.all(2),
              child: Row(
                children: [
                  _buildTabItem(0, 'Sản Phẩm'),
                  _buildTabItem(1, 'Lịch Sử'),
                  _buildTabItem(2, 'Bán Hàng'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _buildCategoryDropdown()),
              const SizedBox(width: 4),
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  onPressed: () {
                    controller.clearFilters();
                    controller.loadProducts();
                  },
                  icon: const Icon(Icons.refresh, size: 14),
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: const Color(0xFF475569),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Color(0xFF94A3B8), size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    onChanged: controller.setSearchQuery,
                    decoration: const InputDecoration(
                      hintText: 'Tìm kiếm...',
                      hintStyle: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 6),
                    ),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label) {
    final isSelected = controller.viewTab.value == index;
    return Expanded(
      child: InkWell(
        onTap: () => controller.setViewTab(index),
        borderRadius: BorderRadius.circular(3),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
            border: isSelected
                ? Border.all(color: const Color(0xFFE2E8F0))
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.primary : const Color(0xFF64748B),
                fontSize: 10,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Obx(() {
      switch (controller.viewTab.value) {
        case 0:
          return _buildProductGrid();
        case 1:
          return _buildSalesHistory();
        case 2:
          return _buildPOS();
        default:
          return _buildProductGrid();
      }
    });
  }

  Widget _buildCategoryDropdown() {
    return Obx(
      () => Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: controller.selectedCategory.value.isEmpty
                ? null
                : controller.selectedCategory.value,
            hint: const Text('Danh mục', style: TextStyle(fontSize: 13)),
            isExpanded: true,
            style: const TextStyle(fontSize: 13, color: Colors.black),
            icon: const Icon(Icons.arrow_drop_down, size: 20),
            items: [
              const DropdownMenuItem(value: '', child: Text('Tất cả')),
              ...controller.categories.map(
                (c) => DropdownMenuItem(
                  value: c,
                  child: Text(c, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (value) => controller.setCategory(value ?? ''),
          ),
        ),
      ),
    );
  }

  Widget _buildProductGrid() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      final products = controller.filteredProducts;
      if (products.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 64,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                'Chưa có sản phẩm nào',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _showProductForm(Get.context!),
                icon: const Icon(Icons.add),
                label: const Text('Thêm Mới'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          12,
          0,
          12,
          80,
        ), // Bottom padding for FAB
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) =>
            _buildMobileProductCard(products[index], isPOS: false),
      );
    });
  }

  Widget _buildMobileProductCard(ProductModel product, {required bool isPOS}) {
    final catColor = _getCategoryColor(product.category);
    final catName = product.category ?? 'Khác';
    final isOut = product.isOutOfStock;
    final isLow = product.stock <= 5 && product.stock > 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () {
            if (isPOS) {
              controller.addToCart(product);
            } else {
              _showProductForm(Get.context!, product: product);
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: catColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(
                      _getCategoryIcon(product.category),
                      size: 20,
                      color: catColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (product.brand != null &&
                              product.brand!.isNotEmpty)
                            Text(
                              '${product.brand} • ',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: catColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              catName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: catColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Text(
                            controller.formatCurrency(product.salePrice),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isOut
                                  ? const Color(0xFFFEF2F2)
                                  : isLow
                                  ? const Color(0xFFFEF3C7)
                                  : const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isOut
                                  ? 'Hết hàng'
                                  : (isLow
                                        ? 'Kho: ${product.stock} ⚠'
                                        : 'Kho: ${product.stock}'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isOut
                                    ? const Color(0xFFDC2626)
                                    : isLow
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFF16A34A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Action Icon
                if (isPOS)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.add_shopping_cart,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String? category) {
    if (category == null) return Icons.inventory_2;
    final cat = category.toLowerCase();
    if (cat.contains('thuc an') || cat.contains('thức ăn'))
      return Icons.restaurant;
    if (cat.contains('phu kien') || cat.contains('phụ kiện'))
      return Icons.checkroom;
    if (cat.contains('do choi') || cat.contains('đồ chơi')) return Icons.toys;
    if (cat.contains('cham soc') || cat.contains('chăm sóc')) return Icons.spa;
    if (cat.contains('thuoc') || cat.contains('thuốc')) return Icons.medication;
    return Icons.inventory_2;
  }

  Color _getCategoryColor(String? category) {
    if (category == null) return Colors.grey;
    final cat = category.toLowerCase();
    if (cat.contains('thuc an') || cat.contains('thức ăn'))
      return Colors.orange;
    if (cat.contains('phu kien') || cat.contains('phụ kiện'))
      return Colors.purple;
    if (cat.contains('do choi') || cat.contains('đồ chơi')) return Colors.pink;
    if (cat.contains('cham soc') || cat.contains('chăm sóc'))
      return Colors.teal;
    if (cat.contains('thuoc') || cat.contains('thuốc')) return Colors.blue;
    return Colors.blueGrey;
  }

  Widget _buildSalesHistory() {
    return Obx(() {
      if (controller.sales.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'Chưa có lịch sử bán hàng',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
              ),
            ],
          ),
        );
      }

      // Mobile: Simple List instead of Table
      return ListView.separated(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: controller.sales.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final sale = controller.sales[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.sell, color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sale.productName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        DateFormat('dd/MM HH:mm').format(sale.saleDate),
                        style: TextStyle(
                          color: Colors.grey.shade900,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      controller.formatCurrency(sale.total),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      sale.returnedQuantity > 0
                          ? '${sale.quantity} (Trả ${sale.returnedQuantity}) x ${controller.formatCurrency(sale.unitPrice)}'
                          : '${sale.quantity} x ${controller.formatCurrency(sale.unitPrice)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    if (sale.caseCode != null) ...[
                      Text(
                        'BA: ${sale.caseCode} | Khách: ${sale.caseCustomerName ?? '?'}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (sale.caseVisitReasons != null &&
                          sale.caseVisitReasons!.isNotEmpty)
                        Text(
                          'Lý do: ${sale.caseVisitReasons}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade900,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ] else ...[
                      const Text(
                        'Loại: Bán lẻ',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    Text(
                      'NV: ${sale.mappedStaffName ?? sale.staffId ?? 'Không rõ'}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade900,
                      ),
                    ),
                  ],
                ),
                if (sale.isReturned)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Đã trả',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(
                      Icons.keyboard_return,
                      color: Colors.orange,
                      size: 18,
                    ),
                    tooltip: 'Hoàn trả hàng',
                    onPressed: () => _showReturnDialog(Get.context!, sale),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          );
        },
      );
    });
  }

  void _showReturnDialog(BuildContext context, ProductSaleModel sale) {
    final availableQty = sale.quantity - sale.returnedQuantity;
    if (availableQty <= 0) {
      Get.snackbar(
        'Thông báo',
        'Đơn hàng này rỗng hoặc đã hoàn trả toàn bộ.',
        backgroundColor: Colors.orange.shade100,
      );
      return;
    }

    final qtyController = TextEditingController(text: availableQty.toString());
    final refundController = TextEditingController(
      text: (sale.unitPrice * availableQty).toStringAsFixed(0),
    );

    Get.dialog(
      AlertDialog(
        title: const Text(
          'Hoàn Trả',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sale.productName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              'Có thể trả: $availableQty',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyController,
              decoration: const InputDecoration(
                labelText: 'Số lượng',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              onChanged: (val) {
                final q = int.tryParse(val) ?? 0;
                if (q > 0 && q <= availableQty) {
                  refundController.text = (sale.unitPrice * q).toStringAsFixed(
                    0,
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: refundController,
              decoration: const InputDecoration(
                labelText: 'Hoàn tiền (VND)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              final q = int.tryParse(qtyController.text) ?? 0;
              final amt = double.tryParse(refundController.text) ?? 0;
              if (q <= 0 || q > availableQty) {
                Get.snackbar(
                  'Lỗi',
                  'Số lượng không hợp lệ',
                  backgroundColor: Colors.red.shade100,
                );
                return;
              }
              if (controller.isReturning.value)
                return; // guard against double submit
              Get.back(); // Explicit dialog close
              controller.returnSaleItem(sale, q, amt);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  Widget _buildPOS() {
    return Stack(
      children: [
        // 1. Full Screen Product Grid
        Positioned.fill(
          child: _buildPOSProductGrid(
            bottomPadding: 160,
          ), // Add padding for cart bar
        ),

        // 2. Floating Cart Bar (Bottom)
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: _buildCompactCartSummary(),
        ),
      ],
    );
  }

  Widget _buildCompactCartSummary() {
    return Obx(() {
      if (controller.cartItems.isEmpty) return const SizedBox.shrink();

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${controller.cartItemCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tổng thanh toán',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        controller.formatCurrency(controller.cartTotal),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _showFullCartSheet(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Xem Giỏ Hàng'),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  void _showFullCartSheet() {
    Get.bottomSheet(
      Container(
        height: Get.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: _buildCartContent(),
            ), // Reuse existing cart logic but adapted
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildCartContent() {
    // Adapted from original _buildCart but purely for the sheet content
    return Obx(
      () => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Chi tiết đơn hàng',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (controller.cartItems.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      controller.clearCart();
                      Get.back();
                    },
                    child: const Text(
                      'Xóa tất cả',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
            const Divider(),
            Expanded(
              child: controller.cartItems.isEmpty
                  ? const Center(child: Text('Giỏ hàng trống'))
                  : ListView.separated(
                      itemCount: controller.cartItems.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final item = controller.cartItems[index];
                        return Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    controller.formatCurrency(
                                      item.product.salePrice,
                                    ),
                                    style: TextStyle(
                                      color: Colors.grey.shade900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () =>
                                      controller.updateCartItemQuantity(
                                        item.product.id,
                                        item.quantity - 1,
                                      ),
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Text(
                                  '${item.quantity}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      controller.updateCartItemQuantity(
                                        item.product.id,
                                        item.quantity + 1,
                                      ),
                                  icon: const Icon(
                                    Icons.add_circle,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            // Staff Selector
            Obx(
              () => DropdownButtonFormField<String>(
                value: controller.selectedStaffId.value.isEmpty
                    ? null
                    : controller.selectedStaffId.value,
                decoration: InputDecoration(
                  labelText: 'Nhân viên bán hàng',
                  labelStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13, color: Colors.black),
                items: controller.staffList
                    .map(
                      (s) => DropdownMenuItem(
                        value: s['id'] as String,
                        child: Text(s['name'] as String),
                      ),
                    )
                    .toList(),
                onChanged: (val) =>
                    controller.selectedStaffId.value = val ?? '',
              ),
            ),
            const SizedBox(height: 12),
            // Payment Method Selection
            Obx(
              () => Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () =>
                          controller.selectedPaymentMethod.value = 'cash',
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color:
                              controller.selectedPaymentMethod.value == 'cash'
                              ? AppColors.successLight
                              : Colors.white,
                          border: Border.all(
                            color:
                                controller.selectedPaymentMethod.value == 'cash'
                                ? AppColors.success
                                : AppColors.border,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Tiền mặt',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color:
                                controller.selectedPaymentMethod.value == 'cash'
                                ? AppColors.success
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () =>
                          controller.selectedPaymentMethod.value = 'transfer',
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color:
                              controller.selectedPaymentMethod.value ==
                                  'transfer'
                              ? AppColors.primaryLight
                              : Colors.white,
                          border: Border.all(
                            color:
                                controller.selectedPaymentMethod.value ==
                                    'transfer'
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Chuyển khoản',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color:
                                controller.selectedPaymentMethod.value ==
                                    'transfer'
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.only(top: 12),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: controller.cartItems.isEmpty
                        ? null
                        : () {
                            Get.back();
                            controller.completeSale();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Thanh Toán ${controller.formatCurrency(controller.cartTotal)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPOSProductGrid({double bottomPadding = 0}) {
    return Obx(() {
      final products = controller.filteredProducts
          .where((p) => !p.isOutOfStock)
          .toList();

      if (products.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 48,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 8),
              Text(
                'Không có sản phẩm',
                style: TextStyle(color: Colors.grey.shade800),
              ),
            ],
          ),
        );
      }

      return ListView.separated(
        padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPadding),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final p = products[index];
          return _buildMobileProductCard(p, isPOS: true);
        },
      );
    });
  }

  Widget _buildCart() {
    return Obx(
      () => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.shopping_cart,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Giỏ Hàng (${controller.cartItemCount})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (controller.cartItems.isNotEmpty)
                  TextButton(
                    onPressed: controller.clearCart,
                    child: const Text('Xóa', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            const Divider(),
            Expanded(
              child: controller.cartItems.isEmpty
                  ? Center(
                      child: Text(
                        'Giỏ hàng trống',
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 12,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: controller.cartItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = controller.cartItems[index];
                        return Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    controller.formatCurrency(
                                      item.product.salePrice,
                                    ),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () => controller.updateCartItemQuantity(
                                item.product.id,
                                item.quantity - 1,
                              ),
                              child: Icon(
                                Icons.remove_circle,
                                size: 24,
                                color: Colors.grey.shade900,
                              ),
                            ),
                            SizedBox(
                              width: 24,
                              child: Center(
                                child: Text(
                                  '${item.quantity}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => controller.updateCartItemQuantity(
                                item.product.id,
                                item.quantity + 1,
                              ),
                              child: const Icon(
                                Icons.add_circle,
                                size: 24,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),

            // Total & Checkout
            Container(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tổng:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        controller.formatCurrency(controller.cartTotal),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: controller.cartItems.isEmpty
                          ? null
                          : () => controller.completeSale(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Thanh Toán',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Reuse dialog logic (duplicate for now to be safe, should refactor to controller mixin later)
  void _showProductForm(BuildContext context, {ProductModel? product}) {
    if (product != null) {
      controller.setupFormForEdit(product);
    } else {
      controller.resetForm();
    }

    // Responsive Dialog (Mobile full width)
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Form(
            key: controller.formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.edit, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        product != null ? 'Sửa' : 'Thêm Mới',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Get.back(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Fields (Simplified for Mobile)
                  TextFormField(
                    controller: controller.nameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên SP',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: controller.costPriceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Giá Vốn',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: controller.salePriceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Giá Bán',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: controller.stockController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Tồn Kho',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      await controller.saveProduct();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Lưu Sản Phẩm'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
