import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../db/database_helper.dart';
import '../models/routine_task.dart';

/// Handles three kinds of notifications:
///  1. Task reminders -- a recurring alarm at a routine task's set time, on
///     whichever weekdays its group covers.
///  2. The goal alarm -- a one-shot, alarm-channel notification scheduled
///     for the exact moment a timer goal will be reached. This is what
///     makes the alarm reliable even if the app is minimized or the
///     process is killed by Android in the background: it's the OS's own
///     AlarmManager firing it, not our Dart code needing to still be
///     running. When the app IS open and reaches the goal itself, the
///     in-app alarm (AlarmPlayer) handles it and this gets cancelled to
///     avoid a duplicate.
///  3. The live timer notification -- an ongoing notification showing the
///     study timer while it runs, with a working "Stop & Save" action.
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const int _timerNotificationId = 999999;
  static const int _goalAlarmId = 999998;

  /// Master switch for task reminders, mirrored from the user's setting.
  bool remindersEnabled = true;

  /// Set by the Timer screen's build method to the exact same "stop and
  /// save" logic its own button uses -- lets the notification's action
  /// button do the real thing (save with the right subject/chapter)
  /// instead of a generic fallback, as long as the app process is alive.
  Future<void> Function()? onStopSaveRequested;

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      // Derive an Etc/GMT location purely from Dart's own UTC offset --
      // avoids flutter_timezone, whose Android plugin code still targets
      // the old Flutter v1 embedding and fails to compile against the
      // current one. Note Etc/GMT's sign is inverted (UTC+6 = "Etc/GMT-6"),
      // and this ignores DST, which doesn't matter for Bangladesh.
      final offsetHours = DateTime.now().timeZoneOffset.inHours;
      final etcName = offsetHours >= 0 ? 'Etc/GMT-$offsetHours' : 'Etc/GMT+${-offsetHours}';
      tz.setLocalLocation(tz.getLocation(etcName));
    } catch (_) {
      // Fall back to whatever `timezone` defaults to (UTC).
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();

    _initialized = true;

    // Safety net: re-schedule every timed routine task fresh on every app
    // start. Covers cases where the original schedule used a wrong
    // timezone (before this offset fix), permission was granted only
    // after the task was first added, or the boot receiver didn't fire.
    await _rescheduleAllReminders();
  }

  void _handleNotificationResponse(NotificationResponse response) {
    if (response.id == _timerNotificationId && response.actionId == 'stop_save') {
      onStopSaveRequested?.call();
    }
  }

  Future<void> _rescheduleAllReminders() async {
    try {
      final tasks = await DatabaseHelper.instance.getAllRoutineTasks();
      for (final t in tasks) {
        if (t.timeOfDay != null) {
          await scheduleTaskReminder(t);
        }
      }
    } catch (_) {
      // Non-fatal -- worst case, reminders stay as they were.
    }
  }

  /// True once permission requests have actually completed and the
  /// underlying plugin reports both are granted -- used to show a warning
  /// in Settings if either is missing, since Android gives no other
  /// feedback when a scheduled reminder silently never fires.
  Future<(bool notifications, bool exactAlarms)> permissionStatus() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final notifications = await androidImpl?.areNotificationsEnabled() ?? false;
    final exactAlarms = await androidImpl?.canScheduleExactNotifications() ?? false;
    return (notifications, exactAlarms);
  }

  Future<void> requestExactAlarmPermission() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestExactAlarmsPermission();
  }

  Future<void> requestNotificationPermission() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
  }

  // ---------- Task reminders ----------

  static const Map<RoutineGroup, List<int>> _groupWeekdays = {
    RoutineGroup.groupA: [DateTime.saturday, DateTime.monday, DateTime.wednesday],
    RoutineGroup.groupB: [DateTime.sunday, DateTime.tuesday, DateTime.thursday],
    RoutineGroup.groupC: [DateTime.friday],
  };

  int _idFor(int taskId, int weekday) => taskId * 10 + weekday;

  Future<void> scheduleTaskReminder(RoutineTask task) async {
    if (task.id == null || task.timeOfDay == null) return;
    await cancelTaskReminders(task.id!);
    if (!remindersEnabled) return;

    final parts = task.timeOfDay!.split(':');
    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

    for (final weekday in _groupWeekdays[task.group] ?? []) {
      final scheduled = _nextInstanceOfWeekdayTime(weekday, hour, minute);
      try {
        await _plugin.zonedSchedule(
          _idFor(task.id!, weekday),
          'Routine reminder',
          task.title,
          scheduled,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'routine_reminders',
              'Routine reminders',
              channelDescription: 'Reminders for your daily routine tasks',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      } catch (_) {
        // Exact scheduling can throw if the exact-alarm permission was
        // revoked after being granted -- skip this one rather than crash.
      }
    }
  }

  Future<void> cancelTaskReminders(int taskId) async {
    for (final weekday in [
      DateTime.saturday,
      DateTime.sunday,
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
    ]) {
      await _plugin.cancel(_idFor(taskId, weekday));
    }
  }

  tz.TZDateTime _nextInstanceOfWeekdayTime(int weekday, int hour, int minute) {
    var scheduled = tz.TZDateTime.now(tz.local);
    scheduled = tz.TZDateTime(tz.local, scheduled.year, scheduled.month, scheduled.day, hour, minute);
    while (scheduled.weekday != weekday || scheduled.isBefore(tz.TZDateTime.now(tz.local))) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  // ---------- Goal alarm (survives the app being minimized) ----------

  /// Schedules a one-shot alarm-channel notification for the moment a
  /// timer goal will be reached. Uses Android's ALARM audio stream (not
  /// media/notification volume) and a full-screen intent so it behaves
  /// like a real alarm clock rather than a regular notification.
  Future<void> scheduleGoalAlarm({required DateTime fireAt, required String subjectLabel}) async {
    if (fireAt.isBefore(DateTime.now())) return;
    try {
      await _plugin.zonedSchedule(
        _goalAlarmId,
        "Time's up!",
        "Your $subjectLabel goal is complete. Open the app to end or extend.",
        tz.TZDateTime.from(fireAt, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'goal_alarm',
            'Study goal alarm',
            channelDescription: "Alerts when your timer goal is reached, even if the app is minimized",
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: true,
            visibility: NotificationVisibility.public,
            sound: RawResourceAndroidNotificationSound('alarm'),
            audioAttributesUsage: AudioAttributesUsage.alarm,
            playSound: true,
            enableVibration: true,
            ongoing: false,
            autoCancel: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // If exact scheduling isn't permitted on this device, the in-app
      // alarm (while the app is open) is still the fallback.
    }
  }

  Future<void> cancelGoalAlarm() async {
    await _plugin.cancel(_goalAlarmId);
  }

  // ---------- Live timer notification ----------

  Future<void> showLiveTimer({required DateTime runningSinceTotal, required String subjectLabel}) async {
    await _plugin.show(
      _timerNotificationId,
      '⏱ $subjectLabel',
      'Studying now -- tap Stop & Save when you finish',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'live_timer',
          'Live study timer',
          channelDescription: 'Shows your running study timer with a Stop & Save action',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          showWhen: true,
          usesChronometer: true,
          when: runningSinceTotal.millisecondsSinceEpoch,
          chronometerCountDown: false,
          category: AndroidNotificationCategory.stopwatch,
          actions: const [
            AndroidNotificationAction('stop_save', 'Stop & Save', showsUserInterface: true),
          ],
        ),
      ),
    );
  }

  Future<void> showPausedTimer({required String subjectLabel, required String elapsedFormatted}) async {
    await _plugin.show(
      _timerNotificationId,
      '⏸ $subjectLabel',
      'Paused at $elapsedFormatted',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'live_timer',
          'Live study timer',
          channelDescription: 'Shows your running study timer with a Stop & Save action',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          actions: [
            AndroidNotificationAction('stop_save', 'Stop & Save', showsUserInterface: true),
          ],
        ),
      ),
    );
  }

  Future<void> cancelLiveTimer() async {
    await _plugin.cancel(_timerNotificationId);
  }
}
