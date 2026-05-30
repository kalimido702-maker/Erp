import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  RealtimeService(this._ref);

  Future<void> connect(int companyId, String token) async {
    if (_disposed) return;
    _disconnect();

    final env = const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000');
    final wsBase = env.replaceFirst(RegExp(r'^http'), 'ws');
    final uri = Uri.parse('$wsBase/app/local?protocol=7&client=flutter&version=8.0.0');

    try {
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: () => _onDone(companyId, token),
      );

      _subscribeTo(companyId, token);
      _startHeartbeat();
      _reconnectDelay = 2;
      _log.i('[WS] Connected to Reverb');
    } catch (e) {
      _log.e('[WS] Connection failed: $e');
      _scheduleReconnect(companyId, token);
    }
  }

  void _subscribeTo(int companyId, String token) {
    _send({
      'event': 'pusher:subscribe',
      'data': {
        'channel': 'private-company.$companyId',
        'auth': token,
      },
    });
  }

  void _onMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final event = msg['event'] as String? ?? '';

      if (event == 'erp.notification') {
        final data = msg['data'];
        final payload = data is String ? jsonDecode(data) as Map<String, dynamic> : data as Map<String, dynamic>;
        final notification = ErpNotification.fromJson(payload);
        _ref.read(notificationsProvider.notifier).add(notification);
        _log.i('[WS] Notification: ${notification.title}');
      }
    } catch (e) {
      _log.w('[WS] Bad message: $e');
    }
  }

  void _onError(Object error) {
    _log.e('[WS] Error: $error');
  }

  void _onDone(int companyId, String token) {
    if (!_disposed) {
      _log.w('[WS] Disconnected, scheduling reconnect');
      _scheduleReconnect(companyId, token);
    }
  }

  void _scheduleReconnect(int companyId, String token) {
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
