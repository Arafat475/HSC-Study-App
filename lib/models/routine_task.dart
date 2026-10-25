/// Which weekday-group a routine task belongs to. Tasks repeat every week
/// on all days in their group -- there is no more "recurring vs one-off"
/// distinction, just three fixed weekly groups the user defined:
///   groupA: Saturday, Monday, Wednesday
///   groupB: Sunday, Tuesday, Thursday
///   groupC: Friday
enum RoutineGroup { groupA, groupB, groupC }

RoutineGroup groupForWeekday(int weekday) {
  // Dart's DateTime.weekday: Monday=1 ... Sunday=7.
  switch (weekday) {
    case DateTime.saturday:
    case DateTime.monday:
    case DateTime.wednesday:
      return RoutineGroup.groupA;
    case DateTime.sunday:
    case DateTime.tuesday:
    case DateTime.thursday:
      return RoutineGroup.groupB;
    case DateTime.friday:
      return RoutineGroup.groupC;
    default:
      return RoutineGroup.groupA;
  }
}

String groupLabel(RoutineGroup group) {
  switch (group) {
    case RoutineGroup.groupA:
      return 'Sat · Mon · Wed';
    case RoutineGroup.groupB:
      return 'Sun · Tue · Thu';
    case RoutineGroup.groupC:
      return 'Friday';
  }
}

class RoutineTask {
  final int? id;
  final String title;
  final int sortOrder;
  final RoutineGroup group;
  final String? timeOfDay; // 'HH:mm', 24-hour, null = no specific time

  RoutineTask({
    this.id,
    required this.title,
    required this.sortOrder,
    required this.group,
    this.timeOfDay,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'sortOrder': sortOrder,
      'weekdayGroup': group.index,
      'timeOfDay': timeOfDay,
    };
  }

  factory RoutineTask.fromMap(Map<String, dynamic> map) {
    return RoutineTask(
      id: map['id'] as int?,
      title: map['title'] as String,
      sortOrder: map['sortOrder'] as int,
      group: RoutineGroup.values[map['weekdayGroup'] as int],
      timeOfDay: map['timeOfDay'] as String?,
    );
  }
}
