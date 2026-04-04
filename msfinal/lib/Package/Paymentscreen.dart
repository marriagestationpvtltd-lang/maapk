import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';

import '../Home/Screen/HomeScreenPage.dart';

class PaymentPage extends StatefulWidget {
  final double amount;
  final double discount;
  final String packageName;
  final int packageId;
  final String packageDuration;

  const PaymentPage({
    super.key,
    required this.amount,
    required this.discount,
    required this.packageName,
    required this.packageId,
    required this.packageDuration,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {


  String _getPaidBy() {
    switch (_selectedMethod) {
      case PaymentMethod.khalti:
        return "khalti";
      case PaymentMethod.card:
        return "hbl";
      case PaymentMethod.esewa:
        return "esewa";
      case PaymentMethod.connectIps:
        return "connectips";
    }
  }

  PaymentMethod _selectedMethod = PaymentMethod.khalti;
  bool _isProcessing = false;
  bool _isActivating = false;
  bool _isCancelled = false;
  String _paymentStatus = '';
  bool _showWebView = false;
  String? _paymentUrl;
  late WebViewController _webViewController;

  double get processingCharge => widget.amount;
  double get discount => widget.discount;
  double get subtotal => processingCharge - discount;
  double get taxRate => 0.13;
  double get taxAmount => subtotal * taxRate;
  double get totalAmount => subtotal + taxAmount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            if (_showWebView) {
              _handlePaymentCancel();
            } else if (!_isProcessing) {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          _showWebView ? 'Payment Processing' : 'Payment',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _showWebView ? _buildWebView() : _buildPaymentForm(),
    );
  }

  Widget _buildPaymentForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payment Status
          if (_paymentStatus.isNotEmpty)
            _buildPaymentStatus(),

          // Payment Methods
          _buildPaymentMethods(),
          const SizedBox(height: 30),

          // Payment Summary
          _buildPaymentSummary(),
          const SizedBox(height: 40),

          // Pay Now Button
          _buildPayNowButton(),
          const SizedBox(height: 20),

          // Security Info
          _buildSecurityInfo(),
        ],
      ),
    );
  }

  Widget _buildWebView() {
    return Column(
      children: [

        Expanded(
          child: WebViewWidget(
            controller: _webViewController,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentStatus() {
    Color statusColor = Colors.orange;
    IconData statusIcon = Icons.info_outline;

    if (_paymentStatus.contains('Success')) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (_paymentStatus.contains('Error')) {
      statusColor = Colors.red;
      statusIcon = Icons.error_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _paymentStatus,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pay with',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),

        // Connect IPS QR Scan
        PaymentMethodTile(
          title: 'Connect IPS QR scan',
          icon: Icons.qr_code_scanner_rounded,
          iconColor: const Color(0xFF4A148C),
          backgroundColor: const Color(0xFFF3E5F5),
          isSelected: _selectedMethod == PaymentMethod.connectIps,
          isEnabled: !_isProcessing,
          onTap: () => _selectMethod(PaymentMethod.connectIps),
        ),
        const SizedBox(height: 12),

        // Khalti
        PaymentMethodTile(
          title: 'Khalti',
          icon: Icons.account_balance_wallet_rounded,
          iconColor: const Color(0xFF5C2D91),
          backgroundColor: const Color(0xFFEDE7F6),
          isSelected: _selectedMethod == PaymentMethod.khalti,
          isEnabled: !_isProcessing,
          onTap: () => _selectMethod(PaymentMethod.khalti),
        ),
        const SizedBox(height: 12),

        // Pay with Card (HBL)
        PaymentMethodTile(
          title: 'Pay with Card',
          icon: Icons.credit_card_rounded,
          iconColor: const Color(0xFF1565C0),
          backgroundColor: const Color(0xFFE3F2FD),
          isSelected: _selectedMethod == PaymentMethod.card,
          isEnabled: !_isProcessing,
          onTap: () => _selectMethod(PaymentMethod.card),
        ),
        const SizedBox(height: 12),

        // Pay with Esewa
        PaymentMethodTile(
          title: 'Pay with Esewa',
          icon: Icons.payment_rounded,
          iconColor: const Color(0xFF2E7D32),
          backgroundColor: const Color(0xFFE8F5E9),
          isSelected: _selectedMethod == PaymentMethod.esewa,
          isEnabled: !_isProcessing,
          onTap: () => _selectMethod(PaymentMethod.esewa),
        ),
      ],
    );
  }

  Widget _buildPaymentSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),

          // Package Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(
              children: [
                const Icon(Icons.diamond_rounded, color: Colors.blue, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.packageName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        widget.packageDuration,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Price Breakdown
          _buildPriceRow('Processing charge', 'Rs. ${processingCharge.toStringAsFixed(0)}'),
          const SizedBox(height: 12),

          _buildPriceRow('Discount', '- Rs. ${discount.toStringAsFixed(0)}',
              isDiscount: true),
          const SizedBox(height: 12),

          const Divider(height: 1, color: Colors.grey),
          const SizedBox(height: 12),

          _buildPriceRow('Amount', 'Rs. ${subtotal.toStringAsFixed(0)}',
              isBold: true),
          const SizedBox(height: 12),

          _buildPriceRow('Tax 13%', 'Rs. ${taxAmount.toStringAsFixed(0)}'),
          const SizedBox(height: 16),

          // Total Amount
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Rs. ${totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value,
      {bool isDiscount = false, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade700,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            color: isDiscount ? Colors.green : Colors.black,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPayNowButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _processPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2196F3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          disabledBackgroundColor: Colors.grey.shade300,
        ),
        child: _isProcessing
            ? const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Processing...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        )
            : const Text(
          'Pay Now',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityInfo() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_rounded, color: Colors.green.shade600, size: 16),
            const SizedBox(width: 8),
            const Text(
              'Secure Payment',
              style: TextStyle(
                fontSize: 14,
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Your payment is secured with 256-bit SSL encryption',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSecureIcon(Icons.verified_user_rounded),
            const SizedBox(width: 16),
            _buildSecureIcon(Icons.shield_rounded),
            const SizedBox(width: 16),
            _buildSecureIcon(Icons.security_rounded),
          ],
        ),
      ],
    );
  }

  Widget _buildSecureIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: Colors.green),
    );
  }

  void _selectMethod(PaymentMethod method) {
    if (!_isProcessing) {
      setState(() {
        _selectedMethod = method;
      });
    }
  }

  Future<void> _processPayment() async {
    setState(() {
      _isProcessing = true;
      _isCancelled = false;
      _isActivating = false;
      _paymentStatus = 'Initiating payment...';
    });

    try {
      if (_selectedMethod == PaymentMethod.khalti) {
        await _processKhaltiPayment();
      } else if (_selectedMethod == PaymentMethod.card) {
        await _processHBLPayment();
      } else if (_selectedMethod == PaymentMethod.esewa) {
        _showComingSoonDialog('Esewa');
      } else if (_selectedMethod == PaymentMethod.connectIps) {
        _showComingSoonDialog('Connect IPS');
      } else {
        throw Exception('Unknown payment method');
      }
    } catch (e) {
      print('Payment error: $e');
      setState(() {
        _paymentStatus = 'Error: ${e.toString()}';
      });

      _showErrorDialog('Failed to process payment: ${e.toString()}');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processKhaltiPayment() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    final userData = jsonDecode(userDataString!);
    final userId = int.tryParse(userData["id"].toString());

    setState(() {
      _paymentStatus = 'Initiating Khalti payment...';
    });

    // Prepare payload
    final payload = {
      "amount": totalAmount.toInt(),
      "userid": userId,
      "packageid": widget.packageId,
      "paidby": "Khalti"
    };

    print('Sending Khalti payment request: $payload');

    // Call Khalti API
    final response = await http.post(
      Uri.parse('https://pay.digitallami.com/khalti_payment.php'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: json.encode(payload),
    );

    print('Khalti Response status: ${response.statusCode}');
    print('Khalti Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['success'] == true && data['payment_url'] != null) {
        final paymentUrl = data['payment_url'];
        setState(() {
          _paymentStatus = 'Opening Khalti payment page...';
        });

        // Open payment URL in WebView
        _openPaymentInWebView(paymentUrl, 'Khalti');
      } else {
        throw Exception(data['message'] ?? 'Failed to initiate Khalti payment');
      }
    } else {
      throw Exception('Khalti server error: ${response.statusCode}');
    }
  }

  Future<void> _processHBLPayment() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    final userData = jsonDecode(userDataString!);
    final userId = int.tryParse(userData["id"].toString());

    setState(() {
      _paymentStatus = 'Initiating HBL card payment...';
    });

    // Create HBL payment URL with query parameters
    final paymentUrl = Uri.parse('http://pay.digitallami.com/hbl/index.php')
        .replace(queryParameters: {
      'input_amount': totalAmount.toStringAsFixed(0),
      'userid': userId.toString(),
      'packageid': widget.packageId.toString(),
      'paidby': 'hbl'
    }).toString();

    print('HBL Payment URL: $paymentUrl');

    setState(() {
      _paymentStatus = 'Opening HBL payment page...';
    });

    // Open HBL payment URL in WebView
    _openPaymentInWebView(paymentUrl, 'HBL Card');
  }

  void _openPaymentInWebView(String paymentUrl, String gatewayName) {
    // Clean the URL (remove backslashes if any)
    final cleanUrl = paymentUrl.replaceAll(r'\', '');

    setState(() {
      _showWebView = true;
      _paymentUrl = cleanUrl;
    });

    // Initialize WebViewController
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            print('WebView loading: $progress%');
          },
          onPageStarted: (String url) {
            print('Page started loading: $url');
          },
          onPageFinished: (String url) {
            print('Page finished loading: $url');
            _handleUrlChange(url);
          },
          onWebResourceError: (WebResourceError error) {
            print('WebView error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            print('Navigation request to: ${request.url}');
            _handleUrlChange(request.url);
            return NavigationDecision.navigate;
          },
          onUrlChange: (UrlChange change) {
            if (change.url != null) {
              print('URL changed to: ${change.url}');
              _handleUrlChange(change.url!);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(cleanUrl));
  }

  void _handleUrlChange(String url) {
    if (_isActivating || _isCancelled) return;
    final lowerUrl = url.toLowerCase();
    // Check cancel/failure FIRST — Khalti may redirect cancel back through the
    // same success.php endpoint but with cancel/failure status query parameters.
    if (_isCancelUrl(lowerUrl)) {
      _handlePaymentCancel();
    } else if (lowerUrl.contains('success.php') || lowerUrl.contains('success=true')) {
      _handlePaymentSuccess(url);
    }
  }

  bool _isCancelUrl(String lowerUrl) {
    // Match path-level cancel/failure segments (e.g. /cancel.php, /failed.php)
    final cancelPaths = [
      'cancel.php',
      'failed.php',
      'failure.php',
      'payment_failed',
      'paymentfailed',
      'payment-failed',
      'payment-cancel',
    ];
    for (final pattern in cancelPaths) {
      if (lowerUrl.contains(pattern)) return true;
    }
    // Match query parameter values like ?status=cancelled, ?status=User+cancelled,
    // ?result=declined, etc. Uses contains() so partial phrases like "user cancelled"
    // are also caught.
    final uri = Uri.tryParse(lowerUrl);
    if (uri != null) {
      final params = uri.queryParameters;
      for (final value in params.values) {
        final lowerValue = value.toLowerCase();
        if (lowerValue.contains('cancel') ||
            lowerValue.contains('fail') ||
            lowerValue == 'declined') return true;
      }
    }
    return false;
  }

  void _handlePaymentCancel() {
    if (!mounted) return;
    setState(() {
      _isCancelled = true;
      _showWebView = false;
      _paymentStatus = 'Payment was cancelled.';
      _isProcessing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment cancelled. Your package has not been activated.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<Map<String, dynamic>> purchasePackage({
    required int userId,
    required String paidBy,
    required int packageId,
  }) async {
    final Uri url = Uri.parse(
        "https://digitallami.com/Api3/purchase_package.php"
    ).replace(queryParameters: {
      "userid": userId.toString(),
      "paidby": paidBy,
      "packageid": packageId.toString(),
    });

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          "status": "error",
          "message": "Server error: ${response.statusCode}"
        };
      }
    } catch (e) {
      return {
        "status": "error",
        "message": e.toString()
      };
    }
  }

  void _handlePaymentSuccess(String url) async {
    // Guard against multiple calls for the same payment event
    if (_isActivating) return;
    setState(() {
      _isActivating = true;
    });

    print('Payment success detected! URL: $url');

    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');

      if (userDataString == null) {
        throw Exception("User not logged in");
      }

      final userData = jsonDecode(userDataString);
      final int userId = int.parse(userData["id"].toString());
      final String paidBy = _getPaidBy();

      setState(() {
        _paymentStatus = "Finalizing purchase...";
      });

      // 🔥 CALL YOUR PHP API
      final result = await purchasePackage(
        userId: userId,
        paidBy: paidBy,
        packageId: widget.packageId,
      );

      if (result["status"] == "success") {
        print("✅ Package activated successfully");

        _showPaymentSuccessDialog();

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _restartApp(context);
        });
      } else {
        throw Exception(result["message"] ?? "Package activation failed");
      }
    } catch (e) {
      print("❌ Error after payment success: $e");
      setState(() {
        _isActivating = false;
      });

      _showErrorDialog(
          "Payment succeeded but package activation failed.\nPlease contact support."
      );
    }
  }
  void _restartApp(BuildContext context) {
    // Clear navigation stack and restart home screen
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: const MatrimonyHomeScreen(),
        ),
      ),
          (route) => false,
    );
  }

  void _showPaymentSuccessDialog() {
    // Close WebView if it's open
    if (_showWebView) {
      setState(() {
        _showWebView = false;
      });
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 24),
            SizedBox(width: 10),
            Text('Payment Successful'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Your payment has been processed successfully!'),
            SizedBox(height: 10),
            Text('Redirecting to home page...'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _goToHomePage();
            },
            child: const Text('Go to Home'),
          ),
        ],
      ),
    );
  }

  void _goToHomePage() {
    // Navigate to your app's home page
    // You might need to adjust this based on your app structure
    Navigator.of(context).popUntil((route) => route.isFirst);

    // If you have a specific home route, use:
    // Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);

    // Or if you want to pop back to the previous screen and refresh:
    // Navigator.of(context).pop(true); // Return success flag
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _processPayment(); // Retry
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _showComingSoonDialog(String methodName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Coming Soon'),
        content: Text('$methodName payment integration is coming soon. Please use Khalti or Card for now.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

enum PaymentMethod {
  connectIps,
  khalti,
  card,
  esewa,
}

extension PaymentMethodExtension on PaymentMethod {
  String get name {
    switch (this) {
      case PaymentMethod.connectIps:
        return 'Connect IPS';
      case PaymentMethod.khalti:
        return 'Khalti';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.esewa:
        return 'Esewa';
    }
  }
}

class PaymentMethodTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;

  const PaymentMethodTile({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.5,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? iconColor : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: iconColor, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}