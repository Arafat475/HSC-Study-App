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
        gradient: const LinearGradient(
          colors: [Color(0xFF2A1F45), Color(0xFF15121F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrimaryColor.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: kPrimaryColor.withOpacity(0.15), blurRadius: 18)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  settings.examName ?? '',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () => _showExamDialog(context, settings),
                child: const Icon(Icons.edit, size: 16, color: kTextMuted),
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
            style: const TextStyle(fontSize: 11.5, color: kTextMuted),
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
    return Column(
      children: [
        Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: kSurfaceColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kBorderColor),
          ),
          child: Text(
            value.toString().padLeft(2, '0'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kTextPrimary),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: kTextMuted, letterSpacing: 0.5)),
      ],
    );
  }
}

class _SetExamPrompt extends StatelessWidget {
  final SettingsProvider settings;
  const _SetExamPrompt({required this.settings});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => showDialog(context: context, builder: (ctx) => _ExamEditDialog(settings: settings)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: kSurfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorderColor),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_outlined, color: kAccentColor, size: 18),
            const SizedBox(width: 10),
            Text(settings.t('set_exam_date'), style: const TextStyle(color: kTextSecondary, fontSize: 13.5)),
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
    return AlertDialog(
      backgroundColor: kSurfaceColorAlt,
      title: Text(widget.settings.t('set_exam_date'), style: const TextStyle(color: kTextPrimary, fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            style: const TextStyle(color: kTextPrimary),
            decoration: const InputDecoration(
              labelText: 'Exam name',
              labelStyle: TextStyle(color: kTextMuted),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: kBorderColor)),
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
                    colorScheme: const ColorScheme.dark(
                      primary: kPrimaryColor,
                      onPrimary: Colors.white,
                      surface: kSurfaceColorAlt,
                      onSurface: kTextPrimary,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _date = picked);
            },
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: kAccentColor),
                const SizedBox(width: 10),
                Text(
                  _date != null ? DateFormat('d MMM yyyy').format(_date!) : 'Select date',
                  style: const TextStyle(color: kTextSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: kTextSecondary)),
        ),
        TextButton(
          onPressed: _date == null || _nameController.text.trim().isEmpty
              ? null
              : () {
                  widget.settings.setExam(_nameController.text.trim(), _date!);
                  Navigator.pop(context);
                },
          child: const Text('Save', style: TextStyle(color: kPrimaryColor)),
        ),
      ],
    );
  }
}
