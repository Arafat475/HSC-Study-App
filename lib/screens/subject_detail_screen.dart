import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import '../providers/settings_provider.dart';
import '../models/subject.dart';
import '../models/chapter.dart';
import '../main.dart';
import '../widgets/neon_grid_background.dart';
import '../widgets/language_toggle.dart';

class SubjectDetailScreen extends StatelessWidget {
  final Subject subject;

  const SubjectDetailScreen({super.key, required this.subject});

  @override
  Widget build(BuildContext context) {
    final appData = context.watch<AppDataProvider>();
    final settings = context.watch<SettingsProvider>();
    final locale = settings.locale;
    final chapters = appData.chaptersBySubject[subject.id!] ?? [];
    final color = Color(subject.colorValue);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          subject.localizedName(locale),
          style: TextStyle(shadows: [Shadow(color: color.withOpacity(0.8), blurRadius: 14)]),
        ),
        actions: const [LanguageToggle()],
      ),
      body: NeonGridBackground(
        child: Column(
          children: [
            _HeaderSummary(chapters: chapters, color: color, settings: settings),
            _Legend(color: color, settings: settings),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                itemCount: chapters.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final chapter = chapters[index];
                  return _ChapterCard(
                    index: index + 1,
                    chapter: chapter,
                    color: color,
                    locale: locale,
                    settings: settings,
                    onChapterToggle: (v) =>
                        context.read<AppDataProvider>().toggleChapterComplete(chapter, v),
                    onRevisionToggle: (v) =>
                        context.read<AppDataProvider>().toggleRevisionComplete(chapter, v),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderSummary extends StatelessWidget {
  final List<Chapter> chapters;
  final Color color;
  final SettingsProvider settings;

  const _HeaderSummary({required this.chapters, required this.color, required this.settings});

  @override
  Widget build(BuildContext context) {
    final total = chapters.length;
    final chDone = chapters.where((c) => c.chapterComplete).length;
    final revDone = chapters.where((c) => c.revisionComplete).length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF12141A).withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 20, spreadRadius: 1)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatChip(label: settings.t('syllabus'), value: '$chDone/$total', color: color),
          Container(width: 1, height: 34, color: kBorderColor),
          _StatChip(label: settings.t('revision'), value: '$revDone/$total', color: kAccentColor),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            shadows: [Shadow(color: color.withOpacity(0.9), blurRadius: 14)],
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: kTextSecondary)),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final SettingsProvider settings;
  const _Legend({required this.color, required this.settings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          Icon(Icons.menu_book, size: 13, color: color),
          const SizedBox(width: 5),
          Text('= ${settings.t('chapter_studied').toLowerCase()}',
              style: const TextStyle(fontSize: 11.5, color: kTextMuted)),
          const SizedBox(width: 14),
          const Icon(Icons.refresh, size: 13, color: kAccentColor),
          const SizedBox(width: 5),
          Text('= ${settings.t('revision_done').toLowerCase()}',
              style: const TextStyle(fontSize: 11.5, color: kTextMuted)),
        ],
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  final int index;
  final Chapter chapter;
  final Color color;
  final String locale;
  final SettingsProvider settings;
  final ValueChanged<bool> onChapterToggle;
  final ValueChanged<bool> onRevisionToggle;

  const _ChapterCard({
    required this.index,
    required this.chapter,
    required this.color,
    required this.locale,
    required this.settings,
    required this.onChapterToggle,
    required this.onRevisionToggle,
  });

  @override
  Widget build(BuildContext context) {
    final bothDone = chapter.chapterComplete && chapter.revisionComplete;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF12141A).withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderColor),
        boxShadow: bothDone
            ? [BoxShadow(color: kAccentColor.withOpacity(0.15), blurRadius: 14, spreadRadius: 1)]
            : [],
      ),
      padding: const EdgeInsets.all(4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              margin: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: bothDone ? kAccentColor : color.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 22,
                          child: Text('$index', style: const TextStyle(color: kTextMuted, fontSize: 12)),
                        ),
                        Expanded(
                          child: Text(
                            chapter.localizedTitle(locale),
                            style: TextStyle(
                              fontSize: 14.5,
                              color: chapter.chapterComplete ? kTextSecondary : kTextPrimary,
                              decoration: chapter.chapterComplete ? TextDecoration.lineThrough : null,
                              decorationColor: kTextMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const SizedBox(width: 22),
                        Expanded(
                          child: _LabeledToggle(
                            icon: Icons.menu_book,
                            label: settings.t('chapter_studied'),
                            value: chapter.chapterComplete,
                            color: color,
                            onChanged: onChapterToggle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _LabeledToggle(
                            icon: Icons.refresh,
                            label: settings.t('revision_done'),
                            value: chapter.revisionComplete,
                            color: kAccentColor,
                            onChanged: onRevisionToggle,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;

  const _LabeledToggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: value ? color.withOpacity(0.16) : kSurfaceColor,
          border: Border.all(color: value ? color : kBorderColor),
          borderRadius: BorderRadius.circular(10),
          boxShadow: value
              ? [BoxShadow(color: color.withOpacity(0.45), blurRadius: 10, spreadRadius: 0.5)]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(value ? Icons.check_circle : icon, size: 15, color: value ? color : kTextMuted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: value ? color : kTextMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
