import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/domain/log_type.dart';

void main() {
  late AppDatabase db;
  late LogRepository repo;
  late DateTime t;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    t = DateTime.utc(2026, 1, 1);
    repo = LogRepository(db, clock: () => t);
  });
  tearDown(() => db.close());

  Future<String> textAt(DateTime at, [String body = 'x']) {
    t = at;
    return repo.createText(body: body);
  }

  group('watchFeed with a limit', () {
    test('gives the newest logs only, in feed order', () async {
      final ids = [
        for (var i = 0; i < 10; i++) await textAt(DateTime.utc(2026, 1, 1, i)),
      ];
      final page = await repo.watchFeed(limit: 3).first;
      expect(page.map((l) => l.id), ids.reversed.take(3));
    });

    test('a bigger limit is the same list, longer: nothing skipped', () async {
      for (var i = 0; i < 10; i++) {
        await textAt(DateTime.utc(2026, 1, 1)); // all the same moment
      }
      final small = await repo.watchFeed(limit: 4).first;
      final big = await repo.watchFeed(limit: 8).first;
      expect(big.take(4).map((l) => l.id), small.map((l) => l.id));
    });

    test('with types, and never Trash', () async {
      await textAt(DateTime.utc(2026, 1, 1, 1));
      t = DateTime.utc(2026, 1, 1, 2);
      final binned = await repo.createEmoji(emoji: '😌', strength: 3);
      await repo.softDelete(binned);
      t = DateTime.utc(2026, 1, 1, 3);
      await repo.createEmoji(emoji: '🙂', strength: 3);
      final page = await repo.watchFeed(types: {LogType.emoji}, limit: 5).first;
      expect(page.map((l) => (l as EmojiLog).emoji), ['🙂']);
    });

    test('re-emits when a log is added', () async {
      final stream = repo.watchFeed(limit: 2);
      final seen = <int>[];
      final sub = stream.listen((logs) => seen.add(logs.length));
      await pumpEventQueue();
      await textAt(DateTime.utc(2026, 1, 2));
      await pumpEventQueue();
      await sub.cancel();
      expect(seen, [0, 1]);
    });
  });

  group('watchFeedBetween', () {
    test('holds every log whose own day falls in the window', () async {
      // 23:30 on 31 Jan in +05:30 is 18:00 UTC: a January day.
      t = DateTime.utc(2026, 1, 31, 18);
      final jan = await repo.createText(body: 'late January');
      await repo.setCreatedAt(jan, DateTime.utc(2026, 1, 31, 18));
      final feb = await textAt(DateTime.utc(2026, 2, 10));
      await textAt(DateTime.utc(2026, 4, 1)); // outside

      final logs = await repo
          .watchFeedBetween(DateTime.utc(2026, 2, 1), DateTime.utc(2026, 3, 1))
          .first;
      final days = {for (final l in logs) l.id: l.localDay};
      expect(days[feb], DateTime.utc(2026, 2, 10));
      // Logs just outside may come along (the window is widened by the
      // largest time zone offsets); none from April.
      expect(logs.every((l) => l.localDay.month <= 2), isTrue);
    });

    test('a log made at 00:30 in +14:00 is found on its own day', () async {
      // 00:30 on 1 Feb at +14:00 is 10:30 on 31 Jan in UTC.
      final early = await repo.createText(body: 'kiritimati');
      await db.customStatement(
        'UPDATE log SET created_at_ms = ?, tz_offset_minutes = 840 '
        'WHERE id = ?',
        [DateTime.utc(2026, 1, 31, 10, 30).millisecondsSinceEpoch, early],
      );
      final logs = await repo
          .watchFeedBetween(DateTime.utc(2026, 2, 1), DateTime.utc(2026, 2, 2))
          .first;
      expect(logs.map((l) => l.id), contains(early));
      expect(
        logs.firstWhere((l) => l.id == early).localDay,
        DateTime.utc(2026, 2, 1),
      );
    });
  });

  group('watchTypeSummaries', () {
    test('counts each type outside Trash, and its newest log', () async {
      await textAt(DateTime.utc(2026, 1, 1, 8));
      await textAt(DateTime.utc(2026, 1, 3, 8));
      t = DateTime.utc(2026, 1, 5);
      final binned = await repo.createEmoji(emoji: '😴', strength: 1);
      await repo.softDelete(binned);
      t = DateTime.utc(2026, 1, 2);
      await repo.createEmoji(emoji: '😌', strength: 4);

      final summaries = await repo.watchTypeSummaries().first;
      expect(summaries[LogType.text]!.count, 2);
      expect(summaries[LogType.text]!.newestDay, DateTime.utc(2026, 1, 3));
      expect(summaries[LogType.emoji]!.count, 1);
      expect(summaries[LogType.emoji]!.newestDay, DateTime.utc(2026, 1, 2));
      expect(summaries.containsKey(LogType.photo), isFalse);
    });

    test('the newest log keeps its own offset', () async {
      final id = await textAt(DateTime.utc(2026, 1, 1, 20));
      await db.customStatement(
        'UPDATE log SET tz_offset_minutes = 330 WHERE id = ?',
        [id],
      );
      final s = (await repo.watchTypeSummaries().first)[LogType.text]!;
      expect(s.newestMoment, DateTime.utc(2026, 1, 2, 1, 30));
      expect(s.newestDay, DateTime.utc(2026, 1, 2));
    });
  });

  test('the feed has indexes, and the first page uses one', () async {
    final plan = await db
        .customSelect(
          'EXPLAIN QUERY PLAN SELECT id FROM log WHERE deleted_at_ms IS NULL '
          'ORDER BY created_at_ms DESC, id DESC LIMIT ?',
          variables: [Variable.withInt(60)],
        )
        .get();
    final detail = plan.map((r) => r.read<String>('detail')).join(' | ');
    expect(detail, contains('log_feed_order'));
    expect(detail, isNot(contains('TEMP B-TREE')));
  });

  test('at 20,000 logs, the first page and the counts are quick', () async {
    await db.transaction(() async {
      for (var i = 0; i < 20000; i++) {
        t = DateTime.utc(2020).add(Duration(hours: i));
        if (i.isEven) {
          await repo.createText(body: 'entry $i');
        } else {
          await repo.createEmoji(emoji: '😌', strength: 3);
        }
      }
    });
    Future<int> ms(Future<Object?> Function() run) async {
      await run();
      final watch = Stopwatch()..start();
      await run();
      return watch.elapsedMilliseconds;
    }

    expect(await ms(() => repo.watchFeed(limit: 60).first), lessThan(40));
    expect(await ms(() => repo.watchTypeSummaries().first), lessThan(40));
    expect(
      await ms(
        () => repo
            .watchFeedBetween(
              DateTime.utc(2021, 3, 1),
              DateTime.utc(2021, 4, 12),
            )
            .first,
      ),
      lessThan(40),
    );
  });
}
