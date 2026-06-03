import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/notification_bell.dart';
import '../../../../shared/widgets/sync_status_banner.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;

    return OfflineAwareScaffold(
      body: Column(
        children: [
          _TopBar(userName: user?.name ?? ''),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(26, 24, 26, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TabsRow(),
                  const SizedBox(height: 18),
                  _KpiRow(),
                  const SizedBox(height: 18),
                  _ContentGrid(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String userName;
  const _TopBar({required this.userName});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 26),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outline)),
      ),
      child: Row(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('لوحة التحكم', style: GoogleFonts.tajawal(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
              Text('نظرة عامة على النظام', style: GoogleFonts.tajawal(fontSize: 12.5, color: cs.onSurface.withAlpha(120))),
            ],
          ),
          const SizedBox(width: 16),
          // search
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  border: Border.all(color: cs.outline),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 13),
                    Icon(Icons.search_rounded, size: 18, color: cs.onSurface.withAlpha(100)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        style: GoogleFonts.tajawal(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'ابحث...',
                          hintStyle: GoogleFonts.tajawal(fontSize: 14, color: cs.onSurface.withAlpha(100)),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // actions
          const Spacer(),
          const NotificationBell(),
          const SizedBox(width: 12),
          _UserAvatar(initial: userName.isNotEmpty ? userName[0] : 'م'),
        ],
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final String initial;
  const _UserAvatar({required this.initial});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(initial, style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tabs + customize
// ─────────────────────────────────────────────────────────────────────────────

class _TabsRow extends StatefulWidget {
  @override
  State<_TabsRow> createState() => _TabsRowState();
}

class _TabsRowState extends State<_TabsRow> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tabs = ['الرئيسية', 'المبيعات', 'المخزون'];

    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            border: Border.all(color: cs.outline),
            borderRadius: BorderRadius.circular(11),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(tabs.length, (i) {
              final active = _tab == i;
              return GestureDetector(
                onTap: () => setState(() => _tab = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? cs.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: active ? [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 4)] : null,
                  ),
                  child: Text(
                    tabs[i],
                    style: GoogleFonts.tajawal(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: active ? cs.primary : cs.onSurface.withAlpha(160),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border.all(color: cs.outlineVariant, style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune_rounded, size: 16, color: cs.onSurface.withAlpha(160)),
              const SizedBox(width: 8),
              Text('تخصيص اللوحة', style: GoogleFonts.tajawal(fontSize: 13.5, fontWeight: FontWeight.w700, color: cs.onSurface.withAlpha(160))),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI row
// ─────────────────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 600) {
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.6,
            children: _kpis,
          );
        }
        return Row(
          children: _kpis.map((k) => Expanded(child: Padding(padding: const EdgeInsets.only(left: 16), child: k))).toList(),
        );
      },
    );
  }

  static final _kpis = [
    _KpiCard(icon: Icons.inventory_2_outlined, tone: _KpiTone.blue, label: 'إجمالي المنتجات', val: '١٢٤', delta: '٦+', up: true),
    _KpiCard(icon: Icons.account_balance_wallet_outlined, tone: _KpiTone.cyan, label: 'قيمة المخزون', val: '٨٤٢٬٠٠٠', unit: 'ر.س', delta: '٪٣٫٢', up: true),
    _KpiCard(icon: Icons.warning_amber_rounded, tone: _KpiTone.warn, label: 'مخزون منخفض', val: '١٢', delta: '٢+', up: false),
    _KpiCard(icon: Icons.label_outline_rounded, tone: _KpiTone.danger, label: 'نفذ من المخزون', val: '٣', delta: '١-', up: true),
  ];
}

enum _KpiTone { blue, cyan, warn, danger }

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final _KpiTone tone;
  final String label;
  final String val;
  final String? unit;
  final String delta;
  final bool up;

  const _KpiCard({required this.icon, required this.tone, required this.label, required this.val, this.unit, required this.delta, required this.up});

  Color _bg(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return switch (tone) {
      _KpiTone.blue   => dark ? const Color(0x293470FF) : AppColors.primaryTint,
      _KpiTone.cyan   => dark ? const Color(0x242BC4FF) : AppColors.accentTint,
      _KpiTone.warn   => dark ? const Color(0x26F2B53D) : AppColors.warnTint,
      _KpiTone.danger => dark ? const Color(0x26FF6E64) : AppColors.dangerTint,
    };
  }

  Color _fg(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return switch (tone) {
      _KpiTone.blue   => dark ? AppColors.primaryDark : AppColors.primary,
      _KpiTone.cyan   => dark ? AppColors.accentDark : AppColors.accent,
      _KpiTone.warn   => dark ? AppColors.warnDark : AppColors.warn,
      _KpiTone.danger => dark ? AppColors.dangerDark : AppColors.danger,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: _bg(context), borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, size: 20, color: _fg(context)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label, style: GoogleFonts.tajawal(fontSize: 13.5, fontWeight: FontWeight.w600, color: cs.onSurface.withAlpha(160))),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(val, style: GoogleFonts.tajawal(fontSize: 28, fontWeight: FontWeight.w800, height: 1, letterSpacing: -0.5)),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(unit!, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: cs.onSurface.withAlpha(120))),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 13, color: up ? AppColors.ok : AppColors.danger),
              const SizedBox(width: 4),
              Text(delta, style: GoogleFonts.tajawal(fontSize: 12.5, fontWeight: FontWeight.w700, color: up ? AppColors.ok : AppColors.danger)),
              const SizedBox(width: 4),
              Text('عن الشهر السابق', style: GoogleFonts.tajawal(fontSize: 12.5, color: cs.onSurface.withAlpha(100))),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Content grid (modules)
