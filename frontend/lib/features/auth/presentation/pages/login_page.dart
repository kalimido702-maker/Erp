import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/brand_logo.dart';
import '../providers/auth_provider.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bg,
      body: ResponsiveLayout(
        mobile: _MobileLayout(),
        desktop: _WebLayout(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Web: split brand + form
// ─────────────────────────────────────────────────────────────────────────────

class _WebLayout extends StatelessWidget {
  const _WebLayout();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(flex: 105, child: _BrandPanel()),
        Expanded(flex: 95, child: _FormPanel()),
      ],
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.5, -1.0),
          end: Alignment(0.5, 1.0),
          colors: AppColors.brandGradientColors,
          stops: [0.0, 0.48, 0.78, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.64, -0.6),
                  radius: 0.9,
                  colors: [Colors.white.withAlpha(46), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Opacity(opacity: 0.13, child: CustomPaint(painter: _GridPainter())),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(56, 56, 56, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Align(alignment: AlignmentDirectional.centerStart, child: BrandLogo.white(height: 52)),
                const Spacer(),
                const _BrandHeadline(),
                const SizedBox(height: 36),
                const _FeatureList(),
                const SizedBox(height: 42),
                const _BrandFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHeadline extends StatelessWidget {
  const _BrandHeadline();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('brand.headline'),
          style: GoogleFonts.tajawal(
            fontSize: 42,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.25,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          context.tr('brand.subtitle'),
          style: GoogleFonts.tajawal(fontSize: 17, height: 1.7, color: Colors.white.withAlpha(209)),
        ),
      ],
    );
  }
}

class _FeatureList extends StatelessWidget {
  const _FeatureList();

  @override
  Widget build(BuildContext context) {
    final feats = <(IconData, String, String)>[
      (Icons.inventory_2_outlined, 'brand.feature_inventory_title', 'brand.feature_inventory_desc'),
      (Icons.receipt_long_outlined, 'brand.feature_sales_title', 'brand.feature_sales_desc'),
      (Icons.bar_chart_rounded, 'brand.feature_reports_title', 'brand.feature_reports_desc'),
    ];
    return Column(
      children: feats
          .map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(36),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withAlpha(56)),
                    ),
                    child: Icon(f.$1, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr(f.$2), style: GoogleFonts.tajawal(fontSize: 15.5, fontWeight: FontWeight.w700, color: Colors.white)),
                      Text(context.tr(f.$3), style: GoogleFonts.tajawal(fontSize: 13.5, color: Colors.white.withAlpha(184))),
                    ],
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _BrandFooter extends StatelessWidget {
  const _BrandFooter();

  @override
  Widget build(BuildContext context) {
    Widget link(String key) => Text(
          context.tr(key),
          style: GoogleFonts.tajawal(fontSize: 13, color: Colors.white.withAlpha(153)),
        );
    return Row(
      children: [
        link('brand.privacy'),
        const SizedBox(width: 26),
        link('brand.terms'),
        const SizedBox(width: 26),
        link('brand.support'),
      ],
    );
  }
}

class _FormPanel extends StatelessWidget {
  const _FormPanel();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? AppColors.bgDark : AppColors.bg,
      child: Column(
        children: [
          _TopBar(isDark: isDark),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: const _LoginForm(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final bool isDark;
  const _TopBar({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 30, 40, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const _LangChip(),
          _ThemeToggleChip(isDark: isDark),
        ],
      ),
    );
  }
}

/// Language switcher — actually toggles the app locale (and RTL/LTR) via i18n.
class _LangChip extends ConsumerWidget {
  const _LangChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => ref.read(i18nControllerProvider.notifier).toggle(),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(999),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌐', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 7),
            Text(context.tr('language.name'),
                style: GoogleFonts.tajawal(fontSize: 13.5, fontWeight: FontWeight.w700, color: cs.onSurface.withAlpha(180))),
          ],
        ),
      ),
    );
  }
}

