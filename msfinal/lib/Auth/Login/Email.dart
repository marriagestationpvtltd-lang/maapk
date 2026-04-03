import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../constant/app_colors.dart';

import '../../Home/Screen/HomeScreenPage.dart';
import '../../Startup/MainControllere.dart';
import '../../Startup/onboarding.dart';
import '../../service/pagenocheck.dart';
import '../../ReUsable/terms_dialog.dart';
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
import '../SuignupModel/signup_model.dart';
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

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();

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
      debugPrint('Login error: $e');
      return null;
    }
  }

  Future<void> _handleLogin() async {
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

  // ── Google Sign-In ──────────────────────────────────────────────────────────

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
      // Sign out first to allow account picker every time
      await googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the picker
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      if (!mounted) return;

      final bool isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

      if (isNewUser) {
        // New user – show T&C first
        setState(() => _isLoading = false);
        final accepted = await TermsConditionsBottomSheet.show(context);

        if (!mounted) return;
        if (!accepted) {
          // User declined – sign out from Firebase/Google
          await FirebaseAuth.instance.signOut();
          await googleSignIn.signOut();
          return;
        }

        // Pre-fill registration model with Google data
        final firebaseUser = userCredential.user!;
        final signupModel = context.read<SignupModel>();
        final fullName = firebaseUser.displayName ?? '';
        final nameParts = fullName.split(' ');
        signupModel.setEmail(firebaseUser.email ?? '');
        if (nameParts.isNotEmpty) signupModel.setFirstName(nameParts.first);
        if (nameParts.length > 1) {
          signupModel.setLastName(nameParts.sublist(1).join(' '));
        }

        _navigateTo(const IntroduceYourselfPage());
      } else {
        // Existing user – try backend Google sign-in endpoint
        final firebaseUser = userCredential.user!;
        final idToken = await firebaseUser.getIdToken();

        final response = await http.post(
          Uri.parse('https://digitallami.com/Api2/google_signin.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': firebaseUser.email,
            'google_id': firebaseUser.uid,
            'firebase_token': idToken,
            'displayName': firebaseUser.displayName ?? '',
          }),
        );

        if (!mounted) return;

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            final token = data['bearer_token'];
            final userData = data['data'];
            final userId = userData['id'];

            await _saveUserData(token.toString(), userData);
            final pageNo = await PageService.getPageNo(userId);

            if (!mounted) return;
            if (pageNo == null) {
              _navigateTo(const OnboardingScreen());
            } else {
              _navigateBasedOnPageNo(pageNo);
            }
            return;
          }
        }

        // Backend endpoint not available or user not found – treat as new user
        setState(() => _isLoading = false);
        final accepted = await TermsConditionsBottomSheet.show(context);
        if (!mounted) return;

        if (!accepted) {
          await FirebaseAuth.instance.signOut();
          await googleSignIn.signOut();
          return;
        }

        final signupModel = context.read<SignupModel>();
        final fullName = firebaseUser.displayName ?? '';
        final nameParts = fullName.split(' ');
        signupModel.setEmail(firebaseUser.email ?? '');
        if (nameParts.isNotEmpty) signupModel.setFirstName(nameParts.first);
        if (nameParts.length > 1) {
          signupModel.setLastName(nameParts.sublist(1).join(' '));
        }

        _navigateTo(const IntroduceYourselfPage());
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message ?? 'Google sign-in failed. Please try again.';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Google sign-in failed. Please try again.';
        _isLoading = false;
      });
    }
  }

  // URL Launcher function
  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch $url'),
            backgroundColor: AppColors.error,
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
      backgroundColor: AppColors.white,
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
                            color: AppColors.textPrimary,
                            fontSize: 28,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Perfect Match.',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 32,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Find your perfect match with our premium matchmaking service',
                          style: TextStyle(
                            color: AppColors.textSecondary,
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
                        color: AppColors.error.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.error.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: AppColors.white,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: AppColors.error,
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
                          color: AppColors.shadowLight,
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
                        labelStyle: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                        floatingLabelStyle: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.borderLight),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: AppColors.background,
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: AppColors.textSecondary,
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
                          color: AppColors.shadowLight,
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
                        labelStyle: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                        floatingLabelStyle: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.borderLight),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: AppColors.background,
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppColors.textSecondary,
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
                        foregroundColor: AppColors.primary,
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

                  // Login Button with premium gradient and animation
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    height: 56,
                    child: _isLoading
                        ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    )
                        : Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
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
                                color: AppColors.white,
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

                  // Divider with "OR" label
                  Row(
                    children: [
                      const Expanded(child: Divider(color: AppColors.border)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(color: AppColors.border)),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Continue with Google button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: AppColors.white,
                        foregroundColor: AppColors.textPrimary,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/google.png',
                            height: 22,
                            width: 22,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.g_mobiledata,
                              size: 26,
                              color: Color(0xFF4285F4),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Continue with Google',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Register Link with premium styling
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account? ",
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          final accepted = await TermsConditionsBottomSheet.show(context);
                          if (!mounted) return;
                          if (accepted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const IntroduceYourselfPage(),
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Create Account',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.primary,
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
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            color: AppColors.textSecondary,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Premium & Secure Matchmaking',
                            style: TextStyle(
                              color: AppColors.textSecondary,
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