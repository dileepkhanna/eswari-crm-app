import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/login_screen.dart';
import 'screens/biometric_lock_screen.dart';
import 'services/auth_service.dart';
import 'services/biometric_service.dart';
import 'services/fcm_service.dart';
import 'services/biometric_lock_manager.dart';
import 'config/api_config.dart';
import 'config/app_theme.dart';
import 'providers/theme_provider.dart';
import 'widgets/biometric_lock_wrapper.dart';
import 'screens/home_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/manager/manager_dashboard_screen.dart';
import 'screens/employee/employee_dashboard_screen.dart';
import 'screens/ase/ase_dashboard_screen.dart';
import 'screens/eswari/eswari_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Firebase only (no token registration yet — user not logged in)
    await Firebase.initializeApp();
    print('✅ Firebase initialized');
    
    // Set up background message handler only
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    print('❌ Error initializing Firebase: $e');
  }
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const EswariCRMApp(),
    ),
  );
}

class EswariCRMApp extends StatelessWidget {
  const EswariCRMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Eswari CRM',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const SplashScreen(),
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

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _pulseController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Logo animation controller
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    // Text animation controller
    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    // Pulse animation controller
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    // Logo animations
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.elasticOut,
      ),
    );
    
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );
    
    // Text animations
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeIn,
      ),
    );
    
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOutCubic,
      ),
    );
    
    // Pulse animation
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Start animations
    _logoController.forward().then((_) {
      _textController.forward();
    });
    
    _checkAuth();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    try {
      print('DEBUG: Starting auth check');
      
      final loggedIn = await AuthService.isLoggedIn();
      print('DEBUG: isLoggedIn = $loggedIn');

      if (!loggedIn) {
        // Not logged in, go to login screen
        print('DEBUG: Navigating to LoginScreen (not logged in)');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }

      // User is logged in, go directly to dashboard (biometric disabled)
      print('DEBUG: User logged in, proceeding to dashboard');
      await _navigateToDashboard();
    } catch (e) {
      print('DEBUG: Error in _checkAuth: $e');
      // On error, go to login screen
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Future<void> _navigateToDashboard() async {
    try {
      print('DEBUG: Starting _navigateToDashboard');
      final token = await AuthService.getAccessToken();
      
      if (token == null || token.isEmpty) {
        print('DEBUG: No token found, redirecting to login');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }
      
      print('DEBUG: Got token: ${token.substring(0, 20)}...');

      Map<String, dynamic>? userData;

      try {
        var response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/accounts/profile/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 10));

        print('DEBUG: Profile API response status: ${response.statusCode}');

        // Token expired — try refresh
        if (response.statusCode == 401) {
          print('DEBUG: Token expired, attempting refresh...');
          final refreshed = await AuthService.refreshToken();
          if (refreshed) {
            final newToken = await AuthService.getAccessToken();
            response = await http.get(
              Uri.parse('${ApiConfig.baseUrl}/accounts/profile/'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $newToken',
              },
            ).timeout(const Duration(seconds: 10));
            print('DEBUG: After refresh, status: ${response.statusCode}');
          }
        }

        if (response.statusCode == 200) {
          userData = jsonDecode(response.body);
          print('DEBUG: Successfully fetched user profile');
        } else if (response.statusCode == 401) {
          // Refresh also failed — must login again
          print('DEBUG: Auth failed after refresh, logging out');
          await AuthService.logout();
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
          return;
        } else {
          // Other error status (500, 404, etc.) — logout and go to login
          print('DEBUG: Profile API failed with status ${response.statusCode}, logging out');
          await AuthService.logout();
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
          return;
        }
      } catch (e) {
        // Network error / timeout — logout and go to login for fresh install
        print('DEBUG: Network error fetching profile: $e');
        
        // Check if we have cached role data - if not, this is likely a fresh install
        final cachedRole = await AuthService.getUserRole();
        if (cachedRole == null || cachedRole.isEmpty) {
          print('DEBUG: No cached role found, treating as fresh install - logging out');
          await AuthService.logout();
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
          return;
        }
        
        // If we have cached data, use it (for offline mode)
        print('DEBUG: Using cached user data for offline mode');
        final companyCode = await AuthService.getCompanyCode() ?? '';
        userData = {'role': cachedRole, 'company': {'code': companyCode}};
      }

      // If we still don't have userData, something went wrong
      if (userData == null) {
        print('DEBUG: No user data available, redirecting to login');
        await AuthService.logout();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }

      final role = userData['role'];
      final companyCode = userData['company']?['code']?.toString() ?? '';
      
      // Validate that we have essential data
      if (role == null || role.isEmpty) {
        print('DEBUG: Invalid user data (no role), redirecting to login');
        await AuthService.logout();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }
      
      print('DEBUG: User role: $role, company: $companyCode');

      // Initialize FCM now that we have a valid auth token
      FCMService.initialize().catchError((e) {
        print('DEBUG: FCM init error (non-fatal): $e');
      });

      if (!mounted) return;

      Widget dashboard;
      if (role == 'admin' || role == 'hr') {
        dashboard = AdminDashboardScreen(userData: userData);
      } else {
        final isASE = companyCode == 'ASE' || companyCode == 'ASE_TECH';
        final isEswari = companyCode == 'ESWARI' || companyCode == 'ESWARI_GROUP';

        if (isASE) {
          dashboard = ASEDashboardScreen(userData: userData);
        } else if (isEswari) {
          dashboard = EswariDashboardScreen(userData: userData);
        } else if (role == 'manager') {
          dashboard = ManagerDashboardScreen(userData: userData);
        } else {
          dashboard = EmployeeDashboardScreen(userData: userData);
        }
      }

      print('DEBUG: Navigating to dashboard: ${dashboard.runtimeType}');
      
      // Wrap dashboard with biometric lock wrapper
      final wrappedDashboard = BiometricLockWrapper(child: dashboard);
      
      // Check if should show biometric prompt (first time)
      final shouldPrompt = await BiometricLockManager.shouldShowBiometricPrompt();
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => wrappedDashboard),
      );
      
      // Show biometric prompt after navigation if needed
      if (shouldPrompt) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (context.mounted) {
            _showBiometricPrompt(context);
          }
        });
      }
    } catch (e) {
      // Unexpected error — logout and go to login
      print('DEBUG: Unexpected error in _navigateToDashboard: $e');
      await AuthService.logout();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D47A1), // Deep blue
              Color(0xFF1565C0), // Primary blue
              Color(0xFF1976D2), // Light blue
              Color(0xFF42A5F5), // Lighter blue
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Animated background circles
            Positioned(
              top: -100,
              right: -100,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              bottom: -150,
              left: -150,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.2 - (_pulseAnimation.value - 1.0),
                    child: Container(
                      width: 400,
                      height: 400,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.03),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Main content
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),
                    
                    // Animated logo
                    AnimatedBuilder(
                      animation: _logoController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _logoOpacity.value,
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: Column(
                              children: [
                                // Main company logo with full design
                                Container(
                                  width: 180,
                                  height: 180,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 30,
                                        spreadRadius: 5,
                                        offset: const Offset(0, 15),
                                      ),
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.1),
                                        blurRadius: 20,
                                        spreadRadius: -5,
                                        offset: const Offset(0, -5),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(30),
                                  child: Image.asset(
                                    'asserts/eswari.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Animated text
                    SlideTransition(
                      position: _textSlide,
                      child: FadeTransition(
                        opacity: _textOpacity,
                        child: Column(
                          children: [
                            const Text(
                              'Connects',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                shadows: [
                                  Shadow(
                                    color: Colors.black26,
                                    offset: Offset(0, 4),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: const Text(
                                'CRM SOLUTION',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Powered by ASE Technologies',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 13,
                                fontWeight: FontWeight.w300,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const Spacer(flex: 2),
                    
                    // Loading indicator
                    FadeTransition(
                      opacity: _textOpacity,
                      child: Column(
                        children: [
                          SizedBox(
                            width: 50,
                            height: 50,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Loading your workspace...',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showBiometricPrompt(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.fingerprint_rounded,
                color: Color(0xFF1565C0),
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Secure Your App',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enable biometric lock to protect your sensitive business data with fingerprint or face recognition.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.security_rounded, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Recommended for security',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[900],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await BiometricLockManager.markBiometricPromptShown();
              Navigator.pop(ctx);
            },
            child: const Text('Not Now'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              
              // Try to enable biometric
              final authenticated = await BiometricService.authenticate(
                localizedReason: 'Authenticate to enable biometric lock',
              );
              
              if (authenticated) {
                await BiometricService.setBiometricEnabled(true);
                await BiometricLockManager.markBiometricPromptShown();
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✓ Biometric lock enabled successfully'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              } else {
                await BiometricLockManager.markBiometricPromptShown();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Authentication failed. You can enable it later in Settings.'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.fingerprint_rounded, size: 20),
            label: const Text('Enable'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