// ─────────────────────────────────────────────────────────────────────────────

class _ContentGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        if (c.maxWidth < 700) {
          return Column(
            children: [
              _ModulesPanel(),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _ModulesPanel()),
            const SizedBox(width: 16),
            SizedBox(width: 340, child: _QuickActionsPanel()),
          ],
        );
      },
    );
  }
}

class _ModulesPanel extends StatelessWidget {
  static const _modules = [
    (Icons.people_outline_rounded, 'الموارد البشرية', AppColors.moduleHr, '/hr/employees'),
    (Icons.inventory_2_outlined, 'المخزون', AppColors.moduleInventory, '/inventory/products'),
    (Icons.receipt_long_outlined, 'المبيعات', AppColors.moduleSales, '/sales/orders'),
    (Icons.local_shipping_outlined, 'المشتريات', AppColors.modulePurchases, '/purchases/orders'),
    (Icons.account_balance_outlined, 'المالية', AppColors.moduleFinance, '/finance/accounts'),
    (Icons.calculate_outlined, 'المحاسبة', AppColors.moduleAccounting, '/finance/transactions'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outline),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 17, 20, 17),
            child: Row(
              children: [
                Text('الوحدات', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outline),
          Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: _modules.map((m) => _ModuleTile(icon: m.$1, label: m.$2, color: m.$3)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ModuleTile({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionsPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = [
      (Icons.warning_amber_rounded, 'شاحن سريع 65W', 'نفذ — يلزم طلب فوري', AppColors.danger),
      (Icons.warning_rounded, 'ماوس Ergo Silent', 'باقٍ ٩ وحدات', AppColors.warn),
      (Icons.info_outline_rounded, 'سماعة AirBuds', 'باقٍ ١٨ وحدة', AppColors.warn),
    ];

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outline),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 17, 20, 17),
            child: Row(
              children: [
                Text('تنبيهات إعادة الطلب', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w800)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(9)),
                  child: Text('٥', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary)),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outline),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
                    child: Icon(item.$1, size: 18, color: item.$4),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.$2, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700)),
                        Text(item.$3, style: GoogleFonts.tajawal(fontSize: 12.5, color: cs.onSurface.withAlpha(140))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.$4 == AppColors.danger ? AppColors.dangerTint : AppColors.warnTint,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      item.$4 == AppColors.danger ? 'نفذ' : 'منخفض',
                      style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w700, color: item.$4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
