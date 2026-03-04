import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/supabase_config.dart';
import 'auth_service.dart';

/// Real-time notification service using WebSocket
/// Connects to Supabase Realtime for live data updates
class RealtimeService extends GetxService {
  static RealtimeService get to => Get.find();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _heartbeatTimer;
  int _refCounter = 0;

  final isConnected = false.obs;
  final _tableListeners = <String, List<Function(Map<String, dynamic>)>>{};

  /// Get access token for RLS-filtered events
  String get _accessToken {
    try {
      if (Get.isRegistered<AuthService>() &&
          AuthService.to.accessToken.isNotEmpty) {
        return AuthService.to.accessToken.value;
      }
    } catch (_) {}
    return SupabaseConfig.anonKey;
  }

  String get _nextRef => '${++_refCounter}';

  /// Connect to Supabase Realtime WebSocket
  Future<void> connect() async {
    if (!SupabaseConfig.isConfigured) {
      debugPrint(
        'RealtimeService: Supabase not configured, skipping connection',
      );
      return;
    }

    if (isConnected.value) return;

    try {
      // Include access token in URL for authenticated realtime
      final wsUrl =
          '${SupabaseConfig.realtimeUrl}'
          '?apikey=${SupabaseConfig.anonKey}'
          '&token=$_accessToken'
          '&vsn=1.0.0';

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );

      // Start heartbeat to keep connection alive
      _startHeartbeat();

      isConnected.value = true;
      debugPrint('RealtimeService: Connected to Supabase Realtime');

      // Re-subscribe all existing listeners
      for (final table in _tableListeners.keys) {
        _sendSubscription(table);
      }
    } catch (e) {
      debugPrint('RealtimeService: Connection error - $e');
      isConnected.value = false;
      _scheduleReconnect();
    }
  }

  /// Subscribe to table changes
  void subscribe(String table, Function(Map<String, dynamic>) callback) {
    _tableListeners[table] ??= [];
    _tableListeners[table]!.add(callback);

    // Send subscription message if connected
    if (isConnected.value && _channel != null) {
      _sendSubscription(table);
    }
  }

  /// Unsubscribe from table changes
  void unsubscribe(String table, Function(Map<String, dynamic>) callback) {
    _tableListeners[table]?.remove(callback);
  }

  /// Handle incoming WebSocket messages
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String);
      final event = data['event'] as String?;
      final topic = data['topic'] as String? ?? '';
      final payload = data['payload'] as Map<String, dynamic>? ?? {};

      if (event == 'phx_reply') {
        final status = payload['status'];
        debugPrint('RealtimeService: Reply on $topic — $status');
      } else if (event == 'postgres_changes') {
        // Supabase Realtime v2 postgres change event
        final changeData = payload['data'] as Map<String, dynamic>? ?? payload;
        final table =
            changeData['table'] as String? ?? payload['table'] as String?;
        final type =
            changeData['type'] as String? ?? payload['type'] as String?;

        if (table != null && _tableListeners.containsKey(table)) {
          debugPrint('RealtimeService: Change on $table ($type)');
          final eventPayload = {
            'table': table,
            'type': type,
            'record':
                changeData['record'] ?? changeData['new'] ?? payload['record'],
            'old_record': changeData['old_record'] ?? changeData['old'],
          };
          for (final callback in _tableListeners[table]!) {
            callback(eventPayload);
          }
        }
      } else if (event == 'system') {
        debugPrint(
          'RealtimeService: System event — ${payload['message'] ?? payload['status']}',
        );
      }
    } catch (e) {
      debugPrint('RealtimeService: Error parsing message - $e');
    }
  }

  void _handleError(dynamic error) {
    debugPrint('RealtimeService: WebSocket error - $error');
    isConnected.value = false;
    _scheduleReconnect();
  }

  void _handleDisconnect() {
    debugPrint('RealtimeService: WebSocket disconnected');
    isConnected.value = false;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    Future.delayed(const Duration(seconds: 5), () {
      if (!isConnected.value) {
        debugPrint('RealtimeService: Attempting reconnection...');
        connect();
      }
    });
  }

  /// Subscribe to postgres changes for a specific table
  void _sendSubscription(String table) {
    final ref = _nextRef;
    final topic = 'realtime:public:$table';

    // Join the channel with postgres_changes config
    _channel?.sink.add(
      jsonEncode({
        'topic': topic,
        'event': 'phx_join',
        'payload': {
          'config': {
            'postgres_changes': [
              {'event': '*', 'schema': 'public', 'table': table},
            ],
          },
          'access_token': _accessToken,
        },
        'ref': ref,
      }),
    );
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (isConnected.value && _channel != null) {
        _channel!.sink.add(
          jsonEncode({
            'topic': 'phoenix',
            'event': 'heartbeat',
            'payload': {},
            'ref': _nextRef,
          }),
        );
      }
    });
  }

  /// Disconnect from WebSocket
  void disconnect() {
    _heartbeatTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    isConnected.value = false;
  }

  @override
  void onClose() {
    disconnect();
    super.onClose();
  }
}
