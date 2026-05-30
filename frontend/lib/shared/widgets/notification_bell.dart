import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/realtime/realtime_service.dart';

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final unread = notifications.where((n) => n.isUnread).length;

    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => _showPanel(context, ref, notifications),
        ),
        if (unread > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                unread > 99 ? '99+' : unread.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  void _showPanel(BuildContext context, WidgetRef ref, List<ErpNotification> notifications) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, controller) => _NotificationPanel(
          notifications: notifications,
          scrollController: controller,
          onMarkAllRead: () => ref.read(notificationsProvider.notifier).markAllRead(),
        ),
      ),
    );
  }
}

class _NotificationPanel extends StatelessWidget {
  final List<ErpNotification> notifications;
  final ScrollController scrollController;
  final VoidCallback onMarkAllRead;

  const _NotificationPanel({
    required this.notifications,
    required this.scrollController,
    required this.onMarkAllRead,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Text('الإشعارات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (notifications.any((n) => n.isUnread))
                TextButton(onPressed: onMarkAllRead, child: const Text('قراءة الكل')),
            ],
          ),
        ),
        const Divider(height: 0),
        Expanded(
          child: notifications.isEmpty
              ? const Center(child: Text('لا توجد إشعارات'))
              : ListView.builder(
                  controller: scrollController,
                  itemCount: notifications.length,
                  itemBuilder: (_, i) => _NotificationTile(notification: notifications[i]),
                ),
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final ErpNotification notification;
  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(notification.severity);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.15),
        child: Icon(_severityIcon(notification.severity), color: color, size: 20),
      ),
      title: Text(
        notification.title,
        style: TextStyle(fontWeight: notification.isUnread ? FontWeight.bold : FontWeight.normal),
      ),
      subtitle: Text(notification.message, maxLines: 2, overflow: TextOverflow.ellipsis),
      tileColor: notification.isUnread ? color.withOpacity(0.04) : null,
    );
  }

  Color _severityColor(String severity) => switch (severity) {
    'error'   => Colors.red,
    'warning' => Colors.orange,
    'success' => Colors.green,
    _         => Colors.blue,
  };

  IconData _severityIcon(String severity) => switch (severity) {
    'error'   => Icons.error_outline,
    'warning' => Icons.warning_amber_outlined,
    'success' => Icons.check_circle_outline,
    _         => Icons.info_outline,
  };
}
