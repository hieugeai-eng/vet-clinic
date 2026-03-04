import 'package:get/get.dart';

/// Legacy Service to monitor network connectivity (Stubbed)
class ConnectivityService extends GetxService {
  final isOnline = true.obs;
  final connectionType = 'none'.obs;

  @override
  void onInit() {
    super.onInit();
  }

  /// Check if currently online (Stubbed to always return true)
  Future<bool> checkConnection() async {
    return true;
  }
}
