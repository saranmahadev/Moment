@Tags(['slow'])
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/backup/backup_cipher.dart';
import 'package:moment/backup/backup_service.dart';
import 'package:moment/data/database.dart';
import 'package:moment/data/log_repository.dart';
import 'package:moment/data/media_store.dart';
import 'package:path/path.dart' as p;

import '../video/video_fakes.dart';

void main() {
  test(
    'a 1 GB video is imported and backed up with memory staying flat',
    () async {
      const oneGigabyte = 1024 * 1024 * 1024;
      final tempDir = Directory.systemTemp.createTempSync('backup_large_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final root = Directory(p.join(tempDir.path, 'support'))..createSync();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = LogRepository(db);

      // A sparse file: 1 GB long without the test writing 1 GB itself.
      final source = File(p.join(tempDir.path, 'big.mp4'));
      final handle = source.openSync(mode: FileMode.write);
      handle.truncateSync(oneGigabyte);
      handle.closeSync();

      final before = ProcessInfo.currentRss;
      var peak = before;
      void sample() {
        final rss = ProcessInfo.currentRss;
        if (rss > peak) peak = rss;
      }

      final video = await MediaStore(
        root: root,
      ).importVideo(source, probe: FakeVideoProbe());
      sample();
      await repo.createVideo(
        path: video.path,
        posterPath: video.posterPath,
        duration: video.duration,
      );

      final service = BackupService(
        db: db,
        mediaRoot: root,
        cipher: BackupCipher(kdfIterations: 10),
      );
      final backup = File(p.join(tempDir.path, 'big.moment'));
      final sink = backup.openWrite();
      var chunks = 0;
      await for (final chunk in service.exportStream(passphrase: 'pw')) {
        sink.add(chunk);
        if (++chunks % 64 == 0) {
          await sink.flush();
          sample();
        }
      }
      await sink.close();
      sample();

      expect(backup.lengthSync(), greaterThan(oneGigabyte));
      // Holding the video in memory would add a gigabyte or more. A
      // streamed export stays within a few chunks plus collector slack.
      expect(peak - before, lessThan(300 * 1024 * 1024));
    },
  );
}
