import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../widgets/carrygo_brand.dart';
import 'create_account_screen.dart';
import 'settings_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final messenger = ScaffoldMessenger.of(context);
    final loginFailed = context.trRead('Login failed');
    setState(() => _isLoading = true);
    try {
      await Provider.of<AuthProvider>(context, listen: false).signIn(
        _identifierController.text.trim(),
        _passwordController.text,
      );
    } catch (e) {
      final message = e is LoginException ? e.message : '$loginFailed: $e';
      messenger.showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final messenger = ScaffoldMessenger.of(context);
    final identifier = _identifierController.text.trim();
    final resetSent = context.trRead('Password reset link sent.');
    final resetFailed = context.trRead('Reset failed');
    if (identifier.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
            content: Text(context.trRead('Enter your email address first.'))),
      );
      return;
    }
    if (!identifier.contains('@')) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(context
              .trRead('Password reset is available for email accounts.')),
        ),
      );
      return;
    }

    try {
      await Provider.of<AuthProvider>(context, listen: false)
          .sendPasswordReset(identifier);
      messenger.showSnackBar(
        SnackBar(content: Text(resetSent)),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$resetFailed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const CarryGoAppBarTitle(label: 'CarryGo'),
        actions: const [SettingsIconButton()],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: CarryGoLogo(size: 170)),
                const SizedBox(height: 16),
                Text(
                  context.tr('We carry. You relax.'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF001B38),
                      ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _identifierController,
                  decoration: InputDecoration(
                    labelText: context.tr('Email or phone number'),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  decoration:
                      InputDecoration(labelText: context.tr('Password')),
                  obscureText: true,
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _isLoading ? null : _login,
                  child: Text(
                    _isLoading
                        ? context.tr('Logging in...')
                        : context.tr('Login'),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateAccountScreen(),
                          ),
                        );
                      },
                      child: Text(context.tr('Create account')),
                    ),
                    TextButton(
                      onPressed: _forgotPassword,
                      child: Text(context.tr('Forgot password?')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
