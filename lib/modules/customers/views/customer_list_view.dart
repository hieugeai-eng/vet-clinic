import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/widgets/main_layout.dart';
import '../controllers/customer_controller.dart';
import '../widgets/customer_form_dialog.dart';
import 'desktop/customer_desktop_view.dart';
import 'mobile/customer_mobile_view.dart';

class CustomerListView extends GetView<CustomerController> {
  const CustomerListView({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveHelper.isMobile(context)
        ? const MainLayout(
            hideAppBar: true,
            child: CustomerMobileView(),
          )
        : MainLayout(
            title: 'Khách Hàng',
            actions: [
              IconButton(
                onPressed: () => controller.loadCustomers(),
                icon: const Icon(Icons.refresh),
                tooltip: 'Tải lại',
              ),
            ],
            child: const Padding(
              padding: EdgeInsets.all(24.0),
              child: CustomerDesktopView(),
            ),
          );
  }
}
