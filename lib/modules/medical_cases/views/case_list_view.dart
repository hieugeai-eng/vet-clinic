import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/main_layout.dart';
import '../../../routes/app_routes.dart';
import '../controllers/case_list_controller.dart';
import 'desktop/case_list_desktop_view.dart';
import 'mobile/case_list_mobile_view.dart';

import '../../../data/models/medical_case_model.dart'; // Added for deep linking

class CaseListView extends StatefulWidget {
  const CaseListView({super.key});

  @override
  State<CaseListView> createState() => _CaseListViewState();
}

class _CaseListViewState extends State<CaseListView> {
  final CaseListController controller = Get.put(CaseListController());

  @override
  void initState() {
    super.initState();
    _handleDeepLink();
  }

  void _handleDeepLink() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = Get.arguments;
      if (args != null && args is Map && args['showDetail'] is MedicalCaseModel) {
        final caseModel = args['showDetail'] as MedicalCaseModel;
        Get.toNamed(Routes.caseCreate, arguments: caseModel);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Hồ Sơ Ca Bệnh',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed(Routes.caseCreate),
        icon: const Icon(Icons.add_circle),
        label: const Text('Tạo Ca Mới'),
        backgroundColor: AppColors.primary,
        elevation: 4,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 900) {
            return const CaseListMobileView(); // Use list for small screens
          } else {
            return const CaseListDesktopView(); // Use table for wide screens
          }
        },
      ),
    );
  }
}
