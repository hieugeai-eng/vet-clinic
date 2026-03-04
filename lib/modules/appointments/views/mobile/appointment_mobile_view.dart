import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/pro_widgets.dart';
import '../../../../data/models/appointment_model.dart';
import '../../../../data/models/customer_model.dart';
import '../../controllers/appointment_controller.dart';

class AppointmentMobileView extends GetView<AppointmentController> {
  const AppointmentMobileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildStats(),
        const SizedBox(height: 8),
        _buildDateFilterAndActions(),
        const SizedBox(height: 6),
        _buildQuickFilters(),
        const SizedBox(height: 8),
        Expanded(child: _buildAppointmentList()),
      ],
    );
  }

  // ── Stats: 2x2 compact ───────────────────────────────────────────────
  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = (constraints.maxWidth - 8) / 2;
          return Obx(
            () => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _buildStatChip(
                    'Hôm Nay',
                    controller.todayCount.toString(),
                    Icons.today,
                    Colors.blue,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildStatChip(
                    'Chờ XN',
                    controller.pendingCount.toString(),
                    Icons.schedule,
                    Colors.orange,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildStatChip(
                    'Đã XN',
                    controller.confirmedCount.toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildStatChip(
                    'Tổng',
                    controller.totalAppointments.toString(),
                    Icons.calendar_today,
                    AppColors.primary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatChip(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Date Filter & Actions ────────────────────────────────────────────
  Widget _buildDateFilterAndActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          // Date filter button
          Expanded(
            child: Obx(() {
              final hasDate = controller.selectedDate.value != null;
              return InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: Get.context!,
                    initialDate:
                        controller.selectedDate.value ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(
                          primary: AppColors.primary,
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  controller.setDateFilter(date);
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: hasDate
                        ? AppColors.primary.withOpacity(0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: hasDate
                          ? AppColors.primary.withOpacity(0.3)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: hasDate
                            ? AppColors.primary
                            : Colors.grey.shade900,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          hasDate
                              ? DateFormat(
                                  'dd/MM/yyyy',
                                ).format(controller.selectedDate.value!)
                              : 'Chọn ngày',
                          style: TextStyle(
                            fontSize: 13,
                            color: hasDate
                                ? AppColors.primary
                                : Colors.grey.shade900,
                            fontWeight: hasDate
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (hasDate)
                        InkWell(
                          onTap: () => controller.setDateFilter(null),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.grey.shade800,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(width: 8),
          // Add appointment button
          ElevatedButton.icon(
            onPressed: () => _showAppointmentForm(),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Thêm', style: TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick Filters (horizontal scroll) ─────────────────────────────────
  Widget _buildQuickFilters() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Obx(
          () => Row(
            children: [
              _buildFilterChip('Tất cả', ''),
              const SizedBox(width: 24),
              _buildFilterChip('Chờ XN', 'pending'),
              const SizedBox(width: 24),
              _buildFilterChip('Đã XN', 'confirmed'),
              const SizedBox(width: 24),
              _buildFilterChip('Hoàn thành', 'completed'),
              const SizedBox(width: 24),
              _buildFilterChip('Đã hủy', 'cancelled'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String status) {
    final isSelected = controller.selectedStatus.value == status;

    return InkWell(
      onTap: () => controller.setStatusFilter(status),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppColors.primary : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  // ── Appointment List (vertical cards) ─────────────────────────────────
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
              Icon(Icons.calendar_today, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'Không có lịch hẹn nào',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
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
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: sortedKeys.length,
        itemBuilder: (context, index) {
          final dateKey = sortedKeys[index];
          final dateAppointments = grouped[dateKey]!;
          final date = DateTime.parse(dateKey);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _isToday(date)
                            ? AppColors.primary
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _formatDateHeader(date),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _isToday(date)
                              ? Colors.white
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${dateAppointments.length} lịch hẹn',
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              ...dateAppointments.map((apt) => _buildMobileCard(apt)),
            ],
          );
        },
      );
    });
  }

  // ── Mobile Appointment Card (vertical layout) ─────────────────────────
  Widget _buildMobileCard(AppointmentModel appointment) {
    final statusColor = controller.getStatusColor(appointment.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _showAppointmentActions(appointment),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Pet name + Status badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appointment.petName ?? 'Thú cưng',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const Text(
                            '—', // Sub-title for breed/age placeholder
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
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
                  ],
                ),
                const SizedBox(height: 12),
                
                // Info rows
                _buildCardInfoRow(
                  Icons.person,
                  '${appointment.customerName ?? "Khách hàng"}' + (appointment.customerPhone != null ? ' - ${appointment.customerPhone}' : ''),
                ),
                const SizedBox(height: 8),
                _buildCardInfoRow(
                  Icons.schedule,
                  '${appointment.time ?? "--:--"} • ${DateFormat('dd/MM/yyyy').format(appointment.appointmentDate)}',
                ),
                const SizedBox(height: 8),
                _buildCardInfoRow(
                  Icons.medical_services,
                  appointment.reason ?? 'Khám bệnh',
                ),

                // Inline buttons based on status
                if (appointment.status == 'pending' || appointment.status == 'confirmed')
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _showAppointmentForm(appointment: appointment);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF475569),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text('Đổi lịch', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (appointment.status == 'pending')
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                controller.updateStatus(appointment.id, 'confirmed');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: const Text('Xác nhận', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                          )
                        else if (appointment.status == 'confirmed')
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                controller.updateStatus(appointment.id, 'completed');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: const Text('Hoàn thành', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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

  Widget _buildCardInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ── Actions Bottom Sheet ──────────────────────────────────────────────
  void _showAppointmentActions(AppointmentModel appointment) {
    final statusColor = controller.getStatusColor(appointment.status);

    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Row(
              children: [
                Icon(
                  controller.getStatusIcon(appointment.status),
                  color: statusColor,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.customerName ?? 'Khách hàng',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${appointment.time ?? '--:--'} • ${DateFormat('dd/MM/yyyy').format(appointment.appointmentDate)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Detail info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  if (appointment.petName != null)
                    _buildDetailInfoRow(
                      Icons.pets,
                      'Thú cưng',
                      appointment.petName!,
                    ),
                  if (appointment.reason != null &&
                      appointment.reason!.isNotEmpty)
                    _buildDetailInfoRow(
                      Icons.description_outlined,
                      'Lý do',
                      appointment.reason!,
                    ),
                  if (appointment.notes != null &&
                      appointment.notes!.isNotEmpty)
                    _buildDetailInfoRow(
                      Icons.note_outlined,
                      'Ghi chú',
                      appointment.notes!,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            // Status actions
            if (appointment.status == 'pending')
              _buildActionTile(Icons.check_circle, 'Xác nhận', Colors.blue, () {
                Get.back();
                controller.updateStatus(appointment.id, 'confirmed');
              }),
            if (appointment.status == 'confirmed')
              _buildActionTile(Icons.done_all, 'Hoàn thành', Colors.green, () {
                Get.back();
                controller.updateStatus(appointment.id, 'completed');
              }),
            _buildActionTile(Icons.edit, 'Sửa lịch hẹn', Colors.blueGrey, () {
              Get.back();
              _showAppointmentForm(appointment: appointment);
            }),
            if (appointment.status != 'cancelled')
              _buildActionTile(Icons.cancel, 'Hủy lịch hẹn', Colors.orange, () {
                Get.back();
                controller.updateStatus(appointment.id, 'cancelled');
              }),
            _buildActionTile(Icons.delete, 'Xóa', Colors.red, () {
              Get.back();
              controller.deleteAppointment(appointment);
            }),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildActionTile(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildDetailInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade800),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ── Appointment Form (bottom sheet) ───────────────────────────────────
  void _showAppointmentForm({AppointmentModel? appointment}) {
    if (appointment != null) {
      controller.setupFormForEdit(appointment);
    } else {
      controller.resetForm();
    }

    Get.bottomSheet(
      Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(Get.context!).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: controller.formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      appointment != null ? Icons.edit : Icons.add,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      appointment != null ? 'Sửa Lịch Hẹn' : 'Tạo Lịch Hẹn',
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
              ),
              // Form
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Customer dropdown
                      Obx(
                        () => DropdownButtonFormField<String>(
                          value: controller.selectedCustomerId.value.isEmpty
                              ? null
                              : controller.selectedCustomerId.value,
                          decoration: InputDecoration(
                            labelText: 'Khách hàng *',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          items: controller.customers
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(
                                    '${c.name} ${c.phone ?? ''}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            controller.selectedCustomerId.value = v ?? '';
                            if (v != null) controller.loadPetsByCustomer(v);
                          },
                          isExpanded: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Pet dropdown
                      Obx(
                        () => controller.customerPets.isEmpty
                            ? const SizedBox.shrink()
                            : DropdownButtonFormField<String>(
                                value: controller.selectedPetId.value.isEmpty
                                    ? null
                                    : controller.selectedPetId.value,
                                decoration: InputDecoration(
                                  labelText: 'Thú cưng',
                                  prefixIcon: const Icon(Icons.pets),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                ),
                                items: controller.customerPets
                                    .map(
                                      (p) => DropdownMenuItem(
                                        value: p.id,
                                        child: Text(
                                          '${p.name} (${p.species ?? ''})',
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    controller.selectedPetId.value = v ?? '',
                                isExpanded: true,
                              ),
                      ),
                      if (controller.customerPets.isNotEmpty)
                        const SizedBox(height: 12),
                      // Date
                      Obx(
                        () => InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: Get.context!,
                              initialDate:
                                  controller.appointmentDate.value ??
                                  DateTime.now(),
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 30),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (date != null)
                              controller.appointmentDate.value = date;
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 18,
                                  color: Colors.grey.shade900,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  controller.appointmentDate.value != null
                                      ? DateFormat('dd/MM/yyyy').format(
                                          controller.appointmentDate.value!,
                                        )
                                      : 'Chọn ngày hẹn *',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color:
                                        controller.appointmentDate.value != null
                                        ? Colors.black87
                                        : Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Time slots
                      const Text(
                        'Chọn giờ:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Obx(
                        () => Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: controller.timeSlots.map((slot) {
                            final parts = slot.split(':');
                            final slotTime = TimeOfDay(
                              hour: int.parse(parts[0]),
                              minute: int.parse(parts[1]),
                            );
                            final isSelected =
                                controller.appointmentTime.value?.hour ==
                                    slotTime.hour &&
                                controller.appointmentTime.value?.minute ==
                                    slotTime.minute;

                            return InkWell(
                              onTap: () =>
                                  controller.appointmentTime.value = slotTime,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  slot,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Reason
                      ProTextField(
                        label: 'Lý do khám',
                        controller: controller.reasonController,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      ProTextField(
                        label: 'Ghi chú',
                        controller: controller.notesController,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              // Save button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Get.back(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Hủy'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Obx(
                        () => ElevatedButton.icon(
                          onPressed: controller.isLoading.value
                              ? null
                              : () async {
                                  final result = await controller
                                      .saveAppointment();
                                  if (result) Get.back();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
                            appointment != null ? 'Cập Nhật' : 'Tạo',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    if (_isToday(date)) return 'Hôm nay';
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day + 1)
      return 'Ngày mai';
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1)
      return 'Hôm qua';
    return DateFormat('EEEE, dd/MM', 'vi').format(date);
  }
}
