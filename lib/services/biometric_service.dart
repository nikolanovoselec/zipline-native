import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'debug_service.dart';

class BiometricService {
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _biometricTokenKey = 'biometric_token';

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final DebugService _debugService = DebugService();

  // Check if biometric authentication is available on the device
  Future<bool> isBiometricAvailable() async {
    try {
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!canCheckBiometrics || !isDeviceSupported) {
        _debugService
            .logAuth('Biometric authentication not available on this device');
        return false;
      }

      final List<BiometricType> availableBiometrics =
          await _localAuth.getAvailableBiometrics();

      _debugService.logAuth('Available biometrics: $availableBiometrics');

      return availableBiometrics.isNotEmpty;
    } catch (e) {
      _debugService.logAuth('Error checking biometric availability: $e');
      return false;
    }
  }

  // Check if biometric authentication is enabled by the user
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  // Enable biometric authentication
  Future<void> enableBiometric(String authToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, true);

    // Store the auth token securely for biometric authentication
    await _secureStorage.write(key: _biometricTokenKey, value: authToken);

    _debugService.logAuth('Biometric authentication enabled');
  }

  // Disable biometric authentication
  Future<void> disableBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, false);

    // Remove the stored auth token
    await _secureStorage.delete(key: _biometricTokenKey);

    _debugService.logAuth('Biometric authentication disabled');
  }

  // Authenticate using biometrics
  Future<bool> authenticate(
      {String reason = 'Please authenticate to access Zipline'}) async {
    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow device PIN/pattern as fallback
          useErrorDialogs: true,
        ),
      );

      _debugService
          .logAuth('Biometric authentication result: $didAuthenticate');

      return didAuthenticate;
    } on PlatformException catch (e) {
      _debugService.logAuth('Biometric authentication error: ${e.message}');
      return false;
    }
  }

  // Get stored auth token after successful biometric authentication
  Future<String?> getStoredAuthToken() async {
    try {
      final token = await _secureStorage.read(key: _biometricTokenKey);
      return token;
    } catch (e) {
      _debugService.logAuth('Error retrieving stored auth token: $e');
      return null;
    }
  }

  // Authenticate and retrieve token in one step
  Future<String?> authenticateAndGetToken() async {
    // First check if biometric is enabled
    final isEnabled = await isBiometricEnabled();
    if (!isEnabled) {
      _debugService.logAuth('Biometric authentication not enabled');
      return null;
    }

    // Ensure we have a stored token before prompting the user
    final existingToken = await getStoredAuthToken();
    if (existingToken == null || existingToken.isEmpty) {
      _debugService.logAuth(
          'No stored auth token found for biometrics. Disabling biometric login.');
      await disableBiometric();
      return null;
    }

    // Authenticate using biometrics
    final authenticated = await authenticate();
    if (!authenticated) {
      _debugService.logAuth('Biometric authentication failed');
      return null;
    }

    // Get and return the stored token
    final token = await getStoredAuthToken();
    if (token == null || token.isEmpty) {
      _debugService.logAuth(
          'Stored auth token missing after biometric authentication; disabling biometric');
      await disableBiometric();
      return null;
    }

    _debugService.logAuth('Successfully authenticated with biometrics');
    return token;
  }

  // Get available biometric types for display
  Future<List<String>> getAvailableBiometricTypes() async {
    try {
      final List<BiometricType> availableBiometrics =
          await _localAuth.getAvailableBiometrics();

      final Set<String> uniqueTypes = {};

      for (final type in availableBiometrics) {
        switch (type) {
          case BiometricType.face:
            uniqueTypes.add('Face ID');
            break;
          case BiometricType.fingerprint:
            uniqueTypes.add('Fingerprint');
            break;
          case BiometricType.iris:
            uniqueTypes.add('Iris');
            break;
          case BiometricType.strong:
          case BiometricType.weak:
            // For generic strong/weak, just add "Biometric" if no specific type is already added
            if (uniqueTypes.isEmpty) {
              uniqueTypes.add('Biometric');
            }
            break;
        }
      }

      return uniqueTypes.toList();
    } catch (e) {
      _debugService.logAuth('Error getting biometric types: $e');
      return [];
    }
  }
}
