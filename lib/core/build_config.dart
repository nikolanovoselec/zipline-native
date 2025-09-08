/// Build-time configuration for the app
///
/// These values can be set at build time using:
/// flutter build apk --dart-define=OAUTH_REDIRECT_URL=https://your-worker.com/app/oauth-redirect
///
/// If not specified, the app will use sensible defaults.
class BuildConfig {
  /// OAuth redirect URL for Cloudflare Worker
  /// Can be set at build time with: --dart-define=OAUTH_REDIRECT_URL=<url>
  /// If not set, will use the Zipline server domain with /app/oauth-redirect path
  static const String oauthRedirectUrl = String.fromEnvironment(
    'OAUTH_REDIRECT_URL',
    defaultValue: '',
  );

  /// Whether OAuth redirect URL was provided at build time
  static bool get hasCustomOAuthUrl => oauthRedirectUrl.isNotEmpty;
}
