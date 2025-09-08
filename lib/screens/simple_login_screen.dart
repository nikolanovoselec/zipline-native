import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/debug_service.dart';
import '../services/biometric_service.dart';
import '../widgets/common/minimal_text_field.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'debug_screen.dart';

class SimpleLoginScreen extends StatefulWidget {
  const SimpleLoginScreen({super.key});

  @override
  State<SimpleLoginScreen> createState() => _SimpleLoginScreenState();
}

class _SimpleLoginScreenState extends State<SimpleLoginScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final DebugService _debugService = DebugService();
  final BiometricService _biometricService = BiometricService();

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _twoFactorController = TextEditingController();

  bool _isLoading = false;
  final bool _obscurePassword = true;
  String? _serverUrl;
  bool _debugLogsEnabled = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _debugService.log('LOGIN', 'Login screen initialized');

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuart,
    ));

    _loadSavedCredentials();
    _animationController.forward();
  }

  Future<void> _loadSavedCredentials() async {
    _debugService.log('LOGIN', 'Loading saved credentials');

    try {
      final credentials = await _authService.getCredentials();
      await _debugService.initialize();
      setState(() {
        _usernameController.text = credentials['username'] ?? '';
        _serverUrl = credentials['ziplineUrl'];
        _debugLogsEnabled = _debugService.debugLogsEnabled;
      });

      _debugService.log('LOGIN', 'Credentials loaded', data: {
        'hasUsername': credentials['username'] != null,
        'hasServerUrl': credentials['ziplineUrl'] != null,
        'debugLogsEnabled': _debugLogsEnabled,
      });

      // Try biometric login if available and enabled
      await _attemptBiometricLogin();
    } catch (e, stackTrace) {
      _debugService.logError('LOGIN', 'Failed to load credentials',
          error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _loginWithOIDC() async {
    if (_serverUrl == null || _serverUrl!.isEmpty) {
      _debugService.log('LOGIN', 'Server URL not configured', level: 'ERROR');
      _showErrorSnackBar(
          'Please configure your Zipline server URL in Settings first');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    _debugService.log('LOGIN', 'Starting OIDC authentication', data: {
      'serverUrl': _serverUrl,
    });

    try {
      final credentials = await _authService.getCredentials();
      final success = await _authService.authenticateWithOIDC(
        ziplineUrl: _serverUrl!,
        cfClientId: credentials['cfClientId'],
        cfClientSecret: credentials['cfClientSecret'],
      );

      _debugService.log('LOGIN', 'OIDC authentication result',
          data: {'success': success});

      if (success) {
        _debugService.log('LOGIN', 'OIDC login successful');
        HapticFeedback.lightImpact();

        // Check if biometric is available and not yet enabled
        await _checkAndPromptForBiometric();

        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const HomeScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1.0, 0.0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOut,
                  )),
                  child: child,
                );
              },
            ),
          );
        }
      } else {
        _debugService.log('LOGIN', 'OIDC authentication failed',
            level: 'ERROR');
        _showErrorSnackBar('OAuth authentication failed. Please try again.');
      }
    } catch (e, stackTrace) {
      _debugService.logError('LOGIN', 'OIDC login exception',
          error: e, stackTrace: stackTrace);
      _showErrorSnackBar('OAuth login failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      _debugService.log('LOGIN', 'Form validation failed');
      return;
    }

    if (_serverUrl == null || _serverUrl!.isEmpty) {
      _debugService.log('LOGIN', 'Server URL not configured', level: 'ERROR');
      _showErrorSnackBar(
          'Please configure your Zipline server URL in Settings first');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    _debugService.log('LOGIN', 'Starting authentication', data: {
      'username': _usernameController.text.trim(),
      'has2FA': _twoFactorController.text.trim().isNotEmpty,
      'serverUrl': _serverUrl,
    });

    try {
      final credentials = await _authService.getCredentials();
      final success = await _authService.authenticateWithZipline(
        ziplineUrl: _serverUrl!,
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        twoFactorCode: _twoFactorController.text.trim().isEmpty
            ? null
            : _twoFactorController.text.trim(),
        cfClientId: credentials['cfClientId'],
        cfClientSecret: credentials['cfClientSecret'],
      );

      _debugService
          .log('LOGIN', 'Authentication result', data: {'success': success});

      if (success) {
        _debugService.log('LOGIN', 'Login successful');
        HapticFeedback.lightImpact();

        // Check if biometric is available and not yet enabled
        await _checkAndPromptForBiometric();

        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const HomeScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1.0, 0.0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOut,
                  )),
                  child: child,
                );
              },
            ),
          );
        }
      } else {
        _debugService.log('LOGIN', 'Authentication failed', level: 'ERROR');
        _showErrorSnackBar(
            'Authentication failed. Please check your credentials.');
      }
    } catch (e, stackTrace) {
      _debugService.logError('LOGIN', 'Login exception',
          error: e, stackTrace: stackTrace);
      _showErrorSnackBar('Login failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkAndPromptForBiometric() async {
    // Check if biometric is already enabled
    final isEnabled = await _biometricService.isBiometricEnabled();
    if (isEnabled) {
      _debugService.log('LOGIN', 'Biometric already enabled');
      return;
    }

    // Check if biometric is available on device
    final isAvailable = await _biometricService.isBiometricAvailable();
    if (!isAvailable) {
      _debugService.log('LOGIN', 'Biometric not available on device');
      return;
    }

    // Get available biometric types
    final biometricTypes = await _biometricService.getAvailableBiometricTypes();
    final biometricText =
        biometricTypes.isNotEmpty ? biometricTypes.join(', ') : 'Biometric';

    // Show dialog to enable biometric
    if (mounted) {
      final shouldEnable = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Enable Biometric Authentication'),
            content: Text(
              'Would you like to use $biometricText to quickly access Zipline in the future?\n\n'
              'This will allow you to skip entering your credentials each time.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Not Now'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Enable'),
              ),
            ],
          );
        },
      );

      if (shouldEnable == true) {
        // First authenticate with biometrics to confirm identity
        final authenticated = await _biometricService.authenticate(
          reason: 'Verify your identity to enable biometric authentication',
        );

        if (authenticated) {
          // Get the current auth token
          final token = await _authService.getAuthToken();
          if (token != null) {
            await _biometricService.enableBiometric(token);
            _debugService.log('LOGIN', 'Biometric authentication enabled');

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.fingerprint, color: Colors.white),
                      const SizedBox(width: 12),
                      const Text('Biometric authentication enabled'),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                ),
              );
            }
          }
        } else {
          _debugService.log(
              'LOGIN', 'Biometric authentication cancelled or failed');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Biometric setup cancelled'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.all(16),
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _attemptBiometricLogin() async {
    // Check if biometric is enabled
    final isEnabled = await _biometricService.isBiometricEnabled();
    if (!isEnabled) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Authenticate with biometrics and get token
      final token = await _biometricService.authenticateAndGetToken();

      if (token != null) {
        // Set the token in auth service
        await _authService.setAuthToken(token);

        // Verify token is still valid
        final isValid = await _authService.isAuthenticated();

        if (isValid) {
          _debugService.log('LOGIN', 'Biometric login successful');
          HapticFeedback.lightImpact();

          if (mounted) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const HomeScreen(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1.0, 0.0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOut,
                    )),
                    child: child,
                  );
                },
              ),
            );
          }
        } else {
          _debugService.log('LOGIN', 'Stored token is invalid');
          // Token is invalid, disable biometric
          await _biometricService.disableBiometric();
          _showErrorSnackBar('Session expired. Please login again.');
        }
      }
    } catch (e) {
      _debugService.logError('LOGIN', 'Biometric login failed', error: e);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _twoFactorController.dispose();
    super.dispose();
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.041),
            Colors.white.withValues(alpha: 0.019),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.09),
          width: 0.29,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }


  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
    required IconData icon,
    bool obscureText = false,
    String? Function(String?)? validator,
    TextInputAction? textInputAction,
    void Function(String)? onFieldSubmitted,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    List<String>? autofillHints,
  }) {
    return MinimalTextField(
      controller: controller,
      label: label,
      placeholder: placeholder,
      icon: icon,
      obscureText: obscureText,
      validator: validator,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      autofillHints: autofillHints,
    );
  }

  Widget _buildButton({
    required String text,
    required VoidCallback? onPressed,
    bool isLoading = false,
    bool isPrimary = true,
    IconData? icon,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              color: isPrimary
                  ? const Color(0xFF1976D2).withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: isPrimary
                    ? const Color(0xFF1976D2).withValues(alpha: 0.78)
                    : Colors.white.withValues(alpha: 0.2),
                width: 1.1,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: isLoading
                ? Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isPrimary
                              ? const Color(0xFF1976D2).withValues(alpha: 0.88)
                              : Colors.white.withValues(alpha: 0.7),
                        ),
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          color: isPrimary
                              ? const Color(0xFF1976D2).withValues(alpha: 0.88)
                              : Colors.white.withValues(alpha: 0.7),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        text,
                        style: TextStyle(
                          color: isPrimary
                              ? const Color(0xFF1976D2).withValues(alpha: 0.88)
                              : Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Stack(
          children: [
            // Settings button in top-right corner with increased touch area
            Positioned(
              top: 18, // Adjusted to account for padding
              right: 18, // Adjusted to account for padding
              child: GestureDetector(
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                  _loadSavedCredentials();
                },
                child: Container(
                  padding: const EdgeInsets.all(6), // Adds 6px touch area around icon
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 0.3,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.settings_outlined,
                      color: const Color(0xFF94A3B8).withValues(alpha: 0.7),
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
            // Main content
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo and Title
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1976D2).withValues(alpha: 0.1),
                              border: Border.all(
                                color: const Color(0xFF1976D2).withValues(alpha: 0.3),
                                width: 1,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.cloud_upload,
                              size: 50,
                              color: const Color(0xFF1976D2).withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            'Zipline Sharing',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign in to your Zipline server',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 14,
                              fontWeight: FontWeight.w300,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 40),

                          // Login form card
                          _buildCard(
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  _buildTextField(
                                    controller: _usernameController,
                                    label: 'Username',
                                    placeholder: 'Enter your username',
                                    icon: Icons.person_outline,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your username';
                                      }
                                      return null;
                                    },
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [
                                      AutofillHints.username
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  _buildTextField(
                                    controller: _passwordController,
                                    label: 'Password',
                                    placeholder: 'Enter your password',
                                    icon: Icons.lock_outline,
                                    obscureText: _obscurePassword,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your password';
                                      }
                                      return null;
                                    },
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _login(),
                                    autofillHints: const [
                                      AutofillHints.password
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  _buildTextField(
                                    controller: _twoFactorController,
                                    label: '2FA Code (optional)',
                                    placeholder: 'Enter 2FA code if enabled',
                                    icon: Icons.security,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _login(),
                                    autofillHints: const [
                                      AutofillHints.oneTimeCode
                                    ],
                                  ),
                                  const SizedBox(height: 32),
                                  _buildButton(
                                    text: 'Sign In',
                                    onPressed: _login,
                                    isLoading: _isLoading,
                                    icon: Icons.login,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildButton(
                                    text: 'Login with OIDC',
                                    onPressed: _loginWithOIDC,
                                    isLoading: false,
                                    isPrimary: false,
                                    icon: Icons.security,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Debug Logs button (only show if enabled)
                          if (_debugLogsEnabled) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFFF6B6B).withValues(alpha: 0.05),
                                    const Color(0xFFFF6B6B).withValues(alpha: 0.02),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(
                                  color:
                                      const Color(0xFFFF6B6B).withValues(alpha: 0.2),
                                  width: 0.29,
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const DebugScreen(),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(18),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.bug_report,
                                        color: const Color(0xFFFF6B6B)
                                            .withValues(alpha: 0.7),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Debug Logs',
                                        style: TextStyle(
                                          color: const Color(0xFFFF6B6B)
                                              .withValues(alpha: 0.7),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
