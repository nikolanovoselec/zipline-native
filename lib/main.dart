import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/biometric_service.dart';
import 'services/connectivity_service.dart';
import 'screens/simple_login_screen.dart';
import 'screens/home_screen.dart';
import 'core/service_locator.dart';
import 'core/constants.dart';
import 'providers/app_state.dart';
import 'providers/theme_provider.dart';
import 'widgets/upload_queue_overlay.dart';

void main() {
  // Setup dependency injection
  setupServiceLocator();
  
  // Initialize sharing service
  locator.sharing.initialize();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: locator.connectivity),
      ],
      child: const ZiplineNativeApp(),
    ),
  );
}

class ZiplineNativeApp extends StatelessWidget {
  const ZiplineNativeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Zipline Sharing',
          builder: (context, child) {
            return UploadQueueOverlay(
              child: Stack(
                children: [
                  // Connection status banner
                  Consumer<ConnectivityService>(
                    builder: (context, connectivity, _) {
                      if (!connectivity.isConnected) {
                        return Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Material(
                            color: AppConstants.warningColor,
                            child: SafeArea(
                              bottom: false,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.wifi_off,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'No internet connection',
                                      style: TextStyle(
                                        color: Colors.white,
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
                      return const SizedBox.shrink();
                    },
                  ),
                  child!,
                  const UploadQueueFloatingButton(),
                ],
              ),
            );
          },
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const SplashScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = locator.auth;
  final BiometricService _biometricService = locator.biometric;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Add a short delay for splash screen effect
    await Future.delayed(const Duration(milliseconds: 400));

    final isAuthenticated = await _authService.isAuthenticated();

    if (isAuthenticated) {
      // Check if biometric is enabled
      final biometricEnabled = await _biometricService.isBiometricEnabled();

      if (biometricEnabled) {
        // Prompt for biometric authentication
        final authenticated = await _biometricService.authenticate(
          reason: 'Authenticate to access Zipline',
        );

        if (!authenticated && mounted) {
          // If biometric authentication fails, go to login screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const SimpleLoginScreen(),
            ),
          );
          return;
        }
      }

      // Biometric passed or not enabled, go to home
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
        );
      }
    } else {
      // Not authenticated, go to login
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const SimpleLoginScreen(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D1B2A), // Dark navy
              Color(0xFF1B263B), // Slightly lighter navy
              Color(0xFF2D3748), // Dark blue-gray
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Background geometric elements
              Positioned(
                top: 100,
                right: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 150,
                left: -75,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                ),
              ),

              // Main content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Futuristic logo container
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF00E5FF).withValues(alpha: 0.2),
                            const Color(0xFF00E5FF).withValues(alpha: 0.05),
                            Colors.transparent,
                          ],
                        ),
                        border: Border.all(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.rocket_launch_outlined,
                          size: 48,
                          color: Color(0xFF00E5FF),
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // App title with futuristic styling
                    Text(
                      'ZIPLINE',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 8.0,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Subtitle with tech styling
                    Text(
                      'File Upload & Sharing',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 2.0,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),

                    const SizedBox(height: 80),

                    // Futuristic loading indicator
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF00E5FF),
                        ),
                        backgroundColor:
                            const Color(0xFF00E5FF).withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
