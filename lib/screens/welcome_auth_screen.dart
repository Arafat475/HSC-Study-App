import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../main.dart';
import 'auth_screen.dart';

/// The very first screen a new user sees -- offers to sign up/log in
/// (unlocking backup) or skip and use the app fully offline. Shown once,
/// before class/group selection, as part of the one-time onboarding flow.
class WelcomeAuthScreen extends StatelessWidget {
  final VoidCallback onSignedIn;
  final VoidCallback onSkip;

  const WelcomeAuthScreen({super.key, required this.onSignedIn, required this.onSkip});

  Future<void> _openAuth(BuildContext context) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
    if (AuthService.instance.currentUser != null) onSignedIn();
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
              const SizedBox(height: 40),
              Icon(Icons.menu_book, size: 48, color: c.primary),
              const SizedBox(height: 20),
              Text(
                'Study Planner',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: c.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign up to back up your progress and restore it on any device -- or skip and use the app fully offline.',
                style: TextStyle(fontSize: 13.5, color: c.textSecondary, height: 1.4),
              ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: c.primary,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _openAuth(context),
                child: const Text('Sign up', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: BorderSide(color: c.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _openAuth(context),
                child: Text('Log in', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: onSkip,
                  child: Text(
                    'Continue without an account',
                    style: TextStyle(color: c.textMuted, fontSize: 13),
                  ),
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
