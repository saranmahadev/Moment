/// What the home screen widget is allowed to know.
///
/// The widget sits outside the app lock, so it never opens the database. The
/// app works everything out here, in Dart, and hands the widget this small
/// snapshot: the streak, the day it was worked out for, the last day the
/// streak stays alive if nothing more is logged, and this week's seven
/// squares. Nothing from an entry is in it.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../streaks/streak_model.dart';

@immutable
class WidgetSnapshot {
  const WidgetSnapshot({
    required this.show,
    required this.asOf,
    required this.streak,
    required this.endsOn,
    required this.week,
  });

  /// Bump when a field changes meaning; readers ignore other versions.
  static const version = 1;

  /// False when the owner chose buttons only (or turned streaks off): the
  /// widget then draws nothing about the journal.
  final bool show;

  /// The local day this was worked out for, `YYYY-MM-DD`.
  final String asOf;

  /// Days in the running streak, 0 when none (or [show] is false).
  final int streak;

  /// The last day, `YYYY-MM-DD`, on which the streak is still alive if
  /// nothing more is logged. The widget compares today with it, so a streak
  /// that lapses at midnight is not shown after the app has stopped running.
  final String? endsOn;

  /// This week, Monday first: whether each day has a log.
  final List<bool> week;

  /// Works the snapshot out of the days that have a log. [today] is a UTC
  /// midnight standing for the local day, as everywhere in the streaks code.
  factory WidgetSnapshot.build({
    required Set<DateTime> days,
    required DateTime today,
    required int grace,
    required bool show,
  }) {
    if (!show) {
      return WidgetSnapshot(
        show: false,
        asOf: _date(today),
        streak: 0,
        endsOn: null,
        week: List.filled(7, false),
      );
    }
    final current = streakOf(days, today, grace: grace).current;
    String? endsOn;
    if (current > 0) {
      // A streak survives at most the grace window past the last log, so
      // looking a fortnight ahead always finds where it ends.
      var last = today;
      for (var i = 1; i <= 14; i++) {
        final day = today.add(Duration(days: i));
        if (streakOf(days, day, grace: grace).current == 0) break;
        last = day;
      }
      endsOn = _date(last);
    }
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return WidgetSnapshot(
      show: true,
      asOf: _date(today),
      streak: current,
      endsOn: endsOn,
      week: [
        for (var i = 0; i < 7; i++)
          days.contains(monday.add(Duration(days: i))),
      ],
    );
  }

  Map<String, Object?> toJson() => {
    'v': version,
    'show': show,
    'asOf': asOf,
    'streak': streak,
    'endsOn': endsOn,
    'week': week,
  };

  String encode() => jsonEncode(toJson());

  /// The snapshot in [text], or null for another version or damaged text.
  static WidgetSnapshot? decode(String text) {
    try {
      final json = jsonDecode(text);
      if (json is! Map || json['v'] != version) return null;
      final week = json['week'];
      return WidgetSnapshot(
        show: json['show'] as bool,
        asOf: json['asOf'] as String,
        streak: json['streak'] as int,
        endsOn: json['endsOn'] as String?,
        week: [for (final v in week as List) v as bool],
      );
    } catch (_) {
      return null;
    }
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is WidgetSnapshot &&
      other.show == show &&
      other.asOf == asOf &&
      other.streak == streak &&
      other.endsOn == endsOn &&
      listEquals(other.week, week);

  @override
  int get hashCode =>
      Object.hash(show, asOf, streak, endsOn, Object.hashAll(week));
}
