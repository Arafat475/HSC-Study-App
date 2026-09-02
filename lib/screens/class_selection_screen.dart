import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../data/seed_data.dart';
import '../main.dart';

/// Shown once, before the rest of the app, so every screen (Timer,
/// Progress, Analytics) can filter its subject list to what's actually
/// relevant instead of showing all 42 subjects across every class/group.
class ClassSelectionScreen extends StatefulWidget {
  const ClassSelectionScreen({super.key});

  @override
  State<ClassSelectionScreen> createState() => _ClassSelectionScreenState();
}

class _ClassSelectionScreenState extends State<ClassSelectionScreen> {
  EduLevel? _level;
  EduGroup? _group;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Study Planner',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: kTextPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'For SSC & HSC Students',
                style: TextStyle(fontSize: 13, color: kTextSecondary),
              ),
              const SizedBox(height: 36),
              const Text(
                "Which class are you in?",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kTextPrimary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _OptionCard(
                      label: 'SSC',
                      subtitle: 'Class 9-10',
                      selected: _level == EduLevel.ssc,
                      onTap: () => setState(() => _level = EduLevel.ssc),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _OptionCard(
                      label: 'HSC',
                      subtitle: 'Class 11-12',
                      selected: _level == EduLevel.hsc,
                      onTap: () => setState(() => _level = EduLevel.hsc),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              if (_level != null) ...[
                const Text(
                  'Which group?',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kTextPrimary),
                ),
                const SizedBox(height: 12),
                _OptionCard(
                  label: 'Science',
                  subtitle: 'Physics, Chemistry, Biology, Higher Math',
                  selected: _group == EduGroup.science,
                  onTap: () => setState(() => _group = EduGroup.science),
                  wide: true,
                ),
                const SizedBox(height: 10),
                _OptionCard(
                  label: 'Business Studies',
                  subtitle: 'Accounting, Finance & Banking, Management, Marketing',
                  selected: _group == EduGroup.business,
                  onTap: () => setState(() => _group = EduGroup.business),
                  wide: true,
                ),
                const SizedBox(height: 10),
                _OptionCard(
                  label: 'Humanities',
                  subtitle: 'History, Civics, Economics, Sociology, Logic',
                  selected: _group == EduGroup.humanities,
                  onTap: () => setState(() => _group = EduGroup.humanities),
                  wide: true,
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: (_level != null && _group != null)
                      ? () => context.read<SettingsProvider>().setClassAndGroup(_level!, _group!)
                      : null,
                  child: const Text('Continue', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final bool wide;

  const _OptionCard({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: wide ? double.infinity : null,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? kPrimaryColor.withOpacity(0.15) : kSurfaceColor,
          border: Border.all(color: selected ? kPrimaryColor : kBorderColor, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: selected ? kPrimaryColor : kTextPrimary,
                    ),
                  ),
                ),
                if (selected) const Icon(Icons.check_circle, color: kPrimaryColor, size: 18),
              ],
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 11.5, color: kTextMuted)),
          ],
        ),
      ),
    );
  }
}
