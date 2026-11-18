import 'package:flutter_test/flutter_test.dart';
import 'package:moment/domain/log_type.dart';
import 'package:moment/widgets/deep_links.dart';

void main() {
  group('parseAppLink', () {
    test('reads an add link for each log type', () {
      for (final type in LogType.values) {
        final link = parseAppLink('moment://add/${type.name}');

        expect(link, isA<AddLink>());
        expect((link as AddLink).type, type);
      }
    });

    test('reads the streaks link', () {
      expect(parseAppLink('moment://streaks'), isA<StreaksLink>());
    });

    test('ignores case and a trailing slash', () {
      expect((parseAppLink('Moment://Add/PHOTO/') as AddLink).type, LogType.photo);
    });

    test('ignores anything else', () {
      for (final text in [
        '',
        'moment://',
        'moment://add',
        'moment://add/diary',
        'moment://add/text/extra',
        'moment://delete/everything',
        'https://example.com/add/text',
        'add/text',
      ]) {
        expect(parseAppLink(text), isNull, reason: text);
      }
    });
  });

  group('DeepLinkInbox', () {
    test('holds one link until it is taken, then it is gone', () {
      final inbox = DeepLinkInbox();

      expect(inbox.take(), isNull);
      inbox.post(const StreaksLink());
      expect(inbox.take(), isA<StreaksLink>());
      expect(inbox.take(), isNull);
    });

    test('tells a listener when a link arrives, and keeps the newest', () {
      final inbox = DeepLinkInbox();
      var heard = 0;
      inbox.addListener(() => heard++);

      inbox.post(const AddLink(LogType.text));
      inbox.post(const AddLink(LogType.audio));

      expect(heard, 2);
      expect((inbox.take() as AddLink).type, LogType.audio);
    });

    test('postText ignores text that is not a link', () {
      final inbox = DeepLinkInbox();

      inbox.postText('nonsense');

      expect(inbox.take(), isNull);
    });
  });
}
