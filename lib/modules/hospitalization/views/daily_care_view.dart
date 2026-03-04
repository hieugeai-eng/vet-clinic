import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/widgets/main_layout.dart';
import '../../../data/models/hospitalization_models.dart';
import '../../../data/models/medicine_model.dart';
import '../controllers/daily_care_controller.dart';
import 'regimen_selector_sheet.dart';
import '../widgets/vital_sign_chart.dart'; // Ensure log_vital_dialog.dart exists or inline it
import '../widgets/weight_chart_widget.dart';
import '../widgets/photo_log_section.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/models/product_model.dart';

class DailyCareView extends StatelessWidget {
  final String hospitalizationId;
  final String petName;

  const DailyCareView({
    super.key,
    required this.hospitalizationId,
    required this.petName,
  });

  @override
  Widget build(BuildContext context) {
    // Unique tag for controller to support multiple pets logs if needed,
    // but usually user views one at a time.
    final controller = Get.put(DailyCareController(), tag: hospitalizationId);

    // Trigger load
    if (controller.currentHospitalizationId.value != hospitalizationId) {
      controller.loadDaily(hospitalizationId);
    }

    return MainLayout(
      title: 'Điều Trị: $petName',
      hideAppBar: true,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Điều Trị: $petName'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Get.back(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _showUpdateDialog(context, controller, petName),
              tooltip: 'Gửi cập nhật cho khách',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => controller.loadDaily(hospitalizationId),
            ),
          ],
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              // Date Navigation Bar
              _buildDateNavBar(context, controller),
              // Past-day read-only banner
              if (!controller.isToday.value)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 16,
                  ),
                  color: Colors.amber.shade50,
                  child: Row(
                    children: [
                      Icon(
                        Icons.history,
                        size: 14,
                        color: Colors.amber.shade800,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Đang xem dữ liệu cũ (chỉ đọc)',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(child: _buildUnifiedTimeline(context, controller)),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildDateNavBar(
    BuildContext context,
    DailyCareController controller,
  ) {
    return Obx(() {
      final today = DateTime.now();
      final admission = controller.admissionDate.value ?? today;
      final startDay = DateTime(admission.year, admission.month, admission.day);
      final endDay = DateTime(today.year, today.month, today.day);

      final days = <DateTime>[];
      var d = startDay;
      while (!d.isAfter(endDay)) {
        days.add(d);
        d = d.add(const Duration(days: 1));
      }
      if (days.isEmpty) days.add(endDay); // Fallback

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Chăm sóc:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  controller.currentDaily.value != null
                      ? (controller.isToday.value ? 'Ổn định' : 'Lịch sử')
                      : '',
                  style: TextStyle(
                    color: Colors.green.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            // Divider
            Container(width: 1, height: 24, color: Colors.grey.shade300),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                    },
                  ),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        bottom: 10.0,
                      ), // make room for scrollbar
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        reverse:
                            true, // Show newest on the right, or we can just scroll to end
                        itemCount: days.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          // We reverse the list visually if we don't use reverse: true. Let's just build normally but align end.
                          final date = days[index];
                          final isSelected = controller.isSameDay(
                            date,
                            controller.selectedDate.value,
                          );
                          final isCurrentToday = controller.isSameDay(
                            date,
                            today,
                          );

                          final formatStr =
                              '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
                          final label = isCurrentToday
                              ? '$formatStr (Hôm nay)'
                              : formatStr;

                          return InkWell(
                            onTap: () => controller.goToDate(date),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF0891B2)
                                      : Colors.grey.shade300,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFF0891B2)
                                      : Colors.grey.shade700,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // --- UNIFIED TIMELINE ---
  Widget _buildUnifiedTimeline(
    BuildContext context,
    DailyCareController controller,
  ) {
    final List<_TimelineEvent> events = [];

    // Treatments (Medicine & Services) and Meals
    for (var t in controller.dailyTreatments) {
      IconData icon;
      Color color;
      String title;
      String typeTag;
      if (t.type == 'meal') {
        icon = Icons.restaurant;
        color = Colors.green.shade600;
        title = 'Cho ăn';
        typeTag = 'meal';
      } else if (t.type == 'medicine') {
        icon = Icons.medication;
        color = Colors.blue.shade600;
        title = 'Thuốc';
        typeTag = 'medicine';
      } else {
        icon = Icons.local_hospital;
        color = Colors.purple.shade600;
        title = 'Thủ thuật';
        typeTag = 'service';
      }

      bool isManual = t.notes != null && t.notes!.startsWith('[M]');
      String cleanNote = isManual ? t.notes!.substring(3) : (t.notes ?? '');

      events.add(
        _TimelineEvent(
          id: t.id,
          status: t.status,
          time: t.timeScheduled ?? '00:00',
          type: typeTag,
          icon: icon,
          color: color,
          title: title,
          detail:
              '${t.name}${t.quantity > 0 ? ' - ${t.quantity} ${t.unit ?? ''}' : ''}${cleanNote.isNotEmpty ? ' ($cleanNote)' : ''}',
          staffName: t.performerId != null
              ? controller.staffNames[t.performerId]
              : (t.status == 'done' ? '---' : null),
          rawData: t,
          isManual: isManual,
        ),
      );
    }

    // Vitals
    for (var v in controller.vitalLogs) {
      final parts = <String>[];
      if (v.temperature != null) parts.add('Nhiệt: ${v.temperature}°C');
      if (v.heartRate != null) parts.add('Tim: ${v.heartRate?.toInt()} bpm');
      if (v.respiratoryRate != null)
        parts.add('Thở: ${v.respiratoryRate?.toInt()}/ph');

      events.add(
        _TimelineEvent(
          id: v.id,
          status: 'done',
          time: v.time,
          type: 'vital',
          icon: Icons.monitor_heart,
          color: Colors.amber.shade700,
          title: 'Sinh hiệu',
          detail:
              parts.join(' · ') +
              (v.notes != null && v.notes!.isNotEmpty ? ' - ${v.notes}' : ''),
          rawData: v,
        ),
      );
    }

    events.sort((a, b) => a.time.compareTo(b.time));

    final logsDesc = List<VitalSignLogModel>.from(controller.vitalLogs)
      ..sort((a, b) => b.time.compareTo(a.time));
    final latestVital = logsDesc.isNotEmpty ? logsDesc.first : null;

    final String dailyNoteStr = (controller.currentDaily.value?.note ?? '')
        .replaceAll(RegExp(r'\[(?:PHOTO|URL):.+?\]\n?'), '')
        .trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Action Buttons
          if (controller.isToday.value) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: const Text('Thêm thuốc/DV'),
                  padding: const EdgeInsets.all(4),
                  onPressed: () => _showAddMedicineDialog(context, controller),
                ),
                ActionChip(
                  avatar: const Icon(Icons.playlist_add, size: 16),
                  label: const Text('Thêm phác đồ'),
                  padding: const EdgeInsets.all(4),
                  onPressed: () => Get.bottomSheet(
                    RegimenSelectorSheet(controller: controller),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.restaurant, size: 16),
                  label: const Text('Cho ăn'),
                  padding: const EdgeInsets.all(4),
                  onPressed: () => _showAddFeedingDialog(context, controller),
                ),
                ActionChip(
                  avatar: const Icon(Icons.monitor_heart, size: 16),
                  label: const Text('Ghi sinh hiệu'),
                  padding: const EdgeInsets.all(4),
                  onPressed: () => _showLogVitalDialog(context, controller),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Vital Summary Card
          if (latestVital != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        if (latestVital.temperature != null)
                          _vitalItem(
                            Icons.thermostat,
                            '${latestVital.temperature}°C',
                            const Color(0xFF0891B2),
                          ),
                        if (latestVital.heartRate != null)
                          _vitalItem(
                            Icons.favorite,
                            '${latestVital.heartRate?.toInt()} bpm',
                            const Color(0xFFDC2626),
                          ),
                        if (latestVital.respiratoryRate != null)
                          _vitalItem(
                            Icons.air,
                            '${latestVital.respiratoryRate?.toInt()}/ph',
                            const Color(0xFF2563EB),
                          ),
                        if (latestVital.weight != null)
                          _vitalItem(
                            Icons.scale,
                            '${latestVital.weight} kg',
                            const Color(0xFF7C3AED),
                          ),
                      ],
                    ),
                  ),
                  if (latestVital.temperature != null)
                    Text(
                      latestVital.temperature! >= 37.5 &&
                              latestVital.temperature! <= 39.5
                          ? '✅ Sinh hiệu bình thường'
                          : '⚠️ Sinh hiệu bất thường',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color:
                            latestVital.temperature! >= 37.5 &&
                                latestVital.temperature! <= 39.5
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Timeline Events
          if (events.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Chưa có sự kiện nào',
                  style: TextStyle(color: Colors.grey.shade800),
                ),
              ),
            )
          else
            ...events.map((e) => _buildTimelineItem(e, controller)),

          const SizedBox(height: 16),
          // Daily Notes
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.yellow.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.yellow.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.edit_note,
                      size: 18,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Ghi chú tổng quát',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: TextEditingController(text: dailyNoteStr),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Nhập ghi chú chung trong ngày...',
                    border: OutlineInputBorder(),
                    fillColor: Colors.white,
                    filled: true,
                    isDense: true,
                  ),
                  enabled: controller.isToday.value,
                  onChanged: (val) {
                    final currentNote =
                        controller.currentDaily.value?.note ?? '';
                    final tagsMatches = RegExp(
                      r'\[(?:PHOTO|URL):.+?\]',
                    ).allMatches(currentNote);
                    final tags = tagsMatches.map((m) => m.group(0)!).join('\n');
                    final newNote = tags.isNotEmpty
                        ? (val.trim().isNotEmpty
                              ? '${val.trim()}\n$tags'
                              : tags)
                        : val.trim();
                    controller.updateDailyNote(newNote);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          PhotoLogSection(
            dailyId: controller.currentDaily.value?.id ?? '',
            currentNotes: controller.currentDaily.value?.note,
            onNotesUpdated: (updatedNotes) {
              controller.updateDailyNote(updatedNotes);
            },
          ),

          const SizedBox(height: 24),
          ExpansionTile(
            title: const Text(
              'Lịch sử chỉ số & Biểu đồ cân nặng',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            children: [
              FutureBuilder<List<Map<String, dynamic>>>(
                future: controller.getWeightHistory(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty)
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Chưa có dữ liệu theo dõi'),
                    );
                  return WeightChartWidget(weightData: snapshot.data!);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vitalItem(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem(
    _TimelineEvent event,
    DailyCareController controller,
  ) {
    bool isDone = event.status == 'done';
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Time
            SizedBox(
              width: 45,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    event.time,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
            // Line
            SizedBox(
              width: 20,
              child: Column(
                children: [
                  Container(
                    width: 2,
                    height: 16,
                    color: const Color(0xFFF1F5F9),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isDone ? event.color : Colors.grey.shade900,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Container(width: 2, color: const Color(0xFFF1F5F9)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Action card
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDone ? Colors.white : Colors.grey.shade50,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade100),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (isDone ? event.color : Colors.grey)
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          event.title,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDone ? event.color : Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.detail,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDone
                                    ? const Color(0xFF0F172A)
                                    : Colors.grey.shade700,
                              ),
                            ),
                            if (event.staffName != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '👤 ${event.staffName}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (controller.isToday.value) ...[
                        if (event.type != 'vital' && !event.isManual)
                          Checkbox(
                            value: isDone,
                            activeColor: Colors.green,
                            visualDensity: VisualDensity.compact,
                            onChanged: (val) {
                              if (val != null) {
                                controller.executeTreatment(
                                  event.rawData
                                      as HospitalizationTreatmentModel,
                                  val,
                                );
                              }
                            },
                          ),
                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert,
                            size: 18,
                            color: Colors.grey,
                          ),
                          padding: EdgeInsets.zero,
                          tooltip: 'Hành động',
                          onSelected: (val) {
                            if (val == 'edit') {
                              Get.defaultDialog(
                                title: 'Tính năng Sửa',
                                middleText:
                                    'Tính năng sửa dữ liệu đang được hoàn thiện. Vui lòng xóa và thêm lại nhé.',
                                textConfirm: 'OK',
                                confirmTextColor: Colors.white,
                                buttonColor: Colors.blue,
                                onConfirm: () => Get.back(),
                              );
                            } else if (val == 'delete') {
                              Get.defaultDialog(
                                title: 'Xác nhận xóa',
                                middleText:
                                    'Bạn có chắc chắn muốn xóa mục này?',
                                textConfirm: 'Xóa',
                                textCancel: 'Hủy',
                                confirmTextColor: Colors.white,
                                buttonColor: Colors.red,
                                cancelTextColor: Colors.grey.shade700,
                                onConfirm: () {
                                  Get.back();
                                  controller.deleteTimelineEvent(event.rawData);
                                },
                              );
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              height: 40,
                              child: Text(
                                'Sửa',
                                style: TextStyle(fontSize: 15),
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              height: 40,
                              child: Text(
                                'Xóa',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddFeedingDialog(
    BuildContext context,
    DailyCareController controller,
  ) {
    final nameController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final unitController = TextEditingController(text: 'phần');
    final notesController = TextEditingController();
    final timeController = TextEditingController(
      text:
          '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
    );

    // Petshop state
    final selectedProduct = Rxn<ProductModel>();
    final petshopQty = 1.obs;
    final petshopProducts = <ProductModel>[].obs;
    final isSearching = false.obs;

    // Load petshop food products initially
    Future<void> searchProducts(String query) async {
      isSearching.value = true;
      try {
        final repo = ProductRepository();
        if (query.isEmpty) {
          petshopProducts.value = await repo.getAll(limit: 30);
        } else {
          petshopProducts.value = await repo.search(query);
        }
      } catch (_) {}
      isSearching.value = false;
    }

    searchProducts('');

    // Common presets
    final presets = [
      'Hạt khô',
      'Pate',
      'Cơm + Thịt',
      'Sữa',
      'Nước canh',
      'Thức ăn lỏng',
      'Royal Canin Recovery',
    ];

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: DefaultTabController(
          length: 2,
          child: Container(
            width: ResponsiveHelper.dialogWidth(context, 500),
            constraints: const BoxConstraints(maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.restaurant_menu,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Thêm Bữa Ăn',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Get.back(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),

                // Tabs
                const TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: AppColors.primary,
                  tabs: [
                    Tab(
                      icon: Icon(Icons.fastfood, size: 18),
                      text: 'Ghi nhanh',
                    ),
                    Tab(
                      icon: Icon(Icons.storefront, size: 18),
                      text: 'Từ Petshop',
                    ),
                  ],
                ),

                // Tab content
                Flexible(
                  child: TabBarView(
                    children: [
                      // --- TAB 1: Manual entry ---
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Chọn nhanh:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: presets.map((preset) {
                                return ActionChip(
                                  label: Text(
                                    preset,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  onPressed: () => nameController.text = preset,
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                labelText: 'Loại thức ăn *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.fastfood),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: quantityController,
                                    decoration: const InputDecoration(
                                      labelText: 'Số lượng',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: unitController,
                                    decoration: const InputDecoration(
                                      labelText: 'Đơn vị',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: timeController,
                              decoration: const InputDecoration(
                                labelText: 'Giờ cho ăn',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.access_time),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: notesController,
                              decoration: const InputDecoration(
                                labelText: 'Ghi chú',
                                border: OutlineInputBorder(),
                                hintText: 'VD: ăn hết, bỏ ăn...',
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  if (nameController.text.trim().isEmpty) {
                                    Get.snackbar(
                                      'Lỗi',
                                      'Vui lòng nhập loại thức ăn',
                                    );
                                    return;
                                  }
                                  controller.addFeedingEntry(
                                    name: nameController.text.trim(),
                                    quantity:
                                        double.tryParse(
                                          quantityController.text,
                                        ) ??
                                        1.0,
                                    unit: unitController.text.trim().isNotEmpty
                                        ? unitController.text.trim()
                                        : null,
                                    timeScheduled:
                                        timeController.text.trim().isNotEmpty
                                        ? timeController.text.trim()
                                        : null,
                                    notes:
                                        notesController.text.trim().isNotEmpty
                                        ? notesController.text.trim()
                                        : null,
                                  );
                                  Get.back();
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Thêm'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // --- TAB 2: Petshop products ---
                      Column(
                        children: [
                          // Search bar
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Tìm sản phẩm petshop...',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                              onChanged: (q) => searchProducts(q),
                            ),
                          ),

                          // Product list
                          Expanded(
                            child: Obx(() {
                              if (isSearching.value)
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              if (petshopProducts.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.inventory_2_outlined,
                                        size: 40,
                                        color: Colors.grey.shade900,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Không tìm thấy sản phẩm',
                                        style: TextStyle(
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                itemCount: petshopProducts.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, index) {
                                  final product = petshopProducts[index];
                                  return Obx(() {
                                    final isSelected =
                                        selectedProduct.value?.id == product.id;
                                    return ListTile(
                                      dense: true,
                                      selected: isSelected,
                                      selectedTileColor: AppColors.primary
                                          .withOpacity(0.05),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      leading: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: product.stock > 0
                                              ? Colors.green.shade50
                                              : Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.inventory_2,
                                          color: product.stock > 0
                                              ? Colors.green.shade700
                                              : Colors.red.shade700,
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(
                                        product.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${product.salePrice.toStringAsFixed(0)}đ • Tồn: ${product.stock}${product.brand != null ? ' • ${product.brand}' : ''}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade900,
                                        ),
                                      ),
                                      trailing: isSelected
                                          ? Icon(
                                              Icons.check_circle,
                                              color: AppColors.primary,
                                            )
                                          : Icon(
                                              Icons.add_circle_outline,
                                              color: Colors.grey.shade900,
                                            ),
                                      onTap: () {
                                        if (product.stock <= 0) {
                                          Get.snackbar(
                                            'Hết hàng',
                                            '${product.name} đã hết hàng trong kho',
                                          );
                                          return;
                                        }
                                        selectedProduct.value = isSelected
                                            ? null
                                            : product;
                                      },
                                    );
                                  });
                                },
                              );
                            }),
                          ),

                          // Bottom: qty + confirm
                          Obx(() {
                            if (selectedProduct.value == null)
                              return const SizedBox(height: 8);
                            final p = selectedProduct.value!;
                            return Container(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.05),
                                border: Border(
                                  top: BorderSide(color: Colors.grey.shade200),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${p.name}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${p.salePrice.toStringAsFixed(0)}đ/sp',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Text(
                                        'Số lượng: ',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                          size: 22,
                                        ),
                                        onPressed: () => petshopQty.value =
                                            (petshopQty.value - 1).clamp(
                                              1,
                                              p.stock,
                                            ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                        ),
                                      ),
                                      Obx(
                                        () => Text(
                                          '${petshopQty.value}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 17,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                          size: 22,
                                        ),
                                        onPressed: () => petshopQty.value =
                                            (petshopQty.value + 1).clamp(
                                              1,
                                              p.stock,
                                            ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                        ),
                                      ),
                                      Text(
                                        '(tồn: ${p.stock})',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'Tổng: ${(p.salePrice * petshopQty.value).toStringAsFixed(0)}đ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        controller.addFeedingFromPetshop(
                                          product: p,
                                          quantity: petshopQty.value,
                                          timeScheduled:
                                              '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                                        );
                                        Get.back();
                                      },
                                      icon: const Icon(
                                        Icons.shopping_cart_checkout,
                                        size: 18,
                                      ),
                                      label: Text(
                                        'Thêm & Trừ kho (${petshopQty.value} sp)',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
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

  // --- DIALOGS ---
  void _showLogVitalDialog(
    BuildContext context,
    DailyCareController controller,
  ) {
    final timeCtl = TextEditingController(
      text:
          '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
    );
    final tempCtl = TextEditingController();
    final weightCtl = TextEditingController();
    final hrCtl = TextEditingController();
    final rrCtl = TextEditingController();
    final notesCtl = TextEditingController();
    final crtValue = RxnString();
    final mmValue = RxnString();
    final faecesValue = RxnString();
    final urineValue = RxnString();

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: ResponsiveHelper.dialogWidth(context, 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.monitor_heart,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Ghi Sinh Hiệu',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Row 1: Time
                      TextField(
                        controller: timeCtl,
                        decoration: const InputDecoration(
                          labelText: 'Giờ đo (HH:mm)',
                          prefixIcon: Icon(Icons.access_time),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Row 2: Temp + Weight
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: tempCtl,
                              decoration: const InputDecoration(
                                labelText: 'Nhiệt độ (°C)',
                                prefixIcon: Icon(Icons.thermostat),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: weightCtl,
                              decoration: const InputDecoration(
                                labelText: 'Cân nặng (kg)',
                                prefixIcon: Icon(Icons.monitor_weight),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Row 3: HR + RR
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: hrCtl,
                              decoration: const InputDecoration(
                                labelText: 'Nhịp tim (bpm)',
                                prefixIcon: Icon(Icons.favorite),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: rrCtl,
                              decoration: const InputDecoration(
                                labelText: 'Nhịp thở (bpm)',
                                prefixIcon: Icon(Icons.air),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Row 4: CRT + Mucous Membrane (dropdowns)
                      Row(
                        children: [
                          Expanded(
                            child: Obx(
                              () => DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'CRT',
                                  prefixIcon: Icon(Icons.timer),
                                ),
                                value: crtValue.value,
                                items: ['< 1s', '1-2s', '2-3s', '> 3s']
                                    .map(
                                      (v) => DropdownMenuItem(
                                        value: v,
                                        child: Text(v),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) => crtValue.value = v,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Obx(
                              () => DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'Niêm mạc',
                                  prefixIcon: Icon(Icons.color_lens),
                                ),
                                value: mmValue.value,
                                items:
                                    [
                                          'Hồng',
                                          'Nhạt',
                                          'Trắng',
                                          'Vàng',
                                          'Tím',
                                          'Đỏ sẫm',
                                        ]
                                        .map(
                                          (v) => DropdownMenuItem(
                                            value: v,
                                            child: Text(v),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (v) => mmValue.value = v,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Row 5: Faeces + Urine (dropdowns)
                      Row(
                        children: [
                          Expanded(
                            child: Obx(
                              () => DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'Phân',
                                  prefixIcon: Icon(Icons.circle),
                                ),
                                value: faecesValue.value,
                                items:
                                    [
                                          'Bình thường',
                                          'Lỏng',
                                          'Có máu',
                                          'Không đi',
                                          'Táo bón',
                                        ]
                                        .map(
                                          (v) => DropdownMenuItem(
                                            value: v,
                                            child: Text(v),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (v) => faecesValue.value = v,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Obx(
                              () => DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'Nước tiểu',
                                  prefixIcon: Icon(Icons.water_drop),
                                ),
                                value: urineValue.value,
                                items:
                                    [
                                          'Bình thường',
                                          'Ít',
                                          'Nhiều',
                                          'Có máu',
                                          'Không đi',
                                        ]
                                        .map(
                                          (v) => DropdownMenuItem(
                                            value: v,
                                            child: Text(v),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (v) => urineValue.value = v,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Row 6: Notes
                      TextField(
                        controller: notesCtl,
                        decoration: const InputDecoration(
                          labelText: 'Ghi chú',
                          prefixIcon: Icon(Icons.notes),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      controller.logVitalSign(
                        VitalSignLogModel(
                          id: Uuid().v4(),
                          dailyId: controller.currentDaily.value!.id,
                          time: timeCtl.text,
                          temperature: double.tryParse(tempCtl.text),
                          weight: double.tryParse(weightCtl.text),
                          heartRate: double.tryParse(hrCtl.text),
                          respiratoryRate: double.tryParse(rrCtl.text),
                          crt: crtValue.value,
                          mucousMembrane: mmValue.value,
                          faeces: faecesValue.value,
                          urine: urineValue.value,
                          notes: notesCtl.text.isNotEmpty
                              ? notesCtl.text
                              : null,
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Lưu'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddMedicineDialog(
    BuildContext context,
    DailyCareController controller,
  ) {
    final selectedMedicine = Rxn<MedicineModel>();
    final quantity = 1.0.obs;
    final dosage = ''.obs;
    final note = ''.obs;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: ResponsiveHelper.dialogWidth(context, 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Thêm thuốc lẻ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Searchable medicine picker
              Autocomplete<MedicineModel>(
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return controller.availableMedicines.take(20);
                  }
                  final query = textEditingValue.text.toLowerCase();
                  return controller.availableMedicines.where(
                    (m) => m.name.toLowerCase().contains(query),
                  );
                },
                displayStringForOption: (m) => m.name,
                onSelected: (m) {
                  selectedMedicine.value = m;
                  dosage.value = m.unit ?? '';
                },
                fieldViewBuilder: (ctx, textCtl, focusNode, onSubmitted) {
                  return TextField(
                    controller: textCtl,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'Gõ tên thuốc để tìm...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.search),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                    ),
                    onChanged: (_) => selectedMedicine.value = null,
                  );
                },
                optionsViewBuilder: (ctx, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 250,
                          maxWidth: 480,
                        ),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (_, index) {
                            final med = options.elementAt(index);
                            return ListTile(
                              dense: true,
                              title: Text(
                                med.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${med.unit ?? ""} • Tồn: ${med.stock ?? "?"}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.medication,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                              ),
                              onTap: () => onSelected(med),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Liều lượng',
                      ),
                      onChanged: (v) => dosage.value = v,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 100,
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'SL'),
                      keyboardType: TextInputType.number,
                      initialValue: '1',
                      onChanged: (v) =>
                          quantity.value = double.tryParse(v) ?? 1.0,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Ghi chú'),
                onChanged: (v) => note.value = v,
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('Hủy'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (selectedMedicine.value != null &&
                          controller.currentDaily.value != null) {
                        final now = DateTime.now();
                        final timeScheduledStr =
                            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
                        final treatment = HospitalizationTreatmentModel(
                          id: Uuid().v4(),
                          dailyId: controller.currentDaily.value!.id,
                          type: 'medicine',
                          name: selectedMedicine.value!.name,
                          refId: selectedMedicine.value!.id,
                          quantity: quantity.value,
                          unit: selectedMedicine.value!.unit,
                          dosage: dosage.value,
                          notes: note.value.isNotEmpty
                              ? '[M]${note.value}'
                              : '[M]',
                          timeScheduled: timeScheduledStr,
                          timePerformed: timeScheduledStr,
                          status: 'done',
                          performerId: controller.getCurrentStaffId(),
                          createdAt: now,
                          updatedAt: now,
                        );
                        await controller.addSingleTreatment(treatment);
                        await controller.executeTreatment(
                          treatment,
                          true,
                        ); // this handles stock deduction & billing
                        Get.back();
                      }
                    },
                    child: const Text('Thêm'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUpdateDialog(
    BuildContext context,
    DailyCareController controller,
    String petName,
  ) {
    final text = controller.generateDailyUpdateText(petName);
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Nội dung cập nhật (Zalo/SMS)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: SelectableText(
                    text,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  Get.back();
                  Get.snackbar(
                    'Đã sao chép',
                    'Nội dung đã được lưu vào clipboard',
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Sao chép nội dung'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('Đóng'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple data class for timeline events
class _TimelineEvent {
  final String id;
  final String status;
  final String time;
  final String type;
  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  final String? staffName;
  final dynamic rawData;

  final bool isManual;

  _TimelineEvent({
    required this.id,
    required this.status,
    required this.time,
    required this.type,
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    this.staffName,
    required this.rawData,
    this.isManual = false,
  });
}
