import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/app_data_provider.dart';
import '../providers/routine_provider.dart';
import '../providers/settings_provider.dart';
import '../models/subject.dart';
import '../main.dart';
import '../widgets/language_toggle.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  AnalyticsPeriod _period = AnalyticsPeriod.daily;

  @override
  Widget build(BuildContext context) {
    final appData = context.watch<AppDataProvider>();
    final routine = context.watch<RoutineProvider>();
    final settings = context.watch<SettingsProvider>();
    final locale = settings.locale;

    if (appData.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: kPrimaryColor)));
    }

    final subjectList = appData.subjectsForLevelGroup(settings.eduLevel!, settings.eduGroup!);
    final subjectIds = subjectList.map((s) => s.id).toSet();
    final scopedChapters = subjectList.expand((s) => appData.chaptersBySubject[s.id!] ?? []).toList();

    final totalSeconds = appData.totalStudySeconds();
    final overallChapterRatio = scopedChapters.isEmpty
        ? 0.0
        : scopedChapters.where((c) => c.chapterComplete).length / scopedChapters.length;
    final overallRevisionRatio = scopedChapters.isEmpty
        ? 0.0
        : scopedChapters.where((c) => c.revisionComplete).length / scopedChapters.length;
    final streak = appData.currentStreakDays();
    final avgSession = appData.averageSessionSeconds();
    final mostStudied = appData.mostStudiedSubject();
    final topChapters = appData.topStudiedChapters(locale: locale);

    final (rangeStart, rangeEnd) = appData.rangeForPeriod(_period);
    final periodSeconds = appData
        .sessionsInRange(rangeStart, rangeEnd)
        .fold<int>(0, (sum, s) => sum + s.durationSeconds);
    final periodSubjectSeconds = Map.fromEntries(
      appData.secondsPerSubjectInRange(rangeStart, rangeEnd).entries.where((e) => subjectIds.contains(e.key)),
    );
    final trend = switch (_period) {
      AnalyticsPeriod.daily => appData.dailyTrend(7),
      AnalyticsPeriod.weekly => appData.weeklyTrend(8),
      AnalyticsPeriod.monthly => appData.monthlyTrend(6),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('analytics')),
        actions: const [LanguageToggle()],
      ),
      body: appData.sessions.isEmpty && overallChapterRatio == 0
          ? _EmptyState()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _PeriodSwitch(period: _period, settings: settings, onChanged: (p) => setState(() => _period = p)),
                const SizedBox(height: 16),
                _SummaryCard(
                  icon: Icons.timer_outlined,
                  label: _periodLabel(_period, settings),
                  value: _formatHours(periodSeconds),
                  color: kPrimaryColor,
                  wide: true,
                ),
                const SizedBox(height: 16),
                _TrendChart(trend: trend, period: _period),
                const SizedBox(height: 16),
                const _SectionTitle('Time by subject'),
                const SizedBox(height: 12),
                _SubjectTimeBreakdown(perSubjectSeconds: periodSubjectSeconds, appData: appData, locale: locale),
                const SizedBox(height: 26),
                if (mostStudied != null) ...[
                  _MostStudiedBanner(subject: mostStudied, locale: locale, seconds: appData.secondsPerSubject()[mostStudied.id!] ?? 0),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        icon: Icons.local_fire_department,
                        label: 'Day streak',
                        value: '$streak',
                        color: const Color(0xFFFB923C),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        icon: Icons.hourglass_bottom,
                        label: 'Avg session',
                        value: _formatHours(avgSession, shortZero: true),
                        color: kAccentColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        icon: Icons.check_circle_outline,
                        label: settings.t('syllabus'),
                        value: '${(overallChapterRatio * 100).round()}%',
                        color: const Color(0xFF4ADE80),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        icon: Icons.refresh,
                        label: settings.t('revision'),
                        value: '${(overallRevisionRatio * 100).round()}%',
                        color: const Color(0xFFFBBF24),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                const _SectionTitle('Routine completion (7 days)'),
                const SizedBox(height: 12),
                FutureBuilder<double>(
                  future: routine.completionRateSince(7),
                  builder: (context, snapshot) {
                    final rate = snapshot.data ?? 0;
                    return _RoutineCompletionCard(rate: rate, hasData: snapshot.hasData);
                  },
                ),
                if (topChapters.isNotEmpty) ...[
                  const SizedBox(height: 26),
                  const _SectionTitle('Most-studied chapters'),
                  const SizedBox(height: 12),
                  _TopChaptersList(chapters: topChapters),
                ],
                const SizedBox(height: 26),
                const _SectionTitle('Progress by subject'),
                const SizedBox(height: 12),
                _SubjectProgressList(appData: appData, locale: locale, settings: settings, subjectList: subjectList),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  String _periodLabel(AnalyticsPeriod p, SettingsProvider s) {
    switch (p) {
      case AnalyticsPeriod.daily:
        return '${s.t('daily')} · ${s.t('total_study_time')}';
      case AnalyticsPeriod.weekly:
        return '${s.t('weekly')} · ${s.t('total_study_time')}';
      case AnalyticsPeriod.monthly:
        return '${s.t('monthly')} · ${s.t('total_study_time')}';
    }
  }

  String _formatHours(int totalSeconds, {bool shortZero = false}) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h == 0 && m == 0) return shortZero ? '${s}s' : '0m';
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }
}

class _PeriodSwitch extends StatelessWidget {
  final AnalyticsPeriod period;
  final SettingsProvider settings;
  final ValueChanged<AnalyticsPeriod> onChanged;

