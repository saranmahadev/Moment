import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/calendar/calendar_screen.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/design/theme.dart';
import 'package:moment/domain/log.dart';
import 'package:moment/domain/log_type.dart';
import 'package:moment/home/feed_card.dart';
import 'package:moment/home/home_screen.dart';
import 'package:moment/library/library_screen.dart';
import 'package:moment/location/location_section_screen.dart';
import 'package:moment/photo/photo_section_screen.dart';
import 'package:moment/section/section_screen.dart';
import 'package:moment/video/video_section_screen.dart';

/// Counts the unlimited feeds a screen asks for: each reads every log.
class _CountingRepository extends LogRepository {
  _CountingRepository(super.db, {super.clock});

  /// Feeds asked for with no limit: every log (of a type, or of all).
  int fullFeeds = 0;

  @override
  Stream<List<Log>> watchFeed({Set<LogType>? types, int? limit}) {
    if (limit == null) fullFeeds++;
    return super.watchFeed(types: types, limit: limit);
  }
}

/// Screens build only what is on screen, however long the library.
void main() {
  final now = DateTime.utc(2026, 11, 18, 21);
  const many = 300;

  late AppDatabase db;
  late _CountingRepository repo;
  late List<String> ids; // newest first

  Future<void> seed(WidgetTester tester, LogType type) async {
    db = AppDatabase(NativeDatabase.memory());
    var t = now;
    repo = _CountingRepository(db, clock: () => t);
    ids = [];
    // Written outside the test's fake clock: hundreds of writes.
    await tester.runAsync(() async {
      await db.transaction(() async {
        for (var i = 0; i < many; i++) {
          t = now.subtract(Duration(hours: 5 * i));
          ids.add(switch (type) {
            LogType.text => await repo.createText(body: 'Entry $i'),
            LogType.emoji => await repo.createEmoji(emoji: '😌', strength: 3),
            LogType.photo => await repo.createPhoto(
              path: '/none/$i.jpg',
              thumbnailPath: '/none/$i-t.jpg',
            ),
            LogType.video => await repo.createVideo(
              path: '/none/$i.mp4',
              posterPath: '/none/$i.jpg',
              duration: const Duration(seconds: 5),
            ),
            LogType.audio => await repo.createAudio(
              path: '/none/$i.m4a',
              duration: const Duration(seconds: 5),
              peaks: const [0.5],
            ),
            LogType.location => await repo.createLocation(
              latitude: 12 + i / 1000,
              longitude: 77,
              name: 'Place $i',
            ),
          });
        }
      });
    });
  }

  Future<void> pump(WidgetTester tester, Widget screen) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(theme: momentTheme(), home: screen));
    await tester.pump();
    await tester.pump();
  }

  /// Takes the screen down, then closes the database the way it was
  /// opened: outside the fake clock.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(db.close);
  }

  int built(Finder finder) =>
      finder.evaluate().length; // skipOffstage: false in the finder

  /// Jumps to the end of the list until [target] is built (each jump can
  /// load another page), or gives up.
  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    for (var i = 0; i < 30 && target.evaluate().isEmpty; i++) {
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      await tester.pump();
      await tester.pump();
    }
  }

  testWidgets('Home builds a page of cards, and loads more as you scroll', (
    tester,
  ) async {
    await seed(tester, LogType.text);
    await pump(
      tester,
      Scaffold(
        body: HomeScreen(repository: repo, now: () => now),
      ),
    );
    expect(repo.fullFeeds, 0);
    expect(built(find.byType(FeedCard, skipOffstage: false)), lessThan(60));

    final oldest = find.byKey(
      ValueKey('feed-card-${ids.last}'),
      skipOffstage: false,
    );
    await scrollTo(tester, oldest);
    expect(oldest, findsOneWidget);
    expect(built(find.byType(FeedCard, skipOffstage: false)), lessThan(60));
    await finish(tester);
  });

  testWidgets('a section builds only the cards on screen', (tester) async {
    await seed(tester, LogType.text);
    await pump(
      tester,
      SectionScreen(type: LogType.text, repository: repo, now: () => now),
    );
    expect(find.text('$many logs'), findsOneWidget);
    expect(built(find.byType(FeedCard, skipOffstage: false)), lessThan(40));
    final oldest = find.byKey(
      ValueKey('section-card-${ids.last}'),
      skipOffstage: false,
    );
    await scrollTo(tester, oldest);
    expect(oldest, findsOneWidget);
    await finish(tester);
  });

  testWidgets('the photo grid builds only the rows on screen', (tester) async {
    await seed(tester, LogType.photo);
    await pump(tester, PhotoSectionScreen(repository: repo, now: () => now));
    final tiles = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('photo-tile-'),
      skipOffstage: false,
    );
    expect(built(tiles), lessThan(60));
    final oldest = find.byKey(
      ValueKey('photo-tile-${ids.last}'),
      skipOffstage: false,
    );
    await scrollTo(tester, oldest);
    expect(oldest, findsOneWidget);
    await finish(tester);
  });

  testWidgets('the video grid builds only the rows on screen', (tester) async {
    await seed(tester, LogType.video);
    await pump(tester, VideoSectionScreen(repository: repo, now: () => now));
    final tiles = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('video-tile-'),
      skipOffstage: false,
    );
    expect(built(tiles), lessThan(60));
    await finish(tester);
  });

  testWidgets('the places list builds only the rows on screen', (tester) async {
    await seed(tester, LogType.location);
    await pump(tester, LocationSectionScreen(repository: repo, now: () => now));
    final rows = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('location-row-'),
      skipOffstage: false,
    );
    expect(built(rows), lessThan(40));
    await finish(tester);
  });

  testWidgets('Library counts without reading every log', (tester) async {
    await seed(tester, LogType.text);
    await pump(
      tester,
      Scaffold(
        body: LibraryScreen(repository: repo, now: () => now),
      ),
    );
    expect(find.textContaining('$many logs'), findsOneWidget);
    expect(repo.fullFeeds, 0);
    await finish(tester);
  });

  testWidgets('Calendar reads only the month it shows', (tester) async {
    await seed(tester, LogType.text);
    await pump(
      tester,
      Scaffold(
        body: CalendarScreen(repository: repo, now: () => now),
      ),
    );
    expect(repo.fullFeeds, 0);
    // Today's log is listed under the selected day.
    expect(find.text('Entry 0'), findsOneWidget);
    await finish(tester);
  });
}
