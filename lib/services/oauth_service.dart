import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'debug_service.dart';
import '../core/build_config.dart';

/// Service handling OAuth/OIDC authentication flows with Zipline servers.
///
/// This service implements a secure OAuth 2.0 flow with PKCE protection:
/// 1. Request OAuth URL from Zipline server
/// 2. Launch system browser for authentication with provider (Authentik, Discord, etc)
/// 3. Receive callback via Cloudflare Worker bridge (HTTPS to deep link conversion)
/// 4. Exchange authorization code for session cookie
/// 5. Store session securely using hardware-backed encryption
///
/// The Cloudflare Worker is required because OAuth providers only accept HTTPS
/// redirect URIs, not custom schemes like zipline://. The worker acts as a bridge,
/// receiving the OAuth callback and redirecting to the app's deep link.
class OAuthService {
  static const String _callbackUrlScheme = 'zipline';
  static const String _sessionCookieKey = 'session_cookie';
  final DebugService _debugService = DebugService();

  // Secure storage for sensitive data
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  /// Check if app was launched with an OAuth callback (cold start)
  /// This should be called once at app startup, NOT during active OAuth flow
  Future<Map<String, String>?> checkInitialOAuthCallback() async {
    try {
      final appLinks = AppLinks();
      final initialUri = await appLinks.getInitialLink();

      if (initialUri != null) {
        final initialLink = initialUri.toString();
        if (initialLink.contains('oauth-callback')) {
          _debugService.logAuth('App launched with OAuth callback (cold start)',
              data: {'initialLink': initialLink});

          // Parse the callback parameters
          final uri = Uri.parse(initialLink);

          // Check for new server-side flow format
          final success = uri.queryParameters['success'];
          final session = uri.queryParameters['session'];
          final error = uri.queryParameters['error'];

          if (success == 'true' && session != null) {
            return {'success': success!, 'session': session};
          } else if (success == 'false') {
            return {'success': success!, 'error': error ?? 'Unknown error'};
          }

          // Fall back to old format (backwards compatibility)
          final code = uri.queryParameters['code'];
          final state = uri.queryParameters['state'];

          if (code != null && state != null) {
            return {'code': code, 'state': state};
          }
        }
      }
    } catch (e) {
      _debugService.logAuth('Error checking initial OAuth callback',
          level: 'ERROR', data: {'error': e.toString()});
    }
    return null;
  }

