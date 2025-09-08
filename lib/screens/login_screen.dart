import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/oauth_service.dart';
import '../widgets/common/minimal_text_field.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final OAuthService _oAuthService = OAuthService();
  final _formKey = GlobalKey<FormState>();

  final _ziplineUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _twoFactorController = TextEditingController();
  final _cfClientIdController = TextEditingController();
  final _cfClientSecretController = TextEditingController();

  bool _isLoading = false;
  bool _showAdvanced = false;
  bool _showTwoFactorField = false;
  int _loginAttempts = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  Future<void> _loadSavedCredentials() async {
    final credentials = await _authService.getCredentials();
    if (mounted) {
      setState(() {
        _ziplineUrlController.text = credentials['ziplineUrl'] ?? '';
        _usernameController.text = credentials['username'] ?? '';
        _cfClientIdController.text = credentials['cfClientId'] ?? '';
        _cfClientSecretController.text = credentials['cfClientSecret'] ?? '';
        if (credentials['cfClientId'] != null &&
            credentials['cfClientId']!.isNotEmpty) {
          _showAdvanced = true;
        }
      });
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _loginAttempts++;
    });

    try {
      final success = await _authService.authenticateWithZipline(
        ziplineUrl: _ziplineUrlController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        twoFactorCode:
            _showTwoFactorField && _twoFactorController.text.trim().isNotEmpty
                ? _twoFactorController.text.trim()
                : null,
        cfClientId: _cfClientIdController.text.trim().isEmpty
            ? null
            : _cfClientIdController.text.trim(),
        cfClientSecret: _cfClientSecretController.text.trim().isEmpty
            ? null
            : _cfClientSecretController.text.trim(),
      );

      if (success && mounted) {
        HapticFeedback.lightImpact();
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
      } else if (mounted) {
        // Intelligently detect if 2FA is needed based on login attempts
        // and whether server returned 401 on first attempt
        if (!_showTwoFactorField && _loginAttempts == 1) {
          setState(() {
            _showTwoFactorField = true;
          });
          _showErrorSnackBar('2FA code required');
          // Focus on 2FA field
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) FocusScope.of(context).requestFocus(FocusNode());
          });
        } else {
          _showErrorSnackBar('Authentication failed');
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        if (errorMessage.contains('401')) {
          if (!_showTwoFactorField) {
            setState(() {
              _showTwoFactorField = true;
            });
            _showErrorSnackBar('2FA code required');
          } else {
            _showErrorSnackBar('Invalid credentials or 2FA code');
          }
        } else {
          _showErrorSnackBar('Connection error');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _oauthLogin() async {
    final ziplineUrl = _ziplineUrlController.text.trim();
    if (ziplineUrl.isEmpty) {
      _showErrorSnackBar('Please enter your Zipline server URL');
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.selectionClick();

    try {
      final success = await _oAuthService.oAuthLogin(
        ziplineUrl: ziplineUrl,
        cfClientId: _cfClientIdController.text.trim().isEmpty
            ? null
            : _cfClientIdController.text.trim(),
        cfClientSecret: _cfClientSecretController.text.trim().isEmpty
            ? null
            : _cfClientSecretController.text.trim(),
      );

      if (success && mounted) {
        HapticFeedback.lightImpact();
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
      } else if (mounted) {
        _showErrorSnackBar('OIDC authentication failed');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('OIDC error occurred');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
    _ziplineUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _twoFactorController.dispose();
    _cfClientIdController.dispose();
    _cfClientSecretController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: child,
      ),
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
      height: 48,
      child: isPrimary
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    const Color(0xFF3B82F6).withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      text,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon:
                  icon != null ? Icon(icon, size: 20) : const SizedBox.shrink(),
              label: Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF94A3B8),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.cloud_upload_outlined,
                              size: 40,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Zipline Sharing',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.94),
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign in to your server',
                            style: TextStyle(
                              color: const Color(0xFF94A3B8).withValues(alpha: 0.77),
                              fontSize: 14,
                              fontWeight: FontWeight.w300,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // Login Card
                      _buildCard(
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Server URL Field
                              MinimalTextField(
                                controller: _ziplineUrlController,
                                label: 'Server URL',
                                placeholder: 'https://zipline.example.com',
                                icon: Icons.dns_outlined,
                                keyboardType: TextInputType.url,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.url],
                                validator: (value) {
                                  if (value?.isEmpty ?? true) {
                                    return 'Server URL is required';
                                  }
                                  if (!value!.startsWith('http://') &&
                                      !value.startsWith('https://')) {
                                    return 'Must start with http:// or https://';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),

                              // Username Field
                              MinimalTextField(
                                controller: _usernameController,
                                label: 'Username',
                                placeholder: 'Enter your username',
                                icon: Icons.person_outline,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.username],
                                validator: (value) {
                                  if (value?.isEmpty ?? true) {
                                    return 'Username is required';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),

                              // Password Field
                              MinimalTextField(
                                controller: _passwordController,
                                label: 'Password',
                                placeholder: 'Enter your password',
                                icon: Icons.lock_outline,
                                obscureText: true,
                                textInputAction: _showTwoFactorField
                                    ? TextInputAction.next
                                    : TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                onFieldSubmitted: (_) {
                                  if (!_showTwoFactorField && !_isLoading) {
                                    _login();
                                  }
                                },
                                validator: (value) {
                                  if (value?.isEmpty ?? true) {
                                    return 'Password is required';
                                  }
                                  return null;
                                },
                              ),

                              // 2FA Field (animated appearance)
                              AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                child: _showTwoFactorField
                                    ? Column(
                                        children: [
                                          const SizedBox(height: 16),
                                          MinimalTextField(
                                            controller: _twoFactorController,
                                            label: '2FA Code',
                                            placeholder: '000000',
                                            icon: Icons.security_outlined,
                                            keyboardType: TextInputType.number,
                                            textInputAction: TextInputAction.done,
                                            autofillHints: const [AutofillHints.oneTimeCode],
                                            onFieldSubmitted: (_) =>
                                                !_isLoading ? _login() : null,
                                          ),
                                        ],
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Login Button
                      _buildButton(
                        text: _isLoading ? 'Signing in...' : 'Sign In',
                        onPressed: _isLoading ? null : _login,
                        isLoading: _isLoading,
                      ),

                      const SizedBox(height: 12),

                      // OIDC Button
                      _buildButton(
                        text: 'Login with OIDC',
                        onPressed: _isLoading ? null : _oauthLogin,
                        isPrimary: false,
                        icon: Icons.security,
                      ),

                      const SizedBox(height: 16),

                      // Advanced Settings Toggle
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _showAdvanced = !_showAdvanced;
                          });
                        },
                        icon: AnimatedRotation(
                          turns: _showAdvanced ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.expand_more,
                            color: const Color(0xFF94A3B8).withValues(alpha: 0.7),
                          ),
                        ),
                        label: Text(
                          _showAdvanced ? 'Hide Advanced' : 'Advanced Settings',
                          style: TextStyle(
                            color: const Color(0xFF94A3B8).withValues(alpha: 0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF94A3B8),
                        ),
                      ),

                      // Advanced Settings (Cloudflare Access)
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: _showAdvanced
                            ? Column(
                                children: [
                                  const SizedBox(height: 8),
                                  _buildCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.cloud_outlined,
                                              color: const Color(0xFF3B82F6)
                                                  .withValues(alpha: 0.8),
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Cloudflare Access',
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withValues(alpha: 0.9),
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Only required if your server uses Cloudflare Access',
                                          style: TextStyle(
                                            color: const Color(0xFF94A3B8)
                                                .withValues(alpha: 0.6),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w300,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        MinimalTextField(
                                          controller: _cfClientIdController,
                                          label: 'CF-Access-Client-Id',
                                          placeholder: 'Enter your Client ID',
                                          icon: Icons.vpn_key_outlined,
                                        ),
                                        const SizedBox(height: 12),
                                        MinimalTextField(
                                          controller: _cfClientSecretController,
                                          label: 'CF-Access-Client-Secret',
                                          placeholder: 'Enter your Client Secret',
                                          icon: Icons.key_outlined,
                                          obscureText: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
