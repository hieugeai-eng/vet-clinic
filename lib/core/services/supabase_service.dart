import 'package:get/get.dart';
import 'package:flutter/foundation.dart';

import '../config/supabase_config.dart';
import 'supabase_rest_client.dart';
import 'realtime_service.dart';

/// Main Supabase service - orchestrates REST client and Realtime
class SupabaseService extends GetxService {
  static SupabaseService get to => Get.find();

  /// Connection status
  final isReady = false.obs;
  final isOnline = false.obs;

  /// Convenience getter for REST client
  SupabaseRestClient get rest => SupabaseRestClient.to;

  /// Convenience getter for Realtime service
  RealtimeService get realtime => RealtimeService.to;

  @override
  void onInit() {
    super.onInit();
    _initialize();
  }

  Future<void> _initialize() async {
    if (!SupabaseConfig.isConfigured) {
      debugPrint('SupabaseService: Not configured - running in offline mode');
      isReady.value = false;
      return;
    }

    try {
      // Connect to realtime
      await realtime.connect();
      isReady.value = true;
      isOnline.value = true;
      debugPrint('SupabaseService: Initialized successfully');
    } catch (e) {
      debugPrint('SupabaseService: Initialization error - $e');
      isReady.value = false;
      isOnline.value = false;
    }
  }

  /// Check if Supabase is configured and ready
  bool get canSync => SupabaseConfig.isConfigured && isReady.value;

  /// Reconnect to Supabase (call after network recovery)
  Future<void> reconnect() async {
    if (!SupabaseConfig.isConfigured) return;

    await realtime.connect();
    isOnline.value = realtime.isConnected.value;
  }
}
