import 'package:flutter/material.dart';
import '../../core/brand.dart';
import '../../core/theme.dart';

/// Branded loading screen shown while the session / profile load on cold
/// start. Deliberately matches LaunchScreen.storyboard (same dark ground, same
/// centred logo) so the native launch image appears to "come alive" rather
/// than cutting to a blank screen, and the wait reads as intentional.
class BrandSplash extends StatelessWidget {
  const BrandSplash({super.key, this.message = 'Preparing your mission…'});

  /// Small status line under the progress bar.
  final String message;

  @override
  Widget build(BuildContext context) {
    // Always dark, regardless of theme, so it is pixel-continuous with the
    // storyboard that precedes it.
    return Scaffold(
      backgroundColor: Colors.black,
      // No SafeArea here on purpose. On one physical iPhone the lockup rendered
      // shifted to the left third of the screen while every simulator centred
      // it — consistent with the device reporting an unexpected horizontal
      // inset. Centring inside a full-size Stack ignores insets entirely (the
      // lockup is in the middle of the screen, well clear of any notch), and
      // the metrics are logged so a device console shows what iOS reported.
      body: LayoutBuilder(
        builder: (context, constraints) {
          final mq = MediaQuery.of(context);
          debugPrint(
            '[startup] splash box=${constraints.biggest} size=${mq.size} '
            'padding=${mq.padding} viewPadding=${mq.viewPadding} '
            'textScale=${mq.textScaler.scale(1).toStringAsFixed(2)}',
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 48),
                  child: BrandLockup(boltHeight: 230, pulse: true),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: mq.viewPadding.bottom + Dims.xxl,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 140,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: const LinearProgressIndicator(
                          minHeight: 3,
                          color: AppColors.accent,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                    ),
                    const SizedBox(height: Dims.m),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
