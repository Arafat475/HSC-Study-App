import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import '../providers/app_data_provider.dart';
import '../providers/timer_provider.dart';
import '../providers/settings_provider.dart';
import '../models/subject.dart';
import '../models/chapter.dart';
import '../models/study_session.dart';
import '../main.dart';
import '../theme/app_colors.dart';
import '../widgets/neon_grid_background.dart';
import '../widgets/language_toggle.dart';
import '../widgets/alert_settings_sheet.dart';
import '../widgets/exam_countdown_card.dart';
import '../widgets/alarm_player.dart';
import '../data/quotes.dart';
import '../services/notification_service.dart';
import '../services/backup_service.dart';

class TimerScreen extends StatelessWidget {
  const TimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: NeonGridBackground(child: _TimerBody()),
    );
  }
}

class _TimerBody extends StatefulWidget {
  const _TimerBody();

  @override
  State<_TimerBody> createState() => _TimerBodyState();
}

class _TimerBodyState extends State<_TimerBody> {
  int? _selectedSubjectId;
  int? _selectedChapterId;
  SessionType _sessionType = SessionType.study;
  bool _goalDialogShowing = false;
  bool _streakBannerDismissed = false;

  @override
  Widget build(BuildContext context) {
    final appData = context.watch<AppDataProvider>();
    final timer = context.watch<TimerProvider>();
    final settings = context.watch<SettingsProvider>();
    final c = context.colors;
    final locale = settings.locale;

    if (appData.loading) {
      return Center(child: CircularProgressIndicator(color: c.primary));
    }

    final subjectList = appData.subjectsForLevelGroup(settings.eduLevel!, settings.eduGroup!);

    _selectedSubjectId ??= subjectList.isNotEmpty ? subjectList.first.id : null;
    final selectedSubject = subjectList.firstWhere(
      (s) => s.id == _selectedSubjectId,
      orElse: () => subjectList.first,
    );
    final chaptersForSubject = appData.chaptersBySubject[selectedSubject.id] ?? [];
    if (_selectedChapterId != null && !chaptersForSubject.any((ch) => ch.id == _selectedChapterId)) {
      _selectedChapterId = null;
    }

    void startTimer() {
      timer.start();
      if (settings.showTimerNotification) {
        NotificationService.instance.showLiveTimer(
          runningSinceTotal: DateTime.now().subtract(Duration(seconds: timer.elapsedSeconds)),
          subjectLabel: selectedSubject.localizedName(locale),
        );
      }
      // Scheduled independently of the app being open -- this is what
      // actually fires the alarm if the app gets minimized or killed
      // before the goal is reached.
      if (timer.goalSeconds != null) {
        final remaining = timer.goalSeconds! - timer.elapsedSeconds;
        NotificationService.instance.scheduleGoalAlarm(
          fireAt: DateTime.now().add(Duration(seconds: remaining)),
          subjectLabel: selectedSubject.localizedName(locale),
        );
      }
    }

    void pauseTimer() {
      timer.pause();
      if (settings.showTimerNotification) {
        NotificationService.instance.showPausedTimer(
          subjectLabel: selectedSubject.localizedName(locale),
          elapsedFormatted: timer.formatted,
        );
      }
      // Paused means not counting toward the goal anymore -- the scheduled
      // alarm would otherwise fire too early.
      NotificationService.instance.cancelGoalAlarm();
    }

    Future<void> saveAndStop() async {
      final (duration, startedAt) = timer.stopAndReset();
      NotificationService.instance.cancelLiveTimer();
      NotificationService.instance.cancelGoalAlarm();
      if (duration > 0 && selectedSubject.id != null) {
        Chapter? chapter;
        try {
          chapter = chaptersForSubject.firstWhere((ch) => ch.id == _selectedChapterId);
        } catch (_) {
          chapter = null;
        }
        await appData.addSession(
          selectedSubject.id!,
          duration,
          startedAt,
          chapterId: chapter?.id,
          chapterTitle: chapter?.title,
          chapterTitleEn: chapter?.titleEn,
          sessionType: _sessionType,
        );
        BackupService.instance.maybeAutoBackup(appData, settings);
        if (settings.soundAlert) SystemSound.play(SystemSoundType.click);
        if (settings.vibrationAlert) {
          Vibration.hasVibrator().then((has) {
            if (has == true) {
              Vibration.vibrate(duration: 250);
            } else {
              HapticFeedback.mediumImpact();
            }
          });
        }
        if (context.mounted) {
          final chapterNote = chapter != null ? ' · ${chapter.localizedTitle(locale)}' : '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Saved ${_fmtDuration(duration)} for ${selectedSubject.localizedName(locale)}$chapterNote',
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: c.surfaceAlt,
            ),
          );
        }
      }
    }

    // Keeps the notification's "Stop & Save" action pointed at this exact
    // closure (with the currently-selected subject/chapter/type baked in)
    // every time this screen rebuilds, so tapping it from the notification
    // saves correctly as long as the app process is still alive.
    NotificationService.instance.onStopSaveRequested = saveAndStop;

    // Goal reached -- the provider has already auto-paused the timer.
    // Alarm keeps going (sound loop + repeating vibration) until the user
    // actually responds, rather than a single easy-to-miss blip.
    if (timer.goalReached && !_goalDialogShowing) {
      _goalDialogShowing = true;
      // The app is open and caught this itself -- the in-app alarm below
      // takes over, so the scheduled system alarm for this same moment
      // would just be a redundant duplicate.
      NotificationService.instance.cancelGoalAlarm();
      AlarmPlayer.instance.start(
        sound: settings.soundAlert,
        vibration: settings.vibrationAlert,
        volume: settings.alertVolume,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!context.mounted) return;
        final action = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const _GoalReachedDialog(),
        );
        await AlarmPlayer.instance.stop();
        _goalDialogShowing = false;
        if (action == 'end') {
          await saveAndStop();
        } else if (action == '5') {
          timer.extendGoal(5 * 60);
          startTimer();
        } else if (action == '10') {
          timer.extendGoal(10 * 60);
          startTimer();
        } else {
          timer.acknowledgeGoal();
        }
      });
    }

    final isTimerBusy = timer.isRunning || timer.elapsedSeconds > 0;
    final goalProgress = timer.goalSeconds != null && timer.goalSeconds! > 0
        ? (timer.elapsedSeconds / timer.goalSeconds!).clamp(0.0, 1.0)
        : null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _NeonTitle(text: settings.t('study_timer'), c: c),
                Row(
                  children: [
                    const LanguageToggle(),
                    InkWell(
                      onTap: () => showAlertSettingsSheet(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: c.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.border),
                        ),
                        child: Icon(Icons.notifications_outlined, size: 18, color: c.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const ExamCountdownCard(),
            if (!_streakBannerDismissed && appData.sessions.isNotEmpty && appData.currentStreakDays() == 0) ...[
              const SizedBox(height: 12),
              _StreakBanner(
                locale: locale,
                c: c,
                onDismiss: () => setState(() => _streakBannerDismissed = true),
              ),
            ],
            const SizedBox(height: 12),
            _QuoteOfTheDayCard(locale: locale, c: c),
            const SizedBox(height: 18),
            _StudyRevisionToggle(
              value: _sessionType,
              enabled: !isTimerBusy,
              settings: settings,
              c: c,
              onChanged: (v) => setState(() => _sessionType = v),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _SubjectPicker(
                    subjects: subjectList,
                    selected: selectedSubject,
                    enabled: !isTimerBusy,
                    locale: locale,
                    c: c,
                    onChanged: (s) => setState(() {
                      _selectedSubjectId = s.id;
                      _selectedChapterId = null;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ChapterPicker(
                    chapters: chaptersForSubject,
                    selectedChapterId: _selectedChapterId,
                    enabled: !isTimerBusy,
                    locale: locale,
                    noChapterLabel: settings.t('no_specific_chapter'),
                    c: c,
                    onChanged: (id) => setState(() => _selectedChapterId = id),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _GoalPicker(
              goalSeconds: timer.goalSeconds,
              enabled: !isTimerBusy,
              settings: settings,
              c: c,
              onChanged: (v) => _handleGoalChange(context, timer, v, locale, c),
            ),
            const SizedBox(height: 28),
            _TimerFace(
              elapsedFormatted: timer.formatted,
              isRunning: timer.isRunning,
              goalProgress: goalProgress,
              readyLabel: settings.t('ready'),
              studyingLabel: settings.t('studying'),
              c: c,
            ),
            const SizedBox(height: 28),
            _TimerControls(
              isRunning: timer.isRunning,
              hasElapsed: timer.elapsedSeconds > 0,
              settings: settings,
              c: c,
              onStart: startTimer,
              onPause: pauseTimer,
              onStop: saveAndStop,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// Sets the goal, and for unusually short or long choices, reacts with a
  /// playful contextual quote rather than just silently accepting it.
  void _handleGoalChange(BuildContext context, TimerProvider timer, int? seconds, String locale, AppColors c) {
    timer.setGoal(seconds);
    if (seconds == null) return;
    final minutes = seconds ~/ 60;
    (String, String)? quote;
    if (minutes > 0 && minutes < 10) {
      quote = Quotes.random(Quotes.shortGoal);
    } else if (minutes > 150) {
      quote = Quotes.random(Quotes.longGoal);
    }
    if (quote != null) {
      final text = locale == 'en' ? quote.$2 : quote.$1;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text, style: TextStyle(color: c.textPrimary)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: c.surfaceAlt,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _fmtDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${s}s';
  }
}

/// Shown when the timer hits its goal -- the provider has already paused
/// it, so this is purely "what now": end the session, or keep going a bit
/// longer. Not dismissible by tapping outside, since silently swallowing
/// this would put the timer back into "running forever past the goal".
class _GoalReachedDialog extends StatelessWidget {
  const _GoalReachedDialog();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AlertDialog(
      backgroundColor: c.surfaceAlt,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.check_circle, color: c.accent, size: 22),
          const SizedBox(width: 10),
          Text("Time's up!", style: TextStyle(color: c.textPrimary, fontSize: 17)),
        ],
      ),
      content: Text(
        "You've reached your goal. Take a short break, or keep going a bit longer.",
        style: TextStyle(color: c.textSecondary, fontSize: 13.5),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'end'),
          child: Text('End session', style: TextStyle(color: c.danger)),
        ),
        Row(
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context, '5'),
              child: Text('+5 min', style: TextStyle(color: c.accent)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, '10'),
              child: Text('+10 min', style: TextStyle(color: c.primary)),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuoteOfTheDayCard extends StatelessWidget {
  final String locale;
  final AppColors c;
  const _QuoteOfTheDayCard({required this.locale, required this.c});

  @override
  Widget build(BuildContext context) {
    final quote = Quotes.ofTheDay();
    final text = locale == 'en' ? quote.$2 : quote.$1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.primary.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Text('✨', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: c.textPrimary, fontStyle: FontStyle.italic, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakBanner extends StatelessWidget {
  final String locale;
  final AppColors c;
  final VoidCallback onDismiss;

  const _StreakBanner({required this.locale, required this.c, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final quote = Quotes.random(Quotes.streakBroken);
    final text = locale == 'en' ? quote.$2 : quote.$1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.warning.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, color: c.textPrimary, height: 1.3)),
          ),
          InkWell(
            onTap: onDismiss,
            child: Icon(Icons.close, size: 16, color: c.textMuted),
          ),
        ],
      ),
    );
  }
}

class _NeonTitle extends StatelessWidget {
  final String text;
  final AppColors c;
  const _NeonTitle({required this.text, required this.c});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
        color: c.isDark ? Colors.white : c.textPrimary,
        shadows: c.isDark
            ? [
                Shadow(color: c.primary.withOpacity(0.9), blurRadius: 16),
                Shadow(color: c.accent.withOpacity(0.4), blurRadius: 26),
              ]
            : [],
      ),
    );
  }
}

class _StudyRevisionToggle extends StatelessWidget {
  final SessionType value;
  final bool enabled;
  final SettingsProvider settings;
  final AppColors c;
  final ValueChanged<SessionType> onChanged;

  const _StudyRevisionToggle({
    required this.value,
    required this.enabled,
    required this.settings,
    required this.c,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              icon: Icons.menu_book,
              label: settings.t('study'),
              selected: value == SessionType.study,
              color: c.primary,
              mutedColor: c.textMuted,
              onTap: enabled ? () => onChanged(SessionType.study) : null,
            ),
          ),
          Expanded(
            child: _SegmentButton(
              icon: Icons.autorenew,
              label: settings.t('revision'),
              selected: value == SessionType.revision,
              color: c.accent,
              mutedColor: c.textMuted,
              onTap: enabled ? () => onChanged(SessionType.revision) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final Color mutedColor;
  final VoidCallback? onTap;

  const _SegmentButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.mutedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? color : mutedColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? color : mutedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectPicker extends StatelessWidget {
  final List<Subject> subjects;
  final Subject selected;
  final bool enabled;
  final String locale;
  final AppColors c;
  final ValueChanged<Subject> onChanged;

  const _SubjectPicker({
    required this.subjects,
    required this.selected,
    required this.enabled,
    required this.locale,
    required this.c,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: c.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.primary.withOpacity(0.35)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: selected.id,
          dropdownColor: c.surfaceAlt,
          iconEnabledColor: c.accent,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          disabledHint: Text(
            selected.localizedName(locale),
            style: TextStyle(color: c.textPrimary, fontSize: 12.5),
            overflow: TextOverflow.ellipsis,
          ),
          onChanged: enabled
              ? (id) => onChanged(subjects.firstWhere((s) => s.id == id))
              : null,
          items: subjects
              .map(
                (s) => DropdownMenuItem(
                  value: s.id,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book, size: 13, color: Color(s.colorValue)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          s.localizedName(locale),
                          style: TextStyle(fontSize: 13, color: c.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _ChapterPicker extends StatelessWidget {
  final List<Chapter> chapters;
  final int? selectedChapterId;
  final bool enabled;
  final String locale;
  final String noChapterLabel;
  final AppColors c;
  final ValueChanged<int?> onChanged;

  const _ChapterPicker({
    required this.chapters,
    required this.selectedChapterId,
    required this.enabled,
    required this.locale,
    required this.noChapterLabel,
    required this.c,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: c.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.accent.withOpacity(0.25)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          isExpanded: true,
          value: selectedChapterId,
          dropdownColor: c.surfaceAlt,
          iconEnabledColor: c.accent,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          onChanged: enabled ? onChanged : null,
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark_border, size: 13, color: c.textMuted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      noChapterLabel,
                      style: TextStyle(fontSize: 12.5, color: c.textMuted, fontStyle: FontStyle.italic),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            ...chapters.map(
              (ch) => DropdownMenuItem<int?>(
                value: ch.id,
                child: Text(
                  ch.localizedTitle(locale),
                  style: TextStyle(fontSize: 13, color: c.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalPicker extends StatelessWidget {
  final int? goalSeconds;
  final bool enabled;
  final SettingsProvider settings;
  final AppColors c;
  final ValueChanged<int?> onChanged;

  const _GoalPicker({
    required this.goalSeconds,
    required this.enabled,
    required this.settings,
    required this.c,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final presets = <(String, int?)>[
      (settings.t('none'), null),
      ('30m', 30 * 60),
      ('60m', 60 * 60),
    ];

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final p in presets) ...[
            _GoalChip(
              label: p.$1,
              selected: goalSeconds == p.$2,
              enabled: enabled,
              c: c,
              onTap: () => onChanged(p.$2),
            ),
            const SizedBox(width: 8),
          ],
          _GoalChip(
            label: settings.t('custom'),
            icon: Icons.edit,
            selected: goalSeconds != null && ![30 * 60, 60 * 60].contains(goalSeconds),
            enabled: enabled,
            c: c,
            onTap: () async {
              final minutes = await _showCustomGoalDialog(context, c);
              if (minutes != null) onChanged(minutes * 60);
            },
          ),
        ],
      ),
    );
  }

  Future<int?> _showCustomGoalDialog(BuildContext context, AppColors c) async {
    final controller = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surfaceAlt,
        title: Text('Goal (minutes)', style: TextStyle(color: c.textPrimary, fontSize: 15)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: 'e.g. 45',
            hintStyle: TextStyle(color: c.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final v = int.tryParse(controller.text.trim());
              Navigator.pop(ctx, v);
            },
            child: Text('Set', style: TextStyle(color: c.primary)),
          ),
        ],
      ),
    );
  }
}

class _GoalChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final bool enabled;
  final AppColors c;
  final VoidCallback onTap;

  const _GoalChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.enabled,
    required this.c,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.primary.withOpacity(0.2) : c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c.primary : c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: selected ? c.primary : c.textMuted),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? c.primary : c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimerFace extends StatelessWidget {
  final String elapsedFormatted;
  final bool isRunning;
  final double? goalProgress; // null = no goal set
  final String readyLabel;
  final String studyingLabel;
  final AppColors c;

  const _TimerFace({
    required this.elapsedFormatted,
    required this.isRunning,
    required this.goalProgress,
    required this.readyLabel,
    required this.studyingLabel,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final faceColor = isRunning ? c.accent : c.primary;
    return Column(
      children: [
        SizedBox(
          width: 230,
          height: 230,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.isDark ? const Color(0xFF12141A) : c.surface,
                  border: Border.all(
                    color: isRunning ? c.accent : c.primary.withOpacity(0.5),
                    width: isRunning ? 3 : 2,
                  ),
                  boxShadow: !c.isDark
                      ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))]
                      : isRunning
                          ? [
                              BoxShadow(color: c.accent.withOpacity(0.55), blurRadius: 40, spreadRadius: 4),
                              BoxShadow(color: c.primary.withOpacity(0.35), blurRadius: 70, spreadRadius: 10),
                            ]
                          : [BoxShadow(color: c.primary.withOpacity(0.2), blurRadius: 24, spreadRadius: 1)],
                ),
              ),
              // Liquid-style fill showing progress toward the goal, clipped
              // to the circle -- only shown once time has actually elapsed,
              // so an unstarted timer doesn't show a misleading sliver.
              if (goalProgress != null && goalProgress! > 0)
                ClipOval(
                  child: SizedBox(
                    width: 224,
                    height: 224,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedFractionallySizedBox(
                        duration: const Duration(milliseconds: 400),
                        heightFactor: goalProgress!.clamp(0.0, 1.0),
                        widthFactor: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                c.accent.withOpacity(0.35),
                                c.accent.withOpacity(0.15),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Text(
                elapsedFormatted,
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: c.isDark ? Colors.white : c.textPrimary,
                  letterSpacing: 2,
                  shadows: c.isDark
                      ? [
                          Shadow(color: faceColor.withOpacity(0.9), blurRadius: 16),
                          Shadow(color: faceColor.withOpacity(0.5), blurRadius: 32),
                        ]
                      : [],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: isRunning ? c.accent.withOpacity(0.15) : Colors.transparent,
            border: Border.all(color: isRunning ? c.accent.withOpacity(0.5) : c.border),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isRunning ? '● $studyingLabel' : readyLabel,
            style: TextStyle(
              color: isRunning ? c.accent : c.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _TimerControls extends StatelessWidget {
  final bool isRunning;
  final bool hasElapsed;
  final SettingsProvider settings;
  final AppColors c;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onStop;

  const _TimerControls({
    required this.isRunning,
    required this.hasElapsed,
    required this.settings,
    required this.c,
    required this.onStart,
    required this.onPause,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (hasElapsed)
          _ControlButton(
            icon: Icons.stop,
            label: settings.t('stop_save'),
            glowColor: c.danger,
            c: c,
            onTap: onStop,
          ),
        if (hasElapsed) const SizedBox(width: 20),
        _ControlButton(
          icon: isRunning ? Icons.pause : Icons.play_arrow,
          label: isRunning ? settings.t('pause') : settings.t('start'),
          glowColor: isRunning ? c.accent : c.primary,
          c: c,
          large: true,
          filled: true,
          onTap: isRunning ? onPause : onStart,
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color glowColor;
  final AppColors c;
  final bool large;
  final bool filled;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.glowColor,
    required this.c,
    required this.onTap,
    this.large = false,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = large ? 76.0 : 56.0;
    return Column(
      children: [
        Material(
          color: filled ? glowColor : (c.isDark ? const Color(0xFF12141A) : c.surface),
          shape: CircleBorder(side: BorderSide(color: glowColor, width: filled ? 0 : 2)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: c.isDark
                    ? [BoxShadow(color: glowColor.withOpacity(0.6), blurRadius: 24, spreadRadius: 2)]
                    : [],
              ),
              child: Icon(icon, color: filled ? Colors.white : glowColor, size: large ? 34 : 22),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
      ],
    );
  }
}
