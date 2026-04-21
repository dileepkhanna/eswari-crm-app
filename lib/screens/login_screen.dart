import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import '../screens/home_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/manager/manager_dashboard_screen.dart';
import '../screens/employee/employee_dashboard_screen.dart';
import '../screens/ase/ase_dashboard_screen.dart';
import '../screens/eswari/eswari_dashboard_screen.dart';
import '../config/company_config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Simple color scheme
  static const Color _primaryColor = Color(0xFF1976D2);
  static const Color _backgroundColor = Color(0xFFF5F5F5);

  // Admin form
  final _adminFormKey  = GlobalKey<FormState>();
  final _adminEmail    = TextEditingController();
  final _adminPassword = TextEditingController();

  // User form
  final _userFormKey   = GlobalKey<FormState>();
  final _userId        = TextEditingController();
  final _userPassword  = TextEditingController();

  bool _adminObscure = true;
  bool _userObscure  = true;
  bool _loading      = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() => _errorMsg = null);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _adminEmail.dispose();
    _adminPassword.dispose();
    _userId.dispose();
    _userPassword.dispose();
    super.dispose();
  }

  Future<void> _login({required bool isAdmin}) async {
    final formKey = isAdmin ? _adminFormKey : _userFormKey;
    if (!formKey.currentState!.validate()) return;

    setState(() {
      _loading  = true;
      _errorMsg = null;
    });

    final identifier = isAdmin ? _adminEmail.text.trim() : _userId.text.trim();
    final password   = isAdmin ? _adminPassword.text : _userPassword.text;

    print('DEBUG LOGIN: Attempting login for: $identifier (isAdmin: $isAdmin)');
    
    final result = await AuthService.login(
      identifier: identifier,
      password: password,
    );

    print('DEBUG LOGIN: Result received - success: ${result['success']}');
    if (!result['success']) {
      print('DEBUG LOGIN: Error: ${result['error']}');
    }

    setState(() => _loading = false);

    if (!mounted) return;

    if (result['success']) {
      print('DEBUG LOGIN: Login successful, processing user data');
      final data = result['data'];
      final rawUser = data['user'] as Map;
      final user = Map<String, dynamic>.from(rawUser);
      final role = user['role'];

      print('DEBUG LOGIN: User role: $role');

      // Initialize FCM now that user is authenticated (token can be registered)
      FCMService.initialize().catchError((e) {
        print('DEBUG LOGIN: FCM init error (non-fatal): $e');
      });

      // company_info is the full object {id, name, code, logo_url} inside user
      // company field is just the integer ID
      // Normalize: set user['company'] to the full map
      Map<String, dynamic> companyMap = {};

      final companyInfo = rawUser['company_info'];
      final dataCompany = data['company'];

      if (companyInfo != null && companyInfo is Map) {
        companyMap = Map<String, dynamic>.from(companyInfo);
      } else if (dataCompany != null && dataCompany is Map) {
        companyMap = Map<String, dynamic>.from(dataCompany);
      }

      user['company'] = companyMap;
      final code = companyMap['code']?.toString() ?? '';
      print('DEBUG LOGIN: Company code: $code');

      Widget nextScreen;
      if (role == 'admin' || role == 'hr') {
        print('DEBUG LOGIN: Navigating to AdminDashboard');
        nextScreen = AdminDashboardScreen(userData: user);
      } else {
        // Route by company for manager/employee
        final isASE = code == 'ASE' || code == 'ASE_TECH';
        final isEswari = code == 'ESWARI' || code == 'ESWARI_GROUP';
        
        if (isASE) {
          print('DEBUG LOGIN: Navigating to ASEDashboard');
          nextScreen = ASEDashboardScreen(userData: user);
        } else if (isEswari) {
          print('DEBUG LOGIN: Navigating to EswariDashboard');
          nextScreen = EswariDashboardScreen(userData: user);
        } else if (role == 'manager') {
          print('DEBUG LOGIN: Navigating to ManagerDashboard');
          nextScreen = ManagerDashboardScreen(userData: user);
        } else {
          print('DEBUG LOGIN: Navigating to EmployeeDashboard');
          nextScreen = EmployeeDashboardScreen(userData: user);
        }
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => nextScreen),
      );
    } else {
      setState(() => _errorMsg = result['error']);
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSimpleHeader(),
                const SizedBox(height: 40),
                _buildSimpleCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleHeader() {
    return Column(
      children: [
        // Logo
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Image.asset('asserts/eswari.png', fit: BoxFit.contain),
        ),
        const SizedBox(height: 20),
        const Text(
          'Eswari Connects',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF212121),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to continue',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Simple Tab Bar
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: _primaryColor,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: _primaryColor,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'User Login'),
                Tab(text: 'Admin Login'),
              ],
            ),
          ),
          // Error message
          if (_errorMsg != null) _buildSimpleError(),
          // Tab content
          SizedBox(
            height: 320,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUserForm(),
                _buildAdminForm(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleError() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700], size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMsg!,
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── User Login Form (First Tab) ───────────────────────────────────
  Widget _buildUserForm() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _userFormKey,
        child: Column(
          children: [
            _buildSimpleTextField(
              controller: _userId,
              label: 'User ID',
              hint: 'Enter your user ID',
              icon: Icons.person_outline,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'User ID is required';
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildSimpleTextField(
              controller: _userPassword,
              label: 'Password',
              hint: 'Enter your password',
              icon: Icons.lock_outline,
              obscure: _userObscure,
              toggleObscure: () =>
                  setState(() => _userObscure = !_userObscure),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                return null;
              },
            ),
            const SizedBox(height: 30),
            _buildSimpleLoginButton(isAdmin: false),
          ],
        ),
      ),
    );
  }

  // ── Admin Login Form (Second Tab) ──────────────────────────────────
  Widget _buildAdminForm() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _adminFormKey,
        child: Column(
          children: [
            _buildSimpleTextField(
              controller: _adminEmail,
              label: 'Email',
              hint: 'admin@example.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildSimpleTextField(
              controller: _adminPassword,
              label: 'Password',
              hint: 'Enter your password',
              icon: Icons.lock_outline,
              obscure: _adminObscure,
              toggleObscure: () =>
                  setState(() => _adminObscure = !_adminObscure),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                return null;
              },
            ),
            const SizedBox(height: 30),
            _buildSimpleLoginButton(isAdmin: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    VoidCallback? toggleObscure,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 15, color: Colors.black),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: _primaryColor, size: 22),
        suffixIcon: toggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey[600],
                  size: 22,
                ),
                onPressed: toggleObscure,
              )
            : null,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: TextStyle(fontSize: 14, color: Colors.grey[700]),
        hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
      ),
    );
  }

  Widget _buildSimpleLoginButton({required bool isAdmin}) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _loading ? null : () => _login(isAdmin: isAdmin),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          disabledBackgroundColor: Colors.grey[400],
        ),
        child: _loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                isAdmin ? 'Sign In as Admin' : 'Sign In',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}
