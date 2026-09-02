import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import '../providers/settings_provider.dart';
import '../models/subject.dart';
import '../main.dart';
import '../widgets/language_toggle.dart';
import 'subject_detail_screen.dart';

enum _ProgressTab { syllabus, revision }

class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> {
  _ProgressTab _tab = _ProgressTab.syllabus;

  @override
  Widget build(BuildContext context) {
    final appData = context.watch<AppDataProvider>();
    final settings = context.watch<SettingsProvider>();
    final locale = settings.locale;

    if (appData.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: kPrimaryColor)));
    }

    final subjectList = appData.subjectsForLevelGroup(settings.eduLevel!, settings.eduGroup!);
    final isSyllabus = _tab == _ProgressTab.syllabus;
    final allChapters = subjectList.expand((s) => appData.chaptersBySubject[s.id!] ?? []).toList();
    final overallDone = isSyllabus
        ? allChapters.where((c) => c.chapterComplete).length
        : allChapters.where((c) => c.revisionComplete).length;
    final overallRatio = allChapters.isEmpty ? 0.0 : overallDone / allChapters.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('nav_progress')),
        actions: const [LanguageToggle()],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _TabSwitch(
              tab: _tab,
              settings: settings,
              onChanged: (t) => setState(() => _tab = t),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: _OverallRing(ratio: overallRatio, isSyllabus: isSyllabus),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: subjectList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final subject = subjectList[index];
                final chapters = appData.chaptersBySubject[subject.id!] ?? [];
                final done = isSyllabus
                    ? chapters.where((c) => c.chapterComplete).length
                    : chapters.where((c) => c.revisionComplete).length;
                final total = chapters.length;

                return _SubjectCard(
                  subject: subject,
                  locale: locale,
                  done: done,
                  total: total,
                  settings: settings,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => SubjectDetailScreen(subject: subject)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TabSwitch extends StatelessWidget {
  final _ProgressTab tab;
  final SettingsProvider settings;
  final ValueChanged<_ProgressTab> onChanged;

  const _TabSwitch({required this.tab, required this.settings, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: settings.t('syllabus'),
              selected: tab == _ProgressTab.syllabus,
              onTap: () => onChanged(_ProgressTab.syllabus),
            ),
          ),
          Expanded(
            child: _TabButton(
              label: settings.t('revision'),
              selected: tab == _ProgressTab.revision,
              onTap: () => onChanged(_ProgressTab.revision),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? kPrimaryColor.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: selected ? kPrimaryColor : kTextMuted,
          ),
        ),
      ),
    );
  }
}

class _OverallRing extends StatelessWidget {
  final double ratio;
  final bool isSyllabus;

  const _OverallRing({required this.ratio, required this.isSyllabus});

  @override
  Widget build(BuildContext context) {
    final color = isSyllabus ? kPrimaryColor : kAccentColor;
    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 130,
            height: 130,
            child: CircularProgressIndicator(
              value: ratio,
              strokeWidth: 10,
              backgroundColor: kBorderColor,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(ratio * 100).round()}%',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  shadows: [Shadow(color: color.withOpacity(0.7), blurRadius: 14)],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final Subject subject;
  final String locale;
  final int done;
  final int total;
  final SettingsProvider settings;
  final VoidCallback onTap;

  const _SubjectCard({
    required this.subject,
    required this.locale,
    required this.done,
    required this.total,
    required this.settings,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(subject.colorValue);
    final remaining = total - done;
    final ratio = total == 0 ? 0.0 : done / total;

    return Material(
      color: kSurfaceColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.menu_book, color: color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      subject.localizedName(locale),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kTextPrimary),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: kTextMuted, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 7,
                  backgroundColor: kBorderColor,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${settings.t('completed')}: $done · ${settings.t('remaining')}: $remaining / $total',
                style: const TextStyle(fontSize: 12, color: kTextSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
