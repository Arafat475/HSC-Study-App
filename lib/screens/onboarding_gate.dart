import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../providers/settings_provider.dart';
import 'welcome_auth_screen.dart';
import 'restore_prompt_screen.dart';
import 'student_details_onboarding_screen.dart';
import 'class_selection_screen.dart';

enum _Step { welcome, restorePrompt, studentDetails, classSelection }

/// Orchestrates the one-time first-run sequence: sign up/log in (or skip)
/// -> if signed in, offer to restore a previous backup -> if still no
/// student name set, ask for student ID details -> pick class/group.
class OnboardingGate extends StatefulWidget {
  const OnboardingGate({super.key});

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  late _Step _step;

  @override
  void initState() {
    super.initState();
    // Already signed in (e.g. app was killed mid-onboarding) -- skip
    // straight to checking for a backup instead of showing Sign up again.
    _step = AuthService.instance.currentUser != null ? _Step.restorePrompt : _Step.welcome;
  }

  bool get _hasStudentName {
    final name = context.read<SettingsProvider>().studentName;
    return name != null && name.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _Step.welcome:
        return WelcomeAuthScreen(
          onSignedIn: () => setState(() => _step = _Step.restorePrompt),
          onSkip: () => setState(() => _step = _Step.classSelection),
        );
      case _Step.restorePrompt:
        return RestorePromptScreen(
          onDone: () => setState(() => _step = _hasStudentName ? _Step.classSelection : _Step.studentDetails),
        );
      case _Step.studentDetails:
        return StudentDetailsOnboardingScreen(
          onDone: () => setState(() => _step = _Step.classSelection),
        );
      case _Step.classSelection:
        return const ClassSelectionScreen();
    }
  }
}
