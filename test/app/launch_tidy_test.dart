import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/app/launch_tidy.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:path/path.dart' as p;

void main() {
  test('launch empties Trash of logs older than 30 days, files too', () async {
    final dir = Directory.systemTemp.createTempSync('launch_tidy_');
    addTearDown(() => dir.deleteSync(recursive: true));
    var now = DateTime.utc(2026, 10, 1);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = LogRepository(db, clock: () => now);

    final photo = File(p.join(dir.path, 'a.jpg'))..writeAsBytesSync([1]);
    final thumb = File(p.join(dir.path, 'a-t.jpg'))..writeAsBytesSync([2]);
    final old = await repo.createPhoto(
      path: photo.path,
      thumbnailPath: thumb.path,
    );
    await repo.softDelete(old);
    now = DateTime.utc(2026, 10, 25);
    final recent = await repo.createText(body: 'binned last week');
    await repo.softDelete(recent);
    final kept = await repo.createText(body: 'kept');

    await tidyAtLaunch(repo, now: DateTime.utc(2026, 11, 1));

    expect((await repo.watchTrash().first).map((l) => l.id), [recent]);
    expect((await repo.watchFeed().first).map((l) => l.id), [kept]);
    expect(photo.existsSync(), isFalse);
    expect(thumb.existsSync(), isFalse);
  });
}
