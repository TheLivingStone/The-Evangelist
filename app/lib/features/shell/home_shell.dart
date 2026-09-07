import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth_account.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';
import '../dashboard/dashboard_screen.dart';
import '../community/community_screen.dart';
import '../map/map_screen.dart';
import '../profile/profile_screen.dart';
import 'start_sheet.dart';
import '../../core/coach_marks.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});
  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  final _loadedTabs = <int>{0};
  Timer? _prefetchTimer;

  static const _screens = [
    DashboardScreen(),
    CommunityScreen(),
    SizedBox.shrink(), // placeholder for the center FAB slot
    MapScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Let the dashboard paint first, then warm only the shared feed data. Avoid
    // constructing three offstage screens and all their network requests.
    _prefetchTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      ref.read(allFeedProvider.future).ignore();
    });
    // First-run coach mark on the one button that matters. Shows once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      CoachMarks.show(
        context,
        id: 'plus',
        target: CoachTargets.plusButton,
        title: 'Start here',
        text:
            'Tap + whenever you share your faith: log a conversation or a '
            'prayer, or save the person you met.',
        delay: const Duration(milliseconds: 900),
      );
    });
  }

  @override
  void dispose() {
    _prefetchTimer?.cancel();
    super.dispose();
  }

  void _openStart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => const StartSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      // Tab screens paint on transparent so the ambient ground shows through
      // the glass layer; content scrolls beneath the floating bar.
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AmbientBackground(),
          IndexedStack(
            index: _index,
            children: List.generate(
              _screens.length,
              (i) => _loadedTabs.contains(i)
                  ? RepaintBoundary(child: _screens[i])
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
      // Liquid Glass navigation: a floating capsule tab bar with the primary
      // action as its own button beside it (the iOS 26 tab bar + action
      // button arrangement), lifted off the home indicator.
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          Dims.l,
          Dims.s,
          Dims.l,
          bottomInset > 0 ? bottomInset - 4 : Dims.m,
        ),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Row(
              children: [
                Expanded(
                  child: GlassCapsule(
                    child: SizedBox(
                      height: 60,
                      child: Row(
                        children: [
                          _navItem(
                            0,
                            Icons.dashboard_outlined,
                            Icons.dashboard,
                            'Home',
                          ),
                          _navItem(
                            1,
                            Icons.groups_outlined,
                            Icons.groups,
                            'Community',
                          ),
                          _navItem(3, Icons.map_outlined, Icons.map, 'Map'),
                          _navItem(
                            4,
                            Icons.person_outline,
                            Icons.person,
                            'Profile',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Dims.m),
                _ActionButton(key: CoachTargets.plusButton, onTap: _openStart),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Switch tabs, but gate Profile (index 4) behind a real account — a guest
  /// tapping Profile is prompted to create one first. All other tabs are open.
  Future<void> _selectTab(int i) async {
    if (i == 4 && !await requireAccount(context, ref)) return;
    if (!mounted) return;
    setState(() {
      _index = i;
      _loadedTabs.add(i);
    });
  }

  Widget _navItem(int i, IconData icon, IconData active, String label) {
    final selected = _index == i;
    final color = selected
        ? AppColors.accent
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    // Expanded so the four items share the row evenly and a longer label can
    // never shove its neighbours off-screen.
    return Expanded(
      child: InkWell(
        onTap: () => _selectTab(i),
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? active : icon, color: color, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(color: color, fontSize: 10, height: 1.0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The primary "what happened today?" action: accent glass circle with a soft
/// glow — the one bold moment in the navigation layer.
class _ActionButton extends StatelessWidget {
  const _ActionButton({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Log what happened today',
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.45),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Glass(
          shape: const CircleBorder(),
          tint: AppColors.accent,
          shadow: false,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: const SizedBox(
                width: 60,
                height: 60,
                child: Icon(Icons.add_rounded, color: Colors.white, size: 32),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
