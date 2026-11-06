import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/domain/log_type.dart';

IdGenerator _sequentialIds() {
  var next = 0;
  return () => 'id-${next++}';
}

void main() {
  late AppDatabase db;
  late LogRepository repo;
  late DateTime now;

  setUp(() {
    now = DateTime.utc(2026, 1, 15, 12);
    db = AppDatabase(NativeDatabase.memory());
    repo = LogRepository(db, clock: () => now, generateId: _sequentialIds());
  });

  tearDown(() async {
    await db.close();
  });

  group('create and read', () {
    test('creates a text log and reads it back', () async {
      final id = await repo.createText(body: 'Quiet evening.');
      final log = await repo.getById(id);

      expect(log, isA<TextLog>());
      final text = log! as TextLog;
      expect(text.id, id);
      expect(text.type, LogType.text);
      expect(text.body, 'Quiet evening.');
      expect(text.createdAt, now);
      expect(text.tzOffsetMinutes, 0);
      expect(text.editedAt, isNull);
      expect(text.deletedAt, isNull);
    });

    test('creates an emoji log and reads it back', () async {
      final id = await repo.createEmoji(
        emoji: '😌',
        label: 'Calm',
        strength: 3,
      );
      final log = await repo.getById(id);

      final emoji = log! as EmojiLog;
      expect(emoji.emoji, '😌');
      expect(emoji.label, 'Calm');
      expect(emoji.strength, 3);
      expect(emoji.type, LogType.emoji);
    });

    test('an emoji log without a label reads back with a null label', () async {
      final id = await repo.createEmoji(emoji: '😴', strength: 1);
      final emoji = await repo.getById(id) as EmojiLog;
      expect(emoji.label, isNull);
    });

    test('createText accepts a backdated createdAt', () async {
      final backdated = DateTime.utc(2020, 3, 1, 9, 30);
      final id = await repo.createText(body: 'Old entry', createdAt: backdated);
      final log = await repo.getById(id) as TextLog;
      expect(log.createdAt, backdated);
    });

    test('getById returns null for an unknown id', () async {
      expect(await repo.getById('missing'), isNull);
    });

    test('rejects a blank text body', () {
      expect(() => repo.createText(body: '   '), throwsArgumentError);
    });

    test('rejects an empty emoji', () {
      expect(
        () => repo.createEmoji(emoji: '', strength: 3),
        throwsArgumentError,
      );
    });

    test('rejects an emoji strength outside 1 to 5', () {
      expect(
        () => repo.createEmoji(emoji: '😌', strength: 0),
        throwsArgumentError,
      );
      expect(
        () => repo.createEmoji(emoji: '😌', strength: 6),
        throwsArgumentError,
      );
    });

    test('ids are unique across creates', () async {
      final id1 = await repo.createText(body: 'one');
      final id2 = await repo.createText(body: 'two');
      expect(id1, isNot(id2));
    });
  });

  group('update', () {
    test('updateText changes the body and stamps editedAt', () async {
      final id = await repo.createText(body: 'Original');
      now = now.add(const Duration(hours: 1));

      await repo.updateText(id, body: 'Edited');

      final log = await repo.getById(id) as TextLog;
      expect(log.body, 'Edited');
      expect(log.editedAt, now);
    });

    test('updateText rejects a blank body', () async {
      final id = await repo.createText(body: 'Original');
      expect(() => repo.updateText(id, body: '  '), throwsArgumentError);
    });

    test('updateText on an unknown id throws', () {
      expect(
        () => repo.updateText('missing', body: 'x'),
        throwsArgumentError,
      );
    });

    test('updateText on an emoji log throws', () async {
      final id = await repo.createEmoji(emoji: '😌', strength: 2);
      expect(
        () => repo.updateText(id, body: 'x'),
        throwsArgumentError,
      );
    });

    test(
      'updateEmoji changes emoji, label and strength, and stamps editedAt',
      () async {
        final id = await repo.createEmoji(
          emoji: '😌',
          label: 'Calm',
          strength: 2,
        );
        now = now.add(const Duration(hours: 1));

        await repo.updateEmoji(id, emoji: '😄', label: 'Happy', strength: 5);

        final log = await repo.getById(id) as EmojiLog;
        expect(log.emoji, '😄');
        expect(log.label, 'Happy');
        expect(log.strength, 5);
        expect(log.editedAt, now);
      },
    );

    test('updateEmoji with only strength leaves emoji and label unchanged', () async {
      final id = await repo.createEmoji(
        emoji: '😌',
        label: 'Calm',
        strength: 2,
      );

      await repo.updateEmoji(id, strength: 4);

      final log = await repo.getById(id) as EmojiLog;
      expect(log.emoji, '😌');
      expect(log.label, 'Calm');
      expect(log.strength, 4);
    });

    test('updateEmoji rejects a strength outside 1 to 5', () async {
      final id = await repo.createEmoji(emoji: '😌', strength: 2);
      expect(
        () => repo.updateEmoji(id, strength: 9),
        throwsArgumentError,
      );
    });
  });
}
