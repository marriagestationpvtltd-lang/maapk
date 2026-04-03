import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

enum ForgotStep { email, otp, reset }

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  ForgotStep step = ForgotStep.email;

  final emailController = TextEditingController();
  final otpController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;

  // Validation error states
  Map<String, bool> _fieldErrors = {
    'email': false,
    'otp': false,
    'password': false,
  };

  // Track which fields have been touched
  Map<String, bool> _fieldTouched = {
    'email': false,
    'otp': false,
    'password': false,
  };

  // Focus nodes
  final Map<String, FocusNode> _focusNodes = {
    'email': FocusNode(),
    'otp': FocusNode(),
    'password': FocusNode(),
  };

  @override
  void initState() {
    super.initState();
    // Initialize focus nodes
    _focusNodes.forEach((key, node) {
      node.addListener(() {
        if (!node.hasFocus) {
          setState(() {
            _fieldTouched[key] = true;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _focusNodes.forEach((key, node) => node.dispose());
    emailController.dispose();
    otpController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  bool _hasError(String fieldName) {
    return _fieldErrors[fieldName] ?? false;
  }

  bool _shouldShowError(String fieldName) {
    return _fieldTouched[fieldName] == true;
  }

  String _getErrorMessage(String fieldName) {
    switch (fieldName) {
      case 'email':
        return 'Email is required';
      case 'otp':
        return 'OTP is required';
      case 'password':
        if (passwordController.text.isEmpty) {
          return 'Password is required';
        } else if (passwordController.text.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return 'Invalid password';
      default:
        return 'This field is required';
    }
  }

  // Get border color based on field state
  Color _getBorderColor(String fieldName) {
    String value = '';
    switch (fieldName) {
      case 'email':
        value = emailController.text;
        break;
      case 'otp':
        value = otpController.text;
        break;
      case 'password':
        value = passwordController.text;
        break;
    }

    // Check if field has error and should show it
    if (_hasError(fieldName) && _shouldShowError(fieldName)) {
      return Colors.red;
    }

    // Return green if has data, black if empty
    return value.isNotEmpty ? const Color(0xFF48A54C) : Colors.black;
  }

  void showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : const Color(0xFFE64B37),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> sendOtp() async {
    // Validate email
    if (emailController.text.isEmpty) {
      setState(() {
        _fieldErrors['email'] = true;
        _fieldTouched['email'] = true;
      });
      return;
    }

    setState(() => loading = true);

    final url = Uri.parse('https://digitallami.com/Api2/forgot_password_send_otp.php');
    final resp = await http.post(url, body: {'email': emailController.text.trim()});
    final data = json.decode(resp.body);

    setState(() => loading = false);

    if (data['success'] == true) {
      showMessage('OTP sent to email');
      setState(() {
        step = ForgotStep.otp;
        _fieldErrors['email'] = false;
      });
    } else {
      showMessage(data['message'] ?? 'Error sending OTP', isError: true);
      setState(() {
        _fieldErrors['email'] = true;
      });
    }
  }

  Future<void> verifyOtp() async {
    // Validate OTP
    if (otpController.text.isEmpty) {
      setState(() {
        _fieldErrors['otp'] = true;
        _fieldTouched['otp'] = true;
      });
      return;
    }

    setState(() => loading = true);

    final url = Uri.parse('https://digitallami.com/Api2/forgot_password_verify_otp.php');
    final resp = await http.post(url, body: {
      'email': emailController.text.trim(),
      'otp': otpController.text.trim(),
    });
    final data = json.decode(resp.body);

    setState(() => loading = false);

    if (data['success'] == true) {
      showMessage('OTP verified');
      setState(() {
        step = ForgotStep.reset;
        _fieldErrors['otp'] = false;
      });
    } else {
      showMessage(data['message'] ?? 'OTP verification failed', isError: true);
      setState(() {
        _fieldErrors['otp'] = true;
      });
    }
  }

  Future<void> resetPassword() async {
    // Validate password
    if (passwordController.text.isEmpty || passwordController.text.length < 6) {
      setState(() {
        _fieldErrors['password'] = true;
        _fieldTouched['password'] = true;
      });
      return;
    }

    setState(() => loading = true);

    final url = Uri.parse('https://digitallami.com/Api2/forgot_password_reset.php');
    final resp = await http.post(url, body: {
      'email': emailController.text.trim(),
      'password': passwordController.text.trim(),
    });
    final data = json.decode(resp.body);

    setState(() => loading = false);

    if (data['success'] == true) {
      showMessage('Password reset successful');
      Navigator.pop(context); // back to login
    } else {
      showMessage(data['message'] ?? 'Password reset failed', isError: true);
    }
  }

  Widget _buildTextField({
    required String fieldName,
    required TextEditingController controller,
    required String labelText,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 55,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: _getBorderColor(fieldName),
              width: 1.6,
            ),
          ),
          child: Row(
            children: [
              // Add appropriate icon based on field type
              if (fieldName == 'email')
                Icon(
                  Icons.email,
                  color: (_hasError(fieldName) && _shouldShowError(fieldName))
                      ? Colors.red
                      : Colors.black,
                )
              else if (fieldName == 'otp')
                Icon(
                  Icons.lock_clock,
                  color: (_hasError(fieldName) && _shouldShowError(fieldName))
                      ? Colors.red
                      : Colors.black,
                )
              else if (fieldName == 'password')
                  Icon(
                    Icons.lock,
                    color: (_hasError(fieldName) && _shouldShowError(fieldName))
                        ? Colors.red
                        : Colors.black,
                  ),
              if (fieldName == 'email' || fieldName == 'otp' || fieldName == 'password')
                const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  focusNode: _focusNodes[fieldName],
                  controller: controller,
                  keyboardType: keyboardType,
                  obscureText: obscureText,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: labelText,
                    hintStyle: TextStyle(
                      fontSize: 16,
                      color: (_hasError(fieldName) && _shouldShowError(fieldName))
                          ? Colors.red.withOpacity(0.7)
                          : Colors.black54,
                    ),
                    suffixIcon: suffixIcon,
                  ),
                  onChanged: (value) {
                    // Clear error when user starts typing
                    if (value.isNotEmpty && _hasError(fieldName)) {
                      setState(() {
                        _fieldErrors[fieldName] = false;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        // Show error text below the field
        if (_hasError(fieldName) && _shouldShowError(fieldName))
          Padding(
            padding: const EdgeInsets.only(left: 15, top: 4),
            child: Text(
              _getErrorMessage(fieldName),
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        const Text(
          "Forgot Password",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFE64B37),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "Enter your email address to receive OTP",
          style: TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),

        // Email field
        _buildTextField(
          fieldName: 'email',
          controller: emailController,
          labelText: 'Email Address*',
          keyboardType: TextInputType.emailAddress,
        ),

        const SizedBox(height: 30),

        // Send OTP button
        Container(
          width: double.infinity,
          height: 55,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE64B37), Color(0xFFE62255)],
            ),
            borderRadius: BorderRadius.circular(30),
          ),
          child: ElevatedButton(
            onPressed: loading ? null : sendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: loading
                ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Text(
              "Send OTP",
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Back to login
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            "Back to Login",
            style: TextStyle(
              color: Color(0xFFE64B37),
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        const Text(
          "Verify OTP",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFE64B37),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "OTP sent to ${emailController.text}",
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),

        // OTP field
        _buildTextField(
          fieldName: 'otp',
          controller: otpController,
          labelText: 'Enter OTP*',
          keyboardType: TextInputType.number,
        ),

        const SizedBox(height: 30),

        // Verify OTP button
        Container(
          width: double.infinity,
          height: 55,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE64B37), Color(0xFFE62255)],
            ),
            borderRadius: BorderRadius.circular(30),
          ),
          child: ElevatedButton(
            onPressed: loading ? null : verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: loading
                ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Text(
              "Verify OTP",
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Resend OTP
        TextButton(
          onPressed: loading ? null : sendOtp,
          child: Text(
            loading ? "Resending..." : "Resend OTP",
            style: const TextStyle(
              color: Color(0xFFE64B37),
              fontSize: 14,
            ),
          ),
        ),

        // Back to email
        TextButton(
          onPressed: () {
            setState(() {
              step = ForgotStep.email;
              otpController.clear();
              _fieldErrors['otp'] = false;
              _fieldTouched['otp'] = false;
            });
          },
          child: const Text(
            "Change Email",
            style: TextStyle(
              color: Colors.black54,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResetStep() {
    bool _passwordVisible = false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        const Text(
          "Reset Password",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFE64B37),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "Create a new password for your account",
          style: TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),

        // New Password field
        _buildTextField(
          fieldName: 'password',
          controller: passwordController,
          labelText: 'New Password*',
          obscureText: !_passwordVisible,
          suffixIcon: IconButton(
            icon: Icon(
              _passwordVisible ? Icons.visibility : Icons.visibility_off,
              color: (_hasError('password') && _shouldShowError('password'))
                  ? Colors.red
                  : Colors.black54,
            ),
            onPressed: () {
              setState(() {
                _passwordVisible = !_passwordVisible;
              });
            },
          ),
        ),

        const SizedBox(height: 10),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            "Password must be at least 6 characters",
            style: TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ),

        const SizedBox(height: 30),

        // Reset Password button
        Container(
          width: double.infinity,
          height: 55,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE64B37), Color(0xFFE62255)],
            ),
            borderRadius: BorderRadius.circular(30),
          ),
          child: ElevatedButton(
            onPressed: loading ? null : resetPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: loading
                ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Text(
              "Reset Password",
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Back to OTP
        TextButton(
          onPressed: () {
            setState(() {
              step = ForgotStep.otp;
              passwordController.clear();
              _fieldErrors['password'] = false;
              _fieldTouched['password'] = false;
            });
          },
          child: const Text(
            "Back to OTP",
            style: TextStyle(
              color: Colors.black54,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFE64B37)),
          onPressed: () {
            if (step == ForgotStep.email) {
              Navigator.pop(context);
            } else if (step == ForgotStep.otp) {
              setState(() => step = ForgotStep.email);
            } else {
              setState(() => step = ForgotStep.otp);
            }
          },
        ),
        title: Text(
          step == ForgotStep.email
              ? "Forgot Password"
              : step == ForgotStep.otp
              ? "Verify OTP"
              : "Reset Password",
          style: const TextStyle(
            color: Color(0xFFE64B37),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: step == ForgotStep.email
              ? _buildEmailStep()
              : step == ForgotStep.otp
              ? _buildOtpStep()
              : _buildResetStep(),
        ),
      ),
    );
  }
}