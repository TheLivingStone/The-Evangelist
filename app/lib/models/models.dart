// Plain Dart models mirroring the Postgres tables (see docs/02-data-model.md).

DateTime? _date(dynamic v) => v == null ? null : DateTime.parse(v.toString());

class Profile {
  final String id;
  final String fullName;
  final String? username;
  final String? city;
  final String? church;
  final String? ministry;
  final String? bio;
  final String? avatarUrl;
  final bool isVisibleOnMap;
  final bool dailyReminderEnabled;
  final String theme;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastEvangelismDate;
  final int weeklyGoal;
  final int totalConversations;
  final int totalSalvations;
  final int totalFollowups;
  final int totalChurchConnections;

  Profile({
    required this.id,
    required this.fullName,
    this.username,
    this.city,
    this.church,
    this.ministry,
    this.bio,
    this.avatarUrl,
    this.isVisibleOnMap = true,
    this.dailyReminderEnabled = true,
    this.theme = 'dark',
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastEvangelismDate,
    this.weeklyGoal = 5,
    this.totalConversations = 0,
    this.totalSalvations = 0,
    this.totalFollowups = 0,
    this.totalChurchConnections = 0,
  });

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'],
        fullName: m['full_name'] ?? 'Evangelist',
        username: m['username'],
        city: m['city'],
        church: m['church'],
        ministry: m['ministry'],
        bio: m['bio'],
        avatarUrl: m['avatar_url'],
        isVisibleOnMap: m['is_visible_on_map'] ?? true,
        dailyReminderEnabled: m['daily_reminder_enabled'] ?? true,
        theme: m['theme'] ?? 'dark',
        currentStreak: m['current_streak'] ?? 0,
        longestStreak: m['longest_streak'] ?? 0,
        lastEvangelismDate: _date(m['last_evangelism_date']),
        weeklyGoal: m['weekly_goal'] ?? 5,
        totalConversations: m['total_conversations'] ?? 0,
        totalSalvations: m['total_salvations'] ?? 0,
        totalFollowups: m['total_followups'] ?? 0,
        totalChurchConnections: m['total_church_connections'] ?? 0,
      );
}

const spiritualStatuses = [
  'new_contact',
  'accepted_christ',
  'followup_started',
  'connected_to_church',
  'active',
];

String prettyStatus(String s) => switch (s) {
      'new_contact' => 'New Contact',
      'accepted_christ' => 'Accepted Christ',
      'followup_started' => 'Follow-Up Started',
      'connected_to_church' => 'Connected to Church',
      'active' => 'Active',
      _ => s,
    };

class Contact {
  final String id;
  final String ownerId;
  final String firstName;
  final String? lastName;
  final String? phone;
  final String? email;
  final String? city;
  final String? metLocation;
  final DateTime dateMet;
  final String status;
  final String? notes;
  final DateTime? nextFollowupAt;
  final List<String> tags;

  Contact({
    required this.id,
    required this.ownerId,
    required this.firstName,
    this.lastName,
    this.phone,
    this.email,
    this.city,
    this.metLocation,
    required this.dateMet,
    this.status = 'new_contact',
    this.notes,
    this.nextFollowupAt,
    this.tags = const [],
  });

  String get displayName =>
      [firstName, lastName].where((e) => e != null && e.isNotEmpty).join(' ');

