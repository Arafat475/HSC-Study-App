import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/routine_task.dart';
import '../models/task_completion.dart';
import '../services/notification_service.dart';

class RoutineProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;
  final _fmt = DateFormat('yyyy-MM-dd');

  DateTime selectedDate = DateTime.now();
  List<RoutineTask> tasksForSelectedDate = [];
  Map<int, TaskStatus> statusesForSelectedDate = {};
  bool loading = true;

  String get selectedDateKey => _fmt.format(selectedDate);

  RoutineGroup get groupForSelectedDate => groupForWeekday(selectedDate.weekday);

  Future<void> init() async {
    await _loadForSelectedDate();
  }

  Future<void> _loadForSelectedDate() async {
    loading = true;
    notifyListeners();
    final group = groupForSelectedDate;
    tasksForSelectedDate = await _db.getTasksForGroup(group.index);
    tasksForSelectedDate.sort((a, b) {
      if (a.timeOfDay == null && b.timeOfDay == null) return 0;
      if (a.timeOfDay == null) return 1;
      if (b.timeOfDay == null) return -1;
      return a.timeOfDay!.compareTo(b.timeOfDay!);
    });
    statusesForSelectedDate = await _db.getCompletionsForDate(selectedDateKey);
    loading = false;
    notifyListeners();
  }

  Future<void> goToDate(DateTime date) async {
    selectedDate = DateTime(date.year, date.month, date.day);
    await _loadForSelectedDate();
  }

  Future<void> goToPreviousDay() => goToDate(selectedDate.subtract(const Duration(days: 1)));

  Future<void> goToNextDay() => goToDate(selectedDate.add(const Duration(days: 1)));

  Future<void> goToToday() => goToDate(DateTime.now());

  bool get isToday {
    final now = DateTime.now();
    return selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
  }

  TaskStatus statusOf(int taskId) => statusesForSelectedDate[taskId] ?? TaskStatus.pending;

  /// Adds a task to a given weekly group -- it will then appear every week
  /// on every day belonging to that group. [timeOfDay] is optional, 'HH:mm'.
  /// If set, a reminder is scheduled for every weekday the group covers.
  Future<void> addTask({
    required String title,
    required RoutineGroup group,
    String? timeOfDay,
  }) async {
    final task = RoutineTask(
      title: title,
      sortOrder: tasksForSelectedDate.length,
      group: group,
      timeOfDay: timeOfDay,
    );
    final id = await _db.insertRoutineTask(task);
    if (timeOfDay != null) {
      await NotificationService.instance.scheduleTaskReminder(
        RoutineTask(id: id, title: title, sortOrder: task.sortOrder, group: group, timeOfDay: timeOfDay),
      );
    }
    await _loadForSelectedDate();
  }

  Future<void> deleteTask(int taskId) async {
    await NotificationService.instance.cancelTaskReminders(taskId);
    await _db.deleteRoutineTask(taskId);
    await _loadForSelectedDate();
  }

  /// Tapping the check button cycles pending -> done -> pending.
  Future<void> markDone(int taskId) async {
    final current = statusOf(taskId);
    final next = current == TaskStatus.done ? TaskStatus.pending : TaskStatus.done;
    await _db.setTaskStatus(taskId, selectedDateKey, next);
    statusesForSelectedDate[taskId] = next;
    notifyListeners();
  }

  /// Tapping the cross button cycles pending -> missed -> pending.
  Future<void> markMissed(int taskId) async {
    final current = statusOf(taskId);
    final next = current == TaskStatus.missed ? TaskStatus.pending : TaskStatus.missed;
    await _db.setTaskStatus(taskId, selectedDateKey, next);
    statusesForSelectedDate[taskId] = next;
    notifyListeners();
  }

  /// Completion rate (done / (done+missed)) over the last [days] days,
  /// used for the Analytics tab. Pending (unmarked) entries are excluded.
  Future<double> completionRateSince(int days) async {
    final since = DateTime.now().subtract(Duration(days: days - 1));
    final sinceKey = _fmt.format(DateTime(since.year, since.month, since.day));
    final completions = await _db.getCompletionsSince(sinceKey);
    if (completions.isEmpty) return 0;
    final done = completions.where((c) => c.status == TaskStatus.done).length;
    return done / completions.length;
  }
}
