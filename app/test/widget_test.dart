import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:the_evangelist/core/providers.dart';
import 'package:the_evangelist/core/theme.dart';
import 'package:the_evangelist/features/community/community_screen.dart';
import 'package:the_evangelist/features/map/map_screen.dart';
import 'package:the_evangelist/features/profile/profile_screen.dart';
import 'package:the_evangelist/main.dart';
import 'package:the_evangelist/models/models.dart';
import 'package:the_evangelist/repositories/repositories.dart';

class _DelayedFeedRepo extends FeedRepo {
  final saved = Completer<void>();

  @override
  Future<void> toggleReaction(String postId, String reaction, bool on) =>
      saved.future;
}

class _DelayedProfileRepo extends ProfileRepo {
  var profile = Profile(id: 'local-user', fullName: 'Evangelist');
  final saved = Completer<void>();

  @override
  Future<Profile?> me() async => profile;

  @override
  Future<void> update(Map<String, dynamic> patch) async {
    await saved.future;
    profile = Profile.fromMap({
      'id': profile.id,
      'full_name': profile.fullName,
      'theme': patch['theme'] ?? profile.theme,
      'is_visible_on_map': profile.isVisibleOnMap,
      'daily_reminder_enabled': profile.dailyReminderEnabled,
    });
  }
}

class _DelayedSessionsRepo extends SessionsRepo {
  final started = Completer<OutreachSession>();

  @override
  Future<OutreachSession> start({String? locationName}) => started.future;
}

class _CountingFeedRepo extends FeedRepo {
  int calls = 0;

  @override
  Future<List<Post>> feed({String? type}) async {
    calls++;
    return [
      Post(
        id: 'testimony',
        authorId: 'local-user',
        type: 'testimony',
        body: 'Testimony',
        createdAt: DateTime.now(),
      ),
      Post(
        id: 'prayer',
        authorId: 'local-user',
        type: 'prayer',
        body: 'Prayer',
        createdAt: DateTime.now(),
      ),
    ];
  }
}

void main() {
  setUp(resetLocalData);

  testWidgets('App theme builds and renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: Center(child: Text('The Evangelist'))),
      ),
    );
    expect(find.text('The Evangelist'), findsOneWidget);
  });

  testWidgets('Local mode opens the app without authentication', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScopedApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('Hi, Evangelist'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Community'), findsOneWidget);
  });

  test('Feed filters share one repository request', () async {
    final repo = _CountingFeedRepo();
    final container = ProviderContainer(
      overrides: [feedRepoProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final results = await Future.wait([
      container.read(feedProvider(null).future),
      container.read(feedProvider('testimony').future),
      container.read(feedProvider('prayer').future),
    ]);

    expect(repo.calls, 1);
    expect(results[0], hasLength(2));
    expect(results[1].single.type, 'testimony');
    expect(results[2].single.type, 'prayer');
  });

  testWidgets('Tabs stay lazy while shared feed data prefetches', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScopedApp());
    await tester.pumpAndSettle();

    expect(find.byType(CommunityScreen, skipOffstage: false), findsNothing);
    expect(find.byType(MapScreen, skipOffstage: false), findsNothing);
    expect(find.byType(ProfileScreen, skipOffstage: false), findsNothing);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityScreen, skipOffstage: false), findsNothing);
    expect(find.byType(MapScreen, skipOffstage: false), findsNothing);
    expect(find.byType(ProfileScreen, skipOffstage: false), findsNothing);

    await tester.tap(find.text('Community'));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityScreen), findsOneWidget);
  });

  testWidgets('Reaction feedback does not wait for persistence', (
    tester,
  ) async {
    final repo = _DelayedFeedRepo();
    final post = Post(
      id: 'post-1',
      authorId: 'local-user',
      type: 'testimony',
      body: 'Testimony',
      createdAt: DateTime.now(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [feedRepoProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Scaffold(body: PostCard(post: post)),
        ),
      ),
    );

    await tester.tap(find.text('🔥 Encouraged'));
    await tester.pump();

    expect(repo.saved.isCompleted, isFalse);
    expect(find.text('🔥 Encouraged 1'), findsOneWidget);

    repo.saved.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('Theme feedback does not wait for persistence', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _DelayedProfileRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileRepoProvider.overrideWithValue(repo)],
        child: const EvangelistApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, 'Dark theme'));
    await tester.pump();

    expect(repo.saved.isCompleted, isFalse);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );

    repo.saved.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('Starting a session shows immediate feedback', (tester) async {
    final repo = _DelayedSessionsRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionsRepoProvider.overrideWithValue(repo)],
        child: const EvangelistApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Outreach Session'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Starting outreach...'), findsOneWidget);
    repo.started.complete(
      OutreachSession(
        id: 'session-1',
        userId: 'local-user',
        startedAt: DateTime.now(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Outreach Live'), findsOneWidget);
  });

  testWidgets('Start sheet opens a live outreach session', (tester) async {
    await tester.pumpWidget(const ProviderScopedApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Outreach Session'));
    await tester.pumpAndSettle();

    expect(find.text('Outreach Live'), findsOneWidget);
    expect(find.text('End Session'), findsOneWidget);
  });

  testWidgets('Quick logging refreshes dashboard and confirms success', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScopedApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log Conversation'));
    await tester.pumpAndSettle();

    expect(find.text('Conversation logged - keep going!'), findsOneWidget);
    expect(find.text('1 day streak'), findsOneWidget);
  });

  testWidgets('A person can be added and appears in My People', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ProviderScopedApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Person'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'First name *'),
      'Jordan',
    );
    await tester.tap(find.text('Save Person'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My People'));
    await tester.pumpAndSettle();

    expect(find.text('Jordan'), findsOneWidget);
  });

  testWidgets('Map renders interactive tiles and location control', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: MapScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byTooltip('Use my location'), findsOneWidget);
    expect(find.byType(RichAttributionWidget), findsOneWidget);
    expect(find.textContaining('Add a Google Maps key'), findsNothing);
  });
}
