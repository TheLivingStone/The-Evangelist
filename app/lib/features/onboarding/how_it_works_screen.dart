import 'package:flutter/material.dart';

import '../../core/glass.dart';
import '../../core/theme.dart';

/// One step of the tour: the button or screen, and what to do with it.
class GuideStep {
  const GuideStep({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.button,
  });

  final IconData icon;
  final Color color;
  final String title;

  /// Plain-language instruction, one or two sentences.
  final String body;

  /// The exact label of the button / screen this step points at, if any.
  final String? button;
}

/// A seven-step tour of the app's buttons and what they do. Shown once right
/// after onboarding, and always available from Profile → "How Go and Tell
/// works".
class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key, this.firstRun = false});

  /// True when pushed automatically after onboarding: the close button reads
  /// "Let's go" instead of "Got it".
  final bool firstRun;

  static const steps = <GuideStep>[
    GuideStep(
      icon: Icons.add_circle,
      color: AppColors.accent,
      title: 'Tap the orange + button',
      button: 'Log what happened today',
      body:
          'It sits at the bottom right of every tab. Tap it any time you have '
          'shared your faith and pick what happened.',
    ),
    GuideStep(
      icon: Icons.chat_bubble,
      color: AppColors.green,
      title: 'Log a conversation or a prayer',
      button: 'Log Conversation · Log Prayer',
      body:
          'One tap saves it to your record and your streak. Nothing else to '
          'fill in unless you want to.',
    ),
    GuideStep(
      icon: Icons.person_add,
      color: AppColors.blue,
      title: 'Save the person you met',
      button: 'Add Person',
      body:
          'Add their name, where you met and how the conversation went, so you '
          'can pray for them and follow up later.',
    ),
    GuideStep(
      icon: Icons.people,
      color: AppColors.purple,
      title: 'Follow up from My People',
      button: 'My People',
      body:
          'Everyone you have saved lives here. Open a person to log a '
          'follow-up, mark a decision, or note when they connect to a church.',
    ),
    GuideStep(
      icon: Icons.auto_awesome,
      color: AppColors.pink,
      title: 'Share a testimony',
      button: 'Create Testimony Post',
      body:
          'Post what God did in the Community tab, and encourage others by '
          'reacting to and commenting on their stories.',
    ),
    GuideStep(
      icon: Icons.church,
      color: AppColors.accent,
      title: 'See the map and the churches',
      button: 'Map · Find & register churches',
      body:
          'The Map tab shows people evangelising near you and church icons '
          'for churches taking part. Join your home church there, or register '
          'it so our team can verify it.',
    ),
    GuideStep(
      icon: Icons.person,
      color: AppColors.green,
      title: 'Your profile and privacy',
      button: 'Profile',
      body:
          'Your streak and totals live here, along with "Show me on the map", '
          '"Share new contacts with my church", reminders and the theme.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: Text('How it works')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          Dims.gutter(context),
          inset.top + kToolbarHeight + Dims.m,
          Dims.gutter(context),
          inset.bottom + Dims.l,
        ),
        children: [
          Text(
            'Seven steps, one habit',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'You can explore everything as a guest. The first time you save '
            'something, we ask you to create an account with Apple, Google or '
            'email so nothing is lost.',
            style: TextStyle(fontSize: 13, color: Dims.muted(context)),
          ),
          const SizedBox(height: Dims.l),
          for (var i = 0; i < steps.length; i++) ...[
            _StepCard(index: i + 1, step: steps[i]),
            const SizedBox(height: Dims.s),
          ],
          const SizedBox(height: Dims.m),
          SizedBox(
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(
                firstRun ? "Let's go" : 'Got it',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.index, required this.step});
  final int index;
  final GuideStep step;

  @override
  Widget build(BuildContext context) {
    return Surfaces.card(
      context,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The button itself, drawn the way it appears in the app.
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: step.color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(
                color: step.color.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Icon(step.icon, color: step.color, size: 22),
          ),
          const SizedBox(width: Dims.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STEP $index',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: step.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (step.button != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    step.button!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Dims.muted(context),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(step.body, style: const TextStyle(fontSize: 13.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
