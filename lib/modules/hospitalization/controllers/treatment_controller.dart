import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../../core/services/permission_service.dart';
import '../../../data/models/treatment_model.dart';
import '../../../data/providers/local/database_provider.dart';
import '../../../core/services/staff_sync_helper.dart';

class TreatmentController extends GetxController {
  final uuid = const Uuid();
  final String hospitalizationId;
  final String petName;

  TreatmentController({required this.hospitalizationId, required this.petName});

  final days = <TreatmentDayModel>[].obs;
  final currentDayId = ''.obs;
  final activities = <TreatmentActivityModel>[].obs;
  final isLoading = false.obs;

  // Staff
  final staffList = <Map<String, dynamic>>[].obs;
  final selectedStaffId = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadDays();
    loadStaff();
  }

  Future<void> loadStaff() async {
    try {
      final result = await StaffSyncHelper.loadStaffWithSync();
      staffList.value = result;
      // Auto-assign current staff AFTER list is loaded
      if (selectedStaffId.value.isEmpty &&
          Get.isRegistered<PermissionService>()) {
        final currentId = PermissionService.to.currentStaffId.value ?? '';
        if (currentId.isNotEmpty &&
            staffList.any((s) => s['id'] == currentId)) {
          selectedStaffId.value = currentId;
        }
      }
    } catch (e) {
      print('Error loading staff: $e');
    }
  }

  /// Load treatment days
  Future<void> loadDays() async {
    isLoading.value = true;
    try {
      final db = await DatabaseProvider.instance.database;
      final result = await db.query(
        'treatment_days',
        where: 'hospitalization_id = ?',
        whereArgs: [hospitalizationId],
        orderBy: 'date DESC',
      );

      days.value = result.map((j) => TreatmentDayModel.fromJson(j)).toList();

      // If no days, create today
      if (days.isEmpty) {
        await _createToday();
      } else {
        // Check if today exists
        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final todayExists = days.any(
          (d) => DateFormat('yyyy-MM-dd').format(d.date) == todayStr,
        );

        if (!todayExists) {
          // Ideally confirm with user, but for now auto-create or let user add?
          // Let's select the latest day by default
        }

        // Select first day (latest)
        selectDay(days.first.id);
      }
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể tải nhật ký: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _createToday() async {
    final db = await DatabaseProvider.instance.database;
    final dayId = uuid.v4();
    final today = DateTime.now();

    await db.insert('treatment_days', {
      'id': dayId,
      'hospitalization_id': hospitalizationId,
      'date': today.toUtc().toIso8601String(),
      'notes': '',
    });

    await loadDays();
    selectDay(dayId);
  }

  /// Add new day (Manually)
  Future<void> addNewDay() async {
    await _createToday();
  }

  /// Select a day to view activities
  Future<void> selectDay(String dayId) async {
    currentDayId.value = dayId;
    await _loadActivities(dayId);
  }

  Future<void> _loadActivities(String dayId) async {
    final db = await DatabaseProvider.instance.database;
    final result = await db.query(
      'treatment_activities',
      where: 'day_id = ?',
      whereArgs: [dayId],
      orderBy: 'time ASC',
    );
    activities.value = result
        .map((j) => TreatmentActivityModel.fromJson(j))
        .toList();
  }

  /// Add activity
  Future<void> addActivity({
    required String type,
    required String name,
    required String value,
    String? performerId,
  }) async {
    if (currentDayId.value.isEmpty) return;

    try {
      final db = await DatabaseProvider.instance.database;
      final time = DateFormat('HH:mm').format(DateTime.now());

      await db.insert('treatment_activities', {
        'id': uuid.v4(),
        'day_id': currentDayId.value,
        'type': type,
        'name': name,
        'value': value,
        'time': time,
        'performer_id': performerId,
      });

      await _loadActivities(currentDayId.value);
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể thêm hoạt động: $e');
    }
  }

  /// Delete activity
  Future<void> deleteActivity(String id) async {
    try {
      final db = await DatabaseProvider.instance.database;
      await db.delete('treatment_activities', where: 'id = ?', whereArgs: [id]);
      await _loadActivities(currentDayId.value);
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể xóa: $e');
    }
  }
}