class _ThemeToggleChip extends StatelessWidget {
  final bool isDark;
  const _ThemeToggleChip({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleBtn(context, Icons.light_mode_rounded, !isDark),
          _toggleBtn(context, Icons.dark_mode_rounded, isDark),
        ],
      ),
    );
  }

  Widget _toggleBtn(BuildContext context, IconData icon, bool active) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 30,
      height: 30,
      decoration: active
          ? BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 4)],
            )
          : null,
      child: Icon(icon, size: 16, color: active ? cs.primary : cs.onSurface.withAlpha(100)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile: full gradient + floating white card
// ─────────────────────────────────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  const _MobileLayout();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.surfaceDark : Colors.white;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.4, -1.0),
          end: Alignment(0.4, 1.0),
          colors: AppColors.brandGradientColors,
          stops: [0.0, 0.48, 0.78, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(opacity: 0.10, child: CustomPaint(painter: _GridPainter())),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 33),
                Expanded(
                  flex: 67,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
                      boxShadow: [BoxShadow(color: Colors.black.withAlpha(28), blurRadius: 30, offset: const Offset(0, -8))],
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(26, 34, 26, 26),
                      child: const _LoginForm(mobile: true),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared form
// ─────────────────────────────────────────────────────────────────────────────

class _LoginForm extends ConsumerStatefulWidget {
  final bool mobile;
  const _LoginForm({this.mobile = false});

  @override
  ConsumerState<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _remember = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authStateProvider.notifier).login(_emailCtrl.text.trim(), _passCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final cs = Theme.of(context).colorScheme;

    ref.listen(authStateProvider, (_, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(next.error.toString(), style: GoogleFonts.tajawal()),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
      }
    });

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.mobile) ...[
            Text(context.tr('auth.welcome_back'), style: GoogleFonts.tajawal(fontSize: 29, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: cs.onSurface)),
            const SizedBox(height: 8),
            Text(context.tr('auth.subtitle'), style: GoogleFonts.tajawal(fontSize: 15, color: cs.onSurface.withAlpha(160))),
            const SizedBox(height: 30),
          ] else ...[
            Text(context.tr('auth.login'), style: GoogleFonts.tajawal(fontSize: 26, fontWeight: FontWeight.w800, color: cs.onSurface)),
            const SizedBox(height: 8),
            Text(context.tr('auth.subtitle_account'), style: GoogleFonts.tajawal(fontSize: 14, color: cs.onSurface.withAlpha(160))),
            const SizedBox(height: 24),
          ],
          _FieldLabel(label: context.tr('auth.email')),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.start,
            decoration: InputDecoration(
              hintText: context.tr('auth.email_hint'),
              prefixIcon: const Icon(Icons.email_outlined, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 44, vertical: 14),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return context.tr('auth.email_required');
              if (!v.contains('@')) return context.tr('auth.email_invalid');
              return null;
            },
          ),
          const SizedBox(height: 18),
          _FieldLabel(label: context.tr('auth.password')),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 44, vertical: 14),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return context.tr('auth.password_required');
              if (v.length < 6) return context.tr('auth.password_short');
              return null;
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _RememberMe(value: _remember, onChanged: (v) => setState(() => _remember = v ?? false)),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(foregroundColor: cs.primary, padding: const EdgeInsets.symmetric(horizontal: 4)),
                  child: Text(context.tr('auth.forgot_password'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: authState.isLoading ? null : _submit,
            child: authState.isLoading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Text(
                    context.tr(widget.mobile ? 'auth.login' : 'auth.login_short'),
                    style: GoogleFonts.tajawal(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
          ),
          if (widget.mobile) ...[
            const SizedBox(height: 18),
            const _BiometricButton(),
            const SizedBox(height: 26),
            Center(child: _SignupHint(lead: context.tr('auth.no_account'), action: context.tr('auth.contact_admin'))),
          ] else ...[
            const SizedBox(height: 30),
            Center(child: _SignupHint(lead: context.tr('auth.no_account'), action: context.tr('auth.signup_free'))),
          ],
        ],
      ),
    );
  }
}

class _BiometricButton extends StatelessWidget {
  const _BiometricButton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        side: BorderSide(color: cs.outlineVariant),
        padding: const EdgeInsets.symmetric(vertical: 11),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(context.tr('auth.biometric'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w700, fontSize: 14.5)),
          const SizedBox(width: 12),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: cs.primary.withAlpha(20), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.fingerprint_rounded, color: cs.primary, size: 20),
          ),
        ],
      ),
    );
  }
}

class _SignupHint extends StatelessWidget {
  final String lead;
  final String action;
  const _SignupHint({required this.lead, required this.action});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text.rich(
      TextSpan(
        text: lead,
        style: GoogleFonts.tajawal(fontSize: 14, color: cs.onSurface.withAlpha(160)),
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: () {},
              child: Text(action, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: cs.primary)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.tajawal(fontSize: 13.5, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface.withAlpha(180)),
    );
  }
}

class _RememberMe extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  const _RememberMe({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            ),
          ),
          const SizedBox(width: 9),
          Text(context.tr('auth.remember_me'), style: GoogleFonts.tajawal(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withAlpha(160))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grid painter for brand backgrounds
// ─────────────────────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(153)
      ..strokeWidth = 1;
    const step = 46.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}
