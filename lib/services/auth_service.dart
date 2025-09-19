import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'oauth_service.dart';
import 'debug_service.dart';
import 'biometric_service.dart';

/// Service responsible for managing authentication with Zipline servers.
/// Supports both traditional username/password and OAuth/OIDC authentication.
/// Stores credentials securely using Flutter Secure Storage for sensitive data.
class AuthService {
  // SharedPreferences keys for secure credential storage
  static SharedPreferences? _prefs;
  final OAuthService _oAuthService = OAuthService();

  // Secure storage for sensitive OAuth data
  // Uses hardware-backed encryption on Android for maximum security
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  static const String _ziplineUrlKey = 'zipline_url';
  static const String _usernameKey = 'zipline_username';
  static const String _passwordKey = 'zipline_password';
  static const String _sessionCookieKey = 'session_cookie';
  static const String _cfClientIdKey = 'cf_client_id';
  static const String _cfClientSecretKey = 'cf_client_secret';

  static bool _sensitiveDataMigrated = false;

  Future<void> _ensurePrefsInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> _migrateSensitiveDataIfNeeded() async {
    if (_sensitiveDataMigrated) return;
    await _ensurePrefsInitialized();

    Future<void> migrateKey(String key) async {
      final legacyValue = _prefs!.getString(key);
      if (legacyValue != null) {
        final existingSecureValue = await _secureStorage.read(key: key);
        if (existingSecureValue == null) {
          await _secureStorage.write(key: key, value: legacyValue);
        }
        await _prefs!.remove(key);
      }
    }

    await migrateKey(_passwordKey);
    await migrateKey(_sessionCookieKey);
    await migrateKey(_cfClientIdKey);
    await migrateKey(_cfClientSecretKey);

    _sensitiveDataMigrated = true;
  }

  /// Saves user credentials securely.
  /// Username/password stored in SharedPreferences, OAuth tokens in secure storage.
  Future<void> saveCredentials({
    required String ziplineUrl,
    required String username,
    required String password,
    String? cfClientId,
    String? cfClientSecret,
  }) async {
    await _ensurePrefsInitialized();
    await _migrateSensitiveDataIfNeeded();

    await _prefs!.setString(_ziplineUrlKey, ziplineUrl);
    await _prefs!.setString(_usernameKey, username);

    await _secureStorage.write(key: _passwordKey, value: password);

    if (cfClientId != null && cfClientId.isNotEmpty) {
      await _secureStorage.write(key: _cfClientIdKey, value: cfClientId);
    } else {
      await _secureStorage.delete(key: _cfClientIdKey);
    }

    if (cfClientSecret != null && cfClientSecret.isNotEmpty) {
      await _secureStorage.write(
          key: _cfClientSecretKey, value: cfClientSecret);
    } else {
      await _secureStorage.delete(key: _cfClientSecretKey);
    }
  }

  Future<Map<String, String?>> getCredentials() async {
    await _ensurePrefsInitialized();
    await _migrateSensitiveDataIfNeeded();

    return {
      'ziplineUrl': _prefs!.getString(_ziplineUrlKey),
      'username': _prefs!.getString(_usernameKey),
      'password': await _secureStorage.read(key: _passwordKey),
      'sessionCookie': await _secureStorage.read(key: _sessionCookieKey),
      'cfClientId': await _secureStorage.read(key: _cfClientIdKey),
      'cfClientSecret': await _secureStorage.read(key: _cfClientSecretKey),
    };
  }

