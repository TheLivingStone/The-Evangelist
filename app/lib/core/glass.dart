import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'theme.dart';

/// Liquid Glass, Flutter edition.
///
/// Follows Apple's HIG for the material: glass is a *functional layer* that
/// floats above content (tab bar, app bars, sheets, primary controls) and lets
/// content scroll and peek through beneath it. Content itself (cards, lists)
/// stays on standard opaque materials — which is also what keeps scrolling
/// cheap, since every [Glass] costs a backdrop blur.
///
/// Two variants, as in the HIG:
/// - regular (default): blurs + adjusts luminosity so text stays legible
/// - clear: highly translucent, for elements over rich/dark backgrounds
///
/// Honors the accessibility "increase contrast" flag by rendering opaque.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 24,
    this.clear = false,
    this.blur = 22,
    this.tint,
    this.padding,
    this.shadow = true,
    this.shape,
  });

  final Widget child;
  final double radius;
  final bool clear;
  final double blur;

  /// Optional colour cast (e.g. the accent for the action button).
  final Color? tint;
  final EdgeInsetsGeometry? padding;
  final bool shadow;

  /// Override the rounded-rect with e.g. a [StadiumBorder] capsule.
  final OutlinedBorder? shape;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final opaque = MediaQuery.of(context).highContrast;
    final shapeBorder =
        shape ??
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

    // Fill: white lift in dark mode, white body in light mode.
    final Color fill;
    if (opaque) {
      fill = dark ? AppColors.dSurface2 : AppColors.lSurface;
    } else if (tint != null) {
      fill = tint!.withValues(alpha: clear ? 0.55 : 0.82);
    } else if (dark) {
      fill = Colors.white.withValues(alpha: clear ? 0.06 : 0.10);
    } else {
      fill = Colors.white.withValues(alpha: clear ? 0.35 : 0.62);
    }
    // Luminosity adjustment behind the fill (regular variant only), so busy
    // content underneath never fights the text on top.
    final dim = (!opaque && !clear && tint == null)
        ? (dark
              ? Colors.black.withValues(alpha: 0.28)
              : Colors.white.withValues(alpha: 0.2))
        : Colors.transparent;
    final edge = dark
        ? Colors.white.withValues(alpha: opaque ? 0.16 : 0.14)
        : Colors.white.withValues(alpha: 0.75);

    Widget body = DecoratedBox(
      decoration: ShapeDecoration(color: fill, shape: shapeBorder),
      child: DecoratedBox(
        // Specular highlight: a soft light catching the top edge, the cue
        // that reads as "glass" rather than "frosted panel".
        decoration: ShapeDecoration(
          shape: shapeBorder,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: dark ? 0.09 : 0.35),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const [0, 0.45],
          ),
        ),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: shapeBorder.copyWith(
              side: BorderSide(color: edge, width: 0.8),
            ),
          ),
          child: padding == null
              ? child
              : Padding(padding: padding!, child: child),
        ),
      ),
    );

    if (!opaque) {
      body = ClipPath(
        clipper: ShapeBorderClipper(shape: shapeBorder),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: ColoredBox(color: dim, child: body),
        ),
      );
    } else {
      body = ClipPath(
        clipper: ShapeBorderClipper(shape: shapeBorder),
        child: body,
      );
    }

    if (!shadow) return body;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shapeBorder,
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.45 : 0.16),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: body,
    );
  }
}

/// Capsule-shaped glass, for pills and grouped controls.
class GlassCapsule extends StatelessWidget {
  const GlassCapsule({
    super.key,
    required this.child,
    this.clear = false,
    this.tint,
    this.padding,
    this.shadow = true,
  });
  final Widget child;
  final bool clear;
  final Color? tint;
  final EdgeInsetsGeometry? padding;
  final bool shadow;
  @override
  Widget build(BuildContext context) => Glass(
    shape: const StadiumBorder(),
    clear: clear,
    tint: tint,
    padding: padding,
    shadow: shadow,
    child: child,
  );
}

/// A translucent app bar with the scroll-edge effect: content slides under it
/// and is blurred/dimmed so the title and actions stay legible. Drop-in for
/// [AppBar]; pair with `extendBodyBehindAppBar: true` on scrolling screens.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.bottom,
    this.automaticallyImplyLeading = true,
    this.centerTitle,
    this.backgroundColor,
    this.foregroundColor,
  });

  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final bool automaticallyImplyLeading;
  final bool? centerTitle;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final opaque = MediaQuery.of(context).highContrast;
    final bg = backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;
    final base =
        backgroundColor != null && backgroundColor != Colors.transparent
        ? backgroundColor!
        : (dark ? AppColors.dBg : AppColors.lBg);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: opaque ? 0 : 20,
          sigmaY: opaque ? 0 : 20,
        ),
        child: Container(
          decoration: BoxDecoration(
            // Scroll-edge effect: strongest at the status bar, thinning toward
            // the content so the bar reads as a pane of glass, not a slab.
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: opaque
                  ? [bg, bg]
                  : [
                      base.withValues(alpha: 0.92),
                      base.withValues(alpha: 0.72),
                    ],
            ),
            border: Border(
              bottom: BorderSide(
                color: (dark ? Colors.white : Colors.black).withValues(
                  alpha: dark ? 0.08 : 0.06,
                ),
                width: 0.6,
              ),
            ),
          ),
          child: AppBar(
            title: title,
            actions: actions,
            leading: leading,
            bottom: bottom,
            automaticallyImplyLeading: automaticallyImplyLeading,
            centerTitle: centerTitle,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            foregroundColor: foregroundColor,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
        ),
      ),
    );
  }
}

/// Inset, floating glass sheet (iOS 26 style) with a drag handle. Use via
/// [showGlassSheet] so the barrier/background are set up correctly.
class GlassSheet extends StatelessWidget {
  const GlassSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 20),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(10, 0, 10, bottom > 0 ? bottom : 12),
      child: Glass(
        radius: 32,
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Presents [child] inside a [GlassSheet]. Returns whatever the sheet pops.
Future<T?> showGlassSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    useSafeArea: true,
    builder: (ctx) => GlassSheet(child: Builder(builder: builder)),
  );
}

/// Ambient ground for the tab shell: the app background with two very soft
/// light sources, so there is something for the glass layer to refract. Kept
/// static (no animation) — it is painted once and cached.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? AppColors.dBg : AppColors.lBg;
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(color: bg),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _glow(
              const Alignment(-1.1, -0.9),
              AppColors.accent,
              dark ? 0.16 : 0.12,
              1.2,
            ),
            _glow(
              const Alignment(1.2, 0.2),
              AppColors.accent2,
              dark ? 0.08 : 0.08,
              1.0,
            ),
            _glow(
              const Alignment(0.2, 1.3),
              AppColors.blue,
              dark ? 0.07 : 0.06,
              1.1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _glow(Alignment at, Color c, double a, double r) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: at,
        radius: r,
        colors: [
          c.withValues(alpha: a),
          c.withValues(alpha: 0),
        ],
      ),
    ),
  );
}
