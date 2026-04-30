import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/soft_card.dart';
import '../data/auth_service.dart';
import 'auth_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.authService,
    required this.onLoggedIn,
    required this.onRegisterRequested,
  });

  final AuthService authService;
  final ValueChanged<AuthResult> onLoggedIn;
  final VoidCallback onRegisterRequested;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      final result = await widget.authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      widget.onLoggedIn(result);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Welcome back',
      subtitle: 'Continue your Enis space with your account.',
      child: Column(
        children: [
          SoftCard(
            child: Column(
              children: [
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: 'password'),
                  onSubmitted: (_) => _login(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          GradientButton(
            label: _loading ? 'Opening...' : 'Welcome back / Geri dön',
            icon: Icons.login_rounded,
            enabled: !_loading,
            onPressed: _login,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _loading ? null : widget.onRegisterRequested,
            child: const Text('Start / Başla'),
          ),
        ],
      ),
    );
  }
}