  Future<bool> authenticateWithZipline({
    required String ziplineUrl,
    required String username,
    required String password,
    String? twoFactorCode,
    String? cfClientId,
    String? cfClientSecret,
  }) async {
    final debugService = DebugService();

    try {
      await _migrateSensitiveDataIfNeeded();

      debugService.logAuth('Starting authentication attempt', data: {
        'ziplineUrl': ziplineUrl,
        'username': username,
        'hasTwoFactorCode': twoFactorCode?.isNotEmpty ?? false,
        'hasCloudflareAccess': cfClientId != null && cfClientSecret != null,
      });

      final loginUrl = Uri.parse('$ziplineUrl/api/auth/login');
      debugService
          .logAuth('Login URL constructed', data: {'url': loginUrl.toString()});

      final Map<String, String> headers = {
        'Content-Type': 'application/json',
      };

      // Add Cloudflare Access headers if provided
      if (cfClientId != null && cfClientSecret != null) {
        headers['CF-Access-Client-Id'] = cfClientId;
        headers['CF-Access-Client-Secret'] = cfClientSecret;
        debugService.logAuth('Added Cloudflare Access headers');
      }

      final Map<String, dynamic> loginData = {
        'username': username,
        'password': '[REDACTED]', // Don't log actual password
      };

      // Add 2FA code if provided
      if (twoFactorCode != null && twoFactorCode.isNotEmpty) {
        loginData['code'] = twoFactorCode;
        debugService.logAuth('Added 2FA code to login data');
      }

      debugService.logHttp('Sending login request', data: {
        'url': loginUrl.toString(),
        'headers': headers.keys.toList(),
        'bodyKeys': loginData.keys.toList(),
      });

      final actualLoginData = {
        'username': username,
        'password': password,
      };
      if (twoFactorCode != null && twoFactorCode.isNotEmpty) {
        actualLoginData['code'] = twoFactorCode;
      }

      final response = await http.post(
        loginUrl,
        headers: headers,
        body: jsonEncode(actualLoginData),
      );

      debugService.logHttp('Received login response', data: {
        'statusCode': response.statusCode,
        'headers': response.headers.keys.toList(),
        'bodyLength': response.body.length,
        'hasCookies': response.headers['set-cookie'] != null,
      });

      if (response.statusCode == 200) {
        debugService.logAuth('Login request successful (200)');

        // Extract session cookie from response
        final cookies = response.headers['set-cookie'];
        debugService.logAuth('Checking for session cookies', data: {
          'cookies': cookies,
          'containsZiplineSession':
              cookies?.contains('zipline_session=') ?? false,
        });

        if (cookies != null && cookies.contains('zipline_session=')) {
          final sessionCookie = _extractSessionCookie(cookies);
          debugService.logAuth('Extracted session cookie', data: {
            'cookieFound': sessionCookie != null,
            'cookieLength': sessionCookie?.length,
          });

          if (sessionCookie != null) {
            await _secureStorage.write(
              key: _sessionCookieKey,
              value: sessionCookie,
            );
            await _ensurePrefsInitialized();
            await _prefs!.remove(_sessionCookieKey);
            debugService.logAuth('Session cookie stored in secure storage');

            // Save credentials on successful authentication
            await saveCredentials(
              ziplineUrl: ziplineUrl,
              username: username,
              password: password,
              cfClientId: cfClientId,
              cfClientSecret: cfClientSecret,
            );
            debugService.logAuth('Credentials saved successfully');

            debugService.logAuth('Authentication completed successfully');
            return true;
          } else {
            debugService.logAuth('Failed to extract session cookie',
                level: 'ERROR');
          }
        } else {
          debugService.logAuth('No zipline_session cookie found in response',
              level: 'ERROR');
        }
      } else {
        debugService.logAuth('Login request failed',
            data: {
              'statusCode': response.statusCode,
              'responseBody': response.body.length > 500
                  ? '${response.body.substring(0, 500)}...'
                  : response.body,
            },
            level: 'ERROR');
      }

      debugService.logAuth('Authentication failed');
      return false;
    } catch (e, stackTrace) {
      debugService.logError('AUTH', 'Authentication exception occurred',
          error: e, stackTrace: stackTrace);
      return false;
    }
  }

  String? _extractSessionCookie(String cookieHeader) {
    final regex = RegExp(r'zipline_session=([^;]+)');
    final match = regex.firstMatch(cookieHeader);
    return match?.group(1);
  }

