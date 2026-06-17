import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import 'supabase.dart';

// Repositories
final profileRepoProvider = Provider((_) => ProfileRepo());
final activityRepoProvider = Provider((_) => ActivityRepo());
final contactsRepoProvider = Provider((_) => ContactsRepo());
final sessionsRepoProvider = Provider((_) => SessionsRepo());
final feedRepoProvider = Provider((_) => FeedRepo());
final mapRepoProvider = Provider((_) => MapRepo());
final achievementsRepoProvider = Provider((_) => AchievementsRepo());
final encouragementRepoProvider = Provider((_) => EncouragementRepo());

// Auth state stream
final authStateProvider = StreamProvider<AuthState>((ref) {
  return supabase.auth.onAuthStateChange;
});

// Current profile
final myProfileProvider = FutureProvider<Profile?>((ref) async {
  ref.watch(authStateProvider); // refresh on auth change
  return ref.read(profileRepoProvider).me();
});

// Theme mode derived from profile.theme (defaults to dark)
final themeModeProvider = Provider<ThemeMode>((ref) {
  final p = ref.watch(myProfileProvider).value;
  return p?.theme == 'light' ? ThemeMode.light : ThemeMode.dark;
});

// Dashboard data
final monthCountsProvider = FutureProvider<Map<String, int>>((ref) {
  ref.watch(myProfileProvider);
  return ref.read(activityRepoProvider).monthCounts();
});

final weekDaysActiveProvider = FutureProvider<int>((ref) {
  ref.watch(myProfileProvider);
  return ref.read(activityRepoProvider).daysActiveThisWeek();
});

final dueFollowupsProvider = FutureProvider<List<Contact>>((ref) {
  ref.watch(myProfileProvider);
  return ref.read(contactsRepoProvider).dueFollowups();
});

final recentActivityProvider = FutureProvider<List<ActivityLog>>((ref) {
  ref.watch(myProfileProvider);
  return ref.read(activityRepoProvider).recent(limit: 10);
});

// Contacts list, parameterised by status filter
final contactsListProvider =
    FutureProvider.family<List<Contact>, String?>((ref, status) {
  return ref.read(contactsRepoProvider).list(statusFilter: status);
});

// Live session
final liveSessionProvider = FutureProvider<OutreachSession?>((ref) {
  return ref.read(sessionsRepoProvider).live();
});

// Community feed, parameterised by type (null = For You)
final feedProvider = FutureProvider.family<List<Post>, String?>((ref, type) {
  return ref.read(feedRepoProvider).feed(type: type);
});

// Achievements
final achievementsProvider = FutureProvider<List<Achievement>>((ref) {
  return ref.read(achievementsRepoProvider).all();
});
