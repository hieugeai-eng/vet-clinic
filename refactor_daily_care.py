import re
with open(r'd:\okada\thu y\okada_vet_clinic\lib\modules\hospitalization\views\daily_care_view.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Replace the build method's Scaffold & Tabs
pattern1_start = """      child: DefaultTabController(
        length: 4,
        child: Scaffold("""
pattern1_end = """              Expanded(
                child: TabBarView(
                  children: [
                    _buildTreatmentTab(context, controller),
                    _buildVitalsTab(context, controller),
                    _buildFeedingTab(context, controller),
                    _buildLogsTab(context, controller),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
      ),"""
replacement1 = """      child: Scaffold(
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
            )
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
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                  color: Colors.amber.shade50,
                  child: Row(
                    children: [
                      Icon(Icons.history, size: 14, color: Colors.amber.shade800),
                      const SizedBox(width: 8),
                      Text('Đang xem dữ liệu cũ (chỉ đọc)', style: TextStyle(fontSize: 12, color: Colors.amber.shade800)),
                    ],
                  ),
                ),
              Expanded(
                child: _buildUnifiedTimeline(context, controller),
              ),
            ],
          );
        }),
      )"""

content = content.replace(content[content.find(pattern1_start):content.find(pattern1_end)+len(pattern1_end)], replacement1)

# 2. Replace _buildTreatmentTab, _buildVitalsTab, _buildFeedingTab
pattern2_start = "  // --- TAB 1: Treatments ---"
pattern2_end = "  void _showAddFeedingDialog(BuildContext context, DailyCareController controller) {"
replacement2 = """  // --- UNIFIED TIMELINE ---
  Widget _buildUnifiedTimeline(BuildContext context, DailyCareController controller) {
    final List<_TimelineEvent> events = [];

    // Treatments (Medicine & Services) and Meals
    for (var t in controller.dailyTreatments) {
      IconData icon; Color color; String title; String typeTag;
      if (t.type == 'meal') {
        icon = Icons.restaurant; color = Colors.green.shade600; title = 'Cho ăn'; typeTag = 'meal';
      } else if (t.type == 'medicine') {
        icon = Icons.medication; color = Colors.blue.shade600; title = 'Thuốc'; typeTag = 'medicine';
      } else {
        icon = Icons.local_hospital; color = Colors.purple.shade600; title = 'Thủ thuật'; typeTag = 'service';
      }

      events.add(_TimelineEvent(
        id: t.id,
        status: t.status,
        time: t.timeScheduled ?? '00:00',
        type: typeTag,
        icon: icon,
        color: color,
        title: title,
        detail: '${t.name}${t.quantity > 0 ? ' - ${t.quantity} ${t.unit ?? ''}' : ''}${t.notes != null && t.notes!.isNotEmpty ? ' (${t.notes})' : ''}',
        staffName: t.performerId != null ? controller.staffNames[t.performerId] : null,
        rawData: t,
      ));
    }

    // Vitals
    for (var v in controller.vitalLogs) {
      final parts = <String>[];
      if (v.temperature != null) parts.add('Nhiệt: ${v.temperature}°C');
      if (v.heartRate != null) parts.add('Tim: ${v.heartRate?.toInt()} bpm');
      if (v.respiratoryRate != null) parts.add('Thở: ${v.respiratoryRate?.toInt()}/ph');
      
      events.add(_TimelineEvent(
        id: v.id,
        status: 'done',
        time: v.time,
        type: 'vital',
        icon: Icons.monitor_heart,
        color: Colors.amber.shade700,
        title: 'Sinh hiệu',
        detail: parts.join(' · ') + (v.notes != null && v.notes!.isNotEmpty ? ' - ${v.notes}' : ''),
        rawData: v,
      ));
    }

    events.sort((a, b) => a.time.compareTo(b.time));

    final logsDesc = List<VitalSignLogModel>.from(controller.vitalLogs)..sort((a, b) => b.time.compareTo(a.time));
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
                  onPressed: () => Get.bottomSheet(RegimenSelectorSheet(controller: controller)),
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
                          _vitalItem(Icons.thermostat, '${latestVital.temperature}°C', const Color(0xFF0891B2)),
                        if (latestVital.heartRate != null)
                          _vitalItem(Icons.favorite, '${latestVital.heartRate?.toInt()} bpm', const Color(0xFFDC2626)),
                        if (latestVital.respiratoryRate != null)
                          _vitalItem(Icons.air, '${latestVital.respiratoryRate?.toInt()}/ph', const Color(0xFF2563EB)),
                        if (latestVital.weight != null)
                          _vitalItem(Icons.scale, '${latestVital.weight} kg', const Color(0xFF7C3AED)),
                      ],
                    ),
                  ),
                  if (latestVital.temperature != null)
                    Text(
                      latestVital.temperature! >= 37.5 && latestVital.temperature! <= 39.5
                          ? '✅ Sinh hiệu bình thường'
                          : '⚠️ Sinh hiệu bất thường',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: latestVital.temperature! >= 37.5 && latestVital.temperature! <= 39.5
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
             Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('Chưa có sự kiện nào', style: TextStyle(color: Colors.grey.shade500))))
          else
            ...events.map((e) => _buildTimelineItem(e, controller)),

          const SizedBox(height: 16),
          // Daily Notes
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
               color: Colors.yellow.shade50,
               borderRadius: BorderRadius.circular(8),
               border: Border.all(color: Colors.yellow.shade200)
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit_note, size: 18, color: Colors.orange.shade700),
                    const SizedBox(width: 6),
                    const Text('Ghi chú tổng quát', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
                    final currentNote = controller.currentDaily.value?.note ?? '';
                    final tagsMatches = RegExp(r'\[(?:PHOTO|URL):.+?\]').allMatches(currentNote);
                    final tags = tagsMatches.map((m) => m.group(0)!).join('\\n');
                    final newNote = tags.isNotEmpty 
                        ? (val.trim().isNotEmpty ? '${val.trim()}\\n$tags' : tags)
                        : val.trim();
                    controller.updateDailyNote(newNote);
                  }
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
            title: const Text('Lịch sử chỉ số & Biểu đồ cân nặng', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            children: [
              FutureBuilder<List<Map<String, dynamic>>>(
                future: controller.getWeightHistory(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text('Chưa có dữ liệu theo dõi'));
                  return WeightChartWidget(weightData: snapshot.data!);
                },
              ),
            ],
          )
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
        Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
      ],
    );
  }

  void _showAddFeedingDialog(BuildContext context, DailyCareController controller) {"""

content = content.replace(content[content.find(pattern2_start):content.find(pattern2_end)+len("  void _showAddFeedingDialog(BuildContext context, DailyCareController controller) {")], replacement2)


# 3. Replace _buildLogsTab & _buildTimelineItem
pattern3_start = "  // --- TAB 4: Logs (Event Timeline) ---"
pattern3_end = "  // --- DIALOGS ---"
replacement3 = """  Widget _buildTimelineItem(_TimelineEvent event, DailyCareController controller) {
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
                   Text(event.time, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                ],
              ),
            ),
            // Line
            SizedBox(
              width: 20,
              child: Column(
                children: [
                  Container(width: 2, height: 16, color: const Color(0xFFF1F5F9)),
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: isDone ? event.color : Colors.grey.shade400,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(child: Container(width: 2, color: const Color(0xFFF1F5F9))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Action card
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDone ? Colors.white : Colors.grey.shade50,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isDone ? event.color : Colors.grey).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4)
                        ),
                        child: Text(event.title, style: TextStyle(fontSize: 10, color: isDone ? event.color : Colors.grey, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(event.detail, style: TextStyle(
                              fontSize: 13, 
                              color: isDone ? const Color(0xFF0F172A) : Colors.grey.shade700,
                              decoration: isDone && event.type != 'vital' ? TextDecoration.lineThrough : null,
                            )),
                            if (event.staffName != null)
                              Text('👤 ${event.staffName}', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                          ],
                        ),
                      ),
                      if (event.type != 'vital' && controller.isToday.value)
                        Checkbox(
                          value: isDone,
                          activeColor: Colors.green,
                          onChanged: (val) {
                            if (val != null) {
                              controller.executeTreatment(event.rawData as HospitalizationTreatmentModel, val);
                            }
                          },
                        )
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- DIALOGS ---"""

content = content.replace(content[content.find(pattern3_start):content.find(pattern3_end)+len("  // --- DIALOGS ---")], replacement3)

# 4. _TimelineEvent class update
pattern4_start = "/// Simple data class for timeline events"
replacement4 = """/// Simple data class for timeline events
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
  final Object? rawData;

  _TimelineEvent({
    required this.id,
    required this.status,
    required this.time,
    required this.type,
    required this.icon,
    required this.color,
    required this.title,
    this.detail = '',
    this.staffName,
    this.rawData,
  });
}
"""

content = content.replace(content[content.rfind(pattern4_start):], replacement4)

with open(r'd:\okada\thu y\okada_vet_clinic\lib\modules\hospitalization\views\daily_care_view.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print('Done')
