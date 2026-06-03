import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_assets.dart';
import '../../core/i18n/translations_scope.dart';
import '../../core/theme/app_colors.dart';

/// The شاملX brand mark. Single place that decides which logo tone to show and
/// provides a graceful icon+text fallback if the asset file isn't present yet.
///
/// - [BrandLogo.white]   → for the brand gradient / dark surfaces.
/// - [BrandLogo.colored] → for light surfaces (sidebar, white cards).
/// - [BrandLogo.auto]    → picks tone from the ambient theme brightness.
class BrandLogo extends StatelessWidget {
  final _Tone _tone;
  final double height;

  const BrandLogo.white({super.key, this.height = 52}) : _tone = _Tone.white;
  const BrandLogo.colored({super.key, this.height = 38}) : _tone = _Tone.colored;
  const BrandLogo.auto({super.key, this.height = 38}) : _tone = _Tone.auto;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final useWhite = switch (_tone) {
      _Tone.white => true,
      _Tone.colored => false,
      _Tone.auto => dark,
    };

    return Image.asset(
      useWhite ? AppAssets.logoWhite : AppAssets.logoColored,
      height: height,
      fit: BoxFit.contain,
      alignment: AlignmentDirectional.centerStart.resolve(Directionality.of(context)),
      errorBuilder: (_, __, ___) => _FallbackMark(white: useWhite, height: height),
    );
  }
}

enum _Tone { white, colored, auto }

class _FallbackMark extends StatelessWidget {
  final bool white;
  final double height;
  const _FallbackMark({required this.white, required this.height});

  @override
  Widget build(BuildContext context) {
    final box = height * 0.88;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: box,
          height: box,
          decoration: BoxDecoration(
            gradient: white
                ? null
                : const LinearGradient(
                    begin: Alignment(-0.5, -1),
                    end: Alignment(0.5, 1),
                    colors: AppColors.brandGradientColors,
                  ),
            color: white ? Colors.white.withAlpha(36) : null,
            borderRadius: BorderRadius.circular(box * 0.26),
            border: white ? Border.all(color: Colors.white.withAlpha(60)) : null,
          ),
          child: Icon(Icons.business_rounded,
              color: Colors.white, size: box * 0.55),
        ),
        SizedBox(width: height * 0.3),
        Text(
          context.tr('brand.name'),
          style: GoogleFonts.tajawal(
            fontSize: height * 0.42,
            fontWeight: FontWeight.w800,
            color: white ? Colors.white : null,
          ),
        ),
      ],
    );
  }
}
