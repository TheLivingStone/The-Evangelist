import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth_account.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';
import '../dashboard/dashboard_screen.dart';
import '../community/community_screen.dart';
import '../map/map_screen.dart';
import '../profile/profile_screen.dart';
import 'start_sheet.dart';

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
      builder: (_) => const StartSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: List.generate(
          _screens.length,
          (i) => _loadedTabs.contains(i)
              ? RepaintBoundary(child: _screens[i])
              : const SizedBox.shrink(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openStart,
        backgroundColor: AppColors.accent,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
      // Drop the button down so it sits level with the nav icons rather than
      // floating high over the notch. _DockedDown nudges the standard docked
      // anchor downward; pair it with a small notchMargin below.
      floatingActionButtonLocation: const _DockedDown(),
      bottomNavigationBar: BottomAppBar(
        // Grow the bar with the user's text size so the icon+label column never
        // overflows (the default 64 overflowed at larger Dynamic Type sizes).
        height: 58 + 14 * MediaQuery.textScalerOf(context).scale(1),
        padding: EdgeInsets.zero,
        shape: const CircularNotchedRectangle(),
        notchMargin: 5,
        color: Theme.of(context).colorScheme.surface,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(0, Icons.dashboard_outlined, Icons.dashboard, 'Home'),
            _navItem(1, Icons.groups_outlined, Icons.groups, 'Community'),
            const SizedBox(width: 40),
            _navItem(3, Icons.map_outlined, Icons.map, 'Map'),
            _navItem(4, Icons.person_outline, Icons.person, 'Profile'),
          ],
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
        borderRadius: BorderRadius.circular(12),
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

/// Centre-docked FAB nudged downward so it rests level with the bottom-nav
/// icons instead of floating high over the notch. Delegates horizontal centring
/// to the standard docked location and only shifts the vertical anchor down.
class _DockedDown extends FloatingActionButtonLocation {
  const _DockedDown();

  /// How far below the standard docked position to drop the button.
  static const double _dropY = 18;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final base = FloatingActionButtonLocation.centerDocked.getOffset(
      scaffoldGeometry,
    );
    // Clamp so the button can never sink below the screen on short bars.
    final maxY =
        scaffoldGeometry.scaffoldSize.height -
        scaffoldGeometry.floatingActionButtonSize.height;
    return Offset(base.dx, (base.dy + _dropY).clamp(0.0, maxY));
  }
}
