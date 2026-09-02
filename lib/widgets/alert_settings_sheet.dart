import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../main.dart';

/// Bottom sheet for toggling sound/vibration feedback when the timer is
/// stopped and a session is saved. Kept intentionally simple -- one alert
/// type, not the multi-category setup some other apps have.
void showAlertSettingsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: kSurfaceColorAlt,
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
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kTextPrimary),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: kTextMuted),
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
            ),
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
    return Row(
      children: [
        Icon(icon, size: 18, color: kTextSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 14.5, color: kTextPrimary)),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: kPrimaryColor,
        ),
      ],
    );
  }
}
