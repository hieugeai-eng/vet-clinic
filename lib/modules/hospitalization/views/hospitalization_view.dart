import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/main_layout.dart';
import '../controllers/hospitalization_controller.dart';
import 'cage_config_view.dart';
import 'desktop/hospitalization_desktop_view.dart';
import 'mobile/hospitalization_mobile_view.dart';
import 'patient_whiteboard_view.dart';
import 'regimen_list_view.dart';

class HospitalizationView extends StatelessWidget {
  const HospitalizationView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HospitalizationController());
    final isMobile = MediaQuery.of(context).size.width < 600;

    return MainLayout(
      title: '', // Bỏ title Lưu Chuồng cũ để không đè UI mới
      actions: const [], // Bỏ các nút bấm cũ không cần thiết ở Top bar
      child: Obx(() {
        if (controller.viewMode.value == 'whiteboard') {
          return const PatientWhiteboardView();
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              return const HospitalizationMobileView(
                key: ValueKey('hosp_mobile'),
              );
            } else {
              return const HospitalizationDesktopView(
                key: ValueKey('hosp_desktop'),
              );
            }
          },
        );
      }),
    );
  }
}
