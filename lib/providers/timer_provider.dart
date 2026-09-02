import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Timer that survives the screen turning off or the app being backgrounded.
///
/// Instead of counting ticks (which Android can pause/delay once the screen
/// locks), elapsed time is always recomputed from real timestamps: how long
/// ago the session started, plus any time already banked before a pause.
/// A periodic ticker only exists to refresh the UI every second while the
/// app is in the foreground -- it is never the source of truth for the
/// duration itself, so a delayed or dropped tick can't cause drift.
///
/// The provider also owns the optional goal duration, since it needs to
/// detect goal-reached moments itself (from its own ticker) rather than
/// relying on the screen to notice -- that's what makes the timer actually
/// stop instead of silently counting past the goal forever.
class TimerProvider extends ChangeNotifier {
  Timer? _uiTicker;
  DateTime? _runStartedAt; // when the current run (since last resume) began
  int _bankedSeconds = 0; // time accumulated from previous runs this session
  bool _isRunning = false;
  DateTime? _sessionStartedAt; // when the whole session first started
  int? _goalSeconds; // null = no goal set
  bool _goalReached = false; // true once elapsed has hit the goal this run

  bool get isRunning => _isRunning;
  DateTime? get sessionStartedAt => _sessionStartedAt;
  int? get goalSeconds => _goalSeconds;
  bool get goalReached => _goalReached;

  int get elapsedSeconds {
    if (_isRunning && _runStartedAt != null) {
      return _bankedSeconds + DateTime.now().difference(_runStartedAt!).inSeconds;
    }
    return _bankedSeconds;
  }

  String get formatted {
    final s = elapsedSeconds;
    final h = (s ~/ 3600).toString().padLeft(2, '0');
    final m = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$h:$m:$sec';
  }

  /// Only settable while not running -- changing the goal mid-run would be
  /// ambiguous about what "reached" means, so the screen disables the goal
  /// picker while busy (same as the subject/chapter pickers).
  void setGoal(int? seconds) {
    if (_isRunning) return;
    _goalSeconds = seconds;
    _goalReached = false;
    notifyListeners();
  }

  void start() {
    if (_isRunning) return;
    _sessionStartedAt ??= DateTime.now();
    _runStartedAt = DateTime.now();
    _isRunning = true;
    _safeWakelock(true);
    _uiTicker?.cancel();
    _uiTicker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    notifyListeners();
  }

  void _onTick() {
    if (!_goalReached && _goalSeconds != null && elapsedSeconds >= _goalSeconds!) {
      _goalReached = true;
      // Auto-pause at the goal -- the screen shows a "time's up" prompt
      // (extend or end) rather than letting the count run forever.
      pause();
      return;
    }
    notifyListeners();
  }

  void pause() {
    if (!_isRunning) return;
    _bankedSeconds = elapsedSeconds;
    _runStartedAt = null;
    _isRunning = false;
    _uiTicker?.cancel();
    _safeWakelock(false);
    notifyListeners();
  }

  /// Adds more time to the goal (e.g. "+5 more minutes") and clears the
  /// reached flag so the timer can be resumed and will alert again if the
  /// new goal is hit.
  void extendGoal(int extraSeconds) {
    if (_goalSeconds == null) return;
    _goalSeconds = _goalSeconds! + extraSeconds;
    _goalReached = false;
    notifyListeners();
  }

  /// Call once the "time's up" prompt has been shown and dismissed, so it
  /// doesn't reappear on the next rebuild.
  void acknowledgeGoal() {
    _goalReached = false;
    notifyListeners();
  }

  /// Call when the app resumes from background -- realigns the displayed
  /// time immediately rather than waiting for the next tick, and re-checks
  /// the goal in case it was reached while backgrounded.
  void refreshAfterResume() {
    if (_isRunning) {
      if (!_goalReached && _goalSeconds != null && elapsedSeconds >= _goalSeconds!) {
        _goalReached = true;
        pause();
      } else {
        notifyListeners();
      }
    }
  }

  /// Returns the finished session's (durationSeconds, startedAt) and resets.
  (int, DateTime) stopAndReset() {
    final duration = elapsedSeconds;
    final startedAt = _sessionStartedAt ?? DateTime.now();
    _uiTicker?.cancel();
    _safeWakelock(false);
    _isRunning = false;
    _bankedSeconds = 0;
    _runStartedAt = null;
    _sessionStartedAt = null;
    _goalSeconds = null;
    _goalReached = false;
    notifyListeners();
    return (duration, startedAt);
  }

  /// Wakelock failures (missing permission, plugin hiccup on a specific
  /// device) must never break the timer itself -- the countdown is still
  /// correct even if the screen locks, this is just a convenience.
  void _safeWakelock(bool enable) {
    try {
      if (enable) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
      }
    } catch (_) {
      // Ignore -- non-critical.
    }
  }

  @override
  void dispose() {
    _uiTicker?.cancel();
    _safeWakelock(false);
    super.dispose();
  }
}
