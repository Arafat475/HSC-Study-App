import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../main.dart';

/// Small pill button that flips between Bangla and English, used in an
/// AppBar's actions. Tapping it switches the whole app's language instantly.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isBn = settings.locale == 'bn';

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => settings.setLocale(isBn ? 'en' : 'bn'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: kSurfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kPrimaryColor.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.translate, size: 14, color: kPrimaryColor),
              const SizedBox(width: 5),
              Text(
                isBn ? 'বাং' : 'EN',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kPrimaryColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
