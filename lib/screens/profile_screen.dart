import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/settings_provider.dart';
import '../providers/app_data_provider.dart';
import '../providers/routine_provider.dart';
import '../data/seed_data.dart';
import '../main.dart';
import '../theme/app_colors.dart';
import '../widgets/language_toggle.dart';
import '../services/auth_service.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Details'),
        actions: const [LanguageToggle()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StudentCard(settings: settings, c: c),
          const SizedBox(height: 24),
          _SectionLabel('Account & Backup', c: c),
          const SizedBox(height: 10),
          const _AccountSection(),
          const SizedBox(height: 24),
          _SectionLabel('Appearance', c: c),
          const SizedBox(height: 10),
          _SettingsCard(
            c: c,
            children: [
              _ToggleRow(
                icon: c.isDark ? Icons.dark_mode : Icons.light_mode,
                label: 'Dark mode',
                value: settings.isDarkMode,
                onChanged: settings.setIsDarkMode,
                c: c,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionLabel('Alerts', c: c),
          const SizedBox(height: 10),
          _SettingsCard(
            c: c,
            children: [
              _ToggleRow(
                icon: Icons.music_note,
                label: settings.t('sound_alert'),
                value: settings.soundAlert,
                onChanged: settings.setSoundAlert,
                c: c,
              ),
              if (settings.soundAlert) ...[
                const SizedBox(height: 4),
                _VolumeSlider(settings: settings, c: c),
              ],
              Divider(color: c.border, height: 24),
              _ToggleRow(
                icon: Icons.vibration,
                label: settings.t('vibration_alert'),
                value: settings.vibrationAlert,
                onChanged: settings.setVibrationAlert,
                c: c,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionLabel('Notifications', c: c),
          const SizedBox(height: 10),
          _SettingsCard(
            c: c,
            children: [
              _ToggleRow(
                icon: Icons.notifications_active_outlined,
                label: 'Task reminders',
                value: settings.taskReminders,
                onChanged: settings.setTaskReminders,
                c: c,
              ),
              Divider(color: c.border, height: 24),
              _ToggleRow(
                icon: Icons.timer_outlined,
                label: 'Show timer in notification bar',
                value: settings.showTimerNotification,
                onChanged: settings.setShowTimerNotification,
                c: c,
              ),
              Divider(color: c.border, height: 24),
              const _PermissionStatusRow(),
            ],
          ),
          const SizedBox(height: 24),
          _SectionLabel('Language', c: c),
          const SizedBox(height: 10),
          _SettingsCard(
            c: c,
            children: [
              Row(
                children: [
                  Icon(Icons.translate, size: 18, color: c.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(child: Text('App language', style: TextStyle(fontSize: 14.5, color: c.textPrimary))),
                  _LanguagePillGroup(settings: settings, c: c),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionLabel('Class & Group', c: c),
          const SizedBox(height: 10),
          _SettingsCard(
            c: c,
            children: [
              Row(
                children: [
                  Icon(Icons.school_outlined, size: 18, color: c.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _classGroupLabel(settings),
                      style: TextStyle(fontSize: 14.5, color: c.textPrimary),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _confirmChangeClass(context, settings),
                    child: Text('Change', style: TextStyle(color: c.primary)),
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
    final c = context.colorsNoWatch;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surfaceAlt,
        title: Text('Change class/group?', style: TextStyle(color: c.textPrimary, fontSize: 16)),
        content: Text(
          "You'll be asked to pick your class and group again. Your subjects, timer history, and chapter progress stay saved.",
          style: TextStyle(color: c.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              settings.clearClassSelection();
              Navigator.pop(ctx);
            },
            child: Text('Change', style: TextStyle(color: c.primary)),
          ),
        ],
      ),
    );
  }
}

/// Sign up/login, and once signed in, backup controls. Fully optional --
/// the whole app works offline without ever touching this section.
class _AccountSection extends StatelessWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return StreamBuilder<User?>(
      stream: AuthService.instance.userChanges,
      builder: (context, snapshot) {
        final user = snapshot.data;
        return _SettingsCard(
          c: c,
          children: [
            if (user == null) _SignedOutRow(c: c) else _SignedInRow(user: user, c: c),
          ],
        );
      },
    );
  }
}

class _SignedOutRow extends StatelessWidget {
  final AppColors c;
  const _SignedOutRow({required this.c});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.cloud_outlined, size: 18, color: c.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Sign up to back up your progress',
            style: TextStyle(fontSize: 14, color: c.textPrimary),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: c.primary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen())),
          child: const Text('Sign up'),
        ),
      ],
    );
  }
}

class _SignedInRow extends StatefulWidget {
  final User user;
  final AppColors c;
  const _SignedInRow({required this.user, required this.c});

  @override
  State<_SignedInRow> createState() => _SignedInRowState();
}

class _SignedInRowState extends State<_SignedInRow> {
  bool _busy = false;

  Future<void> _backupNow() async {
    setState(() => _busy = true);
    try {
      await BackupService.instance.backupNow(
        context.read<AppDataProvider>(),
        context.read<SettingsProvider>(),
      );
      if (mounted) _showSnack('Backed up successfully.');
    } catch (e) {
      if (mounted) _showSnack('Backup failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.c.surfaceAlt,
        title: Text('Restore backup?', style: TextStyle(color: widget.c.textPrimary, fontSize: 16)),
        content: Text(
          "This adds your backed-up chapter progress, sessions, and routine tasks to what's already on this device. Running it more than once can create duplicate sessions/tasks.",
          style: TextStyle(color: widget.c.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: widget.c.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Restore', style: TextStyle(color: widget.c.primary)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await BackupService.instance.restore(
        context.read<AppDataProvider>(),
        context.read<RoutineProvider>(),
        context.read<SettingsProvider>(),
      );
      if (mounted) _showSnack('Restored successfully.');
    } catch (e) {
      if (mounted) _showSnack('Restore failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.c.surfaceAlt,
        title: Text('Sign out?', style: TextStyle(color: widget.c.textPrimary, fontSize: 16)),
        content: Text(
          'Your data stays on this device either way -- signing out just disconnects backup until you sign in again.',
          style: TextStyle(color: widget.c.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: widget.c.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sign out', style: TextStyle(color: widget.c.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) await AuthService.instance.signOut();
  }

  void _showSnack(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: TextStyle(color: widget.c.textPrimary)),
        backgroundColor: widget.c.surfaceAlt,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.cloud_done_outlined, size: 18, color: c.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.user.email ?? 'Signed in',
                style: TextStyle(fontSize: 14, color: c.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_busy)
          Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: c.primary)))
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(side: BorderSide(color: c.border)),
                  onPressed: _backupNow,
                  child: Text('Back up now', style: TextStyle(color: c.textPrimary, fontSize: 12.5)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(side: BorderSide(color: c.border)),
                  onPressed: _restore,
                  child: Text('Restore', style: TextStyle(color: c.textPrimary, fontSize: 12.5)),
                ),
              ),
            ],
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _busy ? null : _signOut,
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
            child: Text('Sign out', style: TextStyle(color: c.danger, fontSize: 12.5)),
          ),
        ),
      ],
    );
  }
}

