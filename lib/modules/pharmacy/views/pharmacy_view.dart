import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/widgets/main_layout.dart';
import '../../../core/widgets/pro_widgets.dart';
import '../../../data/models/medicine_model.dart';
import '../controllers/pharmacy_controller.dart';
import 'mobile/pharmacy_mobile_view.dart';

class PharmacyView extends GetView<PharmacyController> {
  const PharmacyView({super.key});

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Kho Thuốc',
      actions: [
        OutlinedButton.icon(
          onPressed: () => _showTransactionForm(context),
          icon: const Icon(Icons.swap_horiz, size: 18),
          label: const Text('Nhập/Xuất'),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFFB923C)),
            foregroundColor: const Color(0xFFEA580C),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => _showMedicineForm(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Thêm Thuốc'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
          ),
        ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            return const PharmacyMobileView();
          }
          return Column(
            children: [
              _buildStatsBar(),
              _buildToolbar(),
              Expanded(child: _buildContent()),
            ],
          );
        },
      ),
    );
  }

  // ── STATS BAR ──────────────────────────────────
  Widget _buildStatsBar() {
    return Obx(() {
      final medicines = controller.medicines;
      final total = medicines.length;
      final lowStock = medicines
          .where(
            (m) =>
                m.stock <= ((m.minStock ?? 0) > 0 ? m.minStock! : 10) &&
                m.stock > 0,
          )
          .length;
      final now = DateTime.now();
      final nearExpiry = medicines.where((m) {
        if (m.expiryDate == null) return false;
        final diff = m.expiryDate!.difference(now).inDays;
        return diff > 0 && diff <= 90;
      }).length;
      final expired = medicines.where((m) {
        if (m.expiryDate == null) return false;
        return m.expiryDate!.isBefore(now);
      }).length;

      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFAFBFC),
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              _statItem(
                Icons.medication,
                'Tổng thuốc',
                '$total',
                const Color(0xFF4F46E5),
                const Color(0xFFE0E7FF),
              ),
              _divider(),
              _statItem(
                Icons.warning_amber,
                'Sắp hết',
                '$lowStock',
                const Color(0xFFD97706),
                const Color(0xFFFEF3C7),
              ),
              _divider(),
              _statItem(
                Icons.schedule,
                'Sắp HSD',
                '$nearExpiry',
                const Color(0xFFEA580C),
                const Color(0xFFFFEDD5),
              ),
              _divider(),
              _statItem(
                Icons.dangerous,
                'Hết HSD',
                '$expired',
                const Color(0xFFDC2626),
                const Color(0xFFFEF2F2),
              ),
            ],
          ),
        ),
      );
    });
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                  ),
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
          // Tab group
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                _tabItem(0, 'Danh Sách'),
                _tabItem(1, 'Lịch Sử N/X'),
                _tabItem(2, 'Cảnh Báo'),
              ],
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
                        hintText: 'Tìm thuốc...',
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
          const SizedBox(width: 8),
          // Filter button
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.filter_list, size: 14, color: Colors.grey.shade900),
                const SizedBox(width: 4),
                Text(
                  'Nhóm thuốc',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade900),
                ),
              ],
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
          return _buildTransactionList();
        case 2:
          return _buildWarnings();
        default:
          return _buildMedicineTable();
      }
    });
  }

  // ── MEDICINE TABLE ─────────────────────────────
  Widget _buildMedicineTable() {
    return Obx(() {
      if (controller.isLoading.value && controller.medicines.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      final medicines = controller.filteredMedicines;
      if (medicines.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.medication_outlined,
                size: 48,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 12),
              Text(
                'Chưa có thuốc nào',
                style: TextStyle(color: Colors.grey.shade800),
              ),
            ],
          ),
        );
      }

      // Pagination
      const pageSize = 20;
      final totalPages = (medicines.length / pageSize).ceil();
      final currentPage = controller.currentPage.value.clamp(0, totalPages - 1);
      final start = currentPage * pageSize;
      final end = (start + pageSize).clamp(0, medicines.length);
      final pageMedicines = medicines.sublist(start, end);

      return Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Table(
                columnWidths: const {
                  0: FixedColumnWidth(36),
                  1: FlexColumnWidth(3),
                  2: FlexColumnWidth(1.5),
                  3: FixedColumnWidth(70),
                  4: FlexColumnWidth(1.5),
                  5: FixedColumnWidth(80),
                  6: FixedColumnWidth(80),
                  7: FixedColumnWidth(70),
                },
                children: [
                  // Header
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
                      _th('Tên thuốc'),
                      _th('Nhóm'),
                      _th('Tồn kho', align: TextAlign.right),
                      _th('HSD'),
                      _th('Giá nhập', align: TextAlign.right),
                      _th('Giá bán', align: TextAlign.right),
                      _th('Thao tác', align: TextAlign.center),
                    ],
                  ),
                  // Rows
                  for (int i = 0; i < pageMedicines.length; i++)
                    _buildMedicineRow(pageMedicines[i], start + i + 1),
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
                  'Hiển thị ${start + 1}-$end / ${medicines.length} thuốc',
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

  TableRow _buildMedicineRow(MedicineModel m, int index) {
    final now = DateTime.now();
    final isLowStock = m.stock <= ((m.minStock ?? 0) > 0 ? m.minStock! : 10);
    final isExpired = m.expiryDate != null && m.expiryDate!.isBefore(now);
    final isNearExpiry =
        m.expiryDate != null &&
        !isExpired &&
        m.expiryDate!.difference(now).inDays <= 90;
    final categoryColor = _getCategoryColor(m.unit);
    final fmt = NumberFormat('#,###', 'vi');

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
                m.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (m.unit != null && m.unit!.isNotEmpty)
                Text(
                  m.unit!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
                ),
            ],
          ),
        ),
        _td(_badge(m.unit ?? 'Khác', categoryColor.$1, categoryColor.$2)),
        _td(
          isLowStock && m.stock > 0
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${m.stock.toStringAsFixed(0)} ⚠',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                )
              : Text(
                  m.stock.toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF16A34A),
                  ),
                ),
          align: TextAlign.right,
        ),
        _td(
          m.expiryDate != null
              ? isExpired
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '✕ ${DateFormat('dd/MM/yy').format(m.expiryDate!)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFDC2626),
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      )
                    : isNearExpiry
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
                          '⚠ ${DateFormat('dd/MM/yy').format(m.expiryDate!)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      )
                    : Text(
                        DateFormat('dd/MM/yy').format(m.expiryDate!),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      )
              : const Text(
                  '—',
                  style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                ),
        ),
        _td(
          Text(
            m.avgPrice > 0 ? fmt.format(m.avgPrice) : '—',
            style: const TextStyle(fontSize: 13),
          ),
          align: TextAlign.right,
        ),
        _td(
          Text(
            fmt.format(m.avgPrice),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
                () => _showMedicineForm(Get.context!, medicine: m),
              ),
              const SizedBox(width: 4),
              _actBtn(Icons.delete, () => controller.deleteMedicine(m)),
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
            color: isActive ? const Color(0xFF4F46E5) : Colors.white,
            border: Border.all(
              color: isActive ? const Color(0xFF4F46E5) : Colors.grey.shade200,
            ),
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

  (Color, Color) _getCategoryColor(String? category) {
    switch (category?.toLowerCase()) {
      case 'kháng sinh':
        return (const Color(0xFFE0E7FF), const Color(0xFF4F46E5));
      case 'kháng viêm':
        return (const Color(0xFFCFFAFE), const Color(0xFF0891B2));
      case 'ký sinh trùng':
        return (const Color(0xFFEDE9FE), const Color(0xFF7C3AED));
      case 'dịch truyền':
        return (const Color(0xFFE0F2FE), const Color(0xFF0284C7));
      case 'vitamin':
        return (const Color(0xFFDCFCE7), const Color(0xFF16A34A));
      case 'giảm đau':
        return (const Color(0xFFFEF3C7), const Color(0xFFD97706));
      default:
        return (const Color(0xFFF1F5F9), const Color(0xFF475569));
    }
  }

  // ── TRANSACTION LIST ───────────────────────────
  Widget _buildTransactionList() {
    return Obx(() {
      final transactions = controller.transactions;
      if (transactions.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(
                'Chưa có lịch sử nhập/xuất',
                style: TextStyle(color: Colors.grey.shade800),
              ),
            ],
          ),
        );
      }

      final fmt = NumberFormat('#,###', 'vi');
      return ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: transactions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final t = transactions[index];
          final color = _getTransactionColor(t.type);
          final icon = t.type == 'import'
              ? Icons.add_circle
              : t.type == 'export'
              ? Icons.remove_circle
              : Icons.medical_services;
          final label = t.type == 'import'
              ? 'NHẬP'
              : t.type == 'export'
              ? 'XUẤT'
              : 'SỬ DỤNG';

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
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.getMedicineName(t.medicineId),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${t.quantity.toStringAsFixed(0)} · ${t.purpose ?? label}',
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
                    if (t.unitPrice != null && t.unitPrice! > 0)
                      Text(
                        '${fmt.format(t.unitPrice!)}₫',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Text(
                      t.createdAt != null
                          ? DateFormat('dd/MM HH:mm').format(t.createdAt!)
                          : '',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                _badge(label, color.withOpacity(0.15), color),
              ],
            ),
          );
        },
      );
    });
  }

  // ── WARNINGS ───────────────────────────────────
  Widget _buildWarnings() {
    return Obx(() {
      final now = DateTime.now();
      final lowStock = controller.medicines
          .where(
            (m) =>
                m.stock <= ((m.minStock ?? 0) > 0 ? m.minStock! : 10) &&
                m.stock > 0,
          )
          .toList();
      final nearExpiry = controller.medicines
          .where(
            (m) =>
                m.expiryDate != null &&
                !m.expiryDate!.isBefore(now) &&
                m.expiryDate!.difference(now).inDays <= 90,
          )
          .toList();
      final expired = controller.medicines
          .where((m) => m.expiryDate != null && m.expiryDate!.isBefore(now))
          .toList();

      if (lowStock.isEmpty && nearExpiry.isEmpty && expired.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, size: 48, color: Colors.green.shade300),
              const SizedBox(height: 12),
              Text(
                'Không có cảnh báo',
                style: TextStyle(color: Colors.grey.shade800),
              ),
            ],
          ),
        );
      }

      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (expired.isNotEmpty)
            _warningSection(
              'Hết Hạn Sử Dụng',
              expired,
              const Color(0xFFDC2626),
              Icons.dangerous,
            ),
          if (nearExpiry.isNotEmpty)
            _warningSection(
              'Sắp Hết HSD (≤90 ngày)',
              nearExpiry,
              const Color(0xFFD97706),
              Icons.schedule,
            ),
          if (lowStock.isNotEmpty)
            _warningSection(
              'Sắp Hết Hàng',
              lowStock,
              const Color(0xFFEA580C),
              Icons.warning_amber,
            ),
        ],
      );
    });
  }

  Widget _warningSection(
    String title,
    List<MedicineModel> medicines,
    Color color,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              _badge('${medicines.length}', color.withOpacity(0.15), color),
            ],
          ),
          const SizedBox(height: 8),
          ...medicines.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const SizedBox(width: 26),
                  Expanded(
                    child: Text(m.name, style: const TextStyle(fontSize: 12)),
                  ),
                  Text(
                    'Tồn: ${m.stock.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade900),
                  ),
                  if (m.expiryDate != null) ...[
                    const SizedBox(width: 12),
                    Text(
                      'HSD: ${DateFormat('dd/MM/yy').format(m.expiryDate!)}',
                      style: TextStyle(fontSize: 11, color: color),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── MEDICINE FORM (PRESERVED) ──────────────────
  void _showMedicineForm(BuildContext context, {MedicineModel? medicine}) {
    if (medicine != null) {
      controller.setupFormForEdit(medicine);
    } else {
      controller.resetForm();
    }

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: ResponsiveHelper.dialogWidth(context, 600),
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
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          medicine != null ? Icons.edit : Icons.add,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        medicine != null ? 'Sửa Thuốc' : 'Thêm Thuốc Mới',
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
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: ProTextField(
                          label: 'Mã Thuốc *',
                          controller: controller.codeController,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ProTextField(
                          label: 'Tên Thuốc *',
                          controller: controller.nameController,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ProTextField(
                          label: 'Đơn Vị',
                          controller: controller.unitController,
                          hint: 'Viên, ml, Ống...',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ProTextField(
                          label: 'Giá Bán',
                          controller: controller.avgPriceController,
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ProTextField(
                          label: 'Tồn Tối Thiểu',
                          controller: controller.minStockController,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ProTextField(
                          label: 'Số Lô',
                          controller: controller.lotNumberController,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ProTextField(
                          label: 'Nhà Cung Cấp',
                          controller: controller.supplierController,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Obx(
                    () => InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate:
                              controller.expiryDate.value ??
                              DateTime.now().add(const Duration(days: 365)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2035),
                        );
                        if (date != null) controller.expiryDate.value = date;
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 20,
                              color: Colors.grey.shade900,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hạn Sử Dụng',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  controller.expiryDate.value != null
                                      ? DateFormat(
                                          'dd/MM/yyyy',
                                        ).format(controller.expiryDate.value!)
                                      : 'Chọn ngày',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            if (controller.expiryDate.value != null)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () =>
                                    controller.expiryDate.value = null,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
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
                                  await controller.saveMedicine();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
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
                            medicine != null ? 'Cập Nhật' : 'Lưu',
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

  // ── TRANSACTION FORM (PRESERVED) ───────────────
  void _showTransactionForm(BuildContext context) {
    controller.resetTransactionForm();

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: ResponsiveHelper.dialogWidth(context, 500),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: controller.transFormKey,
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
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.swap_horiz,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Nhập / Xuất Kho',
                        style: TextStyle(
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
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTransactionTypeOption(
                            'Nhập Kho',
                            'import',
                            Icons.add_circle,
                          ),
                        ),
                        Expanded(
                          child: _buildTransactionTypeOption(
                            'Xuất Kho',
                            'export',
                            Icons.remove_circle,
                          ),
                        ),
                        Expanded(
                          child: _buildTransactionTypeOption(
                            'Sử Dụng',
                            'use',
                            Icons.medical_services,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Obx(
                    () => DropdownButtonFormField<String>(
                      value: controller.selectedMedicineId.value.isEmpty
                          ? null
                          : controller.selectedMedicineId.value,
                      decoration: InputDecoration(
                        labelText: 'Chọn Thuốc *',
                        prefixIcon: const Icon(Icons.medication_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      items: controller.medicines
                          .map(
                            (m) => DropdownMenuItem(
                              value: m.id,
                              child: Text(
                                '${m.code} - ${m.name} (Tồn: ${m.stock.toStringAsFixed(0)})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          controller.selectedMedicineId.value = value ?? '',
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Chọn thuốc' : null,
                      isExpanded: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ProTextField(
                          label: 'Số Lượng *',
                          controller: controller.quantityController,
                          keyboardType: TextInputType.number,
                          prefixIcon: Icons.numbers,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ProTextField(
                          label: 'Đơn Giá',
                          controller: controller.unitPriceController,
                          keyboardType: TextInputType.number,
                          suffixText: 'VNĐ',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ProTextField(
                    label: 'Mục Đích',
                    controller: controller.purposeController,
                    prefixIcon: Icons.description_outlined,
                  ),
                  const SizedBox(height: 16),
                  ProTextField(
                    label: 'Ghi Chú',
                    controller: controller.transNotesController,
                    maxLines: 2,
                    prefixIcon: Icons.note_outlined,
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
                                  await controller.saveTransaction();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getTransactionColor(
                              controller.transactionType.value,
                            ),
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
                              : Icon(
                                  controller.transactionType.value == 'import'
                                      ? Icons.add_circle
                                      : Icons.remove_circle,
                                ),
                          label: Text(
                            controller.transactionType.value == 'import'
                                ? 'Nhập Kho'
                                : 'Xuất Kho',
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

  Widget _buildTransactionTypeOption(
    String label,
    String value,
    IconData icon,
  ) {
    return Obx(() {
      final isSelected = controller.transactionType.value == value;
      final color = _getTransactionColor(value);
      return InkWell(
        onTap: () => controller.transactionType.value = value,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : Colors.grey, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? color : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Color _getTransactionColor(String type) {
    switch (type) {
      case 'import':
        return Colors.green;
      case 'export':
        return Colors.orange;
      case 'use':
        return Colors.blue;
      default:
        return AppColors.primary;
    }
  }
}