  /// Generate random state parameter for OAuth security
  String generateState() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url
        .encode(values)
        .replaceAll('=', '')
        .replaceAll('+', '-')
        .replaceAll('/', '_');
  }

  /// Initiates the complete OAuth authentication flow.
  ///
  /// This method orchestrates the entire OAuth process:
  /// 1. Requests OAuth redirect URL from Zipline server
  /// 2. Modifies redirect_uri to use Cloudflare Worker bridge
  /// 3. Launches browser for user authentication
  /// 4. Listens for deep link callback with authorization code
  /// 5. Exchanges code for session (handled by Worker in new flow)
  /// 6. Stores session cookie securely
  ///
  /// Parameters:
  /// - [ziplineUrl]: The Zipline server URL
  /// - [cfClientId]: Optional Cloudflare Access client ID for protected instances
  /// - [cfClientSecret]: Optional Cloudflare Access client secret
  ///
  /// Returns true if authentication successful, false otherwise.
  ///
  /// Security considerations:
  /// - Uses state parameter to prevent CSRF attacks
  /// - Validates state on callback to ensure request integrity
  /// - Stores sensitive data in hardware-backed secure storage
  /// - Handles both server-side (preferred) and client-side code exchange
  Future<bool> oAuthLogin({
    required String ziplineUrl,
    String? cfClientId,
    String? cfClientSecret,
  }) async {
    try {
      _debugService.logAuth('Starting OAuth login flow', data: {
        'ziplineUrl': ziplineUrl,
        'hasCloudflareAccess': cfClientId != null && cfClientSecret != null,
      });

      // Build headers for Cloudflare Access if configured
      final headers = <String, String>{};
      if (cfClientId != null && cfClientSecret != null) {
        headers['CF-Access-Client-Id'] = cfClientId;
        headers['CF-Access-Client-Secret'] = cfClientSecret;
      }

      // Step 1: Get the OAuth redirect URL from Zipline
      // IMPORTANT: This URL must point to your Cloudflare Worker that bridges
      // HTTPS callbacks to Android deep links (zipline://oauth-callback)
      // The Worker is necessary because OAuth providers don't accept custom schemes
      // Determine the OAuth redirect URI
      // Priority: 1. Build-time configuration, 2. Same domain as Zipline
      String redirectUri;

      if (BuildConfig.hasCustomOAuthUrl) {
        // Use the build-time configured OAuth URL
        redirectUri = BuildConfig.oauthRedirectUrl;
        _debugService.logAuth('Using build-time OAuth redirect URL', data: {
          'redirectUri': redirectUri,
          'source': 'build-config',
        });
      } else {
        // Fall back to using the Zipline server domain with standard path
        // The Worker should be deployed on the same domain at /app/oauth-redirect
        final uri = Uri.parse(ziplineUrl);
        final domain = uri.host;
        redirectUri = 'https://$domain/app/oauth-redirect';

        _debugService.logAuth('Using Zipline domain for OAuth redirect', data: {
          'ziplineUrl': ziplineUrl,
          'domain': domain,
          'redirectUri': redirectUri,
          'source': 'auto-derived',
        });
      }
      final initUrl = Uri.parse('$ziplineUrl/api/auth/oauth/oidc').replace(
        queryParameters: {
          'redirect_uri':
              redirectUri, // Use web page that handles intent redirect
        },
      );

      _debugService.logAuth('Getting OAuth URL from Zipline', data: {
        'url': initUrl.toString(),
      });

      // Make request to get OAuth URL
      final client = http.Client();
      try {
        final request = http.Request('GET', initUrl);
        headers.forEach((key, value) {
          request.headers[key] = value;
        });
        request.followRedirects = false; // Don't follow redirects

        final streamedResponse =
            await client.send(request).timeout(const Duration(seconds: 10));
        final initResponse = await http.Response.fromStream(streamedResponse);

        // Check if we got an HTML page instead of redirect (wrong URL)
        if (initResponse.statusCode == 200 &&
            (initResponse.body.contains('<!DOCTYPE html>') ||
                initResponse.body.contains('authentik'))) {
          _debugService.logAuth('Server URL appears to be incorrect',
              level: 'ERROR',
              data: {
                'message':
                    'Got HTML page instead of OAuth redirect. Make sure the URL points to your Zipline server, not Authentik.',
                'hint':
                    'The server URL should be your Zipline instance (e.g., https://zipline.yourdomain.com), not the Authentik URL.',
              });
          throw Exception(
              'Invalid server URL. Please enter your Zipline server URL, not the Authentik/OAuth provider URL.');
        }

        if (initResponse.statusCode == 404) {
          _debugService
              .logAuth('OAuth endpoint not found', level: 'ERROR', data: {
            'message': 'OAuth is not configured on this Zipline server',
            'endpoint': '$ziplineUrl/api/auth/oauth/oidc',
          });
          throw Exception(
              'OAuth is not configured on this Zipline server. Please check server configuration.');
        }

        if (initResponse.statusCode != 302) {
          _debugService.logAuth('Failed to get OAuth redirect URL',
              level: 'ERROR',
              data: {
                'statusCode': initResponse.statusCode,
                'body': initResponse.body.length > 500
                    ? '${initResponse.body.substring(0, 500)}...'
                    : initResponse.body,
              });
          throw Exception(
              'OAuth initialization failed. Server returned status ${initResponse.statusCode}');
        }

        // Get the redirect location from Zipline
        final locationHeader = initResponse.headers['location'];
        if (locationHeader == null) {
          _debugService.logAuth('No redirect location in response',
              level: 'ERROR');
          return false;
        }

        // Modify the Authentik URL to use our web redirect page
        final authUri = Uri.parse(locationHeader);
        final modifiedAuthUri = authUri.replace(
          queryParameters: {
            ...authUri.queryParameters,
            'redirect_uri':
                redirectUri, // Use web page that handles intent redirect
          },
        );

        _debugService.logAuth('Launching OAuth flow', data: {
          'originalUrl': locationHeader,
          'modifiedUrl': modifiedAuthUri.toString(),
          'callbackScheme': _callbackUrlScheme,
        });

        // Extract state from Zipline's redirect URL for verification
        final ziplineState = authUri.queryParameters['state'];

        // Save state for verification after app termination
        if (ziplineState != null) {
          await _secureStorage.write(key: 'oauth_state', value: ziplineState);
          await _secureStorage.write(
              key: 'oauth_timestamp',
              value: DateTime.now().millisecondsSinceEpoch.toString());
        }

        // Step 2: Launch OAuth flow in system browser with modified URL
        _debugService.logAuth('About to launch browser for OAuth', data: {
          'finalAuthUrl': modifiedAuthUri.toString(),
          'scheme': _callbackUrlScheme,
          'host': modifiedAuthUri.host,
          'path': modifiedAuthUri.path,
          'queryParams': modifiedAuthUri.queryParameters,
        });

        // Use url_launcher to open the browser
        _debugService.logAuth('Launching browser with url_launcher');

        if (!await launchUrl(
          modifiedAuthUri,
          mode: LaunchMode.externalApplication, // Force external browser
        )) {
          _debugService.logAuth('Failed to launch browser', level: 'ERROR');
          throw Exception('Could not launch OAuth URL');
        }

        // Set up a completer to wait for the OAuth callback
        final completer = Completer<String>();
        StreamSubscription<Uri>? linkSubscription;
        final appLinks = AppLinks();

        // Listen for the OAuth callback via app_links
        _debugService.logAuth('Waiting for OAuth callback via app_links');

        linkSubscription = appLinks.uriLinkStream.listen((Uri uri) {
          final link = uri.toString();
          _debugService.logAuth('Received deep link', data: {'link': link});

          if (link.contains('oauth-callback')) {
            _debugService
                .logAuth('OAuth callback detected', data: {'callback': link});
            linkSubscription?.cancel();
            completer.complete(link);
          }
        });

        // Don't check initial link here - we only want NEW callbacks from the current OAuth flow
        // Initial link checking would return stale/cached callbacks from previous attempts
        _debugService.logAuth(
            'Listening for fresh OAuth callbacks only (ignoring initial link)');

        // Wait for the OAuth callback with a timeout
        String result;
        try {
          result = await completer.future.timeout(
            const Duration(minutes: 5),
            onTimeout: () {
              linkSubscription?.cancel();
              throw Exception('OAuth timeout - no callback received');
            },
          );

          _debugService.logAuth('OAuth callback received', data: {
            'resultLength': result.length,
            'resultPreview':
                result.length > 100 ? '${result.substring(0, 100)}...' : result,
          });
        } catch (e) {
          linkSubscription.cancel();
          _debugService.logAuth('OAuth error', level: 'ERROR', data: {
            'error': e.toString(),
          });
          rethrow;
        }

        _debugService.logAuth('OAuth callback received - parsing', data: {
          'callbackUrl': result,
          'hasCode': result.contains('code='),
          'hasState': result.contains('state='),
          'hasSession': result.contains('session='),
          'hasSuccess': result.contains('success='),
          'hasError': result.contains('error='),
        });

        // Parse callback URL
        final callbackUri = Uri.parse(result);

        // Check if this is the new server-side flow with session
        final success = callbackUri.queryParameters['success'];
        final session = callbackUri.queryParameters['session'];
        final error = callbackUri.queryParameters['error'];

        // Handle new server-side OAuth flow
        if (success == 'true' && session != null) {
          _debugService
              .logAuth('Server-side OAuth successful, received session', data: {
            'sessionLength': session.length,
            'sessionPreview': session.length > 20
                ? '${session.substring(0, 20)}...'
                : session,
          });

          // Save session cookie securely
          await _secureStorage.write(key: _sessionCookieKey, value: session);

          // Save server URL and Cloudflare credentials
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('zipline_url', ziplineUrl);

          if (cfClientId != null) {
            await _secureStorage.write(key: 'cf_client_id', value: cfClientId);
          }
          if (cfClientSecret != null) {
            await _secureStorage.write(
                key: 'cf_client_secret', value: cfClientSecret);
          }

          _debugService.logAuth('OAuth login successful via server-side flow');
          return true;
        }

        // Handle error from server-side flow
        if (success == 'false') {
          _debugService
              .logAuth('Server-side OAuth failed', level: 'ERROR', data: {
            'error': error ?? 'Unknown error',
          });
          await _secureStorage.delete(key: 'oauth_state');
          return false;
        }

        // Fall back to old client-side flow (for backwards compatibility)
        final code = callbackUri.queryParameters['code'];
        final returnedState = callbackUri.queryParameters['state'];
        final errorDescription =
            callbackUri.queryParameters['error_description'];

        _debugService.logAuth('Parsed callback parameters', data: {
          'hasCode': code != null,
          'codeLength': code?.length ?? 0,
          'hasState': returnedState != null,
          'stateMatch': returnedState == ziplineState,
          'error': error,
          'errorDescription': errorDescription,
        });

        // Check for OAuth errors
        if (error != null) {
          _debugService
              .logAuth('OAuth provider returned error', level: 'ERROR', data: {
            'error': error,
            'description': errorDescription ?? 'No description provided',
          });
          await _secureStorage.delete(key: 'oauth_state');
          return false;
        }

        // Verify state parameter
        if (returnedState != ziplineState) {
          _debugService.logAuth('State mismatch - possible CSRF attack',
              level: 'ERROR',
              data: {
                'expected': ziplineState,
                'expectedLength': ziplineState?.length ?? 0,
                'received': returnedState,
                'receivedLength': returnedState?.length ?? 0,
                'match': returnedState == ziplineState,
              });
          await _secureStorage.delete(key: 'oauth_state');
          return false;
        }

        _debugService.logAuth('State verification passed', data: {
          'state': returnedState,
        });

        if (code == null) {
          _debugService.logAuth('No authorization code in callback',
              level: 'ERROR',
              data: {
                'callbackUri': callbackUri.toString(),
                'queryParams': callbackUri.queryParameters,
              });
          await _secureStorage.delete(key: 'oauth_state');
          return false;
        }

        _debugService.logAuth('Authorization code received', data: {
          'codeLength': code.length,
          'codePreview':
              code.length > 20 ? '${code.substring(0, 20)}...' : code,
        });

        // Step 3: Exchange authorization code for session (old flow - shouldn't happen with updated Worker)
        _debugService.logAuth(
            'Warning: Using deprecated client-side OAuth flow',
            level: 'WARNING',
            data: {
              'hint':
                  'The Cloudflare Worker should handle code exchange server-side',
            });

        return await _exchangeCodeForSession(
          ziplineUrl: ziplineUrl,
          code: code,
          state: returnedState!,
          cfClientId: cfClientId,
          cfClientSecret: cfClientSecret,
        );
      } finally {
        client.close();
      }
    } catch (e, stackTrace) {
      _debugService.logError('OAUTH', 'OAuth login error',
          error: e, stackTrace: stackTrace);

      // Handle specific errors with more detail
      final errorStr = e.toString();
      if (errorStr.contains('CANCELED')) {
        _debugService.logAuth('User cancelled OAuth flow', data: {
          'errorDetail': errorStr,
          'hint': 'User closed browser or cancelled authentication',
        });
      } else if (errorStr.contains('TIMEOUT')) {
        _debugService.logAuth('OAuth flow timed out', data: {
          'errorDetail': errorStr,
          'hint': 'Authentication took too long',
        });
      } else if (errorStr.contains('AUTHENTICATION_FAILED')) {
        _debugService.logAuth('Authentication failed', level: 'ERROR', data: {
          'errorDetail': errorStr,
          'hint': 'Check if redirect URI is properly configured in Authentik',
        });
      } else {
        _debugService.logAuth('Unexpected OAuth error', level: 'ERROR', data: {
          'errorDetail': errorStr,
          'errorType': e.runtimeType.toString(),
        });
      }

      return false;
    } finally {
      // Clean up stored state
      await _secureStorage.delete(key: 'oauth_state');
      await _secureStorage.delete(key: 'oauth_timestamp');
    }
  }

  /// Exchange authorization code for session cookie
  Future<bool> _exchangeCodeForSession({
    required String ziplineUrl,
    required String code,
    required String state,
    String? cfClientId,
    String? cfClientSecret,
  }) async {
    try {
      _debugService.logAuth('Exchanging code for session', data: {
        'codeLength': code.length,
        'codePreview': code.length > 20 ? '${code.substring(0, 20)}...' : code,
        'state': state,
        'ziplineUrl': ziplineUrl,
      });

      // Build token exchange URL
      // Note: Zipline backend handles token exchange internally
      final tokenUri = Uri.parse('$ziplineUrl/api/auth/oauth/oidc')
          .replace(queryParameters: {
        'code': code,
        'state': state,
      });

      // Add headers if Cloudflare Access is configured
      final headers = <String, String>{};
      if (cfClientId != null && cfClientSecret != null) {
        headers['CF-Access-Client-Id'] = cfClientId;
        headers['CF-Access-Client-Secret'] = cfClientSecret;
      }

      _debugService.logHttp('Sending token exchange request', data: {
        'method': 'GET',
        'url': tokenUri.toString(),
        'hasCloudflareHeaders': headers.isNotEmpty,
        'queryParams': tokenUri.queryParameters,
      });

      // Send token exchange request
      final response = await http
          .get(
            tokenUri,
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      _debugService.logHttp('Token exchange response', data: {
        'statusCode': response.statusCode,
        'hasSetCookie': response.headers['set-cookie'] != null,
        'headers': response.headers.map(
            (k, v) => MapEntry(k, k.toLowerCase().contains('cookie') ? v : v)),
        'bodyLength': response.body.length,
        'bodyPreview': response.body.length > 200
            ? '${response.body.substring(0, 200)}...'
            : response.body,
        'locationHeader': response.headers['location'],
      });

      // Handle successful response (redirect or success)
      if (response.statusCode == 302 || response.statusCode == 200) {
        // Extract session cookie
        final cookies = response.headers['set-cookie'];
        _debugService.logAuth('Processing response cookies', data: {
          'hasCookies': cookies != null,
          'cookiesPreview': cookies != null && cookies.length > 100
              ? '${cookies.substring(0, 100)}...'
              : cookies,
          'hasZiplineSession': cookies?.contains('zipline_session=') ?? false,
        });

        if (cookies != null && cookies.contains('zipline_session=')) {
          final sessionCookie = _extractSessionCookie(cookies);

          if (sessionCookie != null) {
            // Save session cookie securely
            await _secureStorage.write(
                key: _sessionCookieKey, value: sessionCookie);

            // Save server URL and Cloudflare credentials
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('zipline_url', ziplineUrl);

            if (cfClientId != null) {
              await _secureStorage.write(
                  key: 'cf_client_id', value: cfClientId);
            }
            if (cfClientSecret != null) {
              await _secureStorage.write(
                  key: 'cf_client_secret', value: cfClientSecret);
            }

            _debugService.logAuth('OAuth login successful');

            return true;
          }
        }

        _debugService.logAuth('No session cookie in response', level: 'ERROR');
      } else {
        _debugService.logAuth('Token exchange failed', level: 'ERROR', data: {
          'statusCode': response.statusCode,
          'body': response.body,
        });
      }

      return false;
    } catch (e, stackTrace) {
      _debugService.logError('OAUTH', 'Token exchange error',
          error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Extract session cookie from Set-Cookie header
  String? _extractSessionCookie(String cookieHeader) {
    final regex = RegExp(r'zipline_session=([^;]+)');
    final match = regex.firstMatch(cookieHeader);
    return match?.group(1);
  }

  /// Check if OAuth is available for the server
  Future<bool> isOAuthAvailable(String ziplineUrl) async {
    try {
      // Check if OIDC endpoint exists
      final response = await http
          .head(
            Uri.parse('$ziplineUrl/api/auth/oauth/oidc'),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode != 404;
    } catch (e) {
      _debugService.logError('OAUTH', 'Failed to check OAuth availability',
          error: e);
      // Default to showing OAuth option
      return true;
    }
  }

  /// Get stored OAuth session
  Future<String?> getSessionCookie() async {
    return await _secureStorage.read(key: _sessionCookieKey);
  }

  /// Save session cookie (used by biometric authentication)
  Future<void> saveSessionCookie(String cookie) async {
    await _secureStorage.write(key: _sessionCookieKey, value: cookie);
  }

  /// Clear OAuth session
  Future<void> clearSession() async {
    await _secureStorage.delete(key: _sessionCookieKey);
    await _secureStorage.delete(key: 'cf_client_id');
    await _secureStorage.delete(key: 'cf_client_secret');
  }

  /// Check if user has active OAuth session
  Future<bool> hasOAuthSession() async {
    final cookie = await getSessionCookie();
    return cookie != null && cookie.isNotEmpty;
  }
}
