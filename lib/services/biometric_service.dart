import 'package:local_auth/local_auth.dart';

/// Fingerprint / Face ID unlock (local_auth).
abstract final class BiometricService {
  static final _auth = LocalAuthentication();

  /// Does this device have enrolled biometrics?
  static Future<bool> isAvailable() async {
    try {
      final supported = await _auth.canCheckBiometrics ||
          await _auth.isDeviceSupported();
      if (!supported) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } on Exception {
      return false;
    }
  }

  /// Prompt the user. Returns true on success.
  static Future<bool> authenticate({String reason = 'Unlock DukaFlow'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on Exception {
      return false;
    }
  }
}