  factory Contact.fromMap(Map<String, dynamic> m) => Contact(
        id: m['id'],
        ownerId: m['owner_id'],
        firstName: m['first_name'],
        lastName: m['last_name'],
        phone: m['phone'],
        email: m['email'],
        city: m['city'],
        metLocation: m['met_location'],
        dateMet: _date(m['date_met']) ?? DateTime.now(),
        status: m['status'] ?? 'new_contact',
        notes: m['notes'],
        nextFollowupAt: _date(m['next_followup_at']),
        tags: (m['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      );
}

class ActivityLog {
  final String id;
  final String userId;
  final String type;
  final String? contactId;
  final String? sessionId;
  final String? note;
  final DateTime occurredAt;

  ActivityLog({
    required this.id,
    required this.userId,
    required this.type,
    this.contactId,
    this.sessionId,
    this.note,
    required this.occurredAt,
  });

  factory ActivityLog.fromMap(Map<String, dynamic> m) => ActivityLog(
        id: m['id'],
        userId: m['user_id'],
        type: m['type'],
        contactId: m['contact_id'],
        sessionId: m['session_id'],
        note: m['note'],
        occurredAt: _date(m['occurred_at']) ?? DateTime.now(),
      );
}

class OutreachSession {
  final String id;
  final String userId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final String? locationName;
  final int conversationsCount;
  final int prayersCount;
  final int peopleAddedCount;
  final String status;

  OutreachSession({
    required this.id,
    required this.userId,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds,
    this.locationName,
    this.conversationsCount = 0,
    this.prayersCount = 0,
    this.peopleAddedCount = 0,
    this.status = 'live',
  });

  factory OutreachSession.fromMap(Map<String, dynamic> m) => OutreachSession(
        id: m['id'],
        userId: m['user_id'],
        startedAt: _date(m['started_at']) ?? DateTime.now(),
        endedAt: _date(m['ended_at']),
        durationSeconds: m['duration_seconds'],
        locationName: m['location_name'],
        conversationsCount: m['conversations_count'] ?? 0,
        prayersCount: m['prayers_count'] ?? 0,
        peopleAddedCount: m['people_added_count'] ?? 0,
        status: m['status'] ?? 'live',
      );
}

class Post {
  final String id;
  final String authorId;
  final String type;
  final String body;
  final String? photoUrl;
  final String? city;
  final DateTime createdAt;
  final Profile? author;
  final Map<String, int> reactionCounts;
  final Set<String> myReactions;

  Post({
    required this.id,
    required this.authorId,
    required this.type,
    required this.body,
    this.photoUrl,
    this.city,
    required this.createdAt,
    this.author,
    this.reactionCounts = const {},
    this.myReactions = const {},
  });

  factory Post.fromMap(Map<String, dynamic> m) => Post(
        id: m['id'],
        authorId: m['author_id'],
        type: m['type'] ?? 'testimony',
        body: m['body'] ?? '',
        photoUrl: m['photo_url'],
        city: m['city'],
        createdAt: _date(m['created_at']) ?? DateTime.now(),
        author: m['profiles'] != null
            ? Profile.fromMap(Map<String, dynamic>.from(m['profiles']))
            : null,
      );

  Post copyWith({Map<String, int>? reactionCounts, Set<String>? myReactions}) =>
      Post(
        id: id,
        authorId: authorId,
        type: type,
        body: body,
        photoUrl: photoUrl,
        city: city,
        createdAt: createdAt,
        author: author,
        reactionCounts: reactionCounts ?? this.reactionCounts,
        myReactions: myReactions ?? this.myReactions,
      );
}

class Achievement {
  final String key;
  final String name;
  final String? description;
  final String? icon;
  final bool earned;
  Achievement({
    required this.key,
    required this.name,
    this.description,
    this.icon,
    this.earned = false,
  });
}

class Verse {
  final String id;
  final String text;
  final String reference;
  final String? theme;
  Verse({required this.id, required this.text, required this.reference, this.theme});
  factory Verse.fromMap(Map<String, dynamic> m) => Verse(
        id: m['id'],
        text: m['text'],
        reference: m['reference'],
        theme: m['theme'],
      );
}

class NearbyEvangelist {
  final String userId;
  final String fullName;
  final double distanceM;
  NearbyEvangelist({
    required this.userId,
    required this.fullName,
    required this.distanceM,
  });
  factory NearbyEvangelist.fromMap(Map<String, dynamic> m) => NearbyEvangelist(
        userId: m['user_id'],
        fullName: m['full_name'] ?? 'Evangelist',
        distanceM: (m['distance_m'] as num?)?.toDouble() ?? 0,
      );
}
