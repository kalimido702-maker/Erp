import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/network/connectivity_service.dart';
import '../../core/offline/sync_manager.dart';

/// Displays a non-intrusive status bar at the top of any screen.
/// Shows: offline warning, syncing progress, failed operations alert.
class SyncStatusBanner extends ConsumerWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networkState = ref.watch(networkStateProvider).valueOrNull;
    final syncState = ref.watch(syncStateProvider).valueOrNull;
    final pendingCount = ref.watch(pendingCountProvider).valueOrNull ?? 0;

    if (networkState == NetworkState.online && syncState == SyncManagerState.idle && pendingCount == 0) {
      return const SizedBox.shrink();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _buildBanner(context, ref, networkState, syncState, pendingCount),
    );
  }

  Widget _buildBanner(
    BuildContext context,
    WidgetRef ref,
    NetworkState? network,
    SyncManagerState? sync,
    int pending,
  ) {
    if (network == NetworkState.offline) {
      return _Banner(
        key: const ValueKey('offline'),
        color: const Color(0xFFC62828),
        icon: Icons.cloud_off_rounded,
        message: 'لا يوجد اتصال بالإنترنت',
        subtitle: pending > 0 ? '$pending عملية في الانتظار حتى عودة الاتصال' : 'جميع البيانات محفوظة محلياً',
        trailing: TextButton(
          onPressed: () => ref.read(connectivityServiceProvider).checkNow(),
          child: Text('إعادة المحاولة', style: TextStyle(color: Colors.white, fontSize: 12.sp)),
        ),
      );
    }

    if (sync == SyncManagerState.syncing) {
      return _Banner(
        key: const ValueKey('syncing'),
        color: const Color(0xFF1565C0),
        icon: Icons.sync_rounded,
        message: 'جارٍ المزامنة مع الخادم...',
        subtitle: pending > 0 ? 'تبقى $pending عملية' : null,
        showSpinner: true,
      );
    }

    if (sync == SyncManagerState.error) {
      return _Banner(
        key: const ValueKey('error'),
        color: const Color(0xFFF57C00),
        icon: Icons.sync_problem_rounded,
        message: 'فشلت بعض عمليات المزامنة',
        subtitle: 'اضغط لعرض التفاصيل',
        trailing: TextButton(
          onPressed: () => _showFailedOpsDialog(context, ref),
          child: Text('عرض', style: TextStyle(color: Colors.white, fontSize: 12.sp)),
        ),
      );
    }

    if (pending > 0 && network == NetworkState.online) {
      return _Banner(
        key: const ValueKey('pending'),
        color: const Color(0xFF2E7D32),
        icon: Icons.cloud_upload_rounded,
        message: '$pending عملية في انتظار المزامنة',
        showSpinner: false,
      );
    }

    return const SizedBox.shrink(key: ValueKey('hidden'));
  }

  void _showFailedOpsDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('عمليات فاشلة في المزامنة'),
        content: const Text(
          'بعض العمليات لم تتم مزامنتها بسبب أخطاء من الخادم (مثل بيانات غير صحيحة). '
          'يمكنك حذفها لتجنب تراكمها.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final cleared = await ref.read(syncManagerProvider).clearFailedOperations();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم حذف $cleared عملية فاشلة')),
                );
              }
            },
            child: const Text('حذف الفاشلة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String message;
  final String? subtitle;
  final Widget? trailing;
  final bool showSpinner;

  const _Banner({
    super.key,
    required this.color,
    required this.icon,
    required this.message,
    this.subtitle,
    this.trailing,
    this.showSpinner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      elevation: 4,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: Row(
            children: [
              if (showSpinner)
                SizedBox(
                  width: 16.w,
                  height: 16.h,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.w),
                )
              else
                Icon(icon, color: Colors.white, size: 18.sp),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message,
                      style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w600, fontFamily: 'Cairo'),
                    ),
                    if (subtitle != null)
                      Text(subtitle!, style: TextStyle(color: Colors.white70, fontSize: 11.sp, fontFamily: 'Cairo')),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Wrap any page with this to show offline status
// ──────────────────────────────────────────────

class OfflineAwareScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? drawer;
  final Color? backgroundColor;

  const OfflineAwareScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.drawer,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor,
      floatingActionButton: floatingActionButton,
      drawer: drawer,
      body: Column(
        children: [
          const SyncStatusBanner(),
          Expanded(child: body),
        ],
      ),
    );
  }
}
