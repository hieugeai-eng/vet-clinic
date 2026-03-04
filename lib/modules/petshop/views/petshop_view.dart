import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/main_layout.dart';
import '../controllers/petshop_controller.dart';
import 'desktop/petshop_desktop_view.dart';
import 'mobile/petshop_mobile_view.dart';

class PetshopView extends GetView<PetshopController> {
  const PetshopView({super.key});

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Pet Shop',
      actions: [
        ElevatedButton.icon(
          onPressed: () => _showProductForm(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Thêm Sản Phẩm'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
      // Use LayoutBuilder to switch between Mobile and Desktop views
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 800) {
            return const PetshopMobileView();
          } else {
            return const PetshopDesktopView();
          }
        },
      ),
    );
  }

  // Keep this method here or delegating to the active view?
  // The 'Add Product' button in AppBar calls this.
  // Since both sub-views implement their own forms (for now) or we want a unified one,
  // we can either:
  // 1. Duplicate logic here (easiest for now).
  // 2. Make it static or reusable.
  // Let's rely on the controller to manage state, and just open a dialog here.
  // Actually, MainLayout actions are global.
  // If we click "Add Product" in AppBar, it should open the dialog.
  // Since Mobile view might hide AppBar actions or move them, this button might only appear on Desktop MainLayout?
  // Our MainLayout design shows actions.
  // Let's implement _showProductForm here too so the AppBar button works.

  void _showProductForm(BuildContext context) {
    // Forward to controller to reset
    controller.resetForm();

    // Determine which dialog to show?
    // Or just show a responsive dialog.
    // Since we are in the Parent View, we can use a generic responsive dialog.
    // But wait, the sub-views also have "Edit" buttons that open their own dialogs.
    // It's better if we have ONE generic _showProductForm.
    // For now, I'll copy the responsive logic here.

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          // Responsive width check
          width: context.width > 600 ? 500 : context.width * 0.9,
          padding: const EdgeInsets.all(24),
          child: const PetshopForm(), // Ideally extract Form to widget
        ),
      ),
    );
  }
}

// Minimal Form Wrapper if we don't want to duplicate full code here.
// But since I didn't extract the Form Widget yet, I will just Instantiate the Desktop View's form logic?
// No, that's messy.
// HACK: For the AppBar button, I'll just instantiate the Responsive Form directly.
// But to avoid huge file size again, I should have extracted the Form.
// Plan:
// 1. Create `lib/modules/petshop/views/widgets/petshop_form.dart` (Extract the form).
// 2. Use it in Desktop, Mobile, and Parent View.

// For this step, I will just redirect to the Desktop View's logic via a trick,
// OR I will simply accept that I need to duplicate the form code ONE MORE TIME until I refactor it to a widget.
// Duplication is safer to avoid breaking changes right now.
// I will put a simplified version here for the AppBar button.

class PetshopForm extends GetView<PetshopController> {
  const PetshopForm({super.key});

  @override
  Widget build(BuildContext context) {
    return Form(
      key: controller.formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Thêm Sản Phẩm Mới',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: controller.nameController,
              decoration: const InputDecoration(
                labelText: 'Tên SP',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller.costPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Giá Vốn',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: controller.salePriceController,
                    decoration: const InputDecoration(
                      labelText: 'Giá Bán',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: controller.stockController,
              decoration: const InputDecoration(
                labelText: 'Tồn Kho',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await controller.saveProduct();
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}
