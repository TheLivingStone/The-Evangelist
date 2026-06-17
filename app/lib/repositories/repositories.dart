import '../core/supabase.dart';
import '../models/models.dart';

/// Repositories wrap all Postgrest/RPC access. UI never touches Supabase directly.

class ProfileRepo {
  Future<Profile?> me() async {
    final uid = currentUserId;
    if (uid == null) return null;
    final row =
        await supabase.from('profiles').select().eq('id', uid).maybeSingle();
    return row == null ? null : Profile.fromMap(row);
  }

  Future<Profile> byId(String id) async {
    final row = await supabase.from('profiles').select().eq('id', id).single();
    return Profile.fromMap(row);
  }

  Future<void> update(Map<String, dynamic> patch) async {
    await supabase.from('profiles').update(patch).eq('id', currentUserId!);
  }
}

class ActivityRepo {
  /// Insert an atomic activity log. The DB trigger updates stats + streak.
  Future<void> log(String type, {String? contactId, String? sessionId, String? note}) async {
    await supabase.from('activity_logs').insert({
      'user_id': currentUserId,
      'type': type,
      if (contactId != null) 'contact_id': contactId,
      if (sessionId != null) 'session_id': sessionId,
      if (note != null) 'note': note,
    });
  }

  Future<List<ActivityLog>> recent({int limit = 20}) async {
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
    final start = DateTime.now().copyWith(day: 1, hour: 0, minute: 0, second: 0);
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
    var q = supabase.from('contacts').select().eq('owner_id', currentUserId!);
    if (statusFilter != null) q = q.eq('status', statusFilter);
    final rows = await q.order('next_followup_at', ascending: true, nullsFirst: false);
    return rows.map<Contact>((e) => Contact.fromMap(e)).toList();
  }

  Future<List<Contact>> dueFollowups({int limit = 3}) async {
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
    final row = await supabase
        .from('contacts')
        .insert({...data, 'owner_id': currentUserId})
        .select()
        .single();
    return Contact.fromMap(row);
  }

  Future<void> update(String id, Map<String, dynamic> patch) async {
    await supabase.from('contacts').update(patch).eq('id', id);
  }

  Future<void> delete(String id) async {
    await supabase.from('contacts').delete().eq('id', id);
  }
}

class SessionsRepo {
  Future<OutreachSession?> live() async {
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
    final existing = await live();
    if (existing != null) return existing; // resume, never double-start
    final row = await supabase
        .from('outreach_sessions')
        .insert({
          'user_id': currentUserId,
          'status': 'live',
          if (locationName != null) 'location_name': locationName,
        })
        .select()
        .single();
    return OutreachSession.fromMap(row);
  }

  /// Atomic server-side fan-out: writes counters + activity_logs + clears presence.
  Future<void> end(String sessionId,
      {int conversations = 0, int prayers = 0, int peopleAdded = 0}) async {
    await supabase.rpc('end_session', params: {
      'p_session_id': sessionId,
      'p_conversations': conversations,
      'p_prayers': prayers,
      'p_people_added': peopleAdded,
    });
  }
}

class FeedRepo {
  Future<List<Post>> feed({String? type}) async {
    var q = supabase.from('posts').select('*, profiles!posts_author_id_fkey(*)');
    if (type != null) q = q.eq('type', type);
    final rows = await q.order('created_at', ascending: false).limit(50);
    final posts = rows.map<Post>((e) => Post.fromMap(e)).toList();
    return _hydrateReactions(posts);
  }

  Future<List<Post>> _hydrateReactions(List<Post> posts) async {
    if (posts.isEmpty) return posts;
    final ids = posts.map((p) => p.id).toList();
    final reactions = await supabase
        .from('post_reactions')
        .select('post_id, reaction, user_id')
        .inFilter('post_id', ids);
    final counts = <String, Map<String, int>>{};
    final mine = <String, Set<String>>{};
    final uid = currentUserId;
    for (final r in reactions) {
      final pid = r['post_id'] as String;
      final rx = r['reaction'] as String;
      counts.putIfAbsent(pid, () => {});
      counts[pid]![rx] = (counts[pid]![rx] ?? 0) + 1;
      if (r['user_id'] == uid) {
        mine.putIfAbsent(pid, () => {}).add(rx);
      }
    }
    return posts
        .map((p) => p.copyWith(
              reactionCounts: counts[p.id] ?? {},
              myReactions: mine[p.id] ?? {},
            ))
        .toList();
  }

  Future<Post> create(String type, String body, {String? city}) async {
    final row = await supabase
        .from('posts')
        .insert({
          'author_id': currentUserId,
          'type': type,
          'body': body,
          if (city != null) 'city': city,
        })
        .select('*, profiles!posts_author_id_fkey(*)')
        .single();
    return Post.fromMap(row);
  }

  Future<void> toggleReaction(String postId, String reaction, bool on) async {
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

class MapRepo {
  Future<List<NearbyEvangelist>> nearbyEvangelists(double lat, double lng,
      {int radius = 5000}) async {
    final rows = await supabase.rpc('nearby_evangelists',
        params: {'lat': lat, 'lng': lng, 'radius_m': radius});
    return (rows as List)
        .map((e) => NearbyEvangelist.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Map<String, dynamic>> areaStats(double lat, double lng,
      {int radius = 5000}) async {
    final rows = await supabase.rpc('area_stats',
        params: {'lat': lat, 'lng': lng, 'radius_m': radius});
    final list = rows as List;
    return list.isEmpty ? {} : Map<String, dynamic>.from(list.first);
  }

  /// Upsert this user's live presence (durable backing for the map RPC).
  Future<void> updatePresence(double lat, double lng, String sessionId) async {
    await supabase.from('live_presence').upsert({
      'user_id': currentUserId,
      'location': 'POINT($lng $lat)',
      'is_evangelizing': true,
      'session_id': sessionId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'expires_at':
          DateTime.now().toUtc().add(const Duration(minutes: 5)).toIso8601String(),
    });
  }
}

class AchievementsRepo {
  Future<List<Achievement>> all() async {
    final catalog = await supabase
        .from('achievements')
        .select()
        .order('sort_order', ascending: true);
    final earned = await supabase
        .from('user_achievements')
        .select('achievement_key')
        .eq('user_id', currentUserId!);
    final earnedKeys =
        earned.map<String>((e) => e['achievement_key'] as String).toSet();
    return catalog
        .map<Achievement>((m) => Achievement(
              key: m['key'],
              name: m['name'],
              description: m['description'],
              icon: m['icon'],
              earned: earnedKeys.contains(m['key']),
            ))
        .toList();
  }
}

class EncouragementRepo {
  Future<Verse> randomVerse() async {
    final rows = await supabase.from('verses').select();
    final list = rows.toList()..shuffle();
    return Verse.fromMap(list.first);
  }
}
