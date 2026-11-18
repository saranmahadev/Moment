import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

/// Runs integration_test/frame_budget_test.dart: writes each traced
/// action's timeline summary to build/frame_budget/, prints the numbers,
/// and fails when one is past test_driver/frame_budget.json.
Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final budget =
        jsonDecode(File('test_driver/frame_budget.json').readAsStringSync())
            as Map<String, Object?>;
    final failures = <String>[];
    for (final MapEntry(key: action, value: timelineJson) in data!.entries) {
      final timeline = driver.Timeline.fromJson(
        timelineJson as Map<String, dynamic>,
      );
      final summary = driver.TimelineSummary.summarize(timeline);
      await summary.writeTimelineToFile(
        action,
        destinationDirectory: 'build/frame_budget',
        pretty: true,
      );
      final json = summary.summaryJson;
      final p90 = json['90th_percentile_frame_build_time_millis'] as num;
      final worst = json['worst_frame_build_time_millis'] as num;
      final frames = json['frame_count'] as num;
      final missed = json['missed_frame_build_budget_count'] as num;
      final share = frames == 0 ? 0 : missed / frames;
      stdout.writeln(
        '$action: $frames frames, build p90 ${p90.toStringAsFixed(1)} ms, '
        'worst ${worst.toStringAsFixed(1)} ms, '
        '${(share * 100).toStringAsFixed(1)}% over 16 ms; raster p90 '
        '${(json['90th_percentile_frame_rasterizer_time_millis'] as num).toStringAsFixed(1)} ms',
      );
      final limits = budget[action] as Map<String, Object?>?;
      if (limits == null) {
        failures.add('$action has no budget in frame_budget.json');
        continue;
      }
      if (p90 > (limits['p90_build_ms']! as num)) {
        failures.add('$action: build p90 $p90 ms > ${limits['p90_build_ms']}');
      }
      if (worst > (limits['worst_build_ms']! as num)) {
        failures.add(
          '$action: worst build $worst ms > ${limits['worst_build_ms']}',
        );
      }
      if (share > (limits['missed_build_share']! as num)) {
        failures.add(
          '$action: ${(share * 100).toStringAsFixed(1)}% of frames over '
          'budget > ${((limits['missed_build_share']! as num) * 100)}%',
        );
      }
    }
    if (failures.isNotEmpty) {
      stderr.writeln('Frame budget exceeded:\n  ${failures.join('\n  ')}');
      exit(1);
    }
  },
);
