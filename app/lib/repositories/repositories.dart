import 'dart:math' as math;
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../core/supabase.dart';
import '../core/env.dart';
import '../models/models.dart';

/// Repositories wrap all Postgrest/RPC access. UI never touches Supabase directly.

class _LocalStore {
  static Profile profile = Profile(
    id: 'local-user',
    fullName: 'Evangelist',
    city: 'Atlanta',
    currentStreak: 0,
    weeklyGoal: 5,
  );
  static final contacts = <Contact>[];
  static final activities = <ActivityLog>[];
  static final posts = <Post>[];
  static final comments = <Comment>[];
  static final churches = <Church>[];
  static OutreachSession? liveSession;

  static void reset() {
    profile = Profile(
      id: 'local-user',
      fullName: 'Evangelist',
      city: 'Atlanta',
      currentStreak: 0,
      weeklyGoal: 5,
    );
    contacts.clear();
    activities.clear();
    posts.clear();
    comments.clear();
    churches.clear();
    liveSession = null;
  }

  static String id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  static Map<String, dynamic> profileMap(Profile p) => {
    'id': p.id,
    'full_name': p.fullName,
    'username': p.username,
    'city': p.city,
    'church': p.church,
    'ministry': p.ministry,
    'bio': p.bio,
    'avatar_url': p.avatarUrl,
    'is_visible_on_map': p.isVisibleOnMap,
    'daily_reminder_enabled': p.dailyReminderEnabled,
    'theme': p.theme,
    'current_streak': p.currentStreak,
    'longest_streak': p.longestStreak,
    'last_evangelism_date': p.lastEvangelismDate?.toIso8601String(),
    'weekly_goal': p.weeklyGoal,
    'total_conversations': p.totalConversations,
    'total_salvations': p.totalSalvations,
    'total_followups': p.totalFollowups,
    'total_church_connections': p.totalChurchConnections,
  };

  static Map<String, dynamic> contactMap(Contact c) => {
    'id': c.id,
    'owner_id': c.ownerId,
    'first_name': c.firstName,
    'last_name': c.lastName,
    'phone': c.phone,
    'email': c.email,
    'city': c.city,
    'met_location': c.metLocation,
    'date_met': c.dateMet.toIso8601String(),
    'status': c.status,
    'notes': c.notes,
    'next_followup_at': c.nextFollowupAt?.toIso8601String(),
    'tags': c.tags,
  };
}

/// Clears the in-memory demo store. Intended for deterministic local tests.
void resetLocalData() => _LocalStore.reset();

class ProfileRepo {
  Future<Profile?> me() async {
    if (!Env.backendEnabled) return _LocalStore.profile;
    final uid = currentUserId;
    if (uid == null) return null;
    final row = await supabase
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();
    return row == null ? null : Profile.fromMap(row);
  }

  /// Return the current user's profile row, which the database creates for us.
  ///
  /// Identity is Supabase Auth. A SECURITY DEFINER trigger (handle_new_user on
  /// auth.users) inserts the profiles row at signup, copying full_name +
  /// username from the user's metadata (set via signUp(data: {...}) on the auth
  /// screen). The app therefore never inserts profiles itself — there is no
  /// INSERT policy — it just reads the trigger-created row here.
  ///
  /// The trigger runs inside the signup transaction, so the row normally exists
  /// the moment the client has a session. We still retry a few times to cover
  /// any replication lag before surfacing a clear error.
  Future<Profile> ensure() async {
    if (!Env.backendEnabled) return _LocalStore.profile;
    for (var attempt = 0; attempt < 3; attempt++) {
      final existing = await me();
      if (existing != null) return existing;
      await Future.delayed(const Duration(milliseconds: 350));
    }
    throw StateError('Your profile is still being set up. Please try again.');
  }

  Future<Profile> byId(String id) async {
    if (!Env.backendEnabled) return _LocalStore.profile;
    final row = await supabase.from('profiles').select().eq('id', id).single();
    return Profile.fromMap(row);
  }