  Future<Map<String, String>> getAuthHeaders() async {
    final Map<String, String> headers = {};

    // Try OAuth session first
    final oauthCookie = await _oAuthService.getSessionCookie();
    if (oauthCookie != null) {
      headers['Cookie'] = 'zipline_session=$oauthCookie';

      // Add Cloudflare headers if available from secure storage
      final cfClientId = await _secureStorage.read(key: 'cf_client_id');
      final cfClientSecret = await _secureStorage.read(key: 'cf_client_secret');
      if (cfClientId != null) {
        headers['CF-Access-Client-Id'] = cfClientId;
      }
      if (cfClientSecret != null) {
        headers['CF-Access-Client-Secret'] = cfClientSecret;
      }

      return headers;
    }

    // Fall back to credential-based session
    final credentials = await getCredentials();
    final sessionCookie = credentials['sessionCookie'];
    if (sessionCookie != null) {
      headers['Cookie'] = 'zipline_session=$sessionCookie';
    }

    // Add Cloudflare Access headers if available
    final cfClientId = credentials['cfClientId'];
    final cfClientSecret = credentials['cfClientSecret'];
    if (cfClientId != null && cfClientSecret != null) {
      headers['CF-Access-Client-Id'] = cfClientId;
      headers['CF-Access-Client-Secret'] = cfClientSecret;
    }

    return headers;
  }

  Future<bool> authenticateWithOIDC({
    required String ziplineUrl,
    String? cfClientId,
    String? cfClientSecret,
  }) async {
    final success = await _oAuthService.oAuthLogin(
      ziplineUrl: ziplineUrl,
      cfClientId: cfClientId,
      cfClientSecret: cfClientSecret,
    );

    if (success) {
      // Save the Zipline URL for later use
      await _ensurePrefsInitialized();
      await _prefs!.setString(_ziplineUrlKey, ziplineUrl);

      // After successful OAuth login, fetch and store user info
      final userInfo = await fetchUserInfo();
      if (userInfo != null) {
        // Try multiple possible username fields, including nested structures
        String? username = userInfo['username'] ??
            userInfo['name'] ??
            userInfo['email'] ??
            userInfo['preferred_username'] ??
            userInfo['sub'] ??
            userInfo['displayName'] ??
            userInfo['display_name'];

        if (username != null && username.isNotEmpty) {
          await saveOAuthUsername(username);
          DebugService().logAuth('OAuth username saved', data: {
            'username': username,
            'source': userInfo['username'] != null
                ? 'username'
                : userInfo['name'] != null
                    ? 'name'
                    : userInfo['email'] != null
                        ? 'email'
                        : userInfo['preferred_username'] != null
                            ? 'preferred_username'
                            : userInfo['sub'] != null
                                ? 'sub'
                                : userInfo['displayName'] != null
                                    ? 'displayName'
                                    : 'display_name',
          });
        } else {
          // If still no username, use "nerd" as fallback
          await saveOAuthUsername('nerd');
          DebugService()
              .logAuth('No username in user info, using fallback', data: {
            'fallback': 'nerd',
            'availableKeys': userInfo.keys.toList(),
            'userInfo': userInfo.toString(),
          });
        }
      } else {
        // If user info fetch fails, still use a fallback
        await saveOAuthUsername('nerd');
        DebugService()
            .logAuth('User info fetch failed, using fallback username');
      }
    }

    return success;
  }

  Future<bool> isAuthenticated() async {
    // Check OAuth session first
    final hasOAuth = await _oAuthService.hasOAuthSession();
    if (hasOAuth) return true;

    // Fall back to credential-based session
    final credentials = await getCredentials();
    return credentials['sessionCookie'] != null;
  }

  Future<void> logout() async {
    // Clear OAuth session
    await _oAuthService.clearSession();

    await _migrateSensitiveDataIfNeeded();

    // Clear credential session
    await _secureStorage.delete(key: _sessionCookieKey);
    await _ensurePrefsInitialized();
    await _prefs!.remove(_sessionCookieKey);

    // Disable biometric authentication on logout
    final BiometricService biometricService = BiometricService();
    await biometricService.disableBiometric();
  }

  Future<void> clearAllCredentials() async {
    // Clear OAuth session
    await _oAuthService.clearSession();

    await _migrateSensitiveDataIfNeeded();
    await _ensurePrefsInitialized();

    // Remove only keys owned by AuthService
    await _prefs!.remove(_ziplineUrlKey);
    await _prefs!.remove(_usernameKey);
    await _prefs!.remove(_sessionCookieKey);

    await _secureStorage.delete(key: _passwordKey);
    await _secureStorage.delete(key: _sessionCookieKey);
    await _secureStorage.delete(key: _cfClientIdKey);
    await _secureStorage.delete(key: _cfClientSecretKey);
  }

