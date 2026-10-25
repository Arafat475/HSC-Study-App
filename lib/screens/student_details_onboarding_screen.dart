import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../main.dart';

/// Asked once, right after signing up (or logging in, if a restore didn't
/// already fill this in) -- the student ID card details. Skippable, since
/// nothing else in the app depends on it; it can always be filled in later
/// from My Details.
class StudentDetailsOnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const StudentDetailsOnboardingScreen({super.key, required this.onDone});

  @override
  State<StudentDetailsOnboardingScreen> createState() => _StudentDetailsOnboardingScreenState();
}

class _StudentDetailsOnboardingScreenState extends State<StudentDetailsOnboardingScreen> {
  final _nameController = TextEditingController();
  final _institutionController = TextEditingController();
  final _yearController = TextEditingController();

  Future<void> _save() async {
    final settings = context.read<SettingsProvider>();
    if (_nameController.text.trim().isNotEmpty ||
        _institutionController.text.trim().isNotEmpty ||
        _yearController.text.trim().isNotEmpty) {
      await settings.setStudentProfile(
        name: _nameController.text.trim(),
        institution: _institutionController.text.trim(),
        year: _yearController.text.trim(),
      );
    }
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Icon(Icons.badge_outlined, size: 44, color: c.primary),
              const SizedBox(height: 18),
              Text(
                "Let's set up your student ID",
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: c.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Shown on your profile card. You can skip and fill this in later.',
                style: TextStyle(fontSize: 13, color: c.textSecondary),
              ),
              const SizedBox(height: 28),
              _field(c, _nameController, 'Full name'),
              const SizedBox(height: 12),
              _field(c, _institutionController, 'School / College name'),
              const SizedBox(height: 12),
              _field(c, _yearController, 'Year (e.g. 2027)'),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: c.primary,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _save,
                child: const Text('Continue', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: widget.onDone,
                  child: Text('Skip for now', style: TextStyle(color: c.textMuted, fontSize: 13)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(dynamic c, TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      style: TextStyle(color: c.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.textMuted, fontSize: 13.5),
        filled: true,
        fillColor: c.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.primary)),
      ),
    );
  }
}
