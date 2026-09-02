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
import '../widgets/neon_grid_background.dart';
import '../widgets/language_toggle.dart';
import '../widgets/alert_settings_sheet.dart';
import '../widgets/exam_countdown_card.dart';
import '../widgets/alarm_player.dart';
import '../data/quotes.dart';
import '../services/notification_service.dart';

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
    final locale = settings.locale;

    if (appData.loading) {
      return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
    }

    final subjectList = appData.subjectsForLevelGroup(settings.eduLevel!, settings.eduGroup!);

    _selectedSubjectId ??= subjectList.isNotEmpty ? subjectList.first.id : null;
    final selectedSubject = subjectList.firstWhere(
      (s) => s.id == _selectedSubjectId,
      orElse: () => subjectList.first,
    );
    final chaptersForSubject = appData.chaptersBySubject[selectedSubject.id] ?? [];
    if (_selectedChapterId != null && !chaptersForSubject.any((c) => c.id == _selectedChapterId)) {
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
    }

    void pauseTimer() {
      timer.pause();
      if (settings.showTimerNotification) {
        NotificationService.instance.showPausedTimer(
          subjectLabel: selectedSubject.localizedName(locale),
          elapsedFormatted: timer.formatted,
        );
      }
    }

    Future<void> saveAndStop() async {
      final (duration, startedAt) = timer.stopAndReset();
      NotificationService.instance.cancelLiveTimer();
      if (duration > 0 && selectedSubject.id != null) {
        Chapter? chapter;
        try {
          chapter = chaptersForSubject.firstWhere((c) => c.id == _selectedChapterId);
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
              backgroundColor: kSurfaceColorAlt,
            ),
          );
        }
      }
    }

    // Goal reached -- the provider has already auto-paused the timer.
    // Alarm keeps going (sound loop + repeating vibration) until the user
    // actually responds, rather than a single easy-to-miss blip.
    if (timer.goalReached && !_goalDialogShowing) {
      _goalDialogShowing = true;
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
                _NeonTitle(text: settings.t('study_timer')),
                Row(
                  children: [
                    const LanguageToggle(),
                    InkWell(
                      onTap: () => showAlertSettingsSheet(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: kSurfaceColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: kBorderColor),
                        ),
                        child: const Icon(Icons.notifications_outlined, size: 18, color: kTextSecondary),
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
                onDismiss: () => setState(() => _streakBannerDismissed = true),
              ),
            ],
            const SizedBox(height: 12),
            _QuoteOfTheDayCard(locale: locale),
            const SizedBox(height: 18),
            _StudyRevisionToggle(
              value: _sessionType,
              enabled: !isTimerBusy,
              settings: settings,
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
              onChanged: (v) => _handleGoalChange(context, timer, v, locale),
            ),
            const SizedBox(height: 28),
            _TimerFace(
              elapsedFormatted: timer.formatted,
              isRunning: timer.isRunning,
              goalProgress: goalProgress,
              readyLabel: settings.t('ready'),
              studyingLabel: settings.t('studying'),
            ),
            const SizedBox(height: 28),
            _TimerControls(
              isRunning: timer.isRunning,
              hasElapsed: timer.elapsedSeconds > 0,
              settings: settings,
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
  void _handleGoalChange(BuildContext context, TimerProvider timer, int? seconds, String locale) {
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
          content: Text(text, style: const TextStyle(color: kTextPrimary)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: kSurfaceColorAlt,
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
    return AlertDialog(
      backgroundColor: kSurfaceColorAlt,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.check_circle, color: kAccentColor, size: 22),
          const SizedBox(width: 10),
          const Text("Time's up!", style: TextStyle(color: kTextPrimary, fontSize: 17)),
        ],
      ),
      content: const Text(
        "You've reached your goal. Take a short break, or keep going a bit longer.",
        style: TextStyle(color: kTextSecondary, fontSize: 13.5),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'end'),
          child: const Text('End session', style: TextStyle(color: Color(0xFFEF5350))),
        ),
        Row(
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context, '5'),
              child: const Text('+5 min', style: TextStyle(color: kAccentColor)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, '10'),
              child: const Text('+10 min', style: TextStyle(color: kPrimaryColor)),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuoteOfTheDayCard extends StatelessWidget {
  final String locale;
  const _QuoteOfTheDayCard({required this.locale});

  @override
  Widget build(BuildContext context) {
    final quote = Quotes.ofTheDay();
    final text = locale == 'en' ? quote.$2 : quote.$1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kPrimaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kPrimaryColor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Text('✨', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: kTextPrimary, fontStyle: FontStyle.italic, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakBanner extends StatelessWidget {
  final String locale;
  final VoidCallback onDismiss;

  const _StreakBanner({required this.locale, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final quote = Quotes.random(Quotes.streakBroken);
    final text = locale == 'en' ? quote.$2 : quote.$1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFB923C).withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFB923C).withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, color: kTextPrimary, height: 1.3)),
          ),
          InkWell(
            onTap: onDismiss,
            child: const Icon(Icons.close, size: 16, color: kTextMuted),
          ),
        ],
      ),
    );
  }
}

