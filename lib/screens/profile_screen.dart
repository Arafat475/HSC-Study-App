import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../data/seed_data.dart';
import '../main.dart';
import '../widgets/language_toggle.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Details'),
        actions: const [LanguageToggle()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StudentCard(settings: settings),
          const SizedBox(height: 24),
          const _SectionLabel('Alerts'),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              _ToggleRow(
                icon: Icons.music_note,
                label: settings.t('sound_alert'),
                value: settings.soundAlert,
                onChanged: settings.setSoundAlert,
              ),
              if (settings.soundAlert) ...[
                const SizedBox(height: 4),
                _VolumeSlider(settings: settings),
              ],
              const Divider(color: kBorderColor, height: 24),
              _ToggleRow(
                icon: Icons.vibration,
                label: settings.t('vibration_alert'),
                value: settings.vibrationAlert,
                onChanged: settings.setVibrationAlert,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Notifications'),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              _ToggleRow(
                icon: Icons.notifications_active_outlined,
                label: 'Task reminders',
                value: settings.taskReminders,
                onChanged: settings.setTaskReminders,
              ),
              const Divider(color: kBorderColor, height: 24),
              _ToggleRow(
                icon: Icons.timer_outlined,
                label: 'Show timer in notification bar',
                value: settings.showTimerNotification,
                onChanged: settings.setShowTimerNotification,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Language'),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              Row(
                children: [
                  const Icon(Icons.translate, size: 18, color: kTextSecondary),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('App language', style: TextStyle(fontSize: 14.5, color: kTextPrimary))),
                  _LanguagePillGroup(settings: settings),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Class & Group'),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              Row(
                children: [
                  const Icon(Icons.school_outlined, size: 18, color: kTextSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _classGroupLabel(settings),
                      style: const TextStyle(fontSize: 14.5, color: kTextPrimary),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _confirmChangeClass(context, settings),
                    child: const Text('Change', style: TextStyle(color: kPrimaryColor)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _classGroupLabel(SettingsProvider settings) {
    if (settings.eduLevel == null) return 'Not set';
    final level = settings.eduLevel == EduLevel.ssc ? 'SSC' : 'HSC';
    final group = switch (settings.eduGroup) {
      EduGroup.science => 'Science',
      EduGroup.business => 'Business Studies',
      EduGroup.humanities => 'Humanities',
      _ => '',
    };
    return '$level · $group';
  }

  void _confirmChangeClass(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurfaceColorAlt,
        title: const Text('Change class/group?', style: TextStyle(color: kTextPrimary, fontSize: 16)),
        content: const Text(
          "You'll be asked to pick your class and group again. Your subjects, timer history, and chapter progress stay saved.",
          style: TextStyle(color: kTextSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: kTextSecondary)),
          ),
          TextButton(
            onPressed: () {
              settings.clearClassSelection();
              Navigator.pop(ctx);
            },
            child: const Text('Change', style: TextStyle(color: kPrimaryColor)),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextSecondary));
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(children: children),
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  final SettingsProvider settings;
  const _VolumeSlider({required this.settings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 30, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.volume_down, size: 16, color: kTextMuted),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: kPrimaryColor,
                    inactiveTrackColor: kBorderColor,
                    thumbColor: kPrimaryColor,
                    overlayColor: kPrimaryColor.withOpacity(0.2),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: settings.alertVolume,
                    onChanged: settings.setAlertVolume,
                  ),
                ),
              ),
              const Icon(Icons.volume_up, size: 16, color: kTextMuted),
            ],
          ),
          const Text(
            "When your timer goal ends, the alarm repeats until you respond (end or extend).",
            style: TextStyle(fontSize: 11, color: kTextMuted),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({required this.icon, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: kTextSecondary),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14.5, color: kTextPrimary))),
        Switch(value: value, onChanged: onChanged, activeColor: kPrimaryColor),
      ],
    );
  }
}

class _LanguagePillGroup extends StatelessWidget {
  final SettingsProvider settings;
  const _LanguagePillGroup({required this.settings});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pill('বাং', settings.locale == 'bn', () => settings.setLocale('bn')),
        const SizedBox(width: 6),
        _pill('EN', settings.locale == 'en', () => settings.setLocale('en')),
      ],
    );
  }

  Widget _pill(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? kPrimaryColor.withOpacity(0.2) : Colors.transparent,
          border: Border.all(color: selected ? kPrimaryColor : kBorderColor),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: selected ? kPrimaryColor : kTextMuted),
        ),
      ),
    );
  }
}

/// The "student ID card" -- name, institution, year, class/group, with an
/// edit button. Purely local (shared_preferences) for now; this is the
/// natural place a future sign-up/backup flow would hang off of.
class _StudentCard extends StatelessWidget {
  final SettingsProvider settings;
  const _StudentCard({required this.settings});

  @override
  Widget build(BuildContext context) {
    final hasProfile = settings.studentName != null && settings.studentName!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A1F45), Color(0xFF15121F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kPrimaryColor.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: kPrimaryColor.withOpacity(0.15), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: kAccentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'STUDENT ID',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kAccentColor, letterSpacing: 1),
                ),
              ),
              InkWell(
                onTap: () => _showEditSheet(context, settings),
                child: const Icon(Icons.edit, size: 18, color: kTextMuted),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: kPrimaryColor.withOpacity(0.5)),
                ),
                child: const Icon(Icons.person, color: kPrimaryColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasProfile ? settings.studentName! : 'Add your name',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kTextPrimary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasProfile && (settings.studentInstitution?.isNotEmpty ?? false)
                          ? settings.studentInstitution!
                          : 'School / College not set',
                      style: const TextStyle(fontSize: 12.5, color: kTextSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasProfile && (settings.studentYear?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 16),
            Container(height: 1, color: kBorderColor),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 13, color: kTextMuted),
                const SizedBox(width: 8),
                Text('Year: ${settings.studentYear}', style: const TextStyle(fontSize: 12.5, color: kTextSecondary)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurfaceColorAlt,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _EditProfileSheet(settings: settings),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  final SettingsProvider settings;
  const _EditProfileSheet({required this.settings});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _institutionController;
  late final TextEditingController _yearController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.settings.studentName ?? '');
    _institutionController = TextEditingController(text: widget.settings.studentInstitution ?? '');
    _yearController = TextEditingController(text: widget.settings.studentYear ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Edit details', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kTextPrimary)),
          const SizedBox(height: 16),
          _field(_nameController, 'Full name'),
          const SizedBox(height: 12),
          _field(_institutionController, 'School / College name'),
          const SizedBox(height: 12),
          _field(_yearController, 'Year (e.g. 2027)'),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: kPrimaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                widget.settings.setStudentProfile(
                  name: _nameController.text.trim(),
                  institution: _institutionController.text.trim(),
                  year: _yearController.text.trim(),
                );
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: kTextPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kTextMuted, fontSize: 13.5),
        filled: true,
        fillColor: kSurfaceColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kPrimaryColor)),
      ),
    );
  }
}
