import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/widgets/main_layout.dart';
import '../../../core/widgets/custom_search_field.dart'; // Added
import '../../../data/models/appointment_model.dart';
import '../../../data/models/customer_model.dart'; // Added
import '../../../core/widgets/pro_widgets.dart'; // Added
import '../controllers/appointment_controller.dart';
import 'mobile/appointment_mobile_view.dart';

class AppointmentListView extends StatefulWidget {
  const AppointmentListView({super.key});

  @override
  State<AppointmentListView> createState() => _AppointmentListViewState();
}

class _AppointmentListViewState extends State<AppointmentListView> {
  final AppointmentController controller = Get.find<AppointmentController>();

  @override
  void initState() {
    super.initState();
    _handleDeepLink();
  }

  void _handleDeepLink() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = Get.arguments;
      if (args != null && args is Map && args['showDetail'] is AppointmentModel) {
        final apt = args['showDetail'] as AppointmentModel;
        if (MediaQuery.of(context).size.width < 600) {
          // Unfortunately we can't easily trigger the mobile bottom sheet directly from here without duplicating, 
          // because it's inside AppointmentMobileView. So we just show the desktop dialog for both.
          _showAppointmentDetail(apt);
        } else {
          _showAppointmentDetail(apt);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Lich Hen',
      actions: [
        Obx(
          () => IconButton(
            onPressed: controller.toggleViewMode,
            icon: Icon(
              controller.viewMode.value == 'list'
                  ? Icons.calendar_month
                  : Icons.list,
            ),
            tooltip: controller.viewMode.value == 'list'
                ? 'Xem lịch'
                : 'Xem danh sách',
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => _showAppointmentForm(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Thêm Lịch Hẹn'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            return const AppointmentMobileView();
          }
          return Column(
            children: [
              _buildStats(),
              const SizedBox(height: 4),
              _buildFilters(),
              const SizedBox(height: 6),
              Expanded(
                child: Obx(
                  () => controller.viewMode.value == 'list'
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildDesktopTableHeader(),
                            Expanded(child: _buildAppointmentList()),
                          ],
                        )
                      : _buildCalendarView(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStats() {
    return Obx(() {
      final stats = [
        _buildProStatCard(
          'Hôm Nay',
          controller.todayCount.toString(),
          Icons.today,
          Colors.blue,
        ),
        _buildProStatCard(
          'Chờ XN',
          controller.pendingCount.toString(),
          Icons.schedule,
          Colors.orange,
        ),
        _buildProStatCard(
          'Đã XN',
          controller.confirmedCount.toString(),
          Icons.check_circle,
          Colors.green,
        ),
        _buildProStatCard(
          'Tổng',
          controller.totalAppointments.toString(),
          Icons.calendar_today,
          AppColors.primary,
        ),
      ];

      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: stats
                  .map(
                    (e) => SizedBox(
                      width: (constraints.maxWidth - 6) / 2,
                      child: e,
                    ),
                  )
                  .toList(),
            );
          }

          return Row(
            children: stats
                .map(
                  (e) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: e,
                    ),
                  ),
                )
                .toList(),
          );
        },
      );
    });
  }

  Widget _buildProStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 13),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 800;

          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status Filter
                Obx(
                  () => DropdownButtonFormField<String>(
                    value: controller.selectedStatus.value.isEmpty
                        ? null
                        : controller.selectedStatus.value,
                    decoration: InputDecoration(
                      labelText: 'Trạng thái',
                      labelStyle: TextStyle(
                        color: Colors.grey.shade900,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(Icons.flag_outlined, size: 18),
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
                        vertical: 0,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Tất cả')),
                      ...AppointmentStatus.all.map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(AppointmentStatus.getLabel(s)),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        controller.setStatusFilter(value ?? ''),
                  ),
                ),
                const SizedBox(height: 12),

                // Date Filter
                Obx(
                  () => InkWell(
                    onTap: () => _selectDate(),
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Ngày',
                        labelStyle: TextStyle(
                          color: Colors.grey.shade900,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                        ),
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
                          vertical: 0,
                        ),
                        suffixIcon: controller.selectedDate.value != null
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () => controller.setDateFilter(null),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              )
                            : null,
                      ),
                      child: Text(
                        controller.selectedDate.value != null
                            ? DateFormat(
                                'dd/MM/yyyy',
                              ).format(controller.selectedDate.value!)
                            : 'Chọn ngày',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Quick Filters Row
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildQuickFilterButton(
                        'Hôm nay',
                        () => controller.setDateFilter(DateTime.now()),
                      ),
                      const SizedBox(width: 8),
                      _buildQuickFilterButton(
                        'Ngày mai',
                        () => controller.setDateFilter(
                          DateTime.now().add(const Duration(days: 1)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: controller.clearFilters,
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        tooltip: 'Xóa bộ lọc',
                        style: IconButton.styleFrom(
                          foregroundColor: Colors.grey,
                        ),
                      ),
                      IconButton(
                        onPressed: controller.loadAppointments,
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Tải lại',
                        style: IconButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          // Desktop Layout
          return Row(
            children: [
              // Status filter
              Expanded(
                child: Obx(
                  () => DropdownButtonFormField<String>(
                    value: controller.selectedStatus.value.isEmpty
                        ? null
                        : controller.selectedStatus.value,
                    decoration: InputDecoration(
                      labelText: 'Trạng thái',
                      labelStyle: TextStyle(
                        color: Colors.grey.shade900,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(Icons.flag_outlined, size: 18),
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
                        vertical: 0,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Tất cả')),
                      ...AppointmentStatus.all.map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(AppointmentStatus.getLabel(s)),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        controller.setStatusFilter(value ?? ''),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Date filter
              Expanded(
                child: Obx(
                  () => InkWell(
                    onTap: () => _selectDate(),
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Ngày',
                        labelStyle: TextStyle(
                          color: Colors.grey.shade900,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                        ),
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
                          vertical: 0,
                        ),
                        suffixIcon: controller.selectedDate.value != null
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () => controller.setDateFilter(null),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              )
                            : null,
                      ),
                      child: Text(
                        controller.selectedDate.value != null
                            ? DateFormat(
                                'dd/MM/yyyy',
                              ).format(controller.selectedDate.value!)
                            : 'Chọn ngày',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Quick filters
              _buildQuickFilterButton(
                'Hôm nay',
                () => controller.setDateFilter(DateTime.now()),
              ),
              const SizedBox(width: 8),
              _buildQuickFilterButton(
                'Ngày mai',
                () => controller.setDateFilter(
                  DateTime.now().add(const Duration(days: 1)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: controller.clearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined),
                tooltip: 'Xóa bộ lọc',
                style: IconButton.styleFrom(foregroundColor: Colors.grey),
              ),
              IconButton(
                onPressed: controller.loadAppointments,
                icon: const Icon(Icons.refresh),
                tooltip: 'Tải lại',
                style: IconButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuickFilterButton(String label, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        side: BorderSide(color: Colors.grey.shade300),
        foregroundColor: AppColors.textPrimary,
      ),
      child: Text(label),
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: Get.context!,
      initialDate: controller.selectedDate.value ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) {
      controller.setDateFilter(date);
    }
  }

  Widget _buildAppointmentList() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      final appointments = controller.filteredAppointments;
      if (appointments.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_today, size: 64, color: Colors.grey.shade900),
              const SizedBox(height: 16),
              Text(
                'Khong co lich hen nao',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade900),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _showAppointmentForm(Get.context!),
                icon: const Icon(Icons.add),
                label: const Text('Tao Lich Hen'),
              ),
            ],
          ),
        );
      }

      // Group by date
      final grouped = <String, List<AppointmentModel>>{};
      for (final apt in appointments) {
        final dateKey = DateFormat('yyyy-MM-dd').format(apt.appointmentDate);
        grouped.putIfAbsent(dateKey, () => []);
        grouped[dateKey]!.add(apt);
      }

      final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

      return ListView.builder(
        controller: controller.scrollController,
        itemCount: sortedKeys.length,
        itemBuilder: (context, index) {
          final dateKey = sortedKeys[index];
          final dateAppointments = grouped[dateKey]!;
          final date = DateTime.parse(dateKey);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _isToday(date)
                            ? AppColors.primary
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatDateHeader(date),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: _isToday(date)
                              ? Colors.white
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${dateAppointments.length} lịch hẹn',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                color: Colors.white,
                child: Column(
                  children: dateAppointments.map((apt) => _buildAppointmentCard(apt)).toList(),
                ),
              ),
            ],
          );
        },
      );
    });
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    if (_isToday(date)) return 'Hom nay';
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day + 1) {
      return 'Ngay mai';
    }
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      return 'Hom qua';
    }
    return DateFormat('EEEE, dd/MM/yyyy', 'vi').format(date);
  }

  Widget _buildDesktopTableHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 2),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _buildHeaderCell('Thời gian', flex: 2),
          _buildHeaderCell('Khách hàng', flex: 3),
          _buildHeaderCell('Thú cưng', flex: 3),
          _buildHeaderCell('Dịch vụ', flex: 2),
          _buildHeaderCell('Bác sĩ', flex: 2),
          _buildHeaderCell('Trạng thái', flex: 2),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(AppointmentModel appointment) {
    final statusColor = controller.getStatusColor(appointment.status);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAppointmentDetail(appointment),
          hoverColor: const Color(0xFFF8FAFC),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.time ?? '--:--',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        DateFormat('dd/MM/yyyy').format(appointment.appointmentDate),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.customerName ?? '—',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (appointment.customerPhone != null)
                        Text(
                          appointment.customerPhone!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.petName ?? '—',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // We don't have active sync for breed/age immediately available in list view typically, but we can safely leave subtitle blank or render 'Thú cưng'.
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    appointment.reason ?? '—',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text(
                    '—', // Assume Doctor info not present in model payload mapping
                    style: TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        AppointmentStatus.getLabel(appointment.status),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.grey.shade900),
                    onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _showAppointmentForm(
                          Get.context!,
                          appointment: appointment,
                        );
                        break;
                      case 'delete':
                        controller.deleteAppointment(appointment);
                        break;
                      case 'confirm':
                        controller.updateStatus(appointment.id, 'confirmed');
                        break;
                      case 'complete':
                        controller.updateStatus(appointment.id, 'completed');
                        break;
                      case 'cancel':
                        controller.updateStatus(appointment.id, 'cancelled');
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    if (appointment.status == 'pending')
                      const PopupMenuItem(
                        value: 'confirm',
                        child: ListTile(
                          leading: Icon(Icons.check_circle, color: Colors.blue),
                          title: Text('Xác nhận'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    if (appointment.status == 'confirmed')
                      const PopupMenuItem(
                        value: 'complete',
                        child: ListTile(
                          leading: Icon(Icons.done_all, color: Colors.green),
                          title: Text('Hoàn thành'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit),
                        title: Text('Sửa'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (appointment.status != 'cancelled')
                      const PopupMenuItem(
                        value: 'cancel',
                        child: ListTile(
                          leading: Icon(Icons.cancel, color: Colors.orange),
                          title: Text('Hủy'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.red),
                        title: Text('Xóa', style: TextStyle(color: Colors.red)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarView() {
    return Obx(() {
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

      return Column(
        children: [
          // Month header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('MMMM yyyy', 'vi').format(now),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Calendar grid
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Weekday headers
                    Row(
                      children: ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
                          .map(
                            (day) => Expanded(
                              child: Center(
                                child: Text(
                                  day,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    // Calendar days
                    Expanded(
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              childAspectRatio: 1.2,
                            ),
                        itemCount: 42,
                        itemBuilder: (context, index) {
                          final startOffset = firstDayOfMonth.weekday - 1;
                          final dayNumber = index - startOffset + 1;

                          if (dayNumber < 1 || dayNumber > lastDayOfMonth.day) {
                            return const SizedBox();
                          }

                          final date = DateTime(now.year, now.month, dayNumber);
                          final dayAppointments = controller
                              .getAppointmentsForDate(date);
                          final isToday = _isToday(date);

                          return InkWell(
                            onTap: () {
                              controller.setDateFilter(date);
                              controller.viewMode.value = 'list';
                            },
                            child: Container(
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: isToday
                                    ? AppColors.primary.withOpacity(0.2)
                                    : null,
                                border: isToday
                                    ? Border.all(
                                        color: AppColors.primary,
                                        width: 2,
                                      )
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    dayNumber.toString(),
                                    style: TextStyle(
                                      fontWeight: isToday
                                          ? FontWeight.bold
                                          : null,
                                      color: isToday ? AppColors.primary : null,
                                    ),
                                  ),
                                  if (dayAppointments.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${dayAppointments.length}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
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
              ),
            ),
          ),
        ],
      );
    });
  }

  void _showAppointmentDetail(AppointmentModel appointment) {
    final statusColor = controller.getStatusColor(appointment.status);
    Get.dialog(
      Dialog(
        child: Container(
          width: ResponsiveHelper.dialogWidth(Get.context!, 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      controller.getStatusIcon(appointment.status),
                      color: statusColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lich Hen',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        Text(
                          DateFormat(
                            'EEEE, dd/MM/yyyy',
                            'vi',
                          ).format(appointment.appointmentDate),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (appointment.time != null)
                          Text(
                            'Luc ${appointment.time}',
                            style: const TextStyle(fontSize: 16),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      AppointmentStatus.getLabel(appointment.status),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              _buildDetailRow(
                'Khach hang',
                appointment.customerName ?? 'Chua ro',
              ),
              _buildDetailRow(
                'So dien thoai',
                appointment.customerPhone ?? 'Chua ro',
              ),
              if (appointment.petName != null)
                _buildDetailRow('Thu cung', appointment.petName!),
              if (appointment.reason != null)
                _buildDetailRow('Ly do', appointment.reason!),
              if (appointment.notes != null)
                _buildDetailRow('Ghi chu', appointment.notes!),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (appointment.status == 'pending')
                    OutlinedButton.icon(
                      onPressed: () {
                        Get.back();
                        controller.updateStatus(appointment.id, 'confirmed');
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Xac nhan'),
                    ),
                  if (appointment.status == 'confirmed') ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        Get.back();
                        controller.updateStatus(appointment.id, 'completed');
                      },
                      icon: const Icon(Icons.done_all),
                      label: const Text('Hoan thanh'),
                    ),
                  ],
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Get.back();
                      _showAppointmentForm(
                        Get.context!,
                        appointment: appointment,
                      );
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Sua'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _showAppointmentForm(
    BuildContext context, {
    AppointmentModel? appointment,
  }) {
    if (appointment != null) {
      controller.setupFormForEdit(appointment);
    } else {
      controller.resetForm();
    }

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: ResponsiveHelper.dialogWidth(context, 420),
          padding: const EdgeInsets.all(16),
          child: Form(
            key: controller.formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        appointment != null
                            ? 'Sửa Lịch Hẹn'
                            : 'Thêm Lịch Hẹn',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      IconButton(
                        onPressed: () => Get.back(),
                        icon: const Icon(Icons.close),
                        color: const Color(0xFF94A3B8),
                        splashRadius: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Customer Selection using Search Field to prevent freeze with large lists
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Obx(
                          () => CustomSearchField<CustomerModel>(
                            items: controller.customers.toList(),
                            label: 'Khach hang *',
                            hint: 'Tim kiem khach hang theo ten hoac SDT',
                            prefixIcon: const Icon(Icons.person),
                            displayStringForOption: (customer) =>
                                '${customer.name} - ${customer.phone}',
                            onSelected: (customer) {
                              controller.selectedCustomerId.value = customer.id;
                              controller.selectedPetId.value = '';
                              controller.loadPetsByCustomer(customer.id);
                            },
                            listItemBuilder: (context, customer) {
                              return ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.person, size: 16),
                                ),
                                title: Text(
                                  customer.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(customer.phone),
                                trailing: customer.address != null
                                    ? Icon(
                                        Icons.location_on,
                                        size: 12,
                                        color: Colors.grey.shade900,
                                      )
                                    : null,
                              );
                            },
                            controller: TextEditingController(
                              text: appointment != null
                                  ? controller.customers
                                        .firstWhereOrNull(
                                          (c) => c.id == appointment.customerId,
                                        )
                                        ?.name
                                  : '',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.person_add, color: AppColors.primary, size: 20),
                            tooltip: 'Thêm khách hàng',
                            onPressed: () => _showQuickAddCustomer(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Pet dropdown
                  Obx(
                    () => DropdownButtonFormField<String>(
                      value: controller.selectedPetId.value.isEmpty
                          ? null
                          : controller.selectedPetId.value,
                      decoration: InputDecoration(
                        labelText: 'Thú cưng',
                        labelStyle: TextStyle(
                          color: Colors.grey.shade900,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(Icons.pets, size: 20),
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
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('-- Chọn thú cưng --'),
                        ),
                        ...controller.customerPets.map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text('${p.name} (${p.species})'),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          controller.selectedPetId.value = value ?? '',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Date and Time row
                  Row(
                    children: [
                      Expanded(
                        child: Obx(
                          () => InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate:
                                    controller.appointmentDate.value ??
                                    DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2030),
                              );
                              if (date != null) {
                                controller.appointmentDate.value = date;
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Ngày hẹn *',
                                labelStyle: TextStyle(
                                  color: Colors.grey.shade900,
                                  fontSize: 13,
                                ),
                                prefixIcon: const Icon(
                                  Icons.calendar_today,
                                  size: 20,
                                ),
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
                              child: Text(
                                controller.appointmentDate.value != null
                                    ? DateFormat('dd/MM/yyyy').format(
                                        controller.appointmentDate.value!,
                                      )
                                    : 'Chọn ngày',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Obx(
                          () => DropdownButtonFormField<String>(
                            value: controller.appointmentTime.value != null
                                ? '${controller.appointmentTime.value!.hour.toString().padLeft(2, '0')}:${controller.appointmentTime.value!.minute.toString().padLeft(2, '0')}'
                                : null,
                            decoration: InputDecoration(
                              labelText: 'Giờ hẹn',
                              labelStyle: TextStyle(
                                color: Colors.grey.shade900,
                                fontSize: 13,
                              ),
                              prefixIcon: const Icon(
                                Icons.access_time,
                                size: 20,
                              ),
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
                            items: controller.timeSlots
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                final parts = value.split(':');
                                controller.appointmentTime.value = TimeOfDay(
                                  hour: int.parse(parts[0]),
                                  minute: int.parse(parts[1]),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Reason
                  ProTextField(
                    label: 'Lý do hẹn',
                    controller: controller.reasonController,
                    prefixIcon: Icons.description_outlined,
                  ),
                  const SizedBox(height: 16),

                  // Status (only for edit)
                  if (appointment != null)
                    Obx(
                      () => DropdownButtonFormField<String>(
                        value: controller.formStatus.value,
                        decoration: InputDecoration(
                          labelText: 'Trạng thái',
                          labelStyle: TextStyle(
                            color: Colors.grey.shade900,
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(Icons.flag_outlined, size: 20),
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
                        items: AppointmentStatus.all
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(AppointmentStatus.getLabel(s)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            controller.formStatus.value = value ?? 'pending',
                      ),
                    ),
                  if (appointment != null) const SizedBox(height: 16),

                  // Notes
                  ProTextField(
                    label: 'Ghi chú',
                    controller: controller.notesController,
                    prefixIcon: Icons.note_outlined,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Get.back(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            foregroundColor: const Color(0xFF475569),
                          ),
                          child: const Text(
                            'Hủy',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Obx(
                          () => ElevatedButton(
                            onPressed: controller.isLoading.value
                                ? null
                                : () async {
                                    if (await controller.saveAppointment()) {
                                      Get.back();
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: controller.isLoading.value
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    appointment != null ? 'Cập Nhật' : 'Lưu Lịch Hẹn',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
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

  void _showQuickAddCustomer(BuildContext context) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: ResponsiveHelper.dialogWidth(context, 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Thêm Khách Hàng',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close),
                    color: const Color(0xFF94A3B8),
                    splashRadius: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ProTextField(
                label: 'Tên khách hàng *',
                controller: controller.quickCustomerNameController,
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: 16),
              ProTextField(
                label: 'Số điện thoại *',
                controller: controller.quickCustomerPhoneController,
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_outlined,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        foregroundColor: const Color(0xFF475569),
                      ),
                      child: const Text(
                        'Hủy',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Obx(
                      () => ElevatedButton(
                        onPressed: controller.isLoading.value
                            ? null
                            : () => controller.quickAddCustomer(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: controller.isLoading.value
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Thêm mới',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
