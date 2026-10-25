import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../main.dart';

/// Live-updating days/hrs/min/sec countdown to the user's exam date, with
/// an edit button to set/change it. Shown at the top of the Timer screen.
class ExamCountdownCard extends StatefulWidget {
  const ExamCountdownCard({super.key});

  @override
  State<ExamCountdownCard> createState() => _ExamCountdownCardState();
}

class _ExamCountdownCardState extends State<ExamCountdownCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final c = context.colors;

    if (settings.examDate == null) {
      return _SetExamPrompt(settings: settings);
    }

    final remaining = settings.examDate!.difference(DateTime.now());
    final isPast = remaining.isNegative;
    final d = isPast ? 0 : remaining.inDays;
    final h = isPast ? 0 : remaining.inHours % 24;
    final m = isPast ? 0 : remaining.inMinutes % 60;
    final s = isPast ? 0 : remaining.inSeconds % 60;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: c.isDark
            ? const LinearGradient(
                colors: [Color(0xFF2A1F45), Color(0xFF15121F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [c.primary.withOpacity(0.12), c.surface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.primary.withOpacity(0.4)),
        boxShadow: c.isDark ? [BoxShadow(color: c.primary.withOpacity(0.15), blurRadius: 18)] : [],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  settings.examName ?? '',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () => _showExamDialog(context, settings),
                child: Icon(Icons.edit, size: 16, color: c.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TimeBox(value: d, label: settings.t('days')),
              _TimeBox(value: h, label: settings.t('hours')),
              _TimeBox(value: m, label: settings.t('minutes')),
              _TimeBox(value: s, label: settings.t('seconds')),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            DateFormat('EEEE, d MMM yyyy').format(settings.examDate!),
            style: TextStyle(fontSize: 11.5, color: c.textMuted),
          ),
        ],
      ),
    );
  }

  void _showExamDialog(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (ctx) => _ExamEditDialog(settings: settings),
    );
  }
}

class _TimeBox extends StatelessWidget {
  final int value;
  final String label;
  const _TimeBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.border),
          ),
          child: Text(
            value.toString().padLeft(2, '0'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.textPrimary),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: c.textMuted, letterSpacing: 0.5)),
      ],
    );
  }
}

class _SetExamPrompt extends StatelessWidget {
  final SettingsProvider settings;
  const _SetExamPrompt({required this.settings});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => showDialog(context: context, builder: (ctx) => _ExamEditDialog(settings: settings)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Icon(Icons.event_outlined, color: c.accent, size: 18),
            const SizedBox(width: 10),
            Text(settings.t('set_exam_date'), style: TextStyle(color: c.textSecondary, fontSize: 13.5)),
          ],
        ),
      ),
    );
  }
}

class _ExamEditDialog extends StatefulWidget {
  final SettingsProvider settings;
  const _ExamEditDialog({required this.settings});

  @override
  State<_ExamEditDialog> createState() => _ExamEditDialogState();
}

class _ExamEditDialogState extends State<_ExamEditDialog> {
  late TextEditingController _nameController;
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.settings.examName ?? 'HSC Exam');
    _date = widget.settings.examDate;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AlertDialog(
      backgroundColor: c.surfaceAlt,
      title: Text(widget.settings.t('set_exam_date'), style: TextStyle(color: c.textPrimary, fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            style: TextStyle(color: c.textPrimary),
            decoration: InputDecoration(
              labelText: 'Exam name',
              labelStyle: TextStyle(color: c.textMuted),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: c.border)),
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date ?? DateTime.now().add(const Duration(days: 30)),
                firstDate: DateTime.now(),
                lastDate: DateTime(2030),
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme(
                      brightness: c.isDark ? Brightness.dark : Brightness.light,
                      primary: c.primary,
                      onPrimary: Colors.white,
                      secondary: c.accent,
                      onSecondary: Colors.white,
                      surface: c.surfaceAlt,
                      onSurface: c.textPrimary,
                      error: c.danger,
                      onError: Colors.white,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _date = picked);
            },
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: c.accent),
                const SizedBox(width: 10),
                Text(
                  _date != null ? DateFormat('d MMM yyyy').format(_date!) : 'Select date',
                  style: TextStyle(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
        ),
        TextButton(
          onPressed: _date == null || _nameController.text.trim().isEmpty
              ? null
              : () {
                  widget.settings.setExam(_nameController.text.trim(), _date!);
                  Navigator.pop(context);
                },
          child: Text('Save', style: TextStyle(color: c.primary)),
        ),
      ],
    );
  }
}
