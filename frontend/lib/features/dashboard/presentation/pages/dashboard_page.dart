import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: Text('لوحة التحكم', style: TextStyle(fontFamily: 'Cairo', fontSize: 20.sp)),
            actions: [
              IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                child: CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Text(user?.name.substring(0, 1) ?? 'A', style: const TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: EdgeInsets.all(24.w),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _WelcomeBanner(userName: user?.name ?? ''),
                SizedBox(height: 24.h),
                const _StatsRow(),
                SizedBox(height: 24.h),
                const _ModulesGrid(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  final String userName;
  const _WelcomeBanner({required this.userName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مرحباً، $userName', style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo')),
                SizedBox(height: 4.h),
                Text('نظرة عامة على النظام', style: TextStyle(fontSize: 14.sp, color: Colors.white70, fontFamily: 'Cairo')),
              ],
            ),
          ),
          Icon(Icons.dashboard_outlined, size: 64.sp, color: Colors.white24),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(title: 'إجمالي المبيعات', value: '٠', icon: Icons.trending_up, color: AppColors.salesColor),
        SizedBox(width: 16.w),
        _StatCard(title: 'أوامر الشراء', value: '٠', icon: Icons.shopping_cart_outlined, color: AppColors.purchasesColor),
        SizedBox(width: 16.w),
        _StatCard(title: 'الموظفين', value: '٠', icon: Icons.people_outline, color: AppColors.hrColor),
        SizedBox(width: 16.w),
        _StatCard(title: 'المنتجات', value: '٠', icon: Icons.inventory_2_outlined, color: AppColors.inventoryColor),
      ].map((w) => Expanded(child: w)).toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 28.sp),
            ),
            SizedBox(width: 16.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                Text(title, style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary, fontFamily: 'Cairo')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModulesGrid extends StatelessWidget {
  const _ModulesGrid();

  static const modules = [
    (title: 'الموارد البشرية', icon: Icons.people, color: AppColors.hrColor, route: '/hr/employees'),
    (title: 'المخزون', icon: Icons.inventory_2, color: AppColors.inventoryColor, route: '/inventory/products'),
    (title: 'المبيعات', icon: Icons.point_of_sale, color: AppColors.salesColor, route: '/sales/orders'),
    (title: 'المشتريات', icon: Icons.shopping_bag, color: AppColors.purchasesColor, route: '/purchases/orders'),
    (title: 'المالية', icon: Icons.account_balance, color: AppColors.financeColor, route: '/finance/accounts'),
    (title: 'المحاسبة', icon: Icons.calculate, color: AppColors.accountingColor, route: '/finance/transactions'),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200.w,
        crossAxisSpacing: 16.w,
        mainAxisSpacing: 16.h,
        childAspectRatio: 1.2,
      ),
      itemCount: modules.length,
      itemBuilder: (context, i) {
        final m = modules[i];
        return Card(
          child: InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(m.icon, size: 40.sp, color: m.color),
                  SizedBox(height: 12.h),
                  Text(m.title, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
