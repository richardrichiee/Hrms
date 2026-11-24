import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricAuthResult {
  final bool isSuccess;
  final bool isCancelled;
  final String? errorMessage;

  const BiometricAuthResult({
    required this.isSuccess,
    this.isCancelled = false,
    this.errorMessage,
  });
}

class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  factory BiometricService() => instance;

  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isBiometricAvailable() async {
    if (kIsWeb) return false;
    try {
      final isSupported = await _auth.isDeviceSupported();
      if (!isSupported) return false;

      final canCheck = await _auth.canCheckBiometrics;
      final enrolled = await _auth.getAvailableBiometrics();
      // True if strong/weak biometrics are enrolled, or device supports credentials/biometrics
      return canCheck || enrolled.isNotEmpty || isSupported;
    } catch (e) {
      debugPrint('⚠️ [BiometricService] isBiometricAvailable error: $e');
      return false;
    }
  }

  Future<List<BiometricType>> getEnrolledBiometrics() async {
    if (kIsWeb) return const [];
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return const [];
    }
  }

  Future<BiometricAuthResult> authenticate({
    String localizedReason = 'Verify your identity to continue',
  }) async {
    if (kIsWeb) {
      return const BiometricAuthResult(
        isSuccess: false,
        errorMessage: 'Biometric authentication is not supported on web.',
      );
    }

    try {
      final available = await isBiometricAvailable();
      if (!available) {
        return const BiometricAuthResult(
          isSuccess: false,
          errorMessage:
              'Biometric authentication is not set up on this device. Please enroll Fingerprint or Face ID in device settings.',
        );
      }

      final didAuthenticate = await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );

      if (didAuthenticate) {
        return const BiometricAuthResult(isSuccess: true);
      }

      return const BiometricAuthResult(
        isSuccess: false,
        errorMessage: 'Biometric verification did not match. Please try again.',
      );
    } on LocalAuthException catch (e) {
      debugPrint(
        '⚠️ [BiometricService] LocalAuthException (${e.code.name}): ${e.description}',
      );
      switch (e.code) {
        case LocalAuthExceptionCode.userCanceled:
        case LocalAuthExceptionCode.systemCanceled:
        case LocalAuthExceptionCode.userRequestedFallback:
          return const BiometricAuthResult(
            isSuccess: false,
            isCancelled: true,
            errorMessage: 'Biometric verification was cancelled.',
          );
        case LocalAuthExceptionCode.temporaryLockout:
          return const BiometricAuthResult(
            isSuccess: false,
            errorMessage:
                'Too many failed attempts. Biometrics are temporarily locked. Please wait a moment and try again.',
          );
        case LocalAuthExceptionCode.biometricLockout:
          return const BiometricAuthResult(
            isSuccess: false,
            errorMessage:
                'Biometrics are locked on this device. Unlock your device with your PIN/passcode and try again.',
          );
        case LocalAuthExceptionCode.noBiometricsEnrolled:
        case LocalAuthExceptionCode.noCredentialsSet:
          return const BiometricAuthResult(
            isSuccess: false,
            errorMessage:
                'No biometrics enrolled on this device. Please configure Fingerprint or Face ID in system settings.',
          );
        case LocalAuthExceptionCode.noBiometricHardware:
        case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
          return const BiometricAuthResult(
            isSuccess: false,
            errorMessage:
                'Biometric hardware is unavailable on this device right now.',
          );
        case LocalAuthExceptionCode.authInProgress:
          return const BiometricAuthResult(
            isSuccess: false,
            isCancelled: true,
            errorMessage: 'Authentication is already in progress.',
          );
        case LocalAuthExceptionCode.timeout:
          return const BiometricAuthResult(
            isSuccess: false,
            errorMessage: 'Biometric verification timed out. Please try again.',
          );
        default:
          return BiometricAuthResult(
            isSuccess: false,
            errorMessage: e.description?.trim().isNotEmpty == true
                ? e.description!.trim()
                : 'Biometric verification failed. Please try again.',
          );
      }
    } on PlatformException catch (e) {
      debugPrint(
        '⚠️ [BiometricService] PlatformException: ${e.code} ${e.message}',
      );
      return BiometricAuthResult(
        isSuccess: false,
        errorMessage: e.message?.trim().isNotEmpty == true
            ? e.message!.trim()
            : 'Biometric verification failed. Please try again.',
      );
    } catch (e) {
      debugPrint('⚠️ [BiometricService] Unexpected error: $e');
      return const BiometricAuthResult(
        isSuccess: false,
        errorMessage: 'Biometric verification failed. Please try again.',
      );
    }
  }

  Future<void> stopAuthentication() async {
    if (kIsWeb) return;
    try {
      await _auth.stopAuthentication();
    } catch (_) {}
  }
}
