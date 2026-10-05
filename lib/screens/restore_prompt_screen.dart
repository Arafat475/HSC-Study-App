import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import '../providers/routine_provider.dart';
import '../providers/settings_provider.dart';
import '../services/backup_service.dart';
import '../main.dart';

/// Shown right after signing in during onboarding -- checks whether this
/// account already has a backup and, if so, offers to restore it before
/// the user picks a class/group (since a restore might set that for them
/// already).
class RestorePromptScreen extends StatefulWidget {
  final VoidCallback onDone;
  const RestorePromptScreen({super.key, required this.onDone});

  @override
  State<RestorePromptScreen> createState() => _RestorePromptScreenState();
}

enum _Phase { checking, found, restoring, error }

class _RestorePromptScreenState extends State<RestorePromptScreen> {
  _Phase _phase = _Phase.checking;
  DateTime? _backupTime;
  String? _error;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final time = await BackupService.instance.lastBackupTime();
      if (!mounted) return;
      if (time != null) {
        setState(() {
          _backupTime = time;
          _phase = _Phase.found;
        });
      } else {
        widget.onDone();
      }
    } catch (_) {
      // If checking fails (e.g. offline), don't block onboarding on it.
      widget.onDone();
    }
  }

  Future<void> _restore() async {
    setState(() => _phase = _Phase.restoring);
    try {
      await BackupService.instance.restore(
        context.read<AppDataProvider>(),
        context.read<RoutineProvider>(),
        context.read<SettingsProvider>(),
      );
      widget.onDone();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _phase = _Phase.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (_phase == _Phase.checking) {
      return Scaffold(
        backgroundColor: c.background,
        body: Center(child: CircularProgressIndicator(color: c.primary)),
      );
    }

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.cloud_download_outlined, size: 48, color: c.accent),
              const SizedBox(height: 20),
              Text(
                'Found a previous backup',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (_backupTime != null)
                Text(
                  'From ${DateFormat('d MMM yyyy, h:mm a').format(_backupTime!)}',
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 8),
              Text(
                'Restore your subjects progress, study history, and settings from this account?',
                style: TextStyle(fontSize: 13.5, color: c.textSecondary, height: 1.4),
                textAlign: TextAlign.center,
              ),
              if (_phase == _Phase.error) ...[
                const SizedBox(height: 16),
                Text('Restore failed: $_error', style: TextStyle(color: c.danger, fontSize: 12.5), textAlign: TextAlign.center),
              ],
              const Spacer(),
              if (_phase == _Phase.restoring)
                Center(child: CircularProgressIndicator(color: c.primary))
              else ...[
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: c.primary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _restore,
                  child: const Text('Restore my data', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: widget.onDone,
                  child: Text('Skip, start fresh', style: TextStyle(color: c.textMuted, fontSize: 13)),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
