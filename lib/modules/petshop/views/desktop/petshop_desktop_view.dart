import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:okada_vet_clinic/core/constants/app_colors.dart';
import 'package:okada_vet_clinic/core/widgets/pro_widgets.dart';
import 'package:okada_vet_clinic/data/models/product_model.dart';
import 'package:okada_vet_clinic/modules/petshop/controllers/petshop_controller.dart';

class PetshopDesktopView extends GetView<PetshopController> {
  const PetshopDesktopView({super.key});

  static const _teal = Color(0xFF0D9488);
  static const _tealLight = Color(0xFFCCFBF1);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildStatsBar(),
        _buildToolbar(),
        Expanded(child: _buildContent()),
      ],
    );
  }

  // ── STATS BAR ──────────────────────────────────
  Widget _buildStatsBar() {
    return Obx(
      () => Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFAFBFC),
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              _statItem(
                Icons.inventory_2,
                'Tổng SP',
                controller.totalProducts.toString(),
                _teal,
                _tealLight,
              ),
              _divider(),
              _statItem(
                Icons.attach_money,
                'Doanh thu hôm nay',
                controller.formatCurrency(controller.todayRevenue),
                const Color(0xFF16A34A),
                const Color(0xFFDCFCE7),
              ),
              _divider(),
              _statItem(
                Icons.account_balance_wallet,
                'Giá trị kho',
                controller.formatCurrency(controller.totalStockValue),
                const Color(0xFF2563EB),
                const Color(0xFFDBEAFE),
              ),
              _divider(),
              _statItem(
                Icons.warning_amber,
                'Sắp hết hàng',
                controller.lowStockCount.toString(),
                const Color(0xFFD97706),
                const Color(0xFFFEF3C7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statItem(
    IconData icon,
    String label,
    String value,
    Color valueColor,
    Color iconBg,
  ) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 16, color: valueColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: valueColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
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

  Widget _divider() => Container(width: 1, color: Colors.grey.shade200);

  // ── TOOLBAR ────────────────────────────────────
  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                _tabItem(0, 'Sản Phẩm'),
                _tabItem(1, 'Lịch Sử Bán'),
                _tabItem(2, 'Bán Hàng'),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Category filter
          Obx(
            () => Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(6),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: controller.selectedCategory.value.isEmpty
                      ? null
                      : controller.selectedCategory.value,
                  hint: Text(
                    'Danh mục',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade900),
                  ),
                  isDense: true,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF0F172A),
                  ),
                  icon: Icon(
                    Icons.arrow_drop_down,
                    size: 16,
                    color: Colors.grey.shade900,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(
                        'Tất cả',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade900,
                        ),
                      ),
                    ),
                    ...controller.categories.map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(
                          c,
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => controller.setCategory(v ?? ''),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Search
          Expanded(
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 16, color: Colors.grey.shade900),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      onChanged: controller.setSearchQuery,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: 'Tìm sản phẩm...',
                        hintStyle: TextStyle(fontSize: 12),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 28,
            height: 28,
            child: IconButton(
              onPressed: () {
                controller.clearFilters();
                controller.loadProducts();
              },
              icon: const Icon(Icons.refresh, size: 14),
              tooltip: 'Tải lại',
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF1F5F9),
                foregroundColor: const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabItem(int index, String label) {
    return Obx(() {
      final isActive = controller.viewTab.value == index;
      return InkWell(
        onTap: () => controller.setViewTab(index),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive
                  ? const Color(0xFF0F172A)
                  : const Color(0xFF64748B),
            ),
          ),
        ),
      );
    });
  }

  // ── CONTENT ────────────────────────────────────
  Widget _buildContent() {
    return Obx(() {
      switch (controller.viewTab.value) {
        case 1:
          return _buildSalesHistory();
        case 2:
          return _buildPOS();
        default:
          return _buildProductTable();
      }
    });
  }

  // ── PRODUCT TABLE (NEW — replaces grid per mockup) ─────────────────────
  Widget _buildProductTable() {
    return Obx(() {
      if (controller.isLoading.value && controller.products.isEmpty) {
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
                size: 48,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 12),
              Text(
                'Chưa có sản phẩm nào',
                style: TextStyle(color: Colors.grey.shade800),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _showProductForm(Get.context!),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Thêm Sản Phẩm'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      }

      const pageSize = 20;
      final totalPages = (products.length / pageSize).ceil();
      final currentPage = controller.currentPage.value.clamp(0, totalPages - 1);
      final start = currentPage * pageSize;
      final end = (start + pageSize).clamp(0, products.length);
      final pageProducts = products.sublist(start, end);
      final fmt = NumberFormat('#,###', 'vi');

      return Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Table(
                columnWidths: const {
                  0: FixedColumnWidth(36),
                  1: FlexColumnWidth(1),
                  2: FixedColumnWidth(100),
                  3: FixedColumnWidth(80),
                  4: FixedColumnWidth(90),
                  5: FixedColumnWidth(90),
                  6: FixedColumnWidth(70),
                  7: FixedColumnWidth(80),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                    ),
                    children: [
                      _th('#'),
                      _th('Sản phẩm'),
                      _th('Danh mục'),
                      _th('Tồn kho', align: TextAlign.right),
                      _th('Giá nhập', align: TextAlign.right),
                      _th('Giá bán', align: TextAlign.right),
                      _th('Lời %', align: TextAlign.right),
                      _th('Thao tác', align: TextAlign.center),
                    ],
                  ),
                  for (int i = 0; i < pageProducts.length; i++)
                    _productRow(pageProducts[i], start + i + 1, fmt),
                ],
              ),
            ),
          ),
          // Pagination
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hiển thị ${start + 1}-$end / ${products.length} sản phẩm',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                ),
                Row(
                  children: [
                    _pageBtn('‹', () {
                      if (currentPage > 0)
                        controller.currentPage.value = currentPage - 1;
                    }),
                    for (int i = 0; i < totalPages && i < 5; i++)
                      _pageBtn(
                        '${i + 1}',
                        () => controller.currentPage.value = i,
                        isActive: i == currentPage,
                      ),
                    _pageBtn('›', () {
                      if (currentPage < totalPages - 1)
                        controller.currentPage.value = currentPage + 1;
                    }),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _th(String text, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Color(0xFF475569),
          letterSpacing: 0.3,
        ),
        textAlign: align,
      ),
    );
  }

  TableRow _productRow(ProductModel p, int index, NumberFormat fmt) {
    final isLow = p.stock <= 5 && p.stock > 0;
    final isOut = p.isOutOfStock;
    final catColor = _categoryBadgeColor(p.category);
    double margin = 0;
    if (p.costPrice > 0)
      margin = ((p.salePrice - p.costPrice) / p.costPrice) * 100;

    return TableRow(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      children: [
        _td(Text('$index', style: const TextStyle(fontSize: 13))),
        _td(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (p.brand != null && p.brand!.isNotEmpty)
                Text(
                  p.brand!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
                ),
            ],
          ),
        ),
        _td(_badge(p.category ?? 'Khác', catColor.$1, catColor.$2)),
        _td(
          isOut
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Hết',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                )
              : isLow
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${p.stock} ⚠',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFD97706),
                    ),
                  ),
                )
              : Text(
                  '${p.stock}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF16A34A),
                  ),
                ),
          align: TextAlign.right,
        ),
        _td(
          Text(
            p.costPrice > 0 ? fmt.format(p.costPrice) : '—',
            style: const TextStyle(fontSize: 13),
          ),
          align: TextAlign.right,
        ),
        _td(
          Text(
            fmt.format(p.salePrice),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _teal,
            ),
          ),
          align: TextAlign.right,
        ),
        _td(
          margin > 0
              ? Text(
                  '${margin.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: margin >= 30
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF64748B),
                  ),
                )
              : const Text(
                  '—',
                  style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                ),
          align: TextAlign.right,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _actBtn(
                Icons.edit,
                () => _showProductForm(Get.context!, product: p),
              ),
              const SizedBox(width: 4),
              _actBtn(Icons.delete, () => controller.deleteProduct(p)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _td(Widget child, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Align(
        alignment: align == TextAlign.right
            ? Alignment.centerRight
            : align == TextAlign.center
            ? Alignment.center
            : Alignment.centerLeft,
        child: child,
      ),
    );
  }

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: fg),
      ),
    );
  }

  Widget _actBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 14, color: const Color(0xFF64748B)),
      ),
    );
  }

  Widget _pageBtn(String label, VoidCallback onTap, {bool isActive = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: isActive ? _teal : Colors.white,
            border: Border.all(color: isActive ? _teal : Colors.grey.shade200),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isActive ? Colors.white : Colors.grey.shade900,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  (Color, Color) _categoryBadgeColor(String? category) {
    if (category == null)
      return (const Color(0xFFF1F5F9), const Color(0xFF475569));
    final cat = category.toLowerCase();
    if (cat.contains('thức ăn') || cat.contains('thuc an'))
      return (const Color(0xFFFEF3C7), const Color(0xFFD97706));
    if (cat.contains('phụ kiện') || cat.contains('phu kien'))
      return (const Color(0xFFEDE9FE), const Color(0xFF7C3AED));
    if (cat.contains('đồ chơi') || cat.contains('do choi'))
      return (const Color(0xFFFCE7F3), const Color(0xFFDB2777));
    if (cat.contains('chăm sóc') || cat.contains('cham soc'))
      return (const Color(0xFFCCFBF1), const Color(0xFF0D9488));
    if (cat.contains('thuốc') || cat.contains('thuoc'))
      return (const Color(0xFFDBEAFE), const Color(0xFF2563EB));
    return (const Color(0xFFF1F5F9), const Color(0xFF475569));
  }

  // ── SALES HISTORY ──────────────────────────────
  Widget _buildSalesHistory() {
    return Obx(() {
      if (controller.sales.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(
                'Chưa có lịch sử bán hàng',
                style: TextStyle(color: Colors.grey.shade800),
              ),
            ],
          ),
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: controller.sales.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (_, i) {
          final s = controller.sales[i];
          final fmt = NumberFormat('#,###', 'vi');
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _tealLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.receipt, color: _teal, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.productName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        s.returnedQuantity > 0
                            ? 'SL: ${s.quantity} (Đã trả: ${s.returnedQuantity})'
                            : 'SL: ${s.quantity}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${fmt.format(s.total)}₫',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _teal,
                      ),
                    ),
                    Text(
                      DateFormat('dd/MM HH:mm').format(s.saleDate),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    if (s.caseCode != null) ...[
                      Text(
                        'BA: ${s.caseCode} | Khách: ${s.caseCustomerName ?? '?'} | Thú: ${s.casePetName ?? '?'}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (s.caseVisitReasons != null &&
                          s.caseVisitReasons!.isNotEmpty)
                        Text(
                          'Lý do: ${s.caseVisitReasons}',
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
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    Text(
                      'NV: ${s.mappedStaffName ?? s.staffId ?? 'Không rõ'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                if (s.isReturned)
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
                      'Đã trả hàng',
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
                      size: 20,
                    ),
                    tooltip: 'Hoàn trả hàng',
                    onPressed: () => _showReturnDialog(Get.context!, s),
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
          'Hoàn Trả Hàng',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sản phẩm: ${sale.productName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Số lượng có thể trả: $availableQty'),
            const SizedBox(height: 16),
            TextField(
              controller: qtyController,
              decoration: const InputDecoration(
                labelText: 'Số lượng trả',
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
                labelText: 'Số tiền hoàn (VND)',
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
              Get.back(); // close dialog explicitly
              controller.returnSaleItem(sale, q, amt);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xác nhận hoàn hàng'),
          ),
        ],
      ),
    );
  }

  // ── POS ────────────────────────────────────────
  Widget _buildPOS() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: _buildPOSProductGrid()),
        const SizedBox(width: 16),
        Expanded(child: _buildCart()),
      ],
    );
  }

  Widget _buildPOSProductGrid() {
    return Obx(() {
      final products = controller.filteredProducts
          .where((p) => !p.isOutOfStock)
          .toList();
      if (products.isEmpty) {
        return Center(
          child: Text(
            'Không có sản phẩm còn hàng',
            style: TextStyle(color: Colors.grey.shade800),
          ),
        );
      }

      final fmt = NumberFormat('#,###', 'vi');

      // Use a compact list view for POS to match tabular consistency
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        margin: const EdgeInsets.only(left: 12, top: 12, bottom: 12),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(flex: 5, child: _th('Sản phẩm')),
                  Expanded(
                    flex: 2,
                    child: _th('Danh mục', align: TextAlign.center),
                  ),
                  Expanded(
                    flex: 1,
                    child: _th('Tồn kho', align: TextAlign.right),
                  ),
                  Expanded(
                    flex: 2,
                    child: _th('Giá bán', align: TextAlign.right),
                  ),
                  const SizedBox(width: 48), // space for add button
                ],
              ),
            ),
            // List
            Expanded(
              child: ListView.separated(
                itemCount: products.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey.shade100),
                itemBuilder: (context, index) {
                  final p = products[index];
                  final isLow = p.stock <= 5 && p.stock > 0;
                  final catColor = _categoryBadgeColor(p.category);

                  return InkWell(
                    onTap: () => controller.addToCart(p),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                if (p.brand != null && p.brand!.isNotEmpty)
                                  Text(
                                    p.brand!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: _badge(
                                p.category ?? 'Khác',
                                catColor.$1,
                                catColor.$2,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: isLow
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${p.stock} ⚠',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFD97706),
                                        ),
                                      ),
                                    )
                                  : Text(
                                      '${p.stock}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF16A34A),
                                      ),
                                    ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                fmt.format(p.salePrice),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _teal,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _tealLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.add_shopping_cart,
                              size: 16,
                              color: _teal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    });
  }

  // ── CART ────────────────────────────────────────
  Widget _buildCart() {
    return Obx(
      () => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shopping_cart, color: _teal, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Giỏ Hàng',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (controller.cartItems.isNotEmpty)
                  TextButton(
                    onPressed: controller.clearCart,
                    child: Text(
                      'Xóa',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red.shade400,
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 20),
            Expanded(
              child: controller.cartItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 40,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Giỏ hàng trống',
                            style: TextStyle(
                              color: Colors.grey.shade900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: controller.cartItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final item = controller.cartItems[i];
                        return Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.product.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      controller.formatCurrency(
                                        item.product.salePrice,
                                      ),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () =>
                                        controller.updateCartItemQuantity(
                                          item.product.id,
                                          item.quantity - 1,
                                        ),
                                    child: Icon(
                                      Icons.remove_circle_outline,
                                      size: 18,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 24,
                                    child: Center(
                                      child: Text(
                                        '${item.quantity}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () =>
                                        controller.updateCartItemQuantity(
                                          item.product.id,
                                          item.quantity + 1,
                                        ),
                                    child: const Icon(
                                      Icons.add_circle_outline,
                                      size: 18,
                                      color: _teal,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                controller.formatCurrency(
                                  item.product.salePrice * item.quantity,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: _teal,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            if (controller.cartItems.isNotEmpty) ...[
              const Divider(height: 20),
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
                                  controller.selectedPaymentMethod.value ==
                                      'cash'
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
                                  controller.selectedPaymentMethod.value ==
                                      'cash'
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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tổng cộng:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    controller.formatCurrency(controller.cartTotal),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _teal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: controller.completeSale,
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text(
                    'Thanh Toán',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── PRODUCT FORM (PRESERVED) ───────────────────
  void _showProductForm(BuildContext context, {ProductModel? product}) {
    if (product != null) {
      controller.setupFormForEdit(product);
    } else {
      controller.resetForm();
    }

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Form(
            key: controller.formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _teal.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          product != null ? Icons.edit : Icons.add,
                          color: _teal,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        product != null ? 'Sửa Sản Phẩm' : 'Thêm Sản Phẩm Mới',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Get.back(),
                        icon: const Icon(Icons.close),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey.shade100,
                          foregroundColor: Colors.grey.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ProTextField(
                    label: 'Tên Sản Phẩm *',
                    controller: controller.nameController,
                    prefixIcon: Icons.inventory_2_outlined,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ProTextField(
                          label: 'Thương Hiệu',
                          controller: controller.brandController,
                          prefixIcon: Icons.branding_watermark_outlined,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Obx(
                          () => DropdownButtonFormField<String>(
                            value: controller.categoryValue.value.isEmpty
                                ? null
                                : controller.categoryValue.value,
                            decoration: InputDecoration(
                              labelText: 'Danh Mục',
                              prefixIcon: const Icon(Icons.category_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            items: controller.categories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                controller.categoryValue.value = value ?? '',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ProTextField(
                          label: 'Giá Vốn *',
                          controller: controller.costPriceController,
                          keyboardType: TextInputType.number,
                          suffixText: 'VNĐ',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ProTextField(
                          label: 'Giá Bán *',
                          controller: controller.salePriceController,
                          keyboardType: TextInputType.number,
                          suffixText: 'VNĐ',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ProTextField(
                          label: 'Tồn Kho',
                          controller: controller.stockController,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Get.back(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Hủy'),
                      ),
                      const SizedBox(width: 16),
                      Obx(
                        () => ElevatedButton.icon(
                          onPressed: controller.isLoading.value
                              ? null
                              : () async {
                                  await controller.saveProduct();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          icon: controller.isLoading.value
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(
                            product != null ? 'Cập Nhật' : 'Lưu',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
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
