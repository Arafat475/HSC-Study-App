/// Status of a routine task on a specific day.
/// No row in the database means "pending" (not yet marked).
enum TaskStatus { pending, done, missed }

class TaskCompletion {
  final int? id;
  final int taskId;
  final String date; // 'YYYY-MM-DD'
  final TaskStatus status;

  TaskCompletion({
    this.id,
    required this.taskId,
    required this.date,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taskId': taskId,
      'date': date,
      'status': status == TaskStatus.done ? 1 : 2, // only done/missed are ever stored
    };
  }

  factory TaskCompletion.fromMap(Map<String, dynamic> map) {
    final raw = map['status'] as int;
    return TaskCompletion(
      id: map['id'] as int?,
      taskId: map['taskId'] as int,
      date: map['date'] as String,
      status: raw == 1 ? TaskStatus.done : TaskStatus.missed,
    );
  }
}
