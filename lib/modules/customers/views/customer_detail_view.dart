import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/widgets/main_layout.dart';
import '../../../data/models/customer_model.dart';
import '../controllers/customer_controller.dart';
import 'desktop/customer_desktop_detail_view.dart';
import 'mobile/customer_mobile_detail_view.dart';
import '../widgets/customer_form_dialog.dart';

class CustomerDetailView extends StatefulWidget {
  const CustomerDetailView({super.key});

  @override
  State<CustomerDetailView> createState() => _CustomerDetailViewState();
}

class _CustomerDetailViewState extends State<CustomerDetailView> {
  final controller = Get.find<CustomerController>();

  @override
  void initState() {
    super.initState();
    final customer = Get.arguments as CustomerModel;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.currentCustomer.value = null;
      controller.customerPets.clear();
      controller.loadCustomerDetails(customer.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final argCustomer = Get.arguments as CustomerModel;

    return Scaffold(
      backgroundColor: ResponsiveHelper.isMobile(context) ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value && controller.currentCustomer.value == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final loaded = controller.currentCustomer.value;
          final currentCust = (loaded != null && loaded.id == argCustomer.id) ? loaded : argCustomer;

          if (ResponsiveHelper.isMobile(context)) {
            return MainLayout(
              title: currentCust.name,
              showBackButton: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20, color: Color(0xFF2563EB)),
                  onPressed: () => showCustomerFormDialog(context, customer: currentCust),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
                const SizedBox(width: 8),
              ],
              child: CustomerMobileDetailView(customer: currentCust),
            );
          }
          
          return LayoutBuilder(
            builder: (context, constraints) {
              return Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: constraints.maxWidth > 1200 ? 1200 : constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: CustomerDesktopDetailView(customer: currentCust),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
