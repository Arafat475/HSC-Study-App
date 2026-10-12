import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../db/database_helper.dart';
import '../data/seed_data.dart';
import '../models/study_session.dart';
import '../models/routine_task.dart';
import '../providers/app_data_provider.dart';
import '../providers/routine_provider.dart';
import '../providers/settings_provider.dart';
import 'auth_service.dart';

/// Backs up and restores the user's data via Cloud Firestore, keyed by
/// their Firebase UID. Subjects/chapters themselves aren't backed up (they
/// come from the app's built-in syllabus) -- only what the user actually
/// created or changed: chapter tick progress, study session history,
/// routine tasks, and their settings.
///
/// Matching on restore is done by stable names (subject Bangla name +
/// chapter position) rather than database IDs, since IDs are assigned
/// fresh on every device/install and won't match across devices.
class BackupService {
  BackupService._internal();
  static final BackupService instance = BackupService._internal();

  DateTime? _lastAutoBackupAt;

  DocumentReference<Map<String, dynamic>> _docFor(String uid) {
    return FirebaseFirestore.instance.collection('users').doc(uid).collection('backup').doc('data');
  }

  Future<Map<String, dynamic>> _buildPayload(AppDataProvider appData, SettingsProvider settings) async {
    final chapterProgress = <Map<String, dynamic>>[];
    for (final subject in appData.subjects) {
      final chapters = appData.chaptersBySubject[subject.id!] ?? [];
      for (final ch in chapters) {
        if (ch.chapterComplete || ch.revisionComplete) {
          chapterProgress.add({
            'subjectNameBn': subject.nameBn,
            'sortOrder': ch.sortOrder,
            'chapterComplete': ch.chapterComplete,
            'revisionComplete': ch.revisionComplete,
          });
        }
      }
    }

    final sessions = appData.sessions
        .map((s) {
          final subject = appData.subjectById(s.subjectId);
          if (subject == null) return null;
          return {
            'subjectNameBn': subject.nameBn,
            'chapterTitle': s.chapterTitle,
            'chapterTitleEn': s.chapterTitleEn,
            'sessionType': s.sessionType.index,
            'durationSeconds': s.durationSeconds,
            'startedAt': s.startedAt.toIso8601String(),
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList();

    final routineTasks = await DatabaseHelper.instance.getAllRoutineTasks();
    final routineTasksJson = routineTasks
        .map((t) => {
              'title': t.title,
              'group': t.group.index,
              'timeOfDay': t.timeOfDay,
            })
        .toList();

    return {
      'version': 1,
      'updatedAt': DateTime.now().toIso8601String(),
      'settings': {
        'locale': settings.locale,
        'studentName': settings.studentName,
        'studentInstitution': settings.studentInstitution,
        'studentYear': settings.studentYear,
        'examName': settings.examName,
        'examDate': settings.examDate?.toIso8601String(),
        'eduLevel': settings.eduLevel?.index,
        'eduGroup': settings.eduGroup?.index,
        'soundAlert': settings.soundAlert,
        'vibrationAlert': settings.vibrationAlert,
        'alertVolume': settings.alertVolume,
        'taskReminders': settings.taskReminders,
        'showTimerNotification': settings.showTimerNotification,
        'isDarkMode': settings.isDarkMode,
      },
      'chapterProgress': chapterProgress,
      'sessions': sessions,
      'routineTasks': routineTasksJson,
    };
  }

  /// Manual "Back up now" -- always runs, throws on failure so the caller
  /// can show an error.
  Future<void> backupNow(AppDataProvider appData, SettingsProvider settings) async {
    final user = AuthService.instance.currentUser;
    if (user == null) throw Exception('Not signed in');
    final payload = await _buildPayload(appData, settings);
    await _docFor(user.uid).set(payload);
    _lastAutoBackupAt = DateTime.now();
  }

  /// Best-effort background backup -- silently does nothing if signed out,
  /// and throttles to at most once per 30 seconds so rapid actions (several
  /// chapter taps in a row) don't spam Firestore with writes.
  void maybeAutoBackup(AppDataProvider appData, SettingsProvider settings) {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    final now = DateTime.now();
    if (_lastAutoBackupAt != null && now.difference(_lastAutoBackupAt!) < const Duration(seconds: 30)) {
      return;
    }
    _lastAutoBackupAt = now;
    // Fire-and-forget -- a failed background backup shouldn't interrupt
    // whatever the user was doing.
    _buildPayload(appData, settings).then((payload) => _docFor(user.uid).set(payload)).catchError((_) {});
  }

  /// Returns when the last backup was made, or null if none exists.
  Future<DateTime?> lastBackupTime() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return null;
    final doc = await _docFor(user.uid).get();
    if (!doc.exists) return null;
    final updatedAt = doc.data()?['updatedAt'] as String?;
    return updatedAt != null ? DateTime.tryParse(updatedAt) : null;
  }

  /// Restores from the signed-in user's backup. Additive: re-restoring
  /// twice, or restoring onto a device that already has data, can create
  /// duplicate sessions/routine tasks (chapter progress is safe to restore
  /// repeatedly since it only ever sets flags to true).
  Future<void> restore(AppDataProvider appData, RoutineProvider routine, SettingsProvider settings) async {
    final user = AuthService.instance.currentUser;
    if (user == null) throw Exception('Not signed in');
    final doc = await _docFor(user.uid).get();
    if (!doc.exists) throw Exception('No backup found for this account.');
    final data = doc.data()!;

    final s = (data['settings'] as Map?)?.cast<String, dynamic>() ?? {};
    if (s['locale'] != null) await settings.setLocale(s['locale']);
    if (s['studentName'] != null || s['studentInstitution'] != null || s['studentYear'] != null) {
      await settings.setStudentProfile(
        name: s['studentName'] ?? '',
        institution: s['studentInstitution'] ?? '',
        year: s['studentYear'] ?? '',
      );
    }
    if (s['examName'] != null && s['examDate'] != null) {
      final parsedDate = DateTime.tryParse(s['examDate']);
      if (parsedDate != null) await settings.setExam(s['examName'], parsedDate);
    }
    if (s['eduLevel'] != null && s['eduGroup'] != null) {
      await settings.setClassAndGroup(EduLevel.values[s['eduLevel']], EduGroup.values[s['eduGroup']]);
    }
    if (s['soundAlert'] != null) await settings.setSoundAlert(s['soundAlert']);
    if (s['vibrationAlert'] != null) await settings.setVibrationAlert(s['vibrationAlert']);
    if (s['alertVolume'] != null) await settings.setAlertVolume((s['alertVolume'] as num).toDouble());
    if (s['taskReminders'] != null) await settings.setTaskReminders(s['taskReminders']);
    if (s['showTimerNotification'] != null) await settings.setShowTimerNotification(s['showTimerNotification']);
    if (s['isDarkMode'] != null) await settings.setIsDarkMode(s['isDarkMode']);

    // Chapter progress -- match by subject Bangla name + chapter position.
    final chapterProgress = (data['chapterProgress'] as List?) ?? [];
    for (final raw in chapterProgress) {
      final entry = (raw as Map).cast<String, dynamic>();
      final matches = appData.subjects.where((sub) => sub.nameBn == entry['subjectNameBn']);
      if (matches.isEmpty) continue;
      final chapters = appData.chaptersBySubject[matches.first.id!] ?? [];
      final chMatches = chapters.where((ch) => ch.sortOrder == entry['sortOrder']);
      if (chMatches.isEmpty) continue;
      final chapter = chMatches.first;
      if (entry['chapterComplete'] == true && !chapter.chapterComplete) {
        await appData.toggleChapterComplete(chapter, true);
      }
      if (entry['revisionComplete'] == true && !chapter.revisionComplete) {
        await appData.toggleRevisionComplete(chapter, true);
      }
    }

    // Study session history.
    final sessions = (data['sessions'] as List?) ?? [];
    for (final raw in sessions) {
      final entry = (raw as Map).cast<String, dynamic>();
      final matches = appData.subjects.where((sub) => sub.nameBn == entry['subjectNameBn']);
      if (matches.isEmpty) continue;
      final startedAt = DateTime.tryParse(entry['startedAt'] ?? '');
      if (startedAt == null) continue;
      await appData.addSession(
        matches.first.id!,
        entry['durationSeconds'] ?? 0,
        startedAt,
        chapterTitle: entry['chapterTitle'],
        chapterTitleEn: entry['chapterTitleEn'],
        sessionType: SessionType.values[entry['sessionType'] ?? 0],
      );
    }

    // Routine tasks.
    final routineTasks = (data['routineTasks'] as List?) ?? [];
    for (final raw in routineTasks) {
      final entry = (raw as Map).cast<String, dynamic>();
      await routine.addTask(
        title: entry['title'] ?? '',
        group: RoutineGroup.values[entry['group'] ?? 0],
        timeOfDay: entry['timeOfDay'],
      );
    }

    await appData.loadAll();
  }
}
