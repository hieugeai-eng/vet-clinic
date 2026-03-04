import 'package:get/get.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/debug_logger.dart';
import '../../../routes/app_routes.dart';

class SplashController extends GetxController {
  @override
  void onReady() {
    super.onReady();
    _initialize();
  }

  Future<void> _initialize() async {
    // Artificial delay for better UX (optional, but ensures UI renders)
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      logDebug('Splash: Checking Session...');
      final authService = AuthService.to;

      // Ensure session is loaded
      // Note: If loadSavedSession was already called in main, this is fast.
      // If we move it here, we ensure non-blocking main.
      await authService.loadSavedSession();

      logDebug(
        'Splash: Session Loaded. LoggedIn: ${authService.isLoggedIn.value}',
      );

      if (authService.isLoggedIn.value) {
        Get.offAllNamed(Routes.staffSelect);
      } else {
        Get.offAllNamed(Routes.login);
      }
    } catch (e) {
      logDebug('Splash Error: $e');
      Get.offAllNamed(Routes.login);
    }
  }
}