  // Get the current auth token (OAuth session cookie)
  Future<String?> getAuthToken() async {
    // Get OAuth session cookie
    final oauthCookie = await _oAuthService.getSessionCookie();
    if (oauthCookie != null) {
      return oauthCookie;
    }

    // Fall back to credential-based session if available
    await _migrateSensitiveDataIfNeeded();
    return await _secureStorage.read(key: _sessionCookieKey);
  }

  // Set the auth token (OAuth session cookie)
  Future<void> setAuthToken(String token) async {
    // Store as OAuth session cookie
    await _oAuthService.saveSessionCookie(token);
  }

  // Fetch user information from Zipline API
  Future<Map<String, dynamic>?> fetchUserInfo() async {
    final debugService = DebugService();

    try {
      // Get the Zipline URL from preferences
      await _ensurePrefsInitialized();
      final ziplineUrl = _prefs!.getString(_ziplineUrlKey);

      if (ziplineUrl == null) {
        debugService.logAuth('Cannot fetch user info: No Zipline URL stored',
            level: 'ERROR');
        return null;
      }

      // Get authentication headers
      final headers = await getAuthHeaders();
      if (headers.isEmpty || !headers.containsKey('Cookie')) {
        debugService.logAuth(
            'Cannot fetch user info: No authentication session',
            level: 'ERROR');
        return null;
      }

      debugService.logAuth('Fetching user info from Zipline', data: {
        'url': '$ziplineUrl/api/user',
      });

      // Make request to get user info
      final response = await http
          .get(
            Uri.parse('$ziplineUrl/api/user'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      debugService.logHttp('User info response', data: {
        'statusCode': response.statusCode,
        'bodyLength': response.body.length,
      });

      if (response.statusCode == 200) {
        final userInfo = jsonDecode(response.body);

        // Log the full structure to debug username issue
        debugService.logAuth('User info response structure', data: {
          'responseKeys': userInfo.keys.toList(),
          'fullResponse': userInfo.toString(),
        });

        // Check for nested user object
        if (userInfo['user'] != null && userInfo['user'] is Map) {
          final nestedUser = userInfo['user'];
          debugService.logAuth('Found nested user object', data: {
            'nestedKeys': nestedUser.keys.toList(),
            'username': nestedUser['username'],
            'name': nestedUser['name'],
            'email': nestedUser['email'],
            'id': nestedUser['id'],
          });
          return nestedUser as Map<String, dynamic>;
        }

        // Log the actual structure to debug
        debugService.logAuth('User info fetched successfully', data: {
          'hasUsername': userInfo['username'] != null,
          'hasId': userInfo['id'] != null,
          'username': userInfo['username'],
          'name': userInfo['name'],
          'email': userInfo['email'],
          'responseKeys': userInfo.keys.toList(),
          'responsePreview': userInfo.toString().length > 200
              ? '${userInfo.toString().substring(0, 200)}...'
              : userInfo.toString(),
        });
        return userInfo;
      } else {
        debugService
            .logAuth('Failed to fetch user info', level: 'ERROR', data: {
          'statusCode': response.statusCode,
          'body': response.body.length > 200
              ? '${response.body.substring(0, 200)}...'
              : response.body,
        });
        return null;
      }
    } catch (e, stackTrace) {
      debugService.logError('AUTH', 'Error fetching user info',
          error: e, stackTrace: stackTrace);
      return null;
    }
  }

  // Save username for OAuth users
  Future<void> saveOAuthUsername(String username) async {
    await _ensurePrefsInitialized();
    await _prefs!.setString(_usernameKey, username);
  }

  @visibleForTesting
  static Future<void> resetForTesting() async {
    _prefs = null;
    _sensitiveDataMigrated = false;
    await _secureStorage.delete(key: _passwordKey);
    await _secureStorage.delete(key: _sessionCookieKey);
    await _secureStorage.delete(key: _cfClientIdKey);
    await _secureStorage.delete(key: _cfClientSecretKey);
  }
}
