import 'package:flutter/material.dart';
import 'theme.dart';

/// The brand mark: the bare lightning "E" (no icon tile). Transparent PNG cut
/// from the primary lockup, so it composes onto any background.
class BrandBolt extends StatelessWidget {
  const BrandBolt({super.key, this.height = 150});
  final double height;
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/hero.png',
    height: height,
    filterQuality: FilterQuality.medium,
  );
}

/// The bolt with a slow "breathing" orange glow behind it — the cinematic
/// hero used by the splash and onboarding. Pure paint, no images beyond the
/// bolt itself, so it is cheap to run on the first frame.
class PulsingBolt extends StatefulWidget {
  const PulsingBolt({super.key, this.height = 150});
  final double height;
  @override
  State<PulsingBolt> createState() => _PulsingBoltState();
}

class _PulsingBoltState extends State<PulsingBolt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat(reverse: true);
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Curves.easeInOutSine,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.height;
    return SizedBox(
      width: h * 1.6,
      height: h * 1.25,
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, child) {
          final a = 0.18 + 0.22 * _t.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: h * 0.75,
                height: h * 0.75,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: a),
                      blurRadius: h * 0.6,
                      spreadRadius: h * 0.12,
                    ),
                  ],
                ),
              ),
              child!,
            ],
          );
        },
        child: BrandBolt(height: h),
      ),
    );
  }
}

/// Stacked logo lockup (variation 03 of the logo system): bolt above
/// GO AND TELL / GO. SHARE. DISCIPLE. MAKE DISCIPLES.
class BrandLockup extends StatelessWidget {
  const BrandLockup({
    super.key,
    this.boltHeight = 150,
    this.onDark = true,
    this.showTagline = true,
    this.pulse = false,
  });

  /// Animate the glow behind the bolt.
  final bool pulse;
  final double boltHeight;

  /// Force light type (splash is always black); otherwise follow the theme.
  final bool onDark;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final tag = onDark ? Colors.white54 : Dims.muted(context);
    return MediaQuery.withNoTextScaling(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            pulse
                ? PulsingBolt(height: boltHeight)
                : BrandBolt(height: boltHeight),
            const SizedBox(height: Dims.l),
            const Text(
              'GO AND TELL',
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                height: 1,
              ),
            ),
            if (showTagline) ...[
              const SizedBox(height: 10),
              Text(
                'GO. SHARE. DISCIPLE. MAKE DISCIPLES.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: tag,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
