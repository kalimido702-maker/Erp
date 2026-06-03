import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../theme/app_colors.dart';
import '../utils/auth_guard.dart';
import 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authGuard = AuthGuard(ref);

  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    redirect: authGuard.redirect,
    refreshListenable: authGuard,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (_, __) => const LoginPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.uri.toString(), child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            name: 'dashboard',
            builder: (_, __) => const DashboardPage(),
          ),
          ...AppRoutes.moduleRoutes,
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('الصفحة غير موجودة: ${state.uri}', style: GoogleFonts.tajawal())),
    ),
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// AppShell — responsive: sidebar on wide screens, drawer on narrow
// ─────────────────────────────────────────────────────────────────────────────

class AppShell extends StatelessWidget {
  final String location;
  final Widget child;
  const AppShell({super.key, required this.location, required this.child});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;

    if (wide) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          children: [
            SidebarNav(location: location),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        drawer: Drawer(
          width: 262,
          child: SidebarNav(location: location),
        ),
        body: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar
// ─────────────────────────────────────────────────────────────────────────────

class SidebarNav extends ConsumerWidget {
  final String location;
  const SidebarNav({super.key, required this.location});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final user = ref.watch(authStateProvider).valueOrNull;

    return Container(
      width: 262,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(left: BorderSide(color: cs.outline)),
      ),
      child: Column(
        children: [
          // brand
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: const Alignment(-0.5, -1),
                      end: const Alignment(0.5, 1),
                      colors: AppColors.brandGradientColors,
                    ),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.business_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 11),
                Text('شامل ERP', style: GoogleFonts.tajawal(fontSize: 17, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          // store selector
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                border: Border.all(color: cs.outline),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppColors.brandGradientColors,
                        begin: const Alignment(-0.5, -1),
                        end: const Alignment(0.5, 1),
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Text('ف١', style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الفرع الرئيسي', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700)),
                        Text('الرياض · العليا', style: GoogleFonts.tajawal(fontSize: 12, color: cs.onSurface.withAlpha(120))),
                      ],
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: cs.onSurface.withAlpha(120)),
                ],
              ),
            ),
          ),
          // nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _NavItem(icon: Icons.grid_view_rounded, label: 'لوحة التحكم', path: AppRoutes.dashboard, location: location),
                _NavItem(icon: Icons.receipt_long_outlined, label: 'المبيعات والفواتير', path: AppRoutes.salesOrders, location: location, badge: '٨', badgeSoft: true),
                _NavItem(icon: Icons.point_of_sale_outlined, label: 'نقطة البيع', path: '/pos', location: location),
                _NavSectionLabel(label: 'العمليات'),
                _NavItem(icon: Icons.inventory_2_outlined, label: 'المخزون والمنتجات', path: AppRoutes.products, location: location),
                _NavItem(icon: Icons.local_shipping_outlined, label: 'المشتريات', path: AppRoutes.purchaseOrders, location: location),
                _NavItem(icon: Icons.people_outline_rounded, label: 'العملاء والموردون', path: AppRoutes.customers, location: location),
                _NavSectionLabel(label: 'التحليلات والنظام'),
                _NavItem(icon: Icons.bar_chart_rounded, label: 'التقارير', path: AppRoutes.reports, location: location),
                _NavItem(icon: Icons.account_balance_wallet_outlined, label: 'المحاسبة والخزينة', path: AppRoutes.accounts, location: location),
                _NavItem(icon: Icons.settings_outlined, label: 'الإعدادات', path: AppRoutes.settings, location: location),
              ],
            ),
          ),
          // user footer
          Container(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 20),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outline))),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    user?.name.isNotEmpty == true ? user!.name[0] : 'م',
                    style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, color: cs.primary, fontSize: 15),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? 'المستخدم', style: GoogleFonts.tajawal(fontSize: 13.5, fontWeight: FontWeight.w700)),
                      Text(user?.email ?? '', style: GoogleFonts.tajawal(fontSize: 12, color: cs.onSurface.withAlpha(120)), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Icon(Icons.more_horiz_rounded, size: 18, color: cs.onSurface.withAlpha(120)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavSectionLabel extends StatelessWidget {
  final String label;
  const _NavSectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 7),
      child: Text(
        label,
        style: GoogleFonts.tajawal(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String path;
  final String location;
  final String? badge;
  final bool badgeSoft;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.path,
    required this.location,
    this.badge,
    this.badgeSoft = false,
  });

  bool get _active => location == path || (path != '/' && location.startsWith(path));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // active indicator bar
        if (_active)
          Positioned(
            right: 0,
            top: 8,
            bottom: 8,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(4)),
              ),
            ),
          ),
        Material(
          color: _active ? (dark ? cs.primary.withAlpha(30) : AppColors.primaryTint) : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            onTap: () => context.go(path),
            borderRadius: BorderRadius.circular(11),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 19,
                    color: _active ? cs.primary : cs.onSurface.withAlpha(160),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.tajawal(
                        fontSize: 14.5,
                        fontWeight: _active ? FontWeight.w700 : FontWeight.w600,
                        color: _active ? (dark ? Colors.white : cs.primary) : cs.onSurface.withAlpha(160),
                      ),
                    ),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeSoft ? AppColors.primaryTint2 : AppColors.danger,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge!,
                        style: GoogleFonts.tajawal(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: badgeSoft ? AppColors.primary : Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
