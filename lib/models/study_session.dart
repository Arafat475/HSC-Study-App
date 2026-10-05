enum SessionType { study, revision }

class StudySession {
  final int? id;
  final int subjectId;
  final int? chapterId;
  final String? chapterTitle; // Bangla snapshot
  final String? chapterTitleEn; // English snapshot
  final SessionType sessionType;
  final int durationSeconds;
  final DateTime startedAt;

  StudySession({
    this.id,
    required this.subjectId,
    this.chapterId,
    this.chapterTitle,
    this.chapterTitleEn,
    this.sessionType = SessionType.study,
    required this.durationSeconds,
    required this.startedAt,
  });

  String? localizedChapterTitle(String locale) =>
      locale == 'en' ? (chapterTitleEn ?? chapterTitle) : chapterTitle;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subjectId': subjectId,
      'chapterId': chapterId,
      'chapterTitle': chapterTitle,
      'chapterTitleEn': chapterTitleEn,
      'sessionType': sessionType == SessionType.revision ? 1 : 0,
      'durationSeconds': durationSeconds,
      'startedAt': startedAt.toIso8601String(),
    };
  }

  factory StudySession.fromMap(Map<String, dynamic> map) {
    return StudySession(
      id: map['id'] as int?,
      subjectId: map['subjectId'] as int,
      chapterId: map['chapterId'] as int?,
      chapterTitle: map['chapterTitle'] as String?,
      chapterTitleEn: map['chapterTitleEn'] as String?,
      sessionType: (map['sessionType'] as int? ?? 0) == 1 ? SessionType.revision : SessionType.study,
      durationSeconds: map['durationSeconds'] as int,
      startedAt: DateTime.parse(map['startedAt'] as String),
    );
  }
}
