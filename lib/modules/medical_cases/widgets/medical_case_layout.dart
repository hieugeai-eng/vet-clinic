import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_keys.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/formatters.dart';
import '../controllers/case_form_controller.dart';
import '../../../core/widgets/step_indicator.dart';
import '../../../core/widgets/app_button.dart';
import '../../../data/models/case_log_model.dart';
import '../../../data/repositories/case_log_repository.dart';

/// Unified Layout for Medical Case Workflow (Pro Max UI)
class MedicalCaseLayout extends StatefulWidget {
  final Widget child;
  final String title;
  final int currentStep;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final VoidCallback? onCancel;
  final Widget? customBottomBar;

  const MedicalCaseLayout({
    super.key,
    required this.child,
    required this.title,
    required this.currentStep,
    this.onBack,
    this.onNext,
    this.onCancel,
    this.customBottomBar,
  });

  @override
  State<MedicalCaseLayout> createState() => _MedicalCaseLayoutState();
}

class _MedicalCaseLayoutState extends State<MedicalCaseLayout> {
  late CaseFormController controller;
  final _caseLogRepo = CaseLogRepository();
  List<CaseLogModel> _logs = [];
  bool _isLoadingLogs = true;
  Worker? _savingWorker;

  @override
  void initState() {
    super.initState();
    // Ensure controller is found
    if (!Get.isRegistered<CaseFormController>()) {
      Get.put(CaseFormController());
    }
    controller = Get.find<CaseFormController>();

    // Listen for save completion to reload timeline
    _savingWorker = ever(controller.isSaving, (bool isSaving) {
      if (!isSaving &&
          controller.isEditing.value &&
          controller.caseId != null) {
        _loadLogs();
      }
    });
  }

