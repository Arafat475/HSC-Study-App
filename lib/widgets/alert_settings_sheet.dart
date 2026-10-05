import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../main.dart';

/// Bottom sheet for toggling sound/vibration feedback when the timer is
/// stopped and a session is saved. Kept intentionally simple -- one alert
/// type, not the multi-category setup some other apps have.
void showAlertSettingsSheet(BuildContext context) {
  final c = context.colorsNoWatch;
  showModalBottomSheet(
    context: context,
    backgroundColor: c.surfaceAlt,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => const _AlertSettingsSheet(),
  );
}

class _AlertSettingsSheet extends StatelessWidget {
  const _AlertSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                settings.t('alert_settings'),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.textPrimary),
              ),
              IconButton(
                icon: Icon(Icons.close, color: c.textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ToggleRow(
            icon: Icons.music_note,
            label: settings.t('sound_alert'),
            value: settings.soundAlert,
            onChanged: settings.setSoundAlert,
          ),
          if (settings.soundAlert) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Row(
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
            ),
          ],
          Divider(color: c.border, height: 24),
          _ToggleRow(
            icon: Icons.vibration,
            label: settings.t('vibration_alert'),
            value: settings.vibrationAlert,
            onChanged: settings.setVibrationAlert,
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

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Icon(icon, size: 18, color: c.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 14.5, color: c.textPrimary)),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: c.primary,
        ),
      ],
    );
  }
}
