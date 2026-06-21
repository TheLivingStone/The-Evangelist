import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import 'env.dart';
import 'supabase.dart';

// Repositories
final profileRepoProvider = Provider((_) => ProfileRepo());
final activityRepoProvider = Provider((_) => ActivityRepo());
final contactsRepoProvider = Provider((_) => ContactsRepo());
final sessionsRepoProvider = Provider((_) => SessionsRepo());
final feedRepoProvider = Provider((_) => FeedRepo());
final commentsRepoProvider = Provider((_) => CommentsRepo());
final mapRepoProvider = Provider((_) => MapRepo());
final churchesRepoProvider = Provider((_) => ChurchesRepo());
final achievementsRepoProvider = Provider((_) => AchievementsRepo());
final encouragementRepoProvider = Provider((_) => EncouragementRepo());

// Auth-change signal. Identity is owned by Clerk; the _ClerkBridge in main.dart
// invalidates this whenever Clerk's signed-in user changes. Per-user providers
// watch it so cached data is dropped on sign in/out. The value is irrelevant —
// only the invalidation matters.
final authChangedProvider = Provider<Object>((ref) => Object());

// Current profile. In backend mode this also performs the one-time ensure, so
// the signed-in gate and dashboard share one cached request.
final myProfileProvider = FutureProvider<Profile?>((ref) async {
  ref.watch(authChangedProvider);
  final repo = ref.read(profileRepoProvider);
  if (!Env.backendEnabled) return repo.me();
  if (currentUserId == null) return null;
  return repo.ensure(fullName: clerkAuth?.user?.name ?? '');
});

final ensureProfileProvider = FutureProvider<Profile>((ref) async {
  final profile = await ref.watch(myProfileProvider.future);
  if (profile == null) throw StateError('Signed-in profile is unavailable');
  return profile;
});

// Theme mode derived from profile.theme (defaults to dark)
class ThemeOverride extends Notifier<ThemeMode?> {
  @override
  ThemeMode? build() => null;

  void setMode(ThemeMode? mode) => state = mode;
}

final themeOverrideProvider = NotifierProvider<ThemeOverride, ThemeMode?>(
  ThemeOverride.new,
);

final themeModeProvider = Provider<ThemeMode>((ref) {
  final override = ref.watch(themeOverrideProvider);
  if (override != null) return override;
  final p = ref.watch(myProfileProvider).value;
  return p?.theme == 'light' ? ThemeMode.light : ThemeMode.dark;
});

// Dashboard data
final monthCountsProvider = FutureProvider<Map<String, int>>((ref) {
  ref.watch(authChangedProvider);
  return ref.read(activityRepoProvider).monthCounts();
});

final weekDaysActiveProvider = FutureProvider<int>((ref) {
  ref.watch(authChangedProvider);
  return ref.read(activityRepoProvider).daysActiveThisWeek();
});

final dueFollowupsProvider = FutureProvider<List<Contact>>((ref) {
  ref.watch(authChangedProvider);
  return ref.read(contactsRepoProvider).dueFollowups();
});

final recentActivityProvider = FutureProvider<List<ActivityLog>>((ref) {
  ref.watch(authChangedProvider);
  return ref.read(activityRepoProvider).recent(limit: 10);
});

// Contacts list, parameterised by status filter
final contactsListProvider = FutureProvider.family<List<Contact>, String?>((
  ref,
  status,
) {
  ref.watch(authChangedProvider);
  return ref.read(contactsRepoProvider).list(statusFilter: status);
});

// Live session
final liveSessionProvider = FutureProvider<OutreachSession?>((ref) {
  ref.watch(authChangedProvider);
  return ref.read(sessionsRepoProvider).live();
});

// Fetch and hydrate the community feed once. Filter tabs derive from this
// shared cache instead of issuing their own posts + reactions queries.
final allFeedProvider = FutureProvider<List<Post>>((ref) {
  ref.watch(authChangedProvider);
  return ref.read(feedRepoProvider).feed();
});

final feedProvider = FutureProvider.family<List<Post>, String?>((
  ref,
  type,
) async {
  final posts = await ref.watch(allFeedProvider.future);
  if (type == null) return posts;
  return posts.where((post) => post.type == type).toList(growable: false);
});

// Comment thread for a single post.
final commentsProvider = FutureProvider.family<List<Comment>, String>((
  ref,
  postId,
) {
  ref.watch(authChangedProvider);
  return ref.read(commentsRepoProvider).list(postId);
});

// Achievements
final achievementsProvider = FutureProvider<List<Achievement>>((ref) {
  ref.watch(authChangedProvider);
  return ref.read(achievementsRepoProvider).all();
});