/// Android gives no feedback when a scheduled reminder silently never
/// fires because a permission got denied or revoked -- this surfaces that
/// state directly so it's not a silent mystery.
class _PermissionStatusRow extends StatefulWidget {
  const _PermissionStatusRow();

  @override
  State<_PermissionStatusRow> createState() => _PermissionStatusRowState();
}

class _PermissionStatusRowState extends State<_PermissionStatusRow> with WidgetsBindingObserver {
  bool? _notificationsGranted;
  bool? _exactAlarmsGranted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check when returning from the system permission screen.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final (notifications, exactAlarms) = await NotificationService.instance.permissionStatus();
    if (mounted) {
      setState(() {
        _notificationsGranted = notifications;
        _exactAlarmsGranted = exactAlarms;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bothGranted = _notificationsGranted == true && _exactAlarmsGranted == true;

    if (_notificationsGranted == null) {
      return const SizedBox.shrink();
    }

    if (bothGranted) {
      return Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: c.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Reminders are set up correctly', style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 16, color: c.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Some permissions are off, so reminders may not fire',
                style: TextStyle(fontSize: 12.5, color: c.textPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_notificationsGranted == false)
          Padding(
            padding: const EdgeInsets.only(left: 26, bottom: 6),
            child: TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), alignment: Alignment.centerLeft),
              onPressed: () => NotificationService.instance.requestNotificationPermission(),
              child: Text('Grant notification permission', style: TextStyle(color: c.primary, fontSize: 12.5)),
            ),
          ),
        if (_exactAlarmsGranted == false)
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), alignment: Alignment.centerLeft),
              onPressed: () => NotificationService.instance.requestExactAlarmPermission(),
              child: Text('Grant exact alarm permission', style: TextStyle(color: c.primary, fontSize: 12.5)),
            ),
          ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final AppColors c;
  const _SectionLabel(this.text, {required this.c});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textSecondary));
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  final AppColors c;
  const _SettingsCard({required this.children, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(children: children),
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  final SettingsProvider settings;
  final AppColors c;
  const _VolumeSlider({required this.settings, required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 30, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.volume_down, size: 16, color: c.textMuted),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: c.primary,
                    inactiveTrackColor: c.border,
                    thumbColor: c.primary,
                    overlayColor: c.primary.withOpacity(0.2),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: settings.alertVolume,
                    onChanged: settings.setAlertVolume,
                  ),
                ),
              ),
              Icon(Icons.volume_up, size: 16, color: c.textMuted),
            ],
          ),
          Text(
            "When your timer goal ends, the alarm repeats until you respond (end or extend).",
            style: TextStyle(fontSize: 11, color: c.textMuted),
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
  final AppColors c;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: c.textSecondary),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: TextStyle(fontSize: 14.5, color: c.textPrimary))),
        Switch(value: value, onChanged: onChanged, activeColor: c.primary),
      ],
    );
  }
}