  Future<void> update(Map<String, dynamic> patch) async {
    if (!Env.backendEnabled) {
      _LocalStore.profile = Profile.fromMap({
        ..._LocalStore.profileMap(_LocalStore.profile),
        ...patch,
      });
      return;
    }
    await supabase.from('profiles').update(patch).eq('id', currentUserId!);
  }

  /// Permanently delete the signed-in user's account and all their data.
  ///
  /// Calls the `delete-account` Edge Function, which verifies the caller's JWT
  /// and deletes their auth.users row server-side (the service-role key never
  /// touches the client). Every table cascades from auth.users, so all of the
  /// user's data goes with it. After this returns, the caller must sign out.
  ///
  /// Required by Apple App Store Guideline 5.1.1(v).
  Future<void> deleteAccount() async {
    if (!Env.backendEnabled) {
      _LocalStore.reset();
      return;
    }
    final res = await supabase.functions.invoke('delete-account');
    // supabase_flutter throws FunctionException on non-2xx, so reaching here is
    // success. Defensively surface an explicit error payload if one came back.
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error'].toString());
    }
  }
}

class ActivityRepo {
  /// Insert an atomic activity log. The DB trigger updates stats + streak.
  Future<void> log(
    String type, {
    String? contactId,
    String? sessionId,
    String? note,
  }) async {
    if (!Env.backendEnabled) {
      _LocalStore.activities.insert(
        0,
        ActivityLog(
          id: _LocalStore.id('activity'),
          userId: _LocalStore.profile.id,
          type: type,
          contactId: contactId,
          sessionId: sessionId,
          note: note,
          occurredAt: DateTime.now(),
        ),
      );
      final p = _LocalStore.profile;
      _LocalStore.profile = Profile.fromMap({
        ..._LocalStore.profileMap(p),
        'last_evangelism_date': DateTime.now().toIso8601String(),
        'current_streak': p.currentStreak == 0 ? 1 : p.currentStreak,
        'longest_streak': p.longestStreak == 0 ? 1 : p.longestStreak,
        'total_conversations':
            p.totalConversations + (type == 'conversation' ? 1 : 0),
        'total_salvations': p.totalSalvations + (type == 'salvation' ? 1 : 0),
        'total_followups': p.totalFollowups + (type == 'followup' ? 1 : 0),
        'total_church_connections':
            p.totalChurchConnections + (type == 'church_connection' ? 1 : 0),
      });
      return;
    }
    await supabase.from('activity_logs').insert({
      'user_id': currentUserId,
      'type': type,
      'contact_id': ?contactId,
      'session_id': ?sessionId,
      'note': ?note,
    });
  }

  Future<List<ActivityLog>> recent({int limit = 20}) async {
    if (!Env.backendEnabled) return _LocalStore.activities.take(limit).toList();
    final rows = await supabase
        .from('activity_logs')
        .select()
        .eq('user_id', currentUserId!)
        .order('occurred_at', ascending: false)
        .limit(limit);
    return rows.map<ActivityLog>((e) => ActivityLog.fromMap(e)).toList();
  }

  /// Count of activity logs this calendar month, grouped by type.
  Future<Map<String, int>> monthCounts() async {
    if (!Env.backendEnabled) {
      final now = DateTime.now();
      final out = <String, int>{};
      for (final activity in _LocalStore.activities) {
        if (activity.occurredAt.year != now.year ||
            activity.occurredAt.month != now.month) {
          continue;
        }
        out[activity.type] = (out[activity.type] ?? 0) + 1;
      }
      return out;
    }
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final rows = await supabase
        .from('activity_logs')
        .select('type')
        .eq('user_id', currentUserId!)
        .gte('occurred_at', start.toUtc().toIso8601String());
    final out = <String, int>{};
    for (final r in rows) {
      final t = r['type'] as String;
      out[t] = (out[t] ?? 0) + 1;
    }
    return out;
  }

