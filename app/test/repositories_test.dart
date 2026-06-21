import 'package:flutter_test/flutter_test.dart';
import 'package:the_evangelist/repositories/repositories.dart';

void main() {
  setUp(resetLocalData);

  test('profile reads and updates', () async {
    final repo = ProfileRepo();
    expect((await repo.me())!.fullName, 'Evangelist');

    await repo.update({'full_name': 'Updated', 'theme': 'light'});

    final profile = await repo.me();
    expect(profile!.fullName, 'Updated');
    expect(profile.theme, 'light');
    expect((await repo.byId('local-user')).fullName, 'Updated');
  });

  test('activities update counts, streak, and recent history', () async {
    final repo = ActivityRepo();
    await repo.log('conversation', note: 'First');
    await repo.log('salvation');
    await repo.log('followup');
    await repo.log('church_connection');

    expect(await repo.monthCounts(), {
      'conversation': 1,
      'salvation': 1,
      'followup': 1,
      'church_connection': 1,
    });
    expect(await repo.daysActiveThisWeek(), 1);
    expect((await repo.recent(limit: 2)), hasLength(2));
    final profile = await ProfileRepo().me();
    expect(profile!.currentStreak, 1);
    expect(profile.totalConversations, 1);
    expect(profile.totalSalvations, 1);
    expect(profile.totalFollowups, 1);
    expect(profile.totalChurchConnections, 1);
  });

  test(
    'contacts support add, filter, due ordering, update, and delete',
    () async {
      final repo = ContactsRepo();
      final later = DateTime.now().subtract(const Duration(hours: 1));
      final earlier = DateTime.now().subtract(const Duration(days: 2));
      final first = await repo.add({
        'first_name': 'Later',
        'status': 'active',
        'next_followup_at': later.toIso8601String(),
      });
      await repo.add({
        'first_name': 'Earlier',
        'status': 'new_contact',
        'next_followup_at': earlier.toIso8601String(),
      });

      expect(await repo.list(), hasLength(2));
      expect(await repo.list(statusFilter: 'active'), hasLength(1));
      expect((await repo.dueFollowups()).first.firstName, 'Earlier');

      await repo.update(first.id, {'status': 'connected_to_church'});
      expect(
        (await repo.list(statusFilter: 'connected_to_church')).single.id,
        first.id,
      );
      await repo.delete(first.id);
      expect(await repo.list(), hasLength(1));
    },
  );

  test('sessions resume and end with activity fan-out', () async {
    final repo = SessionsRepo();
    final session = await repo.start(locationName: 'Downtown');
    expect((await repo.start()).id, session.id);
    expect((await repo.live())!.locationName, 'Downtown');

    await repo.end(session.id, conversations: 2, prayers: 1, peopleAdded: 1);

    expect(await repo.live(), isNull);
    final recent = await ActivityRepo().recent();
    expect(recent.where((a) => a.type == 'conversation'), hasLength(2));
    expect(recent.where((a) => a.type == 'prayer'), hasLength(1));
  });

  test('feed supports create, filtering, and reaction toggles', () async {
    final repo = FeedRepo();
    final post = await repo.create('testimony', 'A testimony');
    await repo.create('prayer', 'Please pray');

    expect(await repo.feed(), hasLength(2));
    expect(await repo.feed(type: 'testimony'), hasLength(1));

    await repo.toggleReaction(post.id, 'encouraged', true);
    var updated = (await repo.feed(type: 'testimony')).single;
    expect(updated.myReactions, contains('encouraged'));
    expect(updated.reactionCounts['encouraged'], 1);

    await repo.toggleReaction(post.id, 'encouraged', false);
    updated = (await repo.feed(type: 'testimony')).single;
    expect(updated.myReactions, isNot(contains('encouraged')));
    expect(updated.reactionCounts['encouraged'], 0);
  });

  test('map, achievements, and encouragement have local fallbacks', () async {
    expect(await MapRepo().nearbyEvangelists(0, 0), isEmpty);
    expect((await MapRepo().areaStats(0, 0))['evangelists'], 0);
    expect(await AchievementsRepo().all(), isNotEmpty);
    expect((await EncouragementRepo().randomVerse())!.reference, 'Mark 16:15');
  });
}
