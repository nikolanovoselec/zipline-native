import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/debug_service.dart';
import '../services/biometric_service.dart';
import '../widgets/common/minimal_text_field.dart';
import '../providers/theme_provider.dart';
import 'debug_screen.dart';
import 'simple_login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final DebugService _debugService = DebugService();
  final BiometricService _biometricService = BiometricService();

  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _cfClientIdController = TextEditingController();
  final _cfClientSecretController = TextEditingController();

  bool _isLoading = false;
  bool _hasChanges = false;
  bool _debugLogsEnabled = true;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _debugService.log('SETTINGS', 'Settings screen initialized');
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    _debugService.log('SETTINGS', 'Loading current settings');

    try {
      final credentials = await _authService.getCredentials();
      await _debugService.initialize(); // Ensure debug service is initialized
      setState(() {
        final ziplineUrl = (credentials['ziplineUrl'] ?? '').trim();
        _urlController.text = ziplineUrl;
        _cfClientIdController.text = credentials['cfClientId'] ?? '';
        _cfClientSecretController.text = credentials['cfClientSecret'] ?? '';
        _debugLogsEnabled = _debugService.debugLogsEnabled;
      });

      // Check biometric availability and status
      _biometricAvailable = await _biometricService.isBiometricAvailable();
      _biometricEnabled = await _biometricService.isBiometricEnabled();

      setState(() {});

      _debugService.log('SETTINGS', 'Settings loaded successfully', data: {
        'hasZiplineUrl': credentials['ziplineUrl'] != null,
        'hasCfClientId': credentials['cfClientId'] != null,
        'hasCfClientSecret': credentials['cfClientSecret'] != null,
        'debugLogsEnabled': _debugLogsEnabled,
      });
    } catch (e, stackTrace) {
      _debugService.logError('SETTINGS', 'Failed to load settings',
          error: e, stackTrace: stackTrace);
      _showErrorSnackBar('Failed to load settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      _debugService.log('SETTINGS', 'Settings form validation failed');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    _debugService.log('SETTINGS', 'Saving settings', data: {
      'ziplineUrl': _urlController.text.trim(),
      'hasCfClientId': _cfClientIdController.text.trim().isNotEmpty,
      'hasCfClientSecret': _cfClientSecretController.text.trim().isNotEmpty,
    });

    try {
      // Get current credentials to preserve username/password
      final currentCredentials = await _authService.getCredentials();

      // Save updated settings while preserving authentication
      await _authService.saveCredentials(
        ziplineUrl: _urlController.text.trim(),
        username: currentCredentials['username'] ?? '',
        password: currentCredentials['password'] ?? '',
        cfClientId: _cfClientIdController.text.trim().isEmpty
            ? null
            : _cfClientIdController.text.trim(),
        cfClientSecret: _cfClientSecretController.text.trim().isEmpty
            ? null
            : _cfClientSecretController.text.trim(),
      );

      _debugService.log('SETTINGS', 'Settings saved successfully');

      setState(() {
        _hasChanges = false;
      });

      HapticFeedback.lightImpact();
      _showSuccessSnackBar('Settings saved successfully');
    } catch (e, stackTrace) {
      _debugService.logError('SETTINGS', 'Failed to save settings',
          error: e, stackTrace: stackTrace);
      _showErrorSnackBar('Failed to save settings: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  Future<void> _toggleDebugLogs(bool enabled) async {
    await _debugService.setDebugLogsEnabled(enabled);
    setState(() {
      _debugLogsEnabled = enabled;
    });
  }

  Future<void> _toggleBiometric(bool enabled) async {
    if (enabled) {
      // Enable biometric - need to authenticate first
      final authenticated = await _biometricService.authenticate(
        reason: 'Verify your identity to enable biometric login',
      );

      if (authenticated) {
        // Get current auth token
        final token = await _authService.getAuthToken();
        if (token != null) {
          await _biometricService.enableBiometric(token);
          setState(() {
            _biometricEnabled = true;
          });
          _showSuccessSnackBar('Biometric authentication enabled');
        } else {
          _showErrorSnackBar(
              'Please login first to enable biometric authentication');
        }
      }
    } else {
      // Disable biometric
      await _biometricService.disableBiometric();
      setState(() {
        _biometricEnabled = false;
      });
      _showSuccessSnackBar('Biometric authentication disabled');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
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

  Future<void> _logout() async {
    _debugService.log('SETTINGS', 'User initiated logout');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B263B),
        icon: Icon(
          Icons.logout,
          color: const Color(0xFFFF6B6B),
          size: 48,
        ),
        title: Text(
          'Logout',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        content: Text(
          'Are you sure you want to logout? You will need to login again to access your Zipline server.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        _debugService.log('SETTINGS', 'Logging out user');

        // Clear all authentication data
        await _authService.logout();

        _debugService.log('SETTINGS', 'Logout successful, navigating to login');

        if (mounted) {
          // Navigate to login screen and clear navigation stack
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const SimpleLoginScreen(),
            ),
            (route) => false,
          );
        }
      } catch (e, stackTrace) {
        _debugService.logError('SETTINGS', 'Logout failed',
            error: e, stackTrace: stackTrace);
        _showErrorSnackBar('Logout failed: $e');
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _cfClientIdController.dispose();
    _cfClientSecretController.dispose();
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

  Widget _buildIcon(IconData icon) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFF1976D2).withValues(alpha: 0.18),
        border: Border.all(
          color: const Color(0xFF1976D2).withValues(alpha: 0.81),
          width: 1.1,
        ),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: const Color(0xFF1976D2).withValues(alpha: 0.86),
        size: 16,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
    String? Function(String?)? validator,
    Function(String)? onChanged,
    bool obscureText = false,
    IconData? icon,
    String? prefix,
  }) {
    return MinimalTextField(
      controller: controller,
      label: label,
      placeholder: placeholder,
      validator: validator,
      onChanged: onChanged,
      obscureText: obscureText,
      icon: icon,
      prefix: prefix,
    );
  }

  Widget _buildServerUrlTextField() {
    return _buildTextField(
      controller: _urlController,
      label: '', // Remove redundant label
      placeholder: 'https://zipline.example.com',
      icon: Icons.dns_outlined,
      validator: (value) {
        final trimmed = value?.trim() ?? '';
        if (trimmed.isEmpty) {
          return 'Please enter your Zipline server URL';
        }
        final uri = Uri.tryParse(trimmed);
        if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
          return 'Please enter a valid server address';
        }
        return null;
      },
      onChanged: (_) => _onFieldChanged(),
    );
  }

  Widget _buildButton({
    required String text,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1976D2).withValues(alpha: 0.1),
          border: Border.all(
            color: const Color(0xFF1976D2).withValues(alpha: 0.78),
            width: 0.85,
          ),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(17),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: const Color(0xFF1976D2).withValues(alpha: 0.88),
                      ),
                    )
                  : Text(
                      text,
                      style: TextStyle(
                        color: const Color(0xFF1976D2).withValues(alpha: 0.88),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && _hasChanges) {
          final shouldDiscard = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              icon: const Icon(Icons.warning, color: Colors.orange),
              title: const Text('Unsaved Changes'),
              content: const Text(
                  'You have unsaved changes. Do you want to discard them?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text('Discard'),
                ),
              ],
            ),
          );

          if (shouldDiscard == true && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D1B2A),
          foregroundColor: Colors.white.withValues(alpha: 0.94),
          elevation: 0,
          title: Text(
            'Settings',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.94),
              fontSize: 20,
              fontWeight: FontWeight.w400,
            ),
          ),
          actions: [
            if (_hasChanges)
              IconButton(
                icon: _isLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      )
                    : Icon(
                        Icons.save,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                onPressed: _isLoading ? null : _saveSettings,
                tooltip: 'Save Settings',
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Merged Server Configuration & Cloudflare Access Card
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Server Configuration Section
                    Row(
                      children: [
                        _buildIcon(Icons.cloud),
                        const SizedBox(width: 12),
                        Text(
                          'Server Configuration',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.91),
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'URL of your Zipline server instance',
                      style: TextStyle(
                        color: const Color(0xFF94A3B8).withValues(alpha: 0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(0, -8),
                      child: _buildServerUrlTextField(),
                    ),

                    const SizedBox(height: 24),

                    // Cloudflare Access Section
                    Row(
                      children: [
                        _buildIcon(Icons.security),
                        const SizedBox(width: 12),
                        Text(
                          'Cloudflare Access',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.91),
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Configure if your server uses Cloudflare Access',
                      style: TextStyle(
                        color: const Color(0xFF94A3B8).withValues(alpha: 0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(0, -8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField(
                            controller: _cfClientIdController,
                            label: '',
                            placeholder: '8bb843d76201be508546c94a8a19',
                            icon: Icons.vpn_key_outlined,
                            onChanged: (_) => _onFieldChanged(),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your Cloudflare Access application ID',
                            style: TextStyle(
                              color: const Color(0xFF94A3B8)
                                  .withValues(alpha: 0.72),
                              fontSize: 12,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Client Secret Field - pulled up VERY tight to helper text above
                    Transform.translate(
                      offset: const Offset(0, -16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField(
                            controller: _cfClientSecretController,
                            label: '',
                            placeholder: '••••••••••••••••••••••••••••••••',
                            obscureText: true,
                            icon: Icons.key_outlined,
                            onChanged: (_) => _onFieldChanged(),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your Cloudflare Access application secret',
                            style: TextStyle(
                              color: const Color(0xFF94A3B8)
                                  .withValues(alpha: 0.72),
                              fontSize: 12,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Save Settings Button (inside card)
                    _buildButton(
                      text: _isLoading ? 'Saving...' : 'Save Settings',
                      onPressed: _isLoading ? null : _saveSettings,
                      isLoading: _isLoading,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Debug Logs Section
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildIcon(Icons.developer_mode),
                        const SizedBox(width: 12),
                        Text(
                          'Debug & Troubleshooting',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.91),
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Access logs for troubleshooting',
                      style: TextStyle(
                        color: const Color(0xFF94A3B8).withValues(alpha: 0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Enable Debug Logging',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        Switch(
                          value: _debugLogsEnabled,
                          onChanged: _toggleDebugLogs,
                          activeThumbColor: const Color(0xFF1976D2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildButton(
                      text: 'View Debug Logs',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const DebugScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Theme Section
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildIcon(Icons.palette_outlined),
                        const SizedBox(width: 12),
                        Text(
                          'Appearance',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.91),
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose between dark and light theme',
                      style: TextStyle(
                        color: const Color(0xFF94A3B8).withValues(alpha: 0.72),
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Consumer<ThemeProvider>(
                      builder: (context, themeProvider, child) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Dark Mode',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.81),
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            Switch(
                              value: themeProvider.isDarkMode,
                              onChanged: (_) => themeProvider.toggleTheme(),
                              activeThumbColor: const Color(0xFF1976D2),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Biometric Authentication Section
              if (_biometricAvailable)
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildIcon(Icons.fingerprint),
                          const SizedBox(width: 12),
                          Text(
                            'Biometric Authentication',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.91),
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use fingerprint or face recognition for quick access',
                        style: TextStyle(
                          color:
                              const Color(0xFF94A3B8).withValues(alpha: 0.72),
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Enable Biometric Login',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.81),
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Switch(
                            value: _biometricEnabled,
                            onChanged: _toggleBiometric,
                            activeThumbColor: const Color(0xFF4CAF50),
                          ),
                        ],
                      ),
                      if (_biometricEnabled) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: const Color(0xFF4CAF50),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Biometric login is active',
                              style: TextStyle(
                                color: const Color(0xFF4CAF50)
                                    .withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

              if (_biometricAvailable) const SizedBox(height: 16),

              // Info Card
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildIcon(Icons.info_outline),
                        const SizedBox(width: 12),
                        Text(
                          'Information',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.91),
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '• Server URL is required for all functionality\n'
                      '• Cloudflare Access credentials are optional\n'
                      '• Changes are saved when you tap Save\n'
                      '• Use Debug Logs for troubleshooting',
                      style: TextStyle(
                        color: const Color(0xFF94A3B8).withValues(alpha: 0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Logout Button - Red glassmorphic style
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF6B6B).withValues(alpha: 0.08),
                      const Color(0xFFFF6B6B).withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _logout,
                    borderRadius: BorderRadius.circular(18),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.logout,
                            color:
                                const Color(0xFFFF6B6B).withValues(alpha: 0.9),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Logout',
                            style: TextStyle(
                              color: const Color(0xFFFF6B6B)
                                  .withValues(alpha: 0.9),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
