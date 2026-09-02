import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../models/routine_task.dart';

/// Handles two kinds of notifications:
///  1. Task reminders -- a recurring alarm at a routine task's set time, on
///     whichever weekdays its group covers.
///  2. The live timer notification -- an ongoing, non-dismissible
///     notification showing the study timer while it runs, using Android's
///     native chronometer so it ticks without the app repeatedly updating it.
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Master switch for task reminders, mirrored from the user's setting.
  /// Scheduling checks this so toggling reminders off in Settings takes
  /// effect for any task added/edited afterward. (Reminders already
  /// scheduled before toggling off keep firing until that task is next
  /// added or edited -- a known simplification.)
  bool remindersEnabled = true;

  static const int _timerNotificationId = 999999;

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
      // Fall back to whatever `timezone` defaults to (UTC) -- reminders
      // still fire, just potentially off from local time on that one device.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: androidInit));

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();

    _initialized = true;
  }

  // ---------- Task reminders ----------

  /// Weekdays (Dart's DateTime.weekday values) covered by each routine group.
  static const Map<RoutineGroup, List<int>> _groupWeekdays = {
    RoutineGroup.groupA: [DateTime.saturday, DateTime.monday, DateTime.wednesday],
    RoutineGroup.groupB: [DateTime.sunday, DateTime.tuesday, DateTime.thursday],
    RoutineGroup.groupC: [DateTime.friday],
  };

  /// One notification ID per (task, weekday) pair, so each weekday's
  /// occurrence can be scheduled/cancelled independently.
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

  // ---------- Live timer notification ----------

  /// Shows (or updates) the ongoing timer notification. [runningSinceTotal]
  /// is the timestamp Android's chronometer counts from -- computed as
  /// "now minus total elapsed seconds so far" so it reflects banked time
  /// from earlier pauses too, not just the current run.
  Future<void> showLiveTimer({required DateTime runningSinceTotal, required String subjectLabel}) async {
    await _plugin.show(
      _timerNotificationId,
      'Studying: $subjectLabel',
      'Tap to return to the timer',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'live_timer',
          'Live study timer',
          channelDescription: 'Shows your running study timer',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          showWhen: true,
          usesChronometer: true,
          when: runningSinceTotal.millisecondsSinceEpoch,
          chronometerCountDown: false,
        ),
      ),
    );
  }

  /// Swaps the notification to a static (non-ticking) state while paused.
  Future<void> showPausedTimer({required String subjectLabel, required String elapsedFormatted}) async {
    await _plugin.show(
      _timerNotificationId,
      'Paused: $subjectLabel',
      'Elapsed so far: $elapsedFormatted',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'live_timer',
          'Live study timer',
          channelDescription: 'Shows your running study timer',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
        ),
      ),
    );
  }

  Future<void> cancelLiveTimer() async {
    await _plugin.cancel(_timerNotificationId);
  }
}