  /// Distinct days with activity in the current week (Mon-Sun).
  Future<int> daysActiveThisWeek() async {
    if (!Env.backendEnabled) {
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final start = DateTime(monday.year, monday.month, monday.day);
      return _LocalStore.activities
          .where((a) => !a.occurredAt.isBefore(start))
          .map(
            (a) =>
                '${a.occurredAt.year}-${a.occurredAt.month}-${a.occurredAt.day}',
          )
          .toSet()
          .length;
    }
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(monday.year, monday.month, monday.day);
    final rows = await supabase
        .from('activity_logs')
        .select('occurred_at')
        .eq('user_id', currentUserId!)
        .gte('occurred_at', start.toUtc().toIso8601String());
    final days = <String>{};
    for (final r in rows) {
      final d = DateTime.parse(r['occurred_at']).toLocal();
      days.add('${d.year}-${d.month}-${d.day}');
    }
    return days.length;
  }
}

class ContactsRepo {
  Future<List<Contact>> list({String? statusFilter}) async {
    if (!Env.backendEnabled) {
      final contacts = statusFilter == null
          ? _LocalStore.contacts
          : _LocalStore.contacts.where((c) => c.status == statusFilter);
      return contacts.toList();
    }
    var q = supabase.from('contacts').select().eq('owner_id', currentUserId!);
    if (statusFilter != null) q = q.eq('status', statusFilter);
    final rows = await q.order(
      'next_followup_at',
      ascending: true,
      nullsFirst: false,
    );
    return rows.map<Contact>((e) => Contact.fromMap(e)).toList();
  }

  Future<List<Contact>> dueFollowups({int limit = 3}) async {
    if (!Env.backendEnabled) {
      final now = DateTime.now();
      final due =
          _LocalStore.contacts
              .where(
                (c) =>
                    c.nextFollowupAt != null && !c.nextFollowupAt!.isAfter(now),
              )
              .toList()
            ..sort((a, b) => a.nextFollowupAt!.compareTo(b.nextFollowupAt!));
      return due.take(limit).toList();
    }
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await supabase
        .from('contacts')
        .select()
        .eq('owner_id', currentUserId!)
        .lte('next_followup_at', today)
        .order('next_followup_at', ascending: true)
        .limit(limit);
    return rows.map<Contact>((e) => Contact.fromMap(e)).toList();
  }

  Future<Contact> add(Map<String, dynamic> data) async {
    if (!Env.backendEnabled) {
      final contact = Contact.fromMap({
        ...data,
        'id': _LocalStore.id('contact'),
        'owner_id': _LocalStore.profile.id,
        'date_met': DateTime.now().toIso8601String(),
      });
      _LocalStore.contacts.insert(0, contact);
      return contact;
    }
    final row = await supabase
        .from('contacts')
        .insert({...data, 'owner_id': currentUserId})
        .select()
        .single();
    return Contact.fromMap(row);
  }

  Future<void> update(String id, Map<String, dynamic> patch) async {
    if (!Env.backendEnabled) {
      final index = _LocalStore.contacts.indexWhere((c) => c.id == id);
      if (index >= 0) {
        _LocalStore.contacts[index] = Contact.fromMap({
          ..._LocalStore.contactMap(_LocalStore.contacts[index]),
          ...patch,
        });
      }
      return;
    }
    await supabase.from('contacts').update(patch).eq('id', id);
  }

  Future<void> delete(String id) async {
    if (!Env.backendEnabled) {
      _LocalStore.contacts.removeWhere((c) => c.id == id);
      return;
    }
    await supabase.from('contacts').delete().eq('id', id);
  }
}

