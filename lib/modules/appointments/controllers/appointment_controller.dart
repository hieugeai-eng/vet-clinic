import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../data/models/appointment_model.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/pet_model.dart';
import '../../../data/repositories/appointment_repository.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../data/repositories/pet_repository.dart';

class AppointmentController extends GetxController {
  final AppointmentRepository _appointmentRepository = AppointmentRepository();
  final CustomerRepository _customerRepository = CustomerRepository();
  final PetRepository _petRepository = PetRepository();

  final isLoading = false.obs;
  final appointments = <AppointmentModel>[].obs;
  final customers = <CustomerModel>[].obs;
  final pets = <PetModel>[].obs;
  final customerPets = <PetModel>[].obs;

  // Pagination
  final scrollController = ScrollController();
  final int _limit = 20;
  int _offset = 0;
  final hasMore = true.obs;

  // Filters
  final selectedStatus = ''.obs;
  final selectedDate = Rxn<DateTime>();
  final viewMode = 'list'.obs; // list, calendar

  // Form controllers
  final formKey = GlobalKey<FormState>();
  final selectedCustomerId = ''.obs;
  final selectedPetId = ''.obs;
  final selectedStaffId = ''.obs;
  final reasonController = TextEditingController();
  final notesController = TextEditingController();
  final appointmentDate = Rxn<DateTime>();
  
  // Quick Add Customer controllers
  final quickCustomerNameController = TextEditingController();
  final quickCustomerPhoneController = TextEditingController();
  final appointmentTime = Rxn<TimeOfDay>();
  final formStatus = 'confirmed'.obs;

  // Current editing appointment
  final editingAppointment = Rxn<AppointmentModel>();
  
    // Time slots
  final timeSlots = [
    '08:00',
    '08:30',
    '09:00',
    '09:30',
    '10:00',
    '10:30',
    '11:00',
    '11:30',
    '13:30',
    '14:00',
    '14:30',
    '15:00',
    '15:30',
    '16:00',
    '16:30',
    '17:00',
    '17:30',
    '18:00',
  ];

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
    loadAppointments();
    loadCustomers();

