import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/brand.dart';
import '../../core/providers.dart';
import '../../core/supabase.dart';
import '../../core/theme.dart';
import '../../models/models.dart';

const _kOnboardingDone = 'onboarding_done_v1';

/// True when the first-run flow should be shown: the profile still carries a
/// placeholder name (the DB falls back to 'Evangelist', guests seed 'Guest',
/// and Apple only ever sends a name on the very first authorisation) AND the
/// user has not dismissed onboarding on this device.
final needsOnboardingProvider = FutureProvider<bool>((ref) async {
  final profile = await ref.watch(myProfileProvider.future);
  if (profile == null || profile.hasRealName) return false;
  final prefs = await SharedPreferences.getInstance();
  return !(prefs.getBool(_kOnboardingDone) ?? false);
});

Future<void> _markOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingDone, true);
}

/// Cinematic first run: a black stage, the bolt breathing behind everything,
/// two Scripture "calls" that reveal line by line, then name and weekly goal.
/// Always dark regardless of the user's theme. Works for guests; everything
/// typed here is saved to their profile row.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _pages = 6;
  final _page = PageController();
  final _name = TextEditingController();
  final _city = TextEditingController();
  int _index = 0;
  int _goal = 5;
  bool _busy = false;

  @override
  void dispose() {
    _page.dispose();
    _name.dispose();
    _city.dispose();
    super.dispose();
  }

  void _go(int i) {
    HapticFeedback.lightImpact();
    _page.animateToPage(
      i,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _skip() async {
    await _markOnboardingDone();
    if (!mounted) return;
    ref.invalidate(needsOnboardingProvider);
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    final name = _name.text.trim();
    final city = _city.text.trim();
    try {
      final patch = <String, dynamic>{'weekly_goal': _goal};
      if (name.isNotEmpty) patch['full_name'] = name;
      if (city.isNotEmpty) patch['city'] = city;
      await ref.read(profileRepoProvider).update(patch);
      if (name.isNotEmpty) {
        try {
          await supabase.auth.updateUser(
            UserAttributes(data: {'full_name': name}),
          );
        } catch (_) {
          /* best-effort; the profile row is the source of truth */
        }
      }
      await _markOnboardingDone();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ref.invalidate(myProfileProvider);
      ref.invalidate(needsOnboardingProvider);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save: $error')));
    }
  }

  String get _cta => switch (_index) {
    0 => 'Begin',
    1 => "I'm ready",
    2 => "Let's make it count",
    3 => 'Align with the Kingdom',
    4 => 'Continue',
    _ => 'Start my mission',
  };

  @override
  Widget build(BuildContext context) {
    // Force the dark palette so inputs/buttons match the black stage even for
    // light-theme users.
    return Theme(
      data: AppTheme.dark,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _Stage(),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 44,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _index < _pages - 1
                              ? TextButton(
                                  onPressed: _busy ? null : _skip,
                                  child: const Text(
                                    'Skip',
                                    style: TextStyle(color: Colors.white38),
                                  ),
                                )
                              : null,
                        ),
                      ),
                      Expanded(
                        child: PageView(
                          controller: _page,
                          physics: const NeverScrollableScrollPhysics(),
                          onPageChanged: (i) => setState(() => _index = i),
                          children: [
                            _Welcome(active: _index == 0),
                            _Verse(
                              active: _index == 1,
                              reference: 'MATTHEW 9:37–38',
                              lines: const [
                                'Then he said to his disciples,',
                                '“The harvest is plentiful,',
                                'but the laborers are few;',
                                'therefore pray earnestly to the Lord of the '
                                    'harvest to send out laborers into his '
                                    'harvest.”',
                              ],
                              reflection: null,
                              call: 'Are you ready to be an answered prayer?',
                            ),
                            _Verse(
                              active: _index == 2,
                              reference: 'MARK 16:15–16',
                              lines: const [
                                'And He said to them,',
                                '“Go into all the world and preach the gospel '
                                    'to every creature.',
                                'He who believes and is baptized will be saved; '
                                    'but he who does not believe will be '
                                    'condemned.”',
                              ],
                              reflection:
                                  'Evangelism is an instrument to preach the '
                                  'Gospel. Every day we meet people — we might be '
                                  'the only Bible, and the only introduction to '
                                  'Jesus, they ever see.',
                              call: "So let's make it count.",
                            ),
                            _Verse(
                              active: _index == 3,
                              reference: 'MATTHEW 6:20–21',
                              lines: const [
                                '“But lay up for yourselves treasures in heaven, '
                                    'where neither moth nor rust destroys and '
                                    'where thieves do not break in and steal.',
                                'For where your treasure is, there your heart '
                                    'will be also.”',
                              ],
                              reflection:
                                  'For those who love God, evangelism is '
                                  'non-negotiable. We are not of this world — so '
                                  'let us align with the Kingdom of God and turn '
                                  'our attention from money, selfish gain and the '
                                  'distractions of this world. In our Kingdom, '
                                  'souls are the ultimate treasure: one soul '
                                  'causes a feast in heaven and brings joy to God.',
                              call: 'Store up riches in heaven.',
                            ),
                            _NameCity(
                              active: _index == 4,
                              name: _name,
                              city: _city,
                            ),
                            _Goal(
                              active: _index == 5,
                              goal: _goal,
                              onChanged: (g) {
                                HapticFeedback.selectionClick();
                                setState(() => _goal = g);
                              },
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Dims.xxl,
                          Dims.m,
                          Dims.xxl,
                          Dims.xl,
                        ),
                        child: Column(
                          children: [
                            _Dots(count: _pages, index: _index),
                            const SizedBox(height: Dims.l),
                            SizedBox(
                              height: 52,
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _busy
                                    ? null
                                    : () => _index < _pages - 1
                                          ? _go(_index + 1)
                                          : _finish(),
                                child: _busy
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        _cta,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The stage: black, with a slow-breathing ember glow low on the screen and a
/// soft vignette at the top so the status bar area never feels flat.
class _Stage extends StatefulWidget {
  const _Stage();
  @override
  State<_Stage> createState() => _StageState();
}

class _StageState extends State<_Stage> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOutSine.transform(_c.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, 1.15 - 0.08 * t),
              radius: 1.05 + 0.15 * t,
              colors: [
                AppColors.accent.withValues(alpha: 0.16 + 0.08 * t),
                AppColors.accent.withValues(alpha: 0.04),
                Colors.black,
              ],
              stops: const [0, 0.35, 1],
            ),
          ),
        );
      },
    );
  }
}

/// Staggers its children in: each fades up from 18px below, one after the
/// other, when [active] first becomes true. Re-runs every time the page is
/// shown so going back and forth still feels alive.
class _Reveal extends StatefulWidget {
  const _Reveal({
    required this.active,
    required this.children,
    this.stagger = const Duration(milliseconds: 420),
    this.each = const Duration(milliseconds: 900),
  });
  final bool active;
  final List<Widget> children;
  final Duration stagger;
  final Duration each;
  static const initialDelay = Duration(milliseconds: 250);

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  Duration get _total =>
      _Reveal.initialDelay +
      widget.stagger * (widget.children.length - 1) +
      widget.each;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: _total);
    if (widget.active) _c.forward();
  }

  @override
  void didUpdateWidget(_Reveal old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = _total.inMilliseconds.toDouble();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          _fadeUp(
            i,
            (_Reveal.initialDelay + widget.stagger * i).inMilliseconds /
                totalMs,
            (_Reveal.initialDelay + widget.stagger * i + widget.each)
                    .inMilliseconds /
                totalMs,
          ),
      ],
    );
  }

  Widget _fadeUp(int i, double start, double end) {
    final anim = CurvedAnimation(
      parent: _c,
      curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - anim.value)),
          child: child,
        ),
      ),
      child: widget.children[i],
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dims.xxl),
      child: Center(
        child: _Reveal(
          active: active,
          stagger: const Duration(milliseconds: 600),
          children: const [
            BrandLockup(boltHeight: 210, pulse: true),
            SizedBox(height: Dims.xxl),
            Text(
              'Every conversation counts.\nLet\'s keep track of them.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A Scripture "call": reference overline, the verse revealed line by line in
/// a serif face, an optional reflection, then the call-to-action in orange.
class _Verse extends StatelessWidget {
  const _Verse({
    required this.active,
    required this.reference,
    required this.lines,
    required this.reflection,
    required this.call,
  });
  final bool active;
  final String reference;
  final List<String> lines;
  final String? reflection;
  final String call;

  static const _serif = TextStyle(
    fontFamily: 'Georgia',
    fontFamilyFallback: ['Times New Roman', 'serif'],
    fontStyle: FontStyle.italic,
    fontSize: 22,
    height: 1.4,
    color: Colors.white,
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: Dims.xxl),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: Dims.xl),
              _Reveal(
                active: active,
                children: [
                  Text(
                    reference,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: Dims.l),
                  for (final line in lines) ...[
                    Text(line, style: _serif),
                    const SizedBox(height: 10),
                  ],
                  if (reflection != null) ...[
                    const SizedBox(height: Dims.l),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 28,
                        height: 2,
                        color: AppColors.accent.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: Dims.l),
                    Text(
                      reflection!,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.55,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                  const SizedBox(height: Dims.xl),
                  Text(
                    call,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Dims.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _NameCity extends StatelessWidget {
  const _NameCity({
    required this.active,
    required this.name,
    required this.city,
  });
  final bool active;
  final TextEditingController name;
  final TextEditingController city;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: Dims.xxl),
      child: _Reveal(
        active: active,
        stagger: const Duration(milliseconds: 250),
        each: const Duration(milliseconds: 600),
        children: [
          const SizedBox(height: Dims.xl),
          const Text(
            'What should we call you?',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: Dims.s),
          const Text(
            'Your name appears on your posts and comments. City is optional '
            'and helps you find evangelists and churches nearby.',
            style: TextStyle(fontSize: 14, height: 1.4, color: Colors.white60),
          ),
          const SizedBox(height: Dims.xl),
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: Dims.m),
          TextField(
            controller: city,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'City (optional)',
              prefixIcon: Icon(Icons.location_city_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _Goal extends StatelessWidget {
  const _Goal({
    required this.active,
    required this.goal,
    required this.onChanged,
  });
  final bool active;
  final int goal;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: Dims.xxl),
      child: _Reveal(
        active: active,
        stagger: const Duration(milliseconds: 220),
        each: const Duration(milliseconds: 600),
        children: [
          const SizedBox(height: Dims.xl),
          const Text(
            'Set your weekly mission',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: Dims.s),
          const Text(
            'How many days a week do you want to share your faith? '
            'You can change this any time.',
            style: TextStyle(fontSize: 14, height: 1.4, color: Colors.white60),
          ),
          const SizedBox(height: Dims.xl),
          for (final (days, label) in const [
            (3, 'Getting started'),
            (5, 'Committed'),
            (7, 'Every single day'),
          ]) ...[
            _GoalTile(
              days: days,
              label: label,
              selected: goal == days,
              onTap: () => onChanged(days),
            ),
            const SizedBox(height: Dims.s),
          ],
        ],
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({
    required this.days,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final int days;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Dims.rMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(
          horizontal: Dims.l,
          vertical: Dims.m,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(Dims.rMd),
          border: Border.all(
            color: selected ? AppColors.accent : Colors.white12,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(
              '$days',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: selected ? AppColors.accent : Colors.white,
              ),
            ),
            const SizedBox(width: Dims.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'days a week',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == index ? AppColors.accent : Colors.white24,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}