class _NeonTitle extends StatelessWidget {
  final String text;
  const _NeonTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
        color: Colors.white,
        shadows: [
          Shadow(color: kPrimaryColor.withOpacity(0.9), blurRadius: 16),
          Shadow(color: kAccentColor.withOpacity(0.4), blurRadius: 26),
        ],
      ),
    );
  }
}

class _StudyRevisionToggle extends StatelessWidget {
  final SessionType value;
  final bool enabled;
  final SettingsProvider settings;
  final ValueChanged<SessionType> onChanged;

  const _StudyRevisionToggle({
    required this.value,
    required this.enabled,
    required this.settings,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              icon: Icons.menu_book,
              label: settings.t('study'),
              selected: value == SessionType.study,
              color: kPrimaryColor,
              onTap: enabled ? () => onChanged(SessionType.study) : null,
            ),
          ),
          Expanded(
            child: _SegmentButton(
              icon: Icons.autorenew,
              label: settings.t('revision'),
              selected: value == SessionType.revision,
              color: kAccentColor,
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
  final VoidCallback? onTap;

  const _SegmentButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
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
            Icon(icon, size: 16, color: selected ? color : kTextMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? color : kTextMuted,
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
  final ValueChanged<Subject> onChanged;

  const _SubjectPicker({
    required this.subjects,
    required this.selected,
    required this.enabled,
    required this.locale,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: kSurfaceColor.withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kPrimaryColor.withOpacity(0.35)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: selected.id,
          dropdownColor: kSurfaceColorAlt,
          iconEnabledColor: kAccentColor,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          disabledHint: Text(
            selected.localizedName(locale),
            style: const TextStyle(color: kTextPrimary, fontSize: 12.5),
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
                          style: const TextStyle(fontSize: 13, color: kTextPrimary),
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
  final ValueChanged<int?> onChanged;

  const _ChapterPicker({
    required this.chapters,
    required this.selectedChapterId,
    required this.enabled,
    required this.locale,
    required this.noChapterLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: kSurfaceColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAccentColor.withOpacity(0.25)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          isExpanded: true,
          value: selectedChapterId,
          dropdownColor: kSurfaceColorAlt,
          iconEnabledColor: kAccentColor,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          onChanged: enabled ? onChanged : null,
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bookmark_border, size: 13, color: kTextMuted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      noChapterLabel,
                      style: const TextStyle(fontSize: 12.5, color: kTextMuted, fontStyle: FontStyle.italic),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            ...chapters.map(
              (c) => DropdownMenuItem<int?>(
                value: c.id,
                child: Text(
                  c.localizedTitle(locale),
                  style: const TextStyle(fontSize: 13, color: kTextPrimary),
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
  final ValueChanged<int?> onChanged;

  const _GoalPicker({
    required this.goalSeconds,
    required this.enabled,
    required this.settings,
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
              onTap: () => onChanged(p.$2),
            ),
            const SizedBox(width: 8),
          ],
          _GoalChip(
            label: settings.t('custom'),
            icon: Icons.edit,
            selected: goalSeconds != null && ![30 * 60, 60 * 60].contains(goalSeconds),
            enabled: enabled,
            onTap: () async {
              final minutes = await _showCustomGoalDialog(context);
              if (minutes != null) onChanged(minutes * 60);
            },
          ),
        ],
      ),
    );
  }

  Future<int?> _showCustomGoalDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurfaceColorAlt,
        title: const Text('Goal (minutes)', style: TextStyle(color: kTextPrimary, fontSize: 15)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: kTextPrimary),
          decoration: const InputDecoration(
            hintText: 'e.g. 45',
            hintStyle: TextStyle(color: kTextMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: kTextSecondary)),
          ),
          TextButton(
            onPressed: () {
              final v = int.tryParse(controller.text.trim());
              Navigator.pop(ctx, v);
            },
            child: const Text('Set', style: TextStyle(color: kPrimaryColor)),
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
  final VoidCallback onTap;

  const _GoalChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.enabled,
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
          color: selected ? kPrimaryColor.withOpacity(0.2) : kSurfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? kPrimaryColor : kBorderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: selected ? kPrimaryColor : kTextMuted),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? kPrimaryColor : kTextSecondary,
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

  const _TimerFace({
    required this.elapsedFormatted,
    required this.isRunning,
    required this.goalProgress,
    required this.readyLabel,
    required this.studyingLabel,
  });

  @override
  Widget build(BuildContext context) {
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
                  color: const Color(0xFF12141A),
                  border: Border.all(
                    color: isRunning ? kAccentColor : kPrimaryColor.withOpacity(0.5),
                    width: isRunning ? 3 : 2,
                  ),
                  boxShadow: isRunning
                      ? [
                          BoxShadow(color: kAccentColor.withOpacity(0.55), blurRadius: 40, spreadRadius: 4),
                          BoxShadow(color: kPrimaryColor.withOpacity(0.35), blurRadius: 70, spreadRadius: 10),
                        ]
                      : [
                          BoxShadow(color: kPrimaryColor.withOpacity(0.2), blurRadius: 24, spreadRadius: 1),
                        ],
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
                                kAccentColor.withOpacity(0.35),
                                kAccentColor.withOpacity(0.15),
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
                  color: Colors.white,
                  letterSpacing: 2,
                  shadows: [
                    Shadow(color: (isRunning ? kAccentColor : kPrimaryColor).withOpacity(0.9), blurRadius: 16),
                    Shadow(color: (isRunning ? kAccentColor : kPrimaryColor).withOpacity(0.5), blurRadius: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: isRunning ? kAccentColor.withOpacity(0.15) : Colors.transparent,
            border: Border.all(color: isRunning ? kAccentColor.withOpacity(0.5) : kBorderColor),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isRunning ? '● $studyingLabel' : readyLabel,
            style: TextStyle(
              color: isRunning ? kAccentColor : kTextMuted,
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
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onStop;

  const _TimerControls({
    required this.isRunning,
    required this.hasElapsed,
    required this.settings,
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
            glowColor: const Color(0xFFEF5350),
            onTap: onStop,
          ),
        if (hasElapsed) const SizedBox(width: 20),
        _ControlButton(
          icon: isRunning ? Icons.pause : Icons.play_arrow,
          label: isRunning ? settings.t('pause') : settings.t('start'),
          glowColor: isRunning ? kAccentColor : kPrimaryColor,
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
  final bool large;
  final bool filled;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.glowColor,
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
          color: filled ? glowColor : const Color(0xFF12141A),
          shape: CircleBorder(side: BorderSide(color: glowColor, width: filled ? 0 : 2)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: glowColor.withOpacity(0.6), blurRadius: 24, spreadRadius: 2)],
              ),
              child: Icon(icon, color: filled ? Colors.white : glowColor, size: large ? 34 : 22),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12.5, color: kTextSecondary)),
      ],
    );
  }
}
