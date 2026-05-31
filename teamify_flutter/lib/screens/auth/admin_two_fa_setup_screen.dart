import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_result.dart';
import '../../core/routes.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme.dart';
import '../../services/app_services.dart';
import '../../widgets/widgets.dart';

/// Guides admin users through TOTP 2FA setup before accessing the admin panel.
class AdminTwoFASetupScreen extends StatefulWidget {
  const AdminTwoFASetupScreen({super.key});

  @override
  State<AdminTwoFASetupScreen> createState() => _AdminTwoFASetupScreenState();
}

class _AdminTwoFASetupScreenState extends State<AdminTwoFASetupScreen> {
  final _codeCtrl = TextEditingController();
  bool _loadingSetup = true;
  bool _submitting = false;
  bool _confirmOnly = false;
  String? _qrCodeDataUri;
  String? _secret;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initSetup();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await context.read<AppServices>().auth.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, R.login, (_) => false);
  }

  Future<void> _goToAdmin() async {
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, R.adminHome, (_) => false);
  }

  Future<void> _loadQrSetup() async {
    setState(() {
      _loadingSetup = true;
      _error = null;
      _confirmOnly = false;
      _qrCodeDataUri = null;
      _secret = null;
    });

    final result = await context.read<AppServices>().auth.setup2fa();
    if (!mounted) return;

    if (result.isSuccess) {
      final res = result.data ?? {};
      setState(() {
        _qrCodeDataUri = res['qr_code']?.toString();
        _secret = res['secret']?.toString();
        _confirmOnly = false;
        _loadingSetup = false;
      });
      return;
    }

    final msg = result.error?.toLowerCase() ?? '';
    if (msg.contains('already enabled')) {
      setState(() {
        _confirmOnly = true;
        _error = null;
        _loadingSetup = false;
      });
      return;
    }

    setState(() {
      _error = result.error ?? 'Could not start 2FA setup.';
      _loadingSetup = false;
    });
  }

  Future<void> _initSetup() async {
    setState(() {
      _loadingSetup = true;
      _error = null;
    });

    final session = context.read<SessionController>();
    try {
      await session.restoreSession();
      if (!mounted) return;

      final user = session.currentUser;
      if (user != null &&
          user.isAdmin &&
          user.totpEnabled &&
          !session.admin2faLoginPending &&
          !user.needsAdmin2faSetup) {
        await _goToAdmin();
        return;
      }

      if (session.admin2faLoginPending && (user?.totpEnabled ?? false)) {
        setState(() {
          _confirmOnly = true;
          _loadingSetup = false;
        });
        return;
      }

      await _loadQrSetup();
    } finally {
      if (mounted) setState(() => _loadingSetup = false);
    }
  }

  Future<void> _verifyAndContinue() async {
    final code = _codeCtrl.text.trim();
    if (code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the 6-digit code from your authenticator app'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    final session = context.read<SessionController>();
    final auth = context.read<AppServices>().auth;

    try {
      final ApiResult<dynamic> result = _confirmOnly
          ? await auth.confirm2faLogin(code)
          : await auth.verify2fa(code);

      if (!mounted) return;

      if (result.isFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Verification failed'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final user = result.data;
      if (user != null) {
        session.setCurrentUser(user);
      } else {
        await session.restoreSession();
      }
      session.clearAdmin2faLoginPending();
      await _goToAdmin();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          _confirmOnly && _qrCodeDataUri == null
              ? 'Confirm Two-Factor Authentication'
              : 'Set Up Two-Factor Authentication',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.error),
            tooltip: 'Log out',
            onPressed: _logout,
          ),
        ],
      ),
      body: _loadingSetup
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Icon(
                  Icons.security,
                  size: 48,
                  color: _confirmOnly && _qrCodeDataUri == null
                      ? AppColors.success
                      : AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  _confirmOnly && _qrCodeDataUri == null
                      ? 'Enter your authenticator code'
                      : 'Scan QR code, then enter the 6-digit code',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _confirmOnly && _qrCodeDataUri == null
                      ? 'Open Google Authenticator or Authy on your phone and enter the current 6-digit code.'
                      : 'Install Google Authenticator or Authy, scan the QR code below, then enter the 6-digit code from the app.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                if (_qrCodeDataUri == null && !_confirmOnly) ...[
                  const SizedBox(height: 20),
                  TCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'How to get the code',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 12),
                        _step('1', 'Install Google Authenticator or Authy on your phone.'),
                        _step('2', 'Open the app → + → Scan QR code.'),
                        _step('3', 'Scan the QR code below.'),
                        _step('4', 'Enter the 6-digit number from the app.'),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: const TextStyle(color: AppColors.error)),
                  ),
                if (_qrCodeDataUri != null &&
                    _qrCodeDataUri!.startsWith('data:image'))
                  Center(
                    child: Image.memory(
                      base64Decode(_qrCodeDataUri!.split(',').last),
                      width: 220,
                      height: 220,
                    ),
                  ),
                if (_secret != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          'Manual key: $_secret',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy key',
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _secret!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Key copied')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                const Text(
                  'Authenticator code',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _verifyAndContinue(),
                  decoration: const InputDecoration(
                    hintText: '000000',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),
                TButton(
                  label: _submitting
                      ? 'Verifying…'
                      : (_confirmOnly && _qrCodeDataUri == null
                          ? 'Continue to Admin'
                          : 'Enable 2FA & Continue'),
                  onTap: _submitting ? null : _verifyAndContinue,
                ),
                if (_confirmOnly && _qrCodeDataUri == null) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loadQrSetup,
                    child: const Text('Set up on a new phone (show QR code)'),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loadQrSetup,
                    child: const Text('Regenerate QR code'),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _step(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, height: 1.35)),
          ),
        ],
      ),
    );
  }
}
