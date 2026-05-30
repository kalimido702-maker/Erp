import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:logger/logger.dart';

import '../network/api_client.dart';

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  final service = RealtimeService(ref);
  ref.onDispose(service.dispose);
  return service;
});

final notificationsProvider = StateNotifierProvider<NotificationNotifier, List<ErpNotification>>((ref) {
  return NotificationNotifier();
});

class NotificationNotifier extends StateNotifier<List<ErpNotification>> {
  NotificationNotifier() : super([]);

  void add(ErpNotification notification) {
    state = [notification, ...state];
  }

  void markRead(String id) {
    state = state.map((n) => n.id == id ? n.copyWith(readAt: DateTime.now()) : n).toList();
  }

  void markAllRead() {
    final now = DateTime.now();
    state = state.map((n) => n.copyWith(readAt: now)).toList();
  }

  int get unreadCount => state.where((n) => n.readAt == null).length;
}

class RealtimeService {
  final Ref _ref;
  final _log = Logger();
  WebSocketChannel? _channel;
  Timer? _heartbeat;
  Timer? _reconnectTimer;
  bool _disposed = false;
  int _reconnectDelay = 2;
  int? _companyId;
  String? _token;

  // Reverb runs as a standalone WebSocket server (default port 8080), separate
  // from the HTTP API — so its connection details come from dedicated envs that
  // mirror the backend's REVERB_* settings, not from API_BASE_URL.
  static const _appKey = String.fromEnvironment('REVERB_APP_KEY', defaultValue: 'local');
  static const _wsHost = String.fromEnvironment('REVERB_HOST', defaultValue: 'localhost');
  static const _wsPort = int.fromEnvironment('REVERB_PORT', defaultValue: 8080);
  static const _wsScheme = String.fromEnvironment('REVERB_SCHEME', defaultValue: 'http');

  RealtimeService(this._ref);

  Future<void> connect(int companyId, String token) async {
    if (_disposed) return;
    _disconnect();
    _companyId = companyId;
    _token = token;

    final wsScheme = _wsScheme == 'https' ? 'wss' : 'ws';
    final uri = Uri.parse(
      '$wsScheme://$_wsHost:$_wsPort/app/$_appKey?protocol=7&client=flutter&version=8.0.0',
    );

    try {
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      _startHeartbeat();
      _log.i('[WS] Connecting to Reverb…');
      // Subscription happens after pusher:connection_established (see _onMessage).
    } catch (e) {
      _log.e('[WS] Connection failed: $e');
      _scheduleReconnect();
    }
  }

  /// Pusher private-channel auth: ask the backend to sign socket_id:channel.
  /// Sending the bearer token directly as `auth` would be rejected by Reverb.
  Future<void> _authorizeAndSubscribe(String socketId) async {
    final companyId = _companyId;
    if (companyId == null) return;
    final channel = 'private-company.$companyId';

    try {
      final dio = _ref.read(apiClientProvider).dio;
      final res = await dio.post(
        '/broadcasting/auth',
        data: {'socket_id': socketId, 'channel_name': channel},
      );
      final auth = (res.data as Map)['auth'] as String?;
      if (auth == null) {
        _log.w('[WS] No auth signature returned for $channel');
        return;
      }
      _send({
        'event': 'pusher:subscribe',
        'data': {'channel': channel, 'auth': auth},
      });
      _reconnectDelay = 2; // successful subscription resets backoff
      _log.i('[WS] Subscribed to $channel');
    } catch (e) {
      _log.e('[WS] Channel authorization failed: $e');
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final event = msg['event'] as String? ?? '';

      switch (event) {
        case 'pusher:connection_established':
          final data = _decodeData(msg['data']);
          final socketId = data['socket_id'] as String?;
          if (socketId != null) _authorizeAndSubscribe(socketId);
          return;
        case 'pusher:ping':
          _send({'event': 'pusher:pong', 'data': {}});
          return;
        case 'pusher:error':
          _log.w('[WS] Pusher error: ${msg['data']}');
          return;
        case 'erp.notification':
          final payload = _decodeData(msg['data']);
          final notification = ErpNotification.fromJson(payload);
          _ref.read(notificationsProvider.notifier).add(notification);
          _log.i('[WS] Notification: ${notification.title}');
          return;
        default:
          return;
      }
    } catch (e) {
      _log.w('[WS] Bad message: $e');
    }
  }

  /// Pusher wraps the `data` field as a JSON-encoded string.
  Map<String, dynamic> _decodeData(dynamic data) {
    if (data is String) {
      if (data.isEmpty) return {};
      return jsonDecode(data) as Map<String, dynamic>;
    }
    if (data is Map<String, dynamic>) return data;
    return {};
  }

  void _onError(Object error) {
    _log.e('[WS] Error: $error');
  }

  void _onDone() {
    if (!_disposed) {
      _log.w('[WS] Disconnected, scheduling reconnect');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    final companyId = _companyId;
    final token = _token;
    if (companyId == null || token == null) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelay), () {
      if (!_disposed) {
        _reconnectDelay = (_reconnectDelay * 2).clamp(2, 120);
        connect(companyId, token);
      }
    });
  }

  void _startHeartbeat() {
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
      _send({'event': 'pusher:ping', 'data': {}});
    });
  }

  void _send(Map<String, dynamic> data) {
    _channel?.sink.add(jsonEncode(data));
  }

  void _disconnect() {
    _heartbeat?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  /// Tear down the connection on logout while keeping the service reusable
  /// for the next login (unlike [dispose], does not permanently disable it).
  void disconnect() {
    _companyId = null;
    _token = null;
    _reconnectDelay = 2;
    _disconnect();
  }

  void dispose() {
    _disposed = true;
    _disconnect();
  }
}

class ErpNotification {
  final String id;
  final String type;
  final String title;
  final String message;
  final String severity;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final DateTime? readAt;

  const ErpNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.severity,
    required this.data,
    required this.createdAt,
    this.readAt,
  });

  factory ErpNotification.fromJson(Map<String, dynamic> json) {
    return ErpNotification(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: json['type'] as String? ?? 'info',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      severity: json['severity'] as String? ?? 'info',
      data: (json['data'] as Map<String, dynamic>?) ?? {},
      createdAt: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  ErpNotification copyWith({DateTime? readAt}) => ErpNotification(
    id: id, type: type, title: title, message: message,
    severity: severity, data: data, createdAt: createdAt,
    readAt: readAt ?? this.readAt,
  );

  bool get isRead => readAt != null;
  bool get isUnread => readAt == null;
}
