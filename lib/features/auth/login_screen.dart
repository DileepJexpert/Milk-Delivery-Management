import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/localization/locale_controller.dart';
import '../../data/models/user.dart';
import 'session_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _name = TextEditingController();
  bool _otpSent = false;
  UserRole _role = UserRole.milkman;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() => _error = null);
    final ok = await ref.read(sessionControllerProvider.notifier).verifyOtp(
          phone: _phone.text,
          otp: _otp.text,
          name: _name.text,
          role: _role,
        );
    if (!ok) setState(() => _error = 'Invalid OTP. Use 123456.');
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('app_title')),
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(localeControllerProvider.notifier).toggle(),
            child: Text(
              ref.watch(localeControllerProvider).languageCode.toUpperCase(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            children: [
              const SizedBox(height: 24),
              Text(
                t.t('login_title'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: t.t('phone_hint')),
              ),
              const SizedBox(height: 12),
              if (!_otpSent)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      if (_phone.text.trim().isEmpty) return;
                      setState(() => _otpSent = true);
                    },
                    child: Text(t.t('send_otp')),
                  ),
                )
              else ...[
                TextField(
                  controller: _otp,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: t.t('otp_hint')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _name,
                  decoration: InputDecoration(labelText: t.t('name_hint')),
                ),
                const SizedBox(height: 16),
                Text(
                  t.t('select_role'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SegmentedButton<UserRole>(
                  segments: [
                    ButtonSegment(
                      value: UserRole.milkman,
                      label: Text(t.t('role_milkman')),
                      icon: const Icon(Icons.local_shipping_outlined),
                    ),
                    ButtonSegment(
                      value: UserRole.subscriber,
                      label: Text(t.t('role_subscriber')),
                      icon: const Icon(Icons.home_outlined),
                    ),
                  ],
                  selected: {_role},
                  onSelectionChanged: (s) => setState(() => _role = s.first),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: _verify, child: Text(t.t('verify'))),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Demo accounts',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 6),
                        Text('Milkman: 9000000001 / 123456'),
                        Text('Subscribers: 9111111111 or 9222222222 / 123456'),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