class SessionsRepo {
  Future<OutreachSession?> live() async {
    if (!Env.backendEnabled) return _LocalStore.liveSession;
    final row = await supabase
        .from('outreach_sessions')
        .select()
        .eq('user_id', currentUserId!)
        .eq('status', 'live')
        .order('started_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : OutreachSession.fromMap(row);
  }

  Future<OutreachSession> start({String? locationName}) async {
    if (!Env.backendEnabled) {
      return _LocalStore.liveSession ??= OutreachSession(
        id: _LocalStore.id('session'),
        userId: _LocalStore.profile.id,
        startedAt: DateTime.now(),
        locationName: locationName,
      );
    }
    final existing = await live();
    if (existing != null) return existing; // resume, never double-start
    final row = await supabase
        .from('outreach_sessions')
        .insert({
          'user_id': currentUserId,
          'status': 'live',
          'location_name': ?locationName,
        })
        .select()
        .single();
    return OutreachSession.fromMap(row);
  }

  /// Atomic server-side fan-out: writes counters + activity_logs + clears presence.
  Future<void> end(
    String sessionId, {
    int conversations = 0,
    int prayers = 0,
    int peopleAdded = 0,
  }) async {
    if (!Env.backendEnabled) {
      final activityRepo = ActivityRepo();
      for (var i = 0; i < conversations; i++) {
        await activityRepo.log('conversation', sessionId: sessionId);
      }
      for (var i = 0; i < prayers; i++) {
        await activityRepo.log('prayer', sessionId: sessionId);
      }
      _LocalStore.liveSession = null;
      return;
    }
    await supabase.rpc(
      'end_session',
      params: {
        'p_session_id': sessionId,
        'p_conversations': conversations,
        'p_prayers': prayers,
        'p_people_added': peopleAdded,
      },
    );
  }
}

class FeedRepo {
  Future<List<Post>> feed({String? type}) async {
    if (!Env.backendEnabled) {
      return (type == null
              ? _LocalStore.posts
              : _LocalStore.posts.where((p) => p.type == type))
          .toList();
    }
    var q = supabase
        .from('posts')
        .select(
          'id,author_id,type,body,photo_url,city,created_at,'
          'profiles!posts_author_id_fkey('
          'id,full_name,city,church,ministry,avatar_url)',
        );
    if (type != null) q = q.eq('type', type);
    final rows = await q.order('created_at', ascending: false).limit(50);
    final posts = rows.map<Post>((e) => Post.fromMap(e)).toList();
    return _hydrate(posts);
  }

  /// Attaches reaction counts, the caller's own reactions, and comment counts
  /// to a page of posts in a single fan-out of queries.
  Future<List<Post>> _hydrate(List<Post> posts) async {
    if (posts.isEmpty) return posts;
    final ids = posts.map((p) => p.id).toList();
    final uid = currentUserId!;
    final results = await Future.wait([
      supabase
          .from('post_reaction_counts')
          .select('post_id, reaction, cnt')
          .inFilter('post_id', ids),
      supabase
          .from('post_reactions')
          .select('post_id, reaction')
          .eq('user_id', uid)
          .inFilter('post_id', ids),
      supabase
          .from('post_comment_counts')
          .select('post_id, cnt')
          .inFilter('post_id', ids),
    ]);
    final counts = <String, Map<String, int>>{};
    final mine = <String, Set<String>>{};
    final commentCounts = <String, int>{};
    for (final r in results[0]) {
      final pid = r['post_id'] as String;
      final rx = r['reaction'] as String;
      counts.putIfAbsent(pid, () => {});
      counts[pid]![rx] = r['cnt'] as int;
    }
    for (final r in results[1]) {
      final pid = r['post_id'] as String;
      final rx = r['reaction'] as String;
      mine.putIfAbsent(pid, () => {}).add(rx);
    }
    for (final r in results[2]) {
      commentCounts[r['post_id'] as String] = r['cnt'] as int;
    }
    return posts
        .map(
          (p) => p.copyWith(
            reactionCounts: counts[p.id] ?? {},
            myReactions: mine[p.id] ?? {},
            commentCount: commentCounts[p.id] ?? 0,
          ),
        )
        .toList();
  }

