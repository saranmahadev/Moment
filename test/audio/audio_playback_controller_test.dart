import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:moment/audio/audio_playback_controller.dart';

void main() {
  group('isAudibleState', () {
    test('is playing while the player is playing', () {
      expect(isAudibleState(PlayerState(true, ProcessingState.ready)), isTrue);
      expect(
        isAudibleState(PlayerState(true, ProcessingState.buffering)),
        isTrue,
      );
    });

    test('is not playing when paused', () {
      expect(
        isAudibleState(PlayerState(false, ProcessingState.ready)),
        isFalse,
      );
    });

    test(
      'is not playing once the clip has ended, so Play is offered again',
      () {
        // just_audio keeps `playing` true after the end; the button must not.
        expect(
          isAudibleState(PlayerState(true, ProcessingState.completed)),
          isFalse,
        );
      },
    );
  });
}
