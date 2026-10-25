import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../main.dart';

/// Sign up / log in with either email+password or Google. Not a gate on
/// using the app -- everything works fully offline without an account;
/// this only unlocks cloud backup.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = true;
  bool _loading = false;
  String? _error;

  Future<void> _submitEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter both email and password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final error = _isSignUp
        ? await AuthService.instance.signUpWithEmail(email, password)
        : await AuthService.instance.signInWithEmail(email, password);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      setState(() => _error = error);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _submitGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final error = await AuthService.instance.signInWithGoogle();
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      setState(() => _error = error);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: Text(_isSignUp ? 'Sign up' : 'Log in')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Text(
                _isSignUp ? 'Create an account' : 'Welcome back',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Back up your progress and restore it on any device.',
                style: TextStyle(fontSize: 13, color: c.textSecondary),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: c.textPrimary),
                decoration: _fieldDecoration(c, 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: TextStyle(color: c.textPrimary),
                decoration: _fieldDecoration(c, 'Password'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: c.danger, fontSize: 12.5)),
              ],
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: c.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _loading ? null : _submitEmail,
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_isSignUp ? 'Sign up' : 'Log in'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _loading
                    ? null
                    : () => setState(() {
                          _isSignUp = !_isSignUp;
                          _error = null;
                        }),
                child: Text(
                  _isSignUp ? 'Already have an account? Log in' : "New here? Sign up",
                  style: TextStyle(color: c.primary, fontSize: 13),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: Divider(color: c.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('or', style: TextStyle(color: c.textMuted, fontSize: 12)),
                  ),
                  Expanded(child: Divider(color: c.border)),
                ],
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: BorderSide(color: c.border),
                ),
                onPressed: _loading ? null : _submitGoogle,
                icon: Icon(Icons.g_mobiledata, size: 24, color: c.textPrimary),
                label: Text('Continue with Google', style: TextStyle(color: c.textPrimary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(dynamic c, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: c.textMuted),
      filled: true,
      fillColor: c.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.primary)),
    );
  }
}
