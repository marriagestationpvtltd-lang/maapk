import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../Home/Screen/HomeScreenPage.dart';
import '../../Startup/MainControllere.dart';
import '../../Startup/onboarding.dart';
import '../../service/pagenocheck.dart';
import '../Screen/signupscreen10.dart';
import '../Screen/signupscreen2.dart';
import '../Screen/signupscreen3.dart';
import '../Screen/signupscreen4.dart';
import '../Screen/signupscreen5.dart';
import '../Screen/signupscreen6.dart';
import '../Screen/signupscreen7.dart';
import '../Screen/signupscreen8.dart';
import '../Screen/signupscreen9.dart';
import '../Screen/Signup.dart';
import '../forgetpasswordscreen.dart';

class PrefilledEmailScreen extends StatefulWidget {
  const PrefilledEmailScreen({super.key});

  @override
  State<PrefilledEmailScreen> createState() => _PrefilledEmailScreenState();
}

class _PrefilledEmailScreenState extends State<PrefilledEmailScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // Terms & Privacy Checkbox
  bool _isTermsAccepted = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
    _loadTermsAcceptance();

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
  }

  void _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('user_email');
    if (savedEmail != null) {
      setState(() {
        _emailController.text = savedEmail;
      });
    }
  }

  void _loadTermsAcceptance() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool('terms_accepted') ?? false;
    setState(() {
      _isTermsAccepted = accepted;
    });
  }

  void _saveTermsAcceptance(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('terms_accepted', value);
  }

  Future<Map<String, dynamic>?> _loginUser(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('https://digitallami.com/Api2/signin.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  Future<void> _saveUserData(String token, Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bearer_token', token);
    await prefs.setString('user_data', jsonEncode(userData));
    await prefs.setString('user_email', userData['email']?.toString() ?? '');
    await prefs.setString('user_firstName', userData['firstName']?.toString() ?? '');
    await prefs.setString('user_lastName', userData['lastName']?.toString() ?? '');
    await prefs.setString('user_contactNo', userData['contactNo']?.toString() ?? '');
    await prefs.setBool('is_logged_in', true);
  }

  Future<void> _handleLogin() async {
    // Check if terms are accepted
    if (!_isTermsAccepted) {
      setState(() {
        _errorMessage = 'Please accept the Terms of Service and Privacy Policy to continue';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both email and password';
        _isLoading = false;
      });
      return;
    }

    final loginResponse = await _loginUser(email, password);

    if (!mounted) return;

    if (loginResponse == null || loginResponse['success'] != true) {
      setState(() {
        _errorMessage = loginResponse?['message'] ?? 'Login failed. Please try again.';
        _isLoading = false;
      });
      return;
    }

    final token = loginResponse['bearer_token'];
    final userData = loginResponse['data'];
    final userId = userData['id'];

    if (token == null || userId == null) {
      setState(() {
        _errorMessage = 'Invalid login response';
        _isLoading = false;
      });
      return;
    }

    await _saveUserData(token.toString(), userData);
    final pageNo = await PageService.getPageNo(userId);

    if (!mounted) return;

    if (pageNo == null) {
      _navigateTo(const OnboardingScreen());
      return;
    }

    _navigateBasedOnPageNo(pageNo);
  }

  void _navigateBasedOnPageNo(int pageNo) {
    Widget destination;

    switch (pageNo) {
      case 0:
        destination = const PersonalDetailsPage();
        break;
      case 1:
        destination = const CommunityDetailsPage();
        break;
      case 2:
        destination = const LivingStatusPage();
        break;
      case 3:
        destination = const FamilyDetailsPage();
        break;
      case 4:
        destination = const EducationCareerPage();
        break;
      case 5:
        destination = const AstrologicDetailsPage();
        break;
      case 6:
        destination = const LifestylePage();
        break;
      case 7:
        destination = const PartnerPreferencesPage();
        break;
      case 8:
        destination = const IDVerificationScreen();
        break;
      case 9:
      case 10:
        destination = const MainControllerScreen(initialIndex: 0);
        break;
      default:
        destination = const OnboardingScreen();
    }

    _navigateTo(destination);
  }

  void _navigateTo(Widget screen) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => screen),
          (route) => false,
    );
  }

  // URL Launcher function
  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch $url'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),

                  const SizedBox(height: 40),

                  // Welcome Text
                  SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome Back,',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w300,
                            color: Colors.grey.shade800,
                            fontSize: 28,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Perfect Match.',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFF90E18),
                            fontSize: 32,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Find your perfect match with our premium matchmaking service',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Error message with premium styling
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0F0),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFFE0E0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF90E18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFF90E18),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Email Field with premium styling
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        labelStyle: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                        floatingLabelStyle: const TextStyle(
                          color: Color(0xFFF90E18),
                          fontWeight: FontWeight.w600,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFF90E18),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          color: Colors.grey.shade600,
                          size: 20,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Password Field with premium styling
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                        floatingLabelStyle: const TextStyle(
                          color: Color(0xFFF90E18),
                          fontWeight: FontWeight.w600,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFF90E18),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: Colors.grey.shade600,
                          size: 20,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: Colors.grey.shade600,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Forget Password with premium styling
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ForgotPasswordPage(),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFF90E18),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Terms & Privacy Checkbox
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _isTermsAccepted,
                          onChanged: (bool? value) {
                            setState(() {
                              _isTermsAccepted = value ?? false;
                              _saveTermsAcceptance(_isTermsAccepted);
                            });
                          },
                          activeColor: const Color(0xFFF90E18),
                          checkColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              height: 1.4,
                            ),
                            children: [
                              const TextSpan(text: 'I agree to the '),
                              TextSpan(
                                text: 'Terms of Service',
                                style: const TextStyle(
                                  color: Color(0xFFF90E18),
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => _launchUrl('https://digitallami.com/terms-of-service'),
                              ),
                              const TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: const TextStyle(
                                  color: Color(0xFFF90E18),
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => _launchUrl('https://digitallami.com/privacy-policy'),
                              ),
                              const TextSpan(text: '. By continuing, you confirm that you have read and agree to these terms.'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Login Button with premium gradient and animation
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    height: 56,
                    child: _isLoading
                        ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF90E18)),
                      ),
                    )
                        : Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFF90E18),
                            Color(0xFFC10810),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF90E18).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _handleLogin,
                          child: const Center(
                            child: Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Register Link with premium styling
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 15,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (!_isTermsAccepted) {
                            setState(() {
                              _errorMessage = 'Please accept the Terms of Service and Privacy Policy to create an account';
                            });
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const IntroduceYourselfPage(),
                            ),
                          );
                        },
                        child: const Text(
                          'Create Account',
                          style: TextStyle(
                            color: Color(0xFFF90E18),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            decoration: TextDecoration.underline,
                            decorationColor: Color(0xFFF90E18),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Premium Trust Badge
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            color: Colors.grey.shade600,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Premium & Secure Matchmaking',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}