import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:get_storage/get_storage.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../routes/app_routes.dart';

class AuthController extends GetxController {
  final formKey = GlobalKey<FormBuilderState>();

  final isLoading = false.obs;
  final errorMessage = ''.obs;

  final isPasswordVisible = false.obs;

  /// Saved email from last login session
  final savedEmail = RxnString();

  @override
  void onInit() {
    super.onInit();
    // Load last used email
    final box = GetStorage();
    savedEmail.value = box.read('last_login_email');
  }

  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  Future<void> login() async {
    if (formKey.currentState?.saveAndValidate() ?? false) {
      final values = formKey.currentState!.value;
      final email = values['email'] as String;
      final password = values['password'] as String;

      isLoading.value = true;
      errorMessage.value = '';

      try {
        await AuthService.to.signIn(email: email, password: password);
        // Save email for next login
        final box = GetStorage();
        box.write('last_login_email', email);
        Get.offAllNamed(Routes.staffSelect);
      } catch (e) {
        errorMessage.value =
            'Đăng nhập thất bại: ${e.toString().replaceAll('Exception:', '')}';
      } finally {
        isLoading.value = false;
      }
    }
  }
}
