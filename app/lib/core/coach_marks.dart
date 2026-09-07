import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

/// The real buttons the coach marks point at. Each screen hands its key to the
/// widget it wants explained; the mark is drawn around that widget's exact
/// on-screen rectangle.
class CoachTargets {
  static final plusButton = GlobalKey(debugLabel: 'coach.plus');
  static final logConversation = GlobalKey(debugLabel: 'coach.log');
  static final churchesButton = GlobalKey(debugLabel: 'coach.churches');
  static final composePost = GlobalKey(debugLabel: 'coach.compose');
}

/// One-time callouts pinned to the app's own buttons: a dimmed backdrop with
/// a spotlight on the button and a small box saying what it does. Each mark
/// shows once per install (tracked by [id]) and never stacks with another.
class CoachMarks {
  static const _prefix = 'coach_seen_';
  static bool _showing = false;

  /// Tests and demos: show every mark regardless of what has been seen.
  static bool alwaysShow = false;

  static Future<bool> seen(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefix$id') ?? false;
  }

  static Future<void> markSeen(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$id', true);
  }

  /// Forget every mark so they all show again (Profile → tour, or tests).
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys().where((k) => k.startsWith(_prefix))) {
      await prefs.remove(k);
    }
  }

  /// Show [text] pointing at [target], once per [id]. Waits [delay] so the
  /// screen has settled; quietly does nothing if the target is not on screen.
  static Future<void> show(
    BuildContext context, {
    required String id,
    required GlobalKey target,
    required String text,
    String? title,
    Duration delay = const Duration(milliseconds: 500),
  }) async {
    if (!alwaysShow && await seen(id)) return;
    if (_showing) return;
    await Future<void>.delayed(delay);
    if (!context.mounted || _showing) return;
    final box = target.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;

    _showing = true;
    final done = Completer<void>();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CoachOverlay(
        target: rect,
        title: title,
        text: text,
        onDismiss: () {
          if (done.isCompleted) return;
          entry.remove();
          _showing = false;
          done.complete();
        },
      ),
    );
    overlay.insert(entry);
    await markSeen(id);
    await done.future;
  }
}

class _CoachOverlay extends StatefulWidget {
  const _CoachOverlay({
    required this.target,
    required this.text,
    required this.onDismiss,
    this.title,
  });

  final Rect target;
  final String? title;
  final String text;
  final VoidCallback onDismiss;

  @override
  State<_CoachOverlay> createState() => _CoachOverlayState();
}

class _CoachOverlayState extends State<_CoachOverlay>
    with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final hole = widget.target.inflate(8);
    const margin = 16.0;
    final width = (size.width - margin * 2).clamp(0.0, 320.0);
    final left = (widget.target.center.dx - width / 2).clamp(
      margin,
      size.width - width - margin,
    );
    // Below the button when it sits in the top half, above it otherwise.
    final below = widget.target.center.dy < size.height / 2;
    final arrowX = (widget.target.center.dx - left - 8).clamp(16.0, width - 32);

    return FadeTransition(
      opacity: _fade,
      child: Material(
        color: Colors.transparent,
        child: Semantics(
          label: widget.text,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onDismiss,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _SpotlightPainter(hole)),
                ),
                Positioned(
                  left: left,
                  width: width,
                  top: below ? hole.bottom + 10 : null,
                  bottom: below ? null : size.height - hole.top + 10,
                  child: _Callout(
                    title: widget.title,
                    text: widget.text,
                    arrowX: arrowX,
                    arrowOnTop: below,
                    onGotIt: widget.onDismiss,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dims everything except a rounded window over the target, with an accent
/// ring so the eye lands on the button.
class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter(this.hole);
  final Rect hole;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(hole, const Radius.circular(18));
    final dim = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(r),
    );
    canvas.drawPath(dim, Paint()..color = const Color(0xB3000000));
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.accent,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.hole != hole;
}

class _Callout extends StatelessWidget {
  const _Callout({
    required this.text,
    required this.arrowX,
    required this.arrowOnTop,
    required this.onGotIt,
    this.title,
  });

  final String? title;
  final String text;
  final double arrowX;
  final bool arrowOnTop;
  final VoidCallback onGotIt;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final card = GestureDetector(
      // Taps on the card itself must not fall through to the dismiss layer.
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.accent, width: 1.2),
          boxShadow: const [
            BoxShadow(color: Color(0x80000000), blurRadius: 24),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(text, style: const TextStyle(fontSize: 13.5, height: 1.35)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onGotIt,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text(
                  'Got it',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    // The arrow is a rotated square tucked half under the card's edge: it is
    // painted first, so the card covers its inner half.
    return Padding(
      padding: EdgeInsets.only(
        top: arrowOnTop ? 8 : 0,
        bottom: arrowOnTop ? 0 : 8,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: arrowX,
            top: arrowOnTop ? -8 : null,
            bottom: arrowOnTop ? null : -8,
            child: Transform.rotate(
              angle: 0.785398, // 45°
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: surface,
                  border: Border.all(color: AppColors.accent, width: 1.2),
                ),
              ),
            ),
          ),
          card,
        ],
      ),
    );
  }
}
