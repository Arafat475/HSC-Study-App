import 'package:flutter/foundation.dart';
import '../db/database_helper.dart';
import '../models/subject.dart';
import '../models/chapter.dart';
import '../models/study_session.dart';
import '../data/seed_data.dart';

enum AnalyticsPeriod { daily, weekly, monthly }

class AppDataProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;

  List<Subject> subjects = [];
  Map<int, List<Chapter>> chaptersBySubject = {};
  List<StudySession> sessions = [];
  bool loading = true;

  Future<void> loadAll() async {
    loading = true;
    notifyListeners();

    subjects = await _db.getSubjects();
    for (final s in subjects) {
      chaptersBySubject[s.id!] = await _db.getChaptersForSubject(s.id!);
    }
    sessions = await _db.getAllSessions();

    loading = false;
    notifyListeners();
  }

  Future<void> toggleChapterComplete(Chapter chapter, bool value) async {
    await _db.updateChapterProgress(chapter.id!, chapterComplete: value);
    final list = chaptersBySubject[chapter.subjectId]!;
    final idx = list.indexWhere((c) => c.id == chapter.id);
    list[idx] = chapter.copyWith(chapterComplete: value);
    notifyListeners();
  }

  Future<void> toggleRevisionComplete(Chapter chapter, bool value) async {
    await _db.updateChapterProgress(chapter.id!, revisionComplete: value);
    final list = chaptersBySubject[chapter.subjectId]!;
    final idx = list.indexWhere((c) => c.id == chapter.id);
    list[idx] = chapter.copyWith(revisionComplete: value);
    notifyListeners();
  }

  Future<void> addSession(
    int subjectId,
    int durationSeconds,
    DateTime startedAt, {
    int? chapterId,
    String? chapterTitle,
    String? chapterTitleEn,
    SessionType sessionType = SessionType.study,
  }) async {
    if (durationSeconds <= 0) return;
    final session = StudySession(
      subjectId: subjectId,
      chapterId: chapterId,
      chapterTitle: chapterTitle,
      chapterTitleEn: chapterTitleEn,
      sessionType: sessionType,
      durationSeconds: durationSeconds,
      startedAt: startedAt,
    );
    final id = await _db.insertSession(session);
    sessions.insert(
      0,
      StudySession(
        id: id,
        subjectId: subjectId,
        chapterId: chapterId,
        chapterTitle: chapterTitle,
        chapterTitleEn: chapterTitleEn,
        sessionType: sessionType,
        durationSeconds: durationSeconds,
        startedAt: startedAt,
      ),
    );
    notifyListeners();
  }

  // ---------- Derived / analytics helpers ----------

  Subject? subjectById(int id) {
    try {
      return subjects.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Subjects relevant to the user's chosen class (SSC/HSC) and group --
  /// compulsory subjects for that level always included, plus whichever
  /// group-specific subjects match.
  List<Subject> subjectsForLevelGroup(EduLevel level, EduGroup group) {
    return subjects.where((s) => s.level == level && (s.group == EduGroup.compulsory || s.group == group)).toList();
  }

  int totalStudySeconds() => sessions.fold(0, (sum, s) => sum + s.durationSeconds);

  Map<int, int> secondsPerSubject() {
    final Map<int, int> map = {};
    for (final s in sessions) {
      map[s.subjectId] = (map[s.subjectId] ?? 0) + s.durationSeconds;
    }
    return map;
  }

  double chapterCompletionRatio(int subjectId) {
    final chapters = chaptersBySubject[subjectId] ?? [];
    if (chapters.isEmpty) return 0;
    final done = chapters.where((c) => c.chapterComplete).length;
    return done / chapters.length;
  }

  double revisionCompletionRatio(int subjectId) {
    final chapters = chaptersBySubject[subjectId] ?? [];
    if (chapters.isEmpty) return 0;
    final done = chapters.where((c) => c.revisionComplete).length;
    return done / chapters.length;
  }

  double overallChapterCompletionRatio() {
    final all = chaptersBySubject.values.expand((c) => c).toList();
    if (all.isEmpty) return 0;
    final done = all.where((c) => c.chapterComplete).length;
    return done / all.length;
  }

  double overallRevisionCompletionRatio() {
    final all = chaptersBySubject.values.expand((c) => c).toList();
    if (all.isEmpty) return 0;
    final done = all.where((c) => c.revisionComplete).length;
    return done / all.length;
  }

  /// Study seconds grouped by calendar day for the last [days] days (oldest first).
  List<MapEntry<DateTime, int>> dailyTrend(int days) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final Map<DateTime, int> map = {
      for (int i = days - 1; i >= 0; i--) today.subtract(Duration(days: i)): 0,
    };
    for (final s in sessions) {
      final day = DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day);
      if (map.containsKey(day)) {
        map[day] = map[day]! + s.durationSeconds;
      }
    }
    return map.entries.toList();
  }

  /// Study seconds grouped by week-start (Monday) for the last [weeks] weeks.
  List<MapEntry<DateTime, int>> weeklyTrend(int weeks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisMonday = today.subtract(Duration(days: today.weekday - 1));
    final Map<DateTime, int> map = {
      for (int i = weeks - 1; i >= 0; i--) thisMonday.subtract(Duration(days: 7 * i)): 0,
    };
    final keys = map.keys.toList()..sort();
    for (final s in sessions) {
      final day = DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day);
      for (int i = keys.length - 1; i >= 0; i--) {
        if (!day.isBefore(keys[i])) {
          map[keys[i]] = map[keys[i]]! + s.durationSeconds;
          break;
        }
      }
    }
    return map.entries.toList();
  }

  /// Study seconds grouped by calendar month for the last [months] months.
  List<MapEntry<DateTime, int>> monthlyTrend(int months) {
    final now = DateTime.now();
    final Map<DateTime, int> map = {
      for (int i = months - 1; i >= 0; i--) DateTime(now.year, now.month - i, 1): 0,
    };
    for (final s in sessions) {
      final key = DateTime(s.startedAt.year, s.startedAt.month, 1);
      if (map.containsKey(key)) {
        map[key] = map[key]! + s.durationSeconds;
      }
    }
    return map.entries.toList();
  }

  /// Sessions that fall within [start, end) -- used to scope "time by
  /// subject" to the selected Daily/Weekly/Monthly period.
  List<StudySession> sessionsInRange(DateTime start, DateTime end) {
    return sessions.where((s) => !s.startedAt.isBefore(start) && s.startedAt.isBefore(end)).toList();
  }

  Map<int, int> secondsPerSubjectInRange(DateTime start, DateTime end) {
    final Map<int, int> map = {};
    for (final s in sessionsInRange(start, end)) {
      map[s.subjectId] = (map[s.subjectId] ?? 0) + s.durationSeconds;
    }
    return map;
  }

  /// Convenience: start/end bounds for a given analytics period, ending now.
  (DateTime, DateTime) rangeForPeriod(AnalyticsPeriod period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (period) {
      case AnalyticsPeriod.daily:
        return (today, today.add(const Duration(days: 1)));
      case AnalyticsPeriod.weekly:
        final monday = today.subtract(Duration(days: today.weekday - 1));
        return (monday, monday.add(const Duration(days: 7)));
      case AnalyticsPeriod.monthly:
        final firstOfMonth = DateTime(now.year, now.month, 1);
        final firstOfNextMonth = DateTime(now.year, now.month + 1, 1);
        return (firstOfMonth, firstOfNextMonth);
    }
  }

  /// Consecutive days (ending today or yesterday) with at least one session.
  int currentStreakDays() {
    if (sessions.isEmpty) return 0;
    final studiedDays =
        sessions.map((s) => DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day)).toSet();
    final now = DateTime.now();
    var cursor = DateTime(now.year, now.month, now.day);
    if (!studiedDays.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    int streak = 0;
    while (studiedDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int averageSessionSeconds() {
    if (sessions.isEmpty) return 0;
    return totalStudySeconds() ~/ sessions.length;
  }

  Subject? mostStudiedSubject() {
    final map = secondsPerSubject();
    if (map.isEmpty) return null;
    final topId = map.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return subjectById(topId);
  }

  /// Chapters with the most total study time, most-studied first.
  List<MapEntry<String, int>> topStudiedChapters({int limit = 5, String locale = 'bn'}) {
    final Map<String, int> map = {};
    for (final s in sessions) {
      final title = s.localizedChapterTitle(locale);
      if (title == null) continue;
      final subject = subjectById(s.subjectId);
      final label = subject != null ? '$title (${subject.localizedName(locale)})' : title;
      map[label] = (map[label] ?? 0) + s.durationSeconds;
    }
    final entries = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).toList();
  }
}