    // Auto-refresh when remote data changes via sync
    if (Get.isRegistered<SyncEngine>()) {
      ever(Get.find<SyncEngine>().syncVersion, (_) {
        loadAppointments(refresh: true);
      });
    }
  }

  void _onScroll() {
    if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent * 0.9 &&
        !isLoading.value &&
        hasMore.value) {
      loadAppointments();
    }
  }

  @override
  void onClose() {
    scrollController.dispose();
    reasonController.dispose();
    notesController.dispose();
    quickCustomerNameController.dispose();
    quickCustomerPhoneController.dispose();
    super.onClose();
  }

  bool _isReloading = false;

  Future<void> loadAppointments({bool refresh = false}) async {
    if (refresh) {
      if (_isReloading) return;
      _isReloading = true;
      _offset = 0;
      hasMore.value = true;
      // Do NOT appointments.clear() here to prevent UI flashing
    }

    if (!refresh && (isLoading.value || !hasMore.value)) return;

    // Only show full loading if we have no data at all
    if (appointments.isEmpty) {
      isLoading.value = true;
    }

    try {
      final newItems = await _appointmentRepository.getAll(
        limit: _limit,
        offset: _offset,
      );

      if (newItems.length < _limit) {
        hasMore.value = false;
      }

      if (refresh) {
        appointments.value = newItems;
      } else {
        final existingIds = appointments.map((e) => e.id).toSet();
        final filteredNew = newItems
            .where((e) => !existingIds.contains(e.id))
            .toList();
        appointments.addAll(filteredNew);
      }
      _offset += newItems.length;
    } catch (e) {
      Get.snackbar(
        'Loi',
        'Khong the tai danh sach lich hen: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    } finally {
      isLoading.value = false;
      if (refresh) _isReloading = false;
    }
  }

  Future<void> loadCustomers() async {
    try {
      customers.value = await _customerRepository.getAll();
    } catch (e) {
      debugPrint('Error loading customers: $e');
    }
  }

  Future<void> loadPetsByCustomer(String customerId) async {
    try {
      customerPets.value = await _petRepository.getByCustomerId(customerId);
    } catch (e) {
      debugPrint('Error loading pets: $e');
      customerPets.clear();
    }
  }

  List<AppointmentModel> get filteredAppointments {
    var result = appointments.toList();

    // Filter by status
    if (selectedStatus.value.isNotEmpty) {
      result = result.where((a) => a.status == selectedStatus.value).toList();
    }

    // Filter by date
    if (selectedDate.value != null) {
      final date = selectedDate.value!;
      result = result
          .where(
            (a) =>
                a.appointmentDate.year == date.year &&
                a.appointmentDate.month == date.month &&
                a.appointmentDate.day == date.day,
          )
          .toList();
    }

    return result;
  }

  List<AppointmentModel> get todayAppointments {
    final now = DateTime.now();
    return appointments
        .where(
          (a) =>
              a.appointmentDate.year == now.year &&
              a.appointmentDate.month == now.month &&
              a.appointmentDate.day == now.day,
        )
        .toList();
  }

  List<AppointmentModel> get upcomingAppointments {
    return appointments.where((a) => a.isUpcoming).toList();
  }

  void setStatusFilter(String status) {
    selectedStatus.value = status;
  }

  void setDateFilter(DateTime? date) {
    selectedDate.value = date;
  }

  void clearFilters() {
    selectedStatus.value = '';
    selectedDate.value = null;
  }

  void toggleViewMode() {
    viewMode.value = viewMode.value == 'list' ? 'calendar' : 'list';
  }

  // Get appointments for a specific date (for calendar)
  List<AppointmentModel> getAppointmentsForDate(DateTime date) {
    return appointments
        .where(
          (a) =>
              a.appointmentDate.year == date.year &&
              a.appointmentDate.month == date.month &&
              a.appointmentDate.day == date.day,
        )
        .toList();
  }

  // Form operations
  void resetForm() {
    editingAppointment.value = null;
    selectedCustomerId.value = '';
    selectedPetId.value = '';
    // Auto-assign current staff
    selectedStaffId.value = Get.isRegistered<PermissionService>()
        ? PermissionService.to.currentStaffId.value ?? ''
        : '';
    reasonController.clear();
    notesController.clear();
    quickCustomerNameController.clear();
    quickCustomerPhoneController.clear();
    appointmentDate.value = null;
    appointmentTime.value = null;
    formStatus.value = 'confirmed';
  }

  Future<void> quickAddCustomer(BuildContext context) async {
    if (quickCustomerNameController.text.trim().isEmpty ||
        quickCustomerPhoneController.text.trim().isEmpty) {
      Get.snackbar('Lỗi', 'Vui lòng nhập tên và SĐT khách hàng');
      return;
    }

    try {
      isLoading.value = true;
      final newCustomer = CustomerModel(
        id: const Uuid().v4(),
        name: quickCustomerNameController.text.trim(),
        phone: quickCustomerPhoneController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      final created = await _customerRepository.create(newCustomer);
      await loadCustomers();
      
      selectedCustomerId.value = created.id;
      selectedPetId.value = '';
      await loadPetsByCustomer(created.id);
      
      quickCustomerNameController.clear();
      quickCustomerPhoneController.clear();
      
      Get.back(); // close the nested dialog
      Get.snackbar('Thành công', 'Đã thêm khách hàng mới');
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể thêm khách hàng: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void setupFormForEdit(AppointmentModel appointment) {
    editingAppointment.value = appointment;
    selectedCustomerId.value = appointment.customerId;
    selectedPetId.value = appointment.petId ?? '';
    selectedStaffId.value = appointment.staffId ?? '';
    reasonController.text = appointment.reason ?? '';
    notesController.text = appointment.notes ?? '';
    appointmentDate.value = appointment.appointmentDate;
    formStatus.value = appointment.status;

    if (appointment.time != null) {
      final parts = appointment.time!.split(':');
      if (parts.length == 2) {
        appointmentTime.value = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    }

    loadPetsByCustomer(appointment.customerId);
  }

  Future<bool> saveAppointment() async {
    if (!formKey.currentState!.validate()) return false;

    if (selectedCustomerId.value.isEmpty) {
      Get.snackbar(
        'Loi',
        'Vui long chon khach hang',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade100,
      );
      return false;
    }

    if (appointmentDate.value == null) {
      Get.snackbar(
        'Loi',
        'Vui long chon ngay hen',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade100,
      );
      return false;
    }

    isLoading.value = true;
    try {
      String? timeStr;
      if (appointmentTime.value != null) {
        timeStr =
            '${appointmentTime.value!.hour.toString().padLeft(2, '0')}:${appointmentTime.value!.minute.toString().padLeft(2, '0')}';
      }

      final appointment = AppointmentModel(
        id: editingAppointment.value?.id ?? '',
        customerId: selectedCustomerId.value,
        petId: selectedPetId.value.isEmpty ? null : selectedPetId.value,
        appointmentDate: appointmentDate.value!,
        time: timeStr,
        reason: reasonController.text.trim().isEmpty
            ? null
            : reasonController.text.trim(),
        status: formStatus.value,
        notes: notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim(),
        staffId: selectedStaffId.value.isEmpty ? null : selectedStaffId.value,
      );

      if (editingAppointment.value != null) {
        await _appointmentRepository.update(appointment);
        Get.snackbar(
          'Thanh cong',
          'Da cap nhat lich hen',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
        );
      } else {
        await _appointmentRepository.create(appointment);
        Get.snackbar(
          'Thanh cong',
          'Da tao lich hen moi',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
        );
      }

      await loadAppointments(refresh: true);
      return true;
    } catch (e) {
      Get.snackbar(
        'Loi',
        'Khong the luu lich hen: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateStatus(String id, String status) async {
    try {
      await _appointmentRepository.updateStatus(id, status);
      await loadAppointments(refresh: true);
      Get.snackbar(
        'Thanh cong',
        'Da cap nhat trang thai',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
      );
    } catch (e) {
      Get.snackbar(
        'Loi',
        'Khong the cap nhat trang thai: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  Future<void> deleteAppointment(AppointmentModel appointment) async {
    if (!PermissionService.to.can(AppPermission.appointmentsDelete)) {
      Get.snackbar(
        'Không có quyền',
        'Bạn không được phép xóa lịch hẹn',
        backgroundColor: Colors.orange.shade100,
      );
      return;
    }
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Xac nhan xoa'),
        content: Text(
          'Ban co chac muon xoa lich hen voi "${appointment.customerName ?? 'khach hang'}"?',
        ),
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
        await _appointmentRepository.delete(appointment.id);
        await loadAppointments(refresh: true);
        Get.snackbar(
          'Thanh cong',
          'Da xoa lich hen',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
        );
      } catch (e) {
        Get.snackbar(
          'Loi',
          'Khong the xoa lich hen: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
        );
      }
    }
  }

  // Status helpers
  Color getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'confirmed':
        return Icons.check_circle;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  // Statistics
  int get totalAppointments => appointments.length;
  int get pendingCount =>
      appointments.where((a) => a.status == 'pending').length;
  int get confirmedCount =>
      appointments.where((a) => a.status == 'confirmed').length;
  int get todayCount => todayAppointments.length;
}