class _LanguagePillGroup extends StatelessWidget {
  final SettingsProvider settings;
  final AppColors c;
  const _LanguagePillGroup({required this.settings, required this.c});

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
          color: selected ? c.primary.withOpacity(0.2) : Colors.transparent,
          border: Border.all(color: selected ? c.primary : c.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: selected ? c.primary : c.textMuted),
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
  final AppColors c;
  const _StudentCard({required this.settings, required this.c});

  @override
  Widget build(BuildContext context) {
    final hasProfile = settings.studentName != null && settings.studentName!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.primary.withOpacity(0.4)),
        boxShadow: c.isDark ? [BoxShadow(color: c.primary.withOpacity(0.15), blurRadius: 20)] : [],
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
                  color: c.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'STUDENT ID',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.accent, letterSpacing: 1),
                ),
              ),
              InkWell(
                onTap: () => _showEditSheet(context, settings),
                child: Icon(Icons.edit, size: 18, color: c.textMuted),
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
                  color: c.primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: c.primary.withOpacity(0.5)),
                ),
                child: Icon(Icons.person, color: c.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasProfile ? settings.studentName! : 'Add your name',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasProfile && (settings.studentInstitution?.isNotEmpty ?? false)
                          ? settings.studentInstitution!
                          : 'School / College not set',
                      style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasProfile && (settings.studentYear?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 16),
            Container(height: 1, color: c.border),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 13, color: c.textMuted),
                const SizedBox(width: 8),
                Text('Year: ${settings.studentYear}', style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, SettingsProvider settings) {
    final cc = context.colorsNoWatch;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cc.surfaceAlt,
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
    final c = context.colors;
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
          Text('Edit details', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.textPrimary)),
          const SizedBox(height: 16),
          _field(c, _nameController, 'Full name'),
          const SizedBox(height: 12),
          _field(c, _institutionController, 'School / College name'),
          const SizedBox(height: 12),
          _field(c, _yearController, 'Year (e.g. 2027)'),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: c.primary,
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

  Widget _field(AppColors c, TextEditingController controller, String hint) {
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
