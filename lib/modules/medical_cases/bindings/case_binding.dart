import 'package:get/get.dart';

import '../controllers/case_list_controller.dart';
import '../controllers/case_form_controller.dart';

class CaseBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CaseListController>(() => CaseListController());
  }
}

/// Separate binding for just the list (used on case list page)
class CaseListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CaseListController>(() => CaseListController());
  }
}

/// Separate binding for form steps - reuses controller during multi-step flow
class CaseFormBinding extends Bindings {
  @override
  void dependencies() {
    // Reuse existing controller during step-to-step navigation
    // Only create a new one if none exists (fresh case creation)
    if (!Get.isRegistered<CaseFormController>()) {
      Get.put<CaseFormController>(CaseFormController());
    }
  }
}
