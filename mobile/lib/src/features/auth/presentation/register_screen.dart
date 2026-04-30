import 'package:flutter/material.dart';

import '../../../core/brand/enis_brand.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/soft_card.dart';
import '../../legal/data/legal_service.dart';
import '../../legal/presentation/legal_screen.dart';
import '../data/auth_service.dart';
import 'auth_layout.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    required this.authService,
    required this.legalService,
    required this.onRegistered,
    required this.onLoginRequested,
  });

  final AuthService authService;
  final LegalService legalService;
  final ValueChanged<AuthResult> onRegistered;
  final VoidCallback onLoginRequested;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _avatarNameController = TextEditingController();
  bool _kvkk = false;
  bool _privacy = false;
  bool _terms = false;
  bool _disclaimer = false;
  bool _marketing = false;
  bool _loading = false;

  bool get _requiredConsentsAccepted => _kvkk && _privacy && _terms && _disclaimer;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _avatarNameController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_requiredConsentsAccepted) {
      _showMessage('Required consents must be accepted.');
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await widget.authService.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text,
        avatarName: _avatarNameController.text,
        consents: {
          ConsentKeys.kvkkClarificationSeen: _kvkk,
          ConsentKeys.privacyPolicy: _privacy,
          ConsentKeys.termsOfUse: _terms,
          ConsentKeys.wellnessDisclaimer: _disclaimer,
          ConsentKeys.marketingPermission: _marketing,
        },
      );
      if (!mounted) return;
      widget.onRegistered(result);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openLegal(String slug) async {
    try {
      final document = await widget.legalService.getDocument(slug);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LegalDetailScreen(document: document)),
      );
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Create account',
      subtitle: 'Enis is for wellness and emotional support only.',
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
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'password'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _fullNameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'fullName optional'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _avatarNameController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Karakterinin adı',
                    helperText: 'Bu isim sadece sana özel olacak.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SoftCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ConsentTile(
                  value: _kvkk,
                  label: 'KVKK clarification seen',
                  onChanged: (value) => setState(() => _kvkk = value),
                  onLabelTap: () => _openLegal('kvkk-clarification'),
                ),
                _ConsentTile(
                  value: _privacy,
                  label: 'Privacy policy',
                  onChanged: (value) => setState(() => _privacy = value),
                  onLabelTap: () => _openLegal('privacy-policy'),
                ),
                _ConsentTile(
                  value: _terms,
                  label: 'Terms of use',
                  onChanged: (value) => setState(() => _terms = value),
                  onLabelTap: () => _openLegal('terms-of-use'),
                ),
                _ConsentTile(
                  value: _disclaimer,
                  label: 'Wellness disclaimer',
                  onChanged: (value) => setState(() => _disclaimer = value),
                  onLabelTap: () => _openLegal('disclaimer'),
                ),
                Divider(height: 1, color: EnisColors.deepNavy.withOpacity(0.08)),
                _ConsentTile(
                  value: _marketing,
                  label: 'Marketing permission optional',
                  onChanged: (value) => setState(() => _marketing = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          GradientButton(
            label: _loading ? 'Creating...' : 'Start / Başla',
            icon: Icons.arrow_forward_rounded,
            enabled: !_loading,
            onPressed: _register,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _loading ? null : widget.onLoginRequested,
            child: const Text('Welcome back / Geri dön'),
          ),
        ],
      ),
    );
  }
}

class _ConsentTile extends StatelessWidget {
  const _ConsentTile({
    required this.value,
    required this.label,
    required this.onChanged,
    this.onLabelTap,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onLabelTap;

  @override
  Widget build(BuildContext context) {
    final tappable = onLabelTap != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: (next) => onChanged(next ?? false),
            activeColor: EnisColors.primaryBlue,
          ),
          Expanded(
            child: InkWell(
              onTap: onLabelTap ?? () => onChanged(!value),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: tappable ? EnisColors.primaryBlue : EnisColors.deepNavy,
                              fontWeight: tappable ? FontWeight.w700 : FontWeight.w500,
                            ),
                      ),
                    ),
                    if (tappable)
                      const Icon(
                        Icons.open_in_new_rounded,
                        color: EnisColors.primaryBlue,
                        size: 18,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
