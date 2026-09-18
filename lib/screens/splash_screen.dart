import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../data/hive_service.dart';
import '../services/biometric_service.dart';
import '../state/providers.dart';
import 'login_screen.dart';

/// Splash → biometric unlock (if enabled) → Login.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final settings = ref.read(settingsProvider);
    final hasSession = HiveService.session() != null;

    if (hasSession && settings.biometric && await BiometricService.isAvailable()) {
      final ok = await BiometricService.authenticate(reason: 'Unlock DukaFlow POS');
      if (!mounted) return;
      if (ok) {
        // Restore session silently.
        ref.read(sessionProvider);
        if (ref.read(sessionProvider).user != null) return; // HomeShell renders
      }
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DukaColors.ink,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: DukaColors.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.storefront, color: DukaColors.white, size: 44),
            ),
            const SizedBox(height: 20),
            const Text(
              AppConstants.appName,
              style: TextStyle(
                color: DukaColors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${AppConstants.tagline} • Offline-first POS',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(color: DukaColors.primary, strokeWidth: 3),
            ),
            const SizedBox(height: 48),
            const Text(
              'v2.4.1 • KRA eTIMS • M-Pesa • Works Offline',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