  Future<Post> create(
    String type,
    String body, {
    String? city,
    String? photoUrl,
  }) async {
    if (!Env.backendEnabled) {
      final post = Post(
        id: _LocalStore.id('post'),
        authorId: _LocalStore.profile.id,
        type: type,
        body: body,
        photoUrl: photoUrl,
        city: city ?? _LocalStore.profile.city,
        createdAt: DateTime.now(),
        author: _LocalStore.profile,
      );
      _LocalStore.posts.insert(0, post);
      return post;
    }
    final row = await supabase
        .from('posts')
        .insert({
          'author_id': currentUserId,
          'type': type,
          'body': body,
          'city': ?city,
          'photo_url': ?photoUrl,
        })
        .select(
          'id,author_id,type,body,photo_url,city,created_at,'
          'profiles!posts_author_id_fkey('
          'id,full_name,city,church,ministry,avatar_url)',
        )
        .single();
    return Post.fromMap(row);
  }

  /// Uploads a post photo to the public 'post-photos' bucket under the
  /// caller's user folder and returns its public URL. The bucket + RLS are
  /// created by migrate_feed_comments_photos.sql.
  Future<String> uploadPostPhoto(
    Uint8List bytes, {
    String contentType = 'image/jpeg',
    String ext = 'jpg',
  }) async {
    final uid = currentUserId!;
    final path =
        '$uid/${DateTime.now().microsecondsSinceEpoch}.$ext';
    await supabase.storage
        .from('post-photos')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    return supabase.storage.from('post-photos').getPublicUrl(path);
  }

  Future<void> toggleReaction(String postId, String reaction, bool on) async {
    if (!Env.backendEnabled) {
      final index = _LocalStore.posts.indexWhere((p) => p.id == postId);
      if (index < 0) return;
      final post = _LocalStore.posts[index];
      final mine = {...post.myReactions};
      final counts = {...post.reactionCounts};
      if (on) {
        mine.add(reaction);
        counts[reaction] = (counts[reaction] ?? 0) + 1;
      } else {
        mine.remove(reaction);
        counts[reaction] = ((counts[reaction] ?? 1) - 1).clamp(0, 1 << 30);
      }
      _LocalStore.posts[index] = post.copyWith(
        reactionCounts: counts,
        myReactions: mine,
      );
      return;
    }
    if (on) {
      await supabase.from('post_reactions').upsert({
        'post_id': postId,
        'user_id': currentUserId,
        'reaction': reaction,
      });
    } else {
      await supabase
          .from('post_reactions')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', currentUserId!)
          .eq('reaction', reaction);
    }
  }
}

class CommentsRepo {
  Future<List<Comment>> list(String postId) async {
    if (!Env.backendEnabled) {
      return _LocalStore.comments
          .where((c) => c.postId == postId)
          .toList(growable: false);
    }
    final rows = await supabase
        .from('comments')
        .select(
          'id,post_id,author_id,body,created_at,'
          'profiles!comments_author_id_fkey('
          'id,full_name,city,church,ministry,avatar_url)',
        )
        .eq('post_id', postId)
        .order('created_at', ascending: true);
    return rows.map<Comment>((e) => Comment.fromMap(e)).toList();
  }

