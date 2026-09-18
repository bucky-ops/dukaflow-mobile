import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../services/biometric_service.dart';
import '../state/providers.dart';

/// Login - phone + 4-digit PIN (staff PIN auth) with optional biometric
/// unlock, mirroring the wireframe: +254 phone field, PIN field with show/
/// hide, Biometric Login row, version footer.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _pinCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController(text: '+254');
  bool _showPin = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    BiometricService.isAvailable().then((v) {
      if (mounted) setState(() => _biometricAvailable = v);
    });
  }

  Future<void> _submit() async {
    final pin = _pinCtrl.text.trim();
    if (pin.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your 4-digit PIN')),
      );
      return;
    }
    await ref.read(sessionProvider.notifier).loginWithPin(pin);
    if (!mounted) return;
    final err = ref.read(sessionProvider).error;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      // SessionNotifier state change re-renders MaterialApp home (HomeShell).
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  Future<void> _biometric() async {
    final ok = await BiometricService.authenticate(reason: 'Login to DukaFlow');
    if (ok && mounted) {
      // Biometric restores the last saved session (PIN is never stored).
      await ref.read(sessionProvider.notifier).restore();
      if (mounted && ref.read(sessionProvider).user != null) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    return Scaffold(
      backgroundColor: DukaColors.ink,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: DukaColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.storefront, color: DukaColors.white, size: 36),
                ),
                const SizedBox(height: 16),
                const Text(
                  'DukaFlow',
                  style: TextStyle(
                    color: DukaColors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  'Your Duka in Your Pocket',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            prefixText: '+254 ',
                            prefixIcon: Icon(Icons.phone_iphone),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _pinCtrl,
                          obscureText: !_showPin,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'PIN',
                            counterText: '',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_showPin ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _showPin = !_showPin),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: session.loading ? null : _submit,
                          child: session.loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: DukaColors.white,
                                  ),
                                )
                              : const Text('Login'),
                        ),
                        if (_biometricAvailable) ...[
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _biometric,
                            icon: const Icon(Icons.fingerprint),
                            label: const Text('Biometric Login'),
                          ),
                        ],
                        TextButton(
                          onPressed: () {},
                          child: const Text(
                            'Forgot PIN?',
                            style: TextStyle(color: DukaColors.inkMuted, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Demo PINs: Cashier 1234 • Owner 0000',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(height: 4),
                const Text(
                  'v2.4.1 • KRA eTIMS Connected • M-Pesa Enabled',
                  style: TextStyle(color: Colors.white24, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