  const _PeriodSwitch({required this.period, required this.settings, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final options = [
      (AnalyticsPeriod.daily, settings.t('daily')),
      (AnalyticsPeriod.weekly, settings.t('weekly')),
      (AnalyticsPeriod.monthly, settings.t('monthly')),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor),
      ),
      child: Row(
        children: options.map((o) {
          final selected = period == o.$1;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: () => onChanged(o.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? kPrimaryColor.withOpacity(0.18) : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  o.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? kPrimaryColor : kTextMuted,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insights_outlined, size: 56, color: kBorderColor),
            const SizedBox(height: 16),
            const Text(
              'No data yet. Run a study session or tick off a chapter to see analytics here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kTextMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: kTextPrimary));
  }
}

class _MostStudiedBanner extends StatelessWidget {
  final dynamic subject;
  final String locale;
  final int seconds;

  const _MostStudiedBanner({required this.subject, required this.locale, required this.seconds});

  @override
  Widget build(BuildContext context) {
    final minutes = seconds ~/ 60;
    final color = Color(subject.colorValue as int);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.22), kSurfaceColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events_outlined, color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Most studied subject', style: TextStyle(fontSize: 11.5, color: kTextSecondary)),
                const SizedBox(height: 2),
                Text(
                  '${subject.localizedName(locale)} · ${minutes}m',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool wide;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kTextPrimary)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: kTextSecondary)),
        ],
      ),
    );
  }
}

class _RoutineCompletionCard extends StatelessWidget {
  final double rate;
  final bool hasData;

  const _RoutineCompletionCard({required this.rate, required this.hasData});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderColor),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            height: 46,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: hasData ? rate : 0,
                  strokeWidth: 5,
                  backgroundColor: kBorderColor,
                  valueColor: const AlwaysStoppedAnimation(kAccentColor),
                ),
                Text('${(rate * 100).round()}%',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextPrimary)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Of routine tasks you marked in the last 7 days, this many were completed rather than missed.',
              style: TextStyle(fontSize: 12, color: kTextSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<MapEntry<DateTime, int>> trend;
  final AnalyticsPeriod period;

  const _TrendChart({required this.trend, required this.period});

  @override
  Widget build(BuildContext context) {
    final maxMinutes = trend.map((e) => e.value / 60).fold<double>(1, (a, b) => a > b ? a : b);

    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderColor),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxMinutes * 1.2 + 1,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= trend.length) return const SizedBox.shrink();
                  final day = trend[idx].key;
                  final label = switch (period) {
                    AnalyticsPeriod.daily => DateFormat('E').format(day).substring(0, 2),
                    AnalyticsPeriod.weekly => DateFormat('d/M').format(day),
                    AnalyticsPeriod.monthly => DateFormat('MMM').format(day),
                  };
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(label, style: const TextStyle(fontSize: 10, color: kTextMuted)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (int i = 0; i < trend.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: trend[i].value / 60,
                    width: period == AnalyticsPeriod.daily ? 18 : 14,
                    borderRadius: BorderRadius.circular(4),
                    color: kPrimaryColor,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TopChaptersList extends StatelessWidget {
  final List<MapEntry<String, int>> chapters;

  const _TopChaptersList({required this.chapters});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        children: [
          for (int i = 0; i < chapters.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Text('${i + 1}', style: const TextStyle(fontSize: 12, color: kTextMuted, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(chapters[i].key,
                        style: const TextStyle(fontSize: 13, color: kTextPrimary), overflow: TextOverflow.ellipsis),
                  ),
                  Text('${chapters[i].value ~/ 60}m',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kAccentColor)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SubjectTimeBreakdown extends StatelessWidget {
  final Map<int, int> perSubjectSeconds;
  final AppDataProvider appData;
  final String locale;

  const _SubjectTimeBreakdown({required this.perSubjectSeconds, required this.appData, required this.locale});

  @override
  Widget build(BuildContext context) {
    if (perSubjectSeconds.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kSurfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorderColor),
        ),
        child: const Center(child: Text('No sessions in this period.', style: TextStyle(color: kTextMuted))),
      );
    }

    final entries = perSubjectSeconds.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxSeconds = entries.first.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        children: entries.map((e) {
          final subject = appData.subjectById(e.key);
          if (subject == null) return const SizedBox.shrink();
          final ratio = maxSeconds == 0 ? 0.0 : e.value / maxSeconds;
          final minutes = e.value ~/ 60;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 92,
                  child: Text(subject.localizedName(locale),
                      style: const TextStyle(fontSize: 12.5, color: kTextSecondary), overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 9,
                      backgroundColor: kBorderColor,
                      valueColor: AlwaysStoppedAnimation(Color(subject.colorValue)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  child: Text('${minutes}m',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextPrimary)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SubjectProgressList extends StatelessWidget {
  final AppDataProvider appData;
  final String locale;
  final SettingsProvider settings;
  final List<Subject> subjectList;

  const _SubjectProgressList({
    required this.appData,
    required this.locale,
    required this.settings,
    required this.subjectList,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: subjectList.map((s) {
        final chapters = appData.chaptersBySubject[s.id!] ?? [];
        final chDone = chapters.where((c) => c.chapterComplete).length;
        final revDone = chapters.where((c) => c.revisionComplete).length;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: kSurfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: Color(s.colorValue), shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(s.localizedName(locale), style: const TextStyle(fontSize: 13.5, color: kTextPrimary)),
              ),
              Text(
                '${settings.t('syllabus')} $chDone/${chapters.length} · ${settings.t('revision')} $revDone/${chapters.length}',
                style: const TextStyle(fontSize: 11, color: kTextMuted),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
