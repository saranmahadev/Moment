import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// What the reminder says. Nothing from the journal: a notification can be
/// read on a locked screen.
const reminderTitle = 'Moment';
const reminderBody = 'A moment for today?';

/// The next time the clock reads [time] after [now], in the same (local)
/// terms as [now]: today if that is still ahead, otherwise tomorrow.
DateTime nextReminder(DateTime now, TimeOfDay time) {
  final today = DateTime(now.year, now.month, now.day, time.hour, time.minute);
  return today.isAfter(now)
      ? today
      : DateTime(now.year, now.month, now.day + 1, time.hour, time.minute);
}

/// Schedules the daily reminder. Local notifications only: nothing is
/// sent anywhere, and no server is involved.
abstract interface class ReminderScheduler {
  /// Asks for permission if needed and schedules a notification every day
  /// at [time], replacing any earlier one. False if notifications are not
  /// allowed, in which case nothing is scheduled.
  Future<bool> enable(TimeOfDay time);

  /// Cancels the reminder.
  Future<void> disable();
}

/// The real scheduler, on `flutter_local_notifications`.
class DeviceReminderScheduler implements ReminderScheduler {
  static const _id = 2100;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> _ensureReady() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } on Object {
      // The zone stays UTC. The first reminder is still at the right
      // moment (it is computed from the device clock below); only a later
      // daylight-saving change would shift it, until the app next opens.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  Future<bool> _allowed() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? true;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }
    return true;
  }

  @override
  Future<bool> enable(TimeOfDay time) async {
    await _ensureReady();
    if (!await _allowed()) return false;
    await _plugin.cancel(id: _id);
    await _plugin.zonedSchedule(
      id: _id,
      title: reminderTitle,
      body: reminderBody,
      scheduledDate: tz.TZDateTime.from(
        nextReminder(DateTime.now(), time),
        tz.local,
      ),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder',
          'Evening reminder',
          channelDescription: 'A daily nudge to log something',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // Inexact on purpose: a nudge does not need the exact-alarm
      // permission, and may arrive a few minutes late.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    return true;
  }

  @override
  Future<void> disable() async {
    await _ensureReady();
    await _plugin.cancel(id: _id);
  }
}