  @override
  void dispose() {
    _savingWorker?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    // Only load if explicitly editing a saved case
    if (controller.isEditing.value && controller.caseId != null) {
      if (mounted) setState(() => _isLoadingLogs = true);
      try {
        final results = await _caseLogRepo.getLogsForCase(controller.caseId!);

        if (mounted) {
          setState(() {
            _logs = results;
            _isLoadingLogs = false;
          });
        }
      } catch (e, stack) {
        debugPrint('Error loading case logs: $e\n$stack');
        Get.snackbar(
          'Lỗi tải Timeline',
          'Error: $e',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 10),
        );
        if (mounted) setState(() => _isLoadingLogs = false);
      }
    } else {
      if (mounted) setState(() => _isLoadingLogs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);

    return Scaffold(
      backgroundColor: Colors
          .grey
          .shade50, // Slightly darker grey to contrast with white cards
      body: isDesktop
          ? _buildDesktopLayout(context)
          : _buildMobileLayout(context),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        // Left Panel: Navigation & Summary
        Container(
          width: 280,
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSidebarHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Modern Vertical Stepper
                      _buildVerticalStepper(),
                      const SizedBox(height: 28),
                      const Divider(),
                      const SizedBox(height: 16),
                      // Patient Summary Card
                      _buildPatientSummaryCard(context),
                      if (controller.isEditing.value &&
                          controller.caseId != null) ...[
                        const SizedBox(height: 16),
                        _buildTimeline(),
                      ],
                    ],
                  ),
                ),
              ),
              _buildSidebarFooter(),
            ],
          ),
        ),

        // Right Panel: Main Content
        Expanded(
          child: Column(
            children: [
              // Header
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.border.withOpacity(0.5),
                    ),
                  ),
                ),
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: widget.child,
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: AppColors.border.withOpacity(0.5)),
                  ),
                ),
                child:
                    widget.customBottomBar ??
                    Row(
                      children: [
                        // Global Actions pinned to the left
                        _buildGlobalActions(context),
                        const Spacer(),
                        // Navigation pinned to the right
                        if (widget.onBack != null)
                          AppButton(
                            type: AppButtonType.outline,
                            label: 'Quay lại',
                            onPressed: widget.onBack!,
                          ),
                        const SizedBox(width: 16),
                        if (widget.onNext != null)
                          AppButton(
                            type: AppButtonType.primary,
                            label: 'Tiếp tục',
                            icon: Icons.arrow_forward,
                            onPressed: widget.onNext!,
                          ),
                      ],
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            AppBar(
              title: Text(widget.title, style: const TextStyle(fontSize: 18)),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onCancel ?? controller.cancelForm,
              ),
              elevation: 0,
            ),
            // Step Indicator (Fixed/Pinned - outside scroll)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: StepIndicator(
                steps: [
                  StepItem(
                    title: 'Tiếp nhận',
                    isActive: widget.currentStep == 0,
                    isDone: widget.currentStep > 0,
                  ),
                  StepItem(
                    title: 'Khám LS',
                    isActive: widget.currentStep == 1,
                    isDone: widget.currentStep > 1,
                  ),
                  StepItem(
                    title: 'Chẩn đoán',
                    isActive: widget.currentStep == 2,
                    isDone: widget.currentStep > 2,
                  ),
                  StepItem(
                    title: 'Thanh toán',
                    isActive: widget.currentStep == 3,
                    isDone: widget.currentStep > 3,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    if (widget.currentStep > 0) ...[
                      // Only show summary on subsequent steps
                      _buildPatientSummaryCardWeb(context), // Compact summary
                      if (controller.isEditing.value &&
                          controller.caseId != null) ...[
                        const SizedBox(height: 16),
                        _buildTimeline(),
                      ],
                    ],
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: widget.child,
                    ),
                    const SizedBox(height: 80), // Space for bottom bar
                  ],
                ),
              ),
            ),
          ],
        ),
        // ... (rest of stack)
        // Bottom Actions - keeping unchanged but need to be careful with replace range
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child:
                widget.customBottomBar ??
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mobile global actions
                    _buildMobileGlobalActions(context),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (widget.onBack != null)
                          Expanded(
                            child: AppButton(
                              type: AppButtonType.outline,
                              label: 'Quay lại',
                              onPressed: widget.onBack!,
                            ),
                          ),
                        if (widget.onBack != null && widget.onNext != null)
                          const SizedBox(width: 12),
                        if (widget.onNext != null)
                          Expanded(
                            child: AppButton(
                              type: AppButtonType.primary,
                              label: 'Tiếp tục',
                              icon: Icons.arrow_forward,
                              onPressed: widget.onNext!,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      color: AppColors.primary.withOpacity(0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const FaIcon(
                  FontAwesomeIcons.notesMedical,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bệnh Án Điện Tử',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.slate900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Obx(
                    () => Text(
                      '#${controller.caseCode.value}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalStepper() {
    final steps = [
      {'title': 'Tiếp nhận', 'icon': Icons.assignment_ind_outlined},
      {'title': 'Khám lâm sàng', 'icon': Icons.medical_services_outlined},
      {'title': 'Chẩn đoán & Đ.Trị', 'icon': Icons.healing_outlined},
      {'title': 'Thanh toán', 'icon': Icons.payments_outlined},
    ];

    return Column(
      children: List.generate(steps.length, (index) {
        final isActive = index == widget.currentStep;
        final isCompleted = index < widget.currentStep;

        return InkWell(
          onTap: () => controller.goToStep(index),
          borderRadius: BorderRadius.circular(8),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primary
                            : (isCompleted
                                  ? AppColors.success
                                  : Colors.grey.shade100),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isActive
                              ? AppColors.primary
                              : (isCompleted
                                    ? AppColors.success
                                    : Colors.grey.shade300),
                        ),
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              )
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: isActive
                                      ? Colors.white
                                      : Colors.grey.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    if (index < steps.length - 1)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: isCompleted
                              ? AppColors.success.withOpacity(0.5)
                              : Colors.grey.shade200,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24.0, top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[index]['title'] as String,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isActive
                                ? AppColors.textPrimary
                                : Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPatientSummaryCard(BuildContext context) {
    return Obx(() {
      // Read observables to register listener
      final customer = controller.selectedCustomer.value;
      final pet = controller.selectedPet.value;

      // Fallback to text controller content if manual entry (won't auto-rebuild on typing, but avoids crash)
      final cName = controller.customerNameController.text;
      final pName = controller.petNameController.text;
      final pSpecies = controller.petSpecies.value; // Observable
      final pGender = controller.petGender.value; // Observable
      final pAgeText = controller.petAgeController.text;
      final pAgeUnit = controller.petAgeUnit.value;

      // Only show if info exists
      if (cName.isEmpty && pName.isEmpty) {
        return _buildEmptyPatientState();
      }

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thông tin bệnh nhân',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.slate800,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: FaIcon(
                    _getSpeciesIcon(pSpecies),
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pName.isNotEmpty ? pName : 'Chưa nhập tên',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        '$pSpecies • $pGender • $pAgeText $pAgeUnit',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.slate900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 16,
                  color: AppColors.textLight,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cName.isNotEmpty ? cName : 'Chưa chọn khách',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.slate900,
                    ),
                  ),
                ),
              ],
            ),
            if (controller.phoneController.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.phone_outlined,
                    size: 16,
                    color: AppColors.textLight,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    controller.phoneController.text,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.slate900,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildEmptyPatientState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.pets, color: Colors.grey.shade300, size: 40),
            const SizedBox(height: 8),
            Text(
              'Chưa có thông tin',
              style: TextStyle(color: Colors.grey.shade900, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  // Compact version for Mobile
  Widget _buildPatientSummaryCardWeb(BuildContext context) {
    return Obx(() {
      // Fix: Always read observable first to prevent "Improper usage of GetX"
      final species = controller.petSpecies.value;

      if (controller.petNameController.text.isEmpty)
        return const SizedBox.shrink();

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: FaIcon(
                _getSpeciesIcon(species),
                color: AppColors.primary,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.petNameController.text,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Khách: ${controller.customerNameController.text}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.slate900,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildSidebarFooter() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (widget.onCancel != null)
            TextButton.icon(
              onPressed: widget.onCancel,
              icon: const Icon(Icons.close, size: 16, color: AppColors.error),
              label: const Text(
                'Hủy bỏ',
                style: TextStyle(color: AppColors.error),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getSpeciesIcon(String? species) {
    if (species?.toLowerCase() == 'meo' || species?.toLowerCase() == 'mèo')
      return FontAwesomeIcons.cat;
    return FontAwesomeIcons.dog;
  }

  Widget _buildTimeline() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 16,
          ),
          title: Row(
            children: [
              const Icon(Icons.history, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Nhật ký theo dõi',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (_logs.isNotEmpty && !_isLoadingLogs)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_logs.length}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          children: [
            if (_isLoadingLogs)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_logs.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Chưa có lịch sử cập nhật.',
                    style: TextStyle(color: AppColors.slate800, fontSize: 13),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  final isFirst = index == 0;
                  final isLast = index == _logs.length - 1;

                  return Stack(
                    children: [
                      // Timeline straight line connecting to the next item
                      if (!isLast)
                        Positioned(
                          left: 4, // Center of width 10 circle
                          top: 14, // below the top padding/circle
                          bottom: 0,
                          child: Container(width: 2, color: AppColors.border),
                        ),
                      // Row Content
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(
                              top: 4,
                            ), // align with first line of text
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: log.action == 'CREATED'
                                  ? AppColors.success
                                  : AppColors.primary,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: log.metadata != null
                                      ? () =>
                                            _showLogDetailsDialog(context, log)
                                      : null,
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                log.staffName ?? 'Hệ thống',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _formatDate(log.createdAt),
                                              style: const TextStyle(
                                                color: AppColors.slate800,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          log.notes ?? log.action,
                                          style: const TextStyle(
                                            color: AppColors.slate900,
                                            fontSize: 12,
                                          ),
                                        ),
                                        if (log.metadata != null &&
                                            log.metadata!.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6,
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.insert_chart_outlined,
                                                  size: 14,
                                                  color: AppColors.primary,
                                                ),
                                                const SizedBox(width: 4),
                                                const Text(
                                                  'Xem chi tiết',
                                                  style: TextStyle(
                                                    color: AppColors.primary,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
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
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return "${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')} ${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}";
  }

  Widget _buildGlobalActions(BuildContext context) {
    return Obx(
      () => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Print Menu Button
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'case') {
                controller.previewPdf();
              } else if (value == 'invoice') {
                controller.previewInvoice();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'case',
                child: Row(
                  children: [
                    Icon(
                      FontAwesomeIcons.fileMedical,
                      size: 18,
                      color: AppColors.slate900,
                    ),
                    SizedBox(width: 12),
                    Text('In Bệnh Án'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'invoice',
                child: Row(
                  children: [
                    Icon(
                      FontAwesomeIcons.fileInvoiceDollar,
                      size: 18,
                      color: AppColors.slate900,
                    ),
                    SizedBox(width: 12),
                    Text('In Hóa Đơn'),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.print, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'In Ấn',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: AppColors.primary),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Save Button
          AppButton(
            type: AppButtonType.outline,
            label: controller.isSaving.value ? 'Đang lưu...' : 'Lưu',
            icon: Icons.save_outlined,
            onPressed: (controller.isSaving.value || controller.isCompleted)
                ? null
                : controller.saveCase,
          ),
          const SizedBox(width: 16),
          // Discharge Button
          if (!controller.isCompleted)
            AppButton(
              type: AppButtonType.primary,
              label: 'Quyết Toán',
              icon: Icons.check_circle_outline,
              onPressed: controller.isSaving.value
                  ? null
                  : () => _showDischargeDialog(context),
            )
          else
            const AppButton(
              type: AppButtonType.primary,
              label: 'Đã hoàn thành',
              icon: Icons.done_all,
              onPressed: null,
            ),
        ],
      ),
    );
  }

  Widget _buildMobileGlobalActions(BuildContext context) {
    return Obx(
      () => Row(
        children: [
          // Print Menu
          Expanded(
            flex: 2,
            child: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'case') {
                  controller.previewPdf();
                } else if (value == 'invoice') {
                  controller.previewInvoice();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'case',
                  child: Row(
                    children: [
                      Icon(
                        FontAwesomeIcons.fileMedical,
                        size: 18,
                        color: AppColors.slate900,
                      ),
                      SizedBox(width: 12),
                      Text('In Bệnh Án'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'invoice',
                  child: Row(
                    children: [
                      Icon(
                        FontAwesomeIcons.fileInvoiceDollar,
                        size: 18,
                        color: AppColors.slate900,
                      ),
                      SizedBox(width: 12),
                      Text('In Hóa Đơn'),
                    ],
                  ),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.print, color: AppColors.primary, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'In',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: AppColors.primary,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Save
          Expanded(
            flex: 2,
            child: AppButton(
              type: AppButtonType.outline,
              label: controller.isSaving.value ? 'Đang lưu...' : 'Lưu',
              icon: Icons.save_outlined,
              onPressed: (controller.isSaving.value || controller.isCompleted)
                  ? null
                  : controller.saveCase,
            ),
          ),
          const SizedBox(width: 8),
          // Discharge
          Expanded(
            flex: 3,
            child: !controller.isCompleted
                ? AppButton(
                    type: AppButtonType.primary,
                    label: 'Quyết Toán',
                    icon: Icons.check_circle_outline,
                    onPressed: controller.isSaving.value
                        ? null
                        : () => _showDischargeDialog(context),
                  )
                : const AppButton(
                    type: AppButtonType.primary,
                    label: 'Đã KQ',
                    icon: Icons.done_all,
                    onPressed: null,
                  ),
          ),
        ],
      ),
    );
  }

  void _showDischargeDialog(BuildContext context) {
    // Basic settlement dialog logic extracted from PaymentView for global accessibility
    Get.dialog(
      AlertDialog(
        title: const Text(
          'Xác nhận Quyết toán',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogRow(
                'Tổng chi phí',
                '${Formatters.formatCurrency(controller.totalEstimate.value)}',
              ),
              Obx(
                () => _buildDialogRow(
                  'Tổng đã ứng',
                  '${Formatters.formatCurrency(controller.advancePayment.value + controller.newAdvancePaymentInput.value)}',
                ),
              ),
              const Divider(color: AppColors.border),
              Obx(() {
                final totalAdv =
                    controller.advancePayment.value +
                    controller.newAdvancePaymentInput.value;
                final remaining = controller.totalEstimate.value - totalAdv;
                return _buildDialogRow(
                  'Cần thanh toán',
                  '${Formatters.formatCurrency(remaining)}',
                  isBold: true,
                  color: remaining > 0 ? AppColors.error : AppColors.success,
                );
              }),
              const SizedBox(height: 24),
              const Text(
                'Phương thức thanh toán:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.slate900,
                ),
              ),
              const SizedBox(height: 12),
              Obx(
                () => Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => controller.remainingPaymentMethod.value =
                            AppKeys.cash,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color:
                                controller.remainingPaymentMethod.value ==
                                    AppKeys.cash
                                ? AppColors.successLight
                                : Colors.white,
                            border: Border.all(
                              color:
                                  controller.remainingPaymentMethod.value ==
                                      AppKeys.cash
                                  ? AppColors.success
                                  : AppColors.border,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Tiền mặt',
                            style: TextStyle(
                              color:
                                  controller.remainingPaymentMethod.value ==
                                      AppKeys.cash
                                  ? AppColors.success
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => controller.remainingPaymentMethod.value =
                            AppKeys.transfer,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color:
                                controller.remainingPaymentMethod.value ==
                                    AppKeys.transfer
                                ? AppColors.primaryLight
                                : Colors.white,
                            border: Border.all(
                              color:
                                  controller.remainingPaymentMethod.value ==
                                      AppKeys.transfer
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Chuyển khoản',
                            style: TextStyle(
                              color:
                                  controller.remainingPaymentMethod.value ==
                                      AppKeys.transfer
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
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text(
              'Hủy',
              style: TextStyle(color: AppColors.slate800),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.dischargeCase(
                settlementMethod: controller.remainingPaymentMethod.value,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Hoàn Tất',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.slate900)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontSize: isBold ? 16 : 14,
              color: color ?? AppColors.slate800,
            ),
          ),
        ],
      ),
    );
  }

  void _showLogDetailsDialog(BuildContext context, CaseLogModel log) {
    if (log.metadata == null) return;

    Map<String, dynamic> changes = {};
    try {
      changes = jsonDecode(log.metadata!);
    } catch (_) {
      return;
    }

    if (changes.isEmpty) return;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 550,
          constraints: BoxConstraints(maxHeight: Get.height * 0.8),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      Icons.history_edu,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Chi tiết thao tác',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Bởi ${log.staffName ?? 'Hệ thống'} lúc ${_formatDate(log.createdAt)}',
                          style: const TextStyle(
                            color: AppColors.slate800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.slate600),
                    onPressed: () => Get.back(),
                    hoverColor: Colors.grey.shade100,
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: changes.entries.map((entry) {
                      final field = entry.key;
                      final oldVal = entry.value['old']?.toString() ?? 'Trống';
                      final newVal = entry.value['new']?.toString() ?? 'Trống';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.edit_note,
                                  size: 16,
                                  color: AppColors.slate800,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  field,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: AppColors.slate800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildProfessionalDiffCard(field, oldVal, newVal),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfessionalDiffCard(
    String field,
    String oldVal,
    String newVal,
  ) {
    bool isStructural = field == 'Chi tiết Dịch vụ' || field == 'Ứng tiền';

    if (isStructural) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (oldVal.isNotEmpty &&
                oldVal != 'Không đổi' &&
                oldVal != 'Trống') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.05),
                  borderRadius:
                      newVal.isEmpty ||
                          newVal == 'Không thêm mới' ||
                          newVal == 'Trống'
                      ? BorderRadius.circular(12)
                      : const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                  border:
                      newVal.isEmpty ||
                          newVal == 'Không thêm mới' ||
                          newVal == 'Trống'
                      ? null
                      : Border(bottom: BorderSide(color: Colors.grey.shade100)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dữ liệu cũ / Đã xóa',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      oldVal,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (newVal.isNotEmpty &&
                newVal != 'Không thêm mới' &&
                newVal != 'Trống') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.05),
                  borderRadius:
                      oldVal.isEmpty ||
                          oldVal == 'Không đổi' ||
                          oldVal == 'Trống'
                      ? BorderRadius.circular(12)
                      : const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dữ liệu mới / Cập nhật',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      newVal,
                      style: const TextStyle(
                        color: AppColors.slate800,
                        fontSize: 13,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.02),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Trước đó',
                      style: TextStyle(color: AppColors.slate800, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      oldVal,
                      style: const TextStyle(
                        color: AppColors.error,
                        decoration: TextDecoration.lineThrough,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(width: 1, color: Colors.grey.shade200),
            Container(
              width: 32,
              alignment: Alignment.center,
              color: Colors.grey.shade50,
              child: const Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: AppColors.slate600,
              ),
            ),
            Container(width: 1, color: Colors.grey.shade200),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.03),
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Cập nhật thành',
                      style: TextStyle(color: AppColors.slate800, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      newVal,
                      style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