  Future<Comment> add(String postId, String body) async {
    if (!Env.backendEnabled) {
      final comment = Comment(
        id: _LocalStore.id('comment'),
        postId: postId,
        authorId: _LocalStore.profile.id,
        body: body,
        createdAt: DateTime.now(),
        author: _LocalStore.profile,
      );
      _LocalStore.comments.add(comment);
      return comment;
    }
    final row = await supabase
        .from('comments')
        .insert({'post_id': postId, 'author_id': currentUserId, 'body': body})
        .select(
          'id,post_id,author_id,body,created_at,'
          'profiles!comments_author_id_fkey('
          'id,full_name,city,church,ministry,avatar_url)',
        )
        .single();
    return Comment.fromMap(row);
  }
}

class MapRepo {
  Future<List<NearbyEvangelist>> nearbyEvangelists(
    double lat,
    double lng, {
    int radius = 5000,
  }) async {
    if (!Env.backendEnabled) return _demoNearby(lat, lng);
    final rows = await supabase.rpc(
      'nearby_evangelists',
      params: {'lat': lat, 'lng': lng, 'radius_m': radius},
    );
    return (rows as List)
        .map((e) => NearbyEvangelist.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Map<String, dynamic>> areaStats(
    double lat,
    double lng, {
    int radius = 5000,
  }) async {
    if (!Env.backendEnabled) {
      final near = _demoNearby(lat, lng);
      return {
        'evangelists': near.length,
        'outreaches_today': near.length + 4,
        'churches_nearby': 6,
      };
    }
    final rows = await supabase.rpc(
      'area_stats',
      params: {'lat': lat, 'lng': lng, 'radius_m': radius},
    );
    final list = rows as List;
    return list.isEmpty ? {} : Map<String, dynamic>.from(list.first);
  }

  /// Deterministic demo evangelists scattered ~1-4 km around [lat]/[lng].
  /// Used only in local mode (BACKEND_ENABLED=false) so the map is alive
  /// without a backend. Offsets are fixed (no RNG) so pins don't jump on
  /// every rebuild. ~111 km per degree of latitude is close enough here.
  static List<NearbyEvangelist> _demoNearby(double lat, double lng) {
    const seeds = <(String, double, double)>[
      ('Grace M.', 0.012, 0.008),
      ('David O.', -0.009, 0.014),
      ('Sarah K.', 0.018, -0.011),
      ('Joshua T.', -0.015, -0.006),
      ('Esther N.', 0.006, 0.020),
    ];
    final cosLat = math.cos(lat * math.pi / 180).abs().clamp(0.2, 1.0);
    return [
      for (final (name, dLat, dLng) in seeds)
        NearbyEvangelist.fromMap({
          'user_id': 'demo-${name.hashCode}',
          'full_name': name,
          'approx_lat': lat + dLat,
          'approx_lng': lng + dLng,
          'distance_m': (math.sqrt(dLat * dLat + dLng * dLng) * 111000 / cosLat)
              .roundToDouble(),
        }),
    ];
  }

  /// Upsert this user's live presence (durable backing for the map RPC).
  Future<void> updatePresence(double lat, double lng, String sessionId) async {
    if (!Env.backendEnabled) return;
    await supabase.from('live_presence').upsert({
      'user_id': currentUserId,
      'location': 'POINT($lng $lat)',
      'is_evangelizing': true,
      'session_id': sessionId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'expires_at': DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 5))
          .toIso8601String(),
    });
  }
}

class ChurchesRepo {
  /// Churches near a point (public directory). Returns verified + pending.
  Future<List<Church>> nearby(double lat, double lng, {int radius = 8000}) async {
    if (!Env.backendEnabled) {
      return _LocalStore.churches;
    }
    final rows = await supabase.rpc(
      'nearby_churches',
      params: {'lat': lat, 'lng': lng, 'radius_m': radius},
    );
    return (rows as List)
        .map((e) => Church.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Register a NEW church at [lat]/[lng], claimed by the current user. The
  /// church starts unverified + pending review (an owner vets it before it is
  /// shown as trusted). Returns the new church id.
  Future<String> register({
    required String name,
    required double lat,
    required double lng,
    String? address,
    String? city,
    String? serviceTimes,
    String? website,
    String? statement,
    String? claimantName,
    String? claimantRole,
    String? claimantPhone,
    String? claimantEmail,
  }) async {
    if (!Env.backendEnabled) {
      final church = Church(
        id: _LocalStore.id('church'),
        name: name,
        city: city,
        address: address,
        serviceTimes: serviceTimes,
        website: website,
        isVerified: false,
        claimStatus: 'pending',
        latitude: lat,
        longitude: lng,
      );
      _LocalStore.churches.insert(0, church);
      return church.id;
    }
    final id = await supabase.rpc(
      'register_church',
      params: {
        'p_name': name,
        'p_lat': lat,
        'p_lng': lng,
        'p_address': address,
        'p_city': city,
        'p_service_times': serviceTimes,
        'p_website': website,
        'p_statement': statement,
        'p_claimant_name': claimantName,
        'p_claimant_role': claimantRole,
        'p_claimant_phone': claimantPhone,
        'p_claimant_email': claimantEmail,
      },
    );
    return id.toString();
  }

  /// Claim an EXISTING church (a pastor requesting to manage a listing). Sets
  /// it back to pending for owner review.
  Future<void> claim({
    required String churchId,
    required String claimantName,
    required String claimantRole,
    String? claimantPhone,
    String? claimantEmail,
    String? message,
  }) async {
    if (!Env.backendEnabled) return;
    await supabase.rpc(
      'claim_church',
      params: {
        'p_church_id': churchId,
        'p_claimant_name': claimantName,
        'p_claimant_role': claimantRole,
        'p_claimant_phone': claimantPhone,
        'p_claimant_email': claimantEmail,
        'p_message': message,
      },
    );
  }

  // ---- Church membership (members ↔ churches) ------------------------------

  /// The current user marks a directory church as their home church. Creates a
  /// PENDING membership the church manager then confirms. One home church only.
  Future<void> joinChurch(String churchId) async {
    if (!Env.backendEnabled) return;
    await supabase.rpc('join_church', params: {'p_church_id': churchId});
  }

  /// Leave the current home church.
  Future<void> leaveChurch() async {
    if (!Env.backendEnabled) return;
    await supabase.rpc('leave_church');
  }

  /// What church (if any) the current user belongs to, and whether it's
  /// confirmed yet. Null when they haven't joined one.
  Future<ChurchMembership?> myMembership() async {
    if (!Env.backendEnabled) return null;
    final rows = await supabase.rpc('my_church_membership');
    final list = (rows as List?) ?? const [];
    if (list.isEmpty) return null;
    return ChurchMembership.fromMap(Map<String, dynamic>.from(list.first));
  }

  /// Members (pending first) for a church the current user MANAGES. Empty if
  /// the caller isn't the church's claimant.
  Future<List<ChurchMemberRequest>> memberRequests(String churchId) async {
    if (!Env.backendEnabled) return const [];
    final rows = await supabase.rpc(
      'church_member_requests',
      params: {'p_church_id': churchId},
    );
    return ((rows as List?) ?? const [])
        .map((e) => ChurchMemberRequest.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Church manager confirms a pending member.
  Future<void> confirmMember(String membershipId) async {
    if (!Env.backendEnabled) return;
    await supabase.rpc('confirm_member', params: {'p_membership_id': membershipId});
  }

  /// Church manager removes a member.
  Future<void> removeMember(String membershipId) async {
    if (!Env.backendEnabled) return;
    await supabase.rpc('remove_member', params: {'p_membership_id': membershipId});
  }
}

class AchievementsRepo {
  Future<List<Achievement>> all() async {
    if (!Env.backendEnabled) {
      return [
        Achievement(key: 'first_step', name: 'First Step', icon: '🔥'),
        Achievement(key: 'faithful', name: 'Faithful', icon: '🏅'),
        Achievement(key: 'encourager', name: 'Encourager', icon: '🙏'),
      ];
    }
    final results = await Future.wait([
      supabase
          .from('achievements')
          .select()
          .order('sort_order', ascending: true),
      supabase
          .from('user_achievements')
          .select('achievement_key')
          .eq('user_id', currentUserId!),
    ]);
    final catalog = results[0];
    final earned = results[1];
    final earnedKeys = earned
        .map<String>((e) => e['achievement_key'] as String)
        .toSet();
    return catalog
        .map<Achievement>(
          (m) => Achievement(
            key: m['key'],
            name: m['name'],
            description: m['description'],
            icon: m['icon'],
            earned: earnedKeys.contains(m['key']),
          ),
        )
        .toList();
  }
}

class EncouragementRepo {
  Future<Verse?> randomVerse() async {
    if (!Env.backendEnabled) {
      return Verse(
        id: 'local-verse',
        text:
            'Go into all the world and proclaim the gospel to the whole creation.',
        reference: 'Mark 16:15',
        theme: 'mission',
      );
    }
    final rows = await supabase.from('verses').select();
    final list = rows.toList()..shuffle();
    if (list.isEmpty) return null;
    return Verse.fromMap(list.first);
  }
}
