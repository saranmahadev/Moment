import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment/settings/reminder_scheduler.dart';

void main() {
  group('nextReminder', () {
    const evening = TimeOfDay(hour: 21, minute: 0);

    test('is later today when that time is still ahead', () {
      expect(
        nextReminder(DateTime(2026, 11, 6, 20, 59), evening),
        DateTime(2026, 11, 6, 21),
      );
    });

    test('is tomorrow when that time has passed, or is right now', () {
      expect(
        nextReminder(DateTime(2026, 11, 6, 21), evening),
        DateTime(2026, 11, 7, 21),
      );
      expect(
        nextReminder(DateTime(2026, 11, 6, 23, 30), evening),
        DateTime(2026, 11, 7, 21),
      );
    });

    test('rolls over the end of a month and a year', () {
      expect(
        nextReminder(
          DateTime(2026, 12, 31, 22),
          const TimeOfDay(hour: 7, minute: 45),
        ),
        DateTime(2027, 1, 1, 7, 45),
      );
    });
  });

  test('the notification says nothing private', () {
    expect(reminderTitle, 'Moment');
    expect(reminderBody, 'A moment for today?');
  });
}
