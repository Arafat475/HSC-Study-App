import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_strings.dart';
import '../data/seed_data.dart';
import '../services/notification_service.dart';

class SettingsProvider extends ChangeNotifier {
  static const _kLocale = 'locale';
  static const _kSound = 'sound_alert';
  static const _kVibration = 'vibration_alert';
  static const _kVolume = 'alert_volume';
  static const _kExamName = 'exam_name';
  static const _kExamDate = 'exam_date';
  static const _kEduLevel = 'edu_level';
  static const _kEduGroup = 'edu_group';
  static const _kStudentName = 'student_name';
  static const _kInstitution = 'student_institution';
  static const _kYear = 'student_year';
  static const _kTaskReminders = 'task_reminders';
  static const _kShowTimerNotification = 'show_timer_notification';

  SharedPreferences? _prefs;

  String locale = 'bn'; // 'bn' or 'en'
  bool soundAlert = true;
  bool vibrationAlert = true;
  double alertVolume = 0.8; // 0.0 - 1.0
  String? examName;
  DateTime? examDate;
  EduLevel? eduLevel; // null until the user picks on first launch
  EduGroup? eduGroup; // null for SSC-only users who have no group, or unset
  String? studentName;
  String? studentInstitution; // school or college name
  String? studentYear; // e.g. "2027" or "Class 10"
  bool taskReminders = true;
  bool showTimerNotification = true;
  bool loaded = false;

  bool get needsClassSelection => eduLevel == null;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    locale = _prefs!.getString(_kLocale) ?? 'bn';
    soundAlert = _prefs!.getBool(_kSound) ?? true;
    vibrationAlert = _prefs!.getBool(_kVibration) ?? true;
    alertVolume = _prefs!.getDouble(_kVolume) ?? 0.8;
    examName = _prefs!.getString(_kExamName);
    final examDateStr = _prefs!.getString(_kExamDate);
    examDate = examDateStr != null ? DateTime.tryParse(examDateStr) : null;

    final levelIdx = _prefs!.getInt(_kEduLevel);
    eduLevel = levelIdx != null ? EduLevel.values[levelIdx] : null;
    final groupIdx = _prefs!.getInt(_kEduGroup);
    eduGroup = groupIdx != null ? EduGroup.values[groupIdx] : null;

    studentName = _prefs!.getString(_kStudentName);
    studentInstitution = _prefs!.getString(_kInstitution);
    studentYear = _prefs!.getString(_kYear);

    taskReminders = _prefs!.getBool(_kTaskReminders) ?? true;
    showTimerNotification = _prefs!.getBool(_kShowTimerNotification) ?? true;
    NotificationService.instance.remindersEnabled = taskReminders;

    loaded = true;
    notifyListeners();
  }

  String t(String key) => AppStrings.t(key, locale);

  Future<void> setLocale(String value) async {
    locale = value;
    await _prefs?.setString(_kLocale, value);
    notifyListeners();
  }

  Future<void> setSoundAlert(bool value) async {
    soundAlert = value;
    await _prefs?.setBool(_kSound, value);
    notifyListeners();
  }

  Future<void> setVibrationAlert(bool value) async {
    vibrationAlert = value;
    await _prefs?.setBool(_kVibration, value);
    notifyListeners();
  }

  Future<void> setAlertVolume(double value) async {
    alertVolume = value;
    await _prefs?.setDouble(_kVolume, value);
    notifyListeners();
  }

  Future<void> setExam(String name, DateTime date) async {
    examName = name;
    examDate = date;
    await _prefs?.setString(_kExamName, name);
    await _prefs?.setString(_kExamDate, date.toIso8601String());
    notifyListeners();
  }

  Future<void> clearExam() async {
    examName = null;
    examDate = null;
    await _prefs?.remove(_kExamName);
    await _prefs?.remove(_kExamDate);
    notifyListeners();
  }

  /// Sets the user's class (SSC/HSC) and, for either level, their group.
  /// Group applies to both -- SSC also splits into Science/Business/
  /// Humanities alongside its compulsory subjects.
  Future<void> setClassAndGroup(EduLevel level, EduGroup group) async {
    eduLevel = level;
    eduGroup = group;
    await _prefs?.setInt(_kEduLevel, level.index);
    await _prefs?.setInt(_kEduGroup, group.index);
    notifyListeners();
  }

  /// Lets the user change their class/group later from a settings entry
  /// point, distinct from the one-time first-launch flow.
  Future<void> clearClassSelection() async {
    eduLevel = null;
    eduGroup = null;
    await _prefs?.remove(_kEduLevel);
    await _prefs?.remove(_kEduGroup);
    notifyListeners();
  }

  Future<void> setStudentProfile({
    required String name,
    required String institution,
    required String year,
  }) async {
    studentName = name;
    studentInstitution = institution;
    studentYear = year;
    await _prefs?.setString(_kStudentName, name);
    await _prefs?.setString(_kInstitution, institution);
    await _prefs?.setString(_kYear, year);
    notifyListeners();
  }

  Future<void> setTaskReminders(bool value) async {
    taskReminders = value;
    NotificationService.instance.remindersEnabled = value;
    await _prefs?.setBool(_kTaskReminders, value);
    notifyListeners();
  }

  Future<void> setShowTimerNotification(bool value) async {
    showTimerNotification = value;
    await _prefs?.setBool(_kShowTimerNotification, value);
    notifyListeners();
  }
}
