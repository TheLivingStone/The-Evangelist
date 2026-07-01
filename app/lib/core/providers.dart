import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

// Raw Supabase auth event stream. The underlying BehaviorSubject replays the
// latest state to new listeners, so late subscribers (and the cold-start gate)
// immediately see the current session. In demo mode (backend disabled) Supabase
// is never initialised, so emit nothing rather than touching Supabase.instance.
final authStateProvider = StreamProvider<AuthState>((ref) {
  if (!Env.backendEnabled) return const Stream.empty();
  return supabase.auth.onAuthStateChange;
});

// The signed-in user's id (uuid), or null. Derived from the auth stream, with a
// synchronous fallback so there is no null flash on the first frame. Null in
// demo mode (no Supabase instance to read).
final currentUserIdProvider = Provider<String?>((ref) {
  if (!Env.backendEnabled) return null;
  ref.watch(authStateProvider);
  return supabase.auth.currentUser?.id;
});

// Auth-change signal: per-user providers watch this so cached data drops when
// the user changes. It DERIVES from the user id, so it changes only on sign in
// / out / account switch — token refreshes (same id) cause no churn. No manual
// invalidation needed anywhere.
final authChangedProvider = Provider<Object>((ref) {
  return ref.watch(currentUserIdProvider) ?? const _SignedOut();
});

class _SignedOut {
  const _SignedOut();
}

// Current profile. The profiles row is created DB-side by the handle_new_user
// trigger on signup; ensure() just reads it (see ProfileRepo.ensure).
final myProfileProvider = FutureProvider<Profile?>((ref) async {
  ref.watch(authChangedProvider);
  final repo = ref.read(profileRepoProvider);
  if (!Env.backendEnabled) return repo.me();
  if (currentUserId == null) return null;
  return repo.ensure();
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

// Another user's public profile, by id — used by the map's tap-to-reveal card.
// profiles are world-readable to authenticated users (RLS: select using true),
// so this works for any evangelist shown on the map. Cached per id.
final publicProfileProvider = FutureProvider.family<Profile?, String>((
  ref,
  userId,
) async {
  if (userId.isEmpty) return null;
  try {
    return await ref.read(profileRepoProvider).byId(userId);
  } catch (_) {
    return null; // tolerate a missing/unreadable profile — card falls back
  }
});

// The current user's home-church membership (null if they haven't joined one).
final myMembershipProvider = FutureProvider<ChurchMembership?>((ref) {
  ref.watch(authChangedProvider);
  return ref.read(churchesRepoProvider).myMembership();
});

// Members (pending first) of a church the current user manages.
final churchMembersProvider =
    FutureProvider.family<List<ChurchMemberRequest>, String>((ref, churchId) {
  ref.watch(authChangedProvider);
  return ref.read(churchesRepoProvider).memberRequests(churchId);
});

// Contacts shared with a church the current user manages.
final churchSharedContactsProvider =
    FutureProvider.family<List<ChurchSharedContact>, String>((ref, churchId) {
  ref.watch(authChangedProvider);
  return ref.read(churchesRepoProvider).sharedContacts(churchId);
});
