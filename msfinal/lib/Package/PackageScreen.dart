import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

import 'Paymentscreen.dart';
import 'historypage.dart';

// First, add url_launcher to pubspec.yaml:
// dependencies:
//   url_launcher: ^6.1.14

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final PageController _pageController = PageController(viewportFraction: 0.78);
  List<Package> packages = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchPackages();
  }

  Future<void> fetchPackages() async {
    try {
      final response = await http.get(
        Uri.parse('https://digitallami.com/Api2/packagelist.php'),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Parsed data: $data');

        if (data['success'] == true) {
          setState(() {
            packages = (data['data'] as List)
                .map((item) => Package.fromJson(item))
                .toList();
            isLoading = false;
          });
          print('Loaded ${packages.length} packages');
        } else {
          setState(() {
            errorMessage = data['message'] ?? 'Failed to load packages';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Server error: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        errorMessage = 'Network error: $e';
        isLoading = false;
      });
    }
  }

  // Define gradient colors for different packages
  final List<Gradient> gradients = [
    LinearGradient(
      colors: [Color(0xff2c2c2c), Color(0xff1c1c1c)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    LinearGradient(
      colors: [Color(0xfff44336), Color(0xffec407a)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    LinearGradient(
      colors: [Color(0xfff9a825), Color(0xfff57f17)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    LinearGradient(
      colors: [Color(0xff4CAF50), Color(0xff2E7D32)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Subscription',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();

                final token = prefs.getString('bearer_token');
                final userDataString = prefs.getString('user_data');
                final userData = jsonDecode(userDataString!);
                final userIdd = int.tryParse(userData["id"].toString());
               Navigator.push(context, MaterialPageRoute(builder: (context) => PackageHistoryPage(userid: userIdd.toString(),),));
                // Navigate to history page
              },
              child: const Text(
                'History',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 30),
          Expanded(
            child: isLoading
                ? const Center(
              child: CircularProgressIndicator(),
            )
                : errorMessage.isNotEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error: $errorMessage',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: fetchPackages,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
                : packages.isEmpty
                ? const Center(
              child: Text('No subscription packages available'),
            )
                : PageView.builder(
              controller: _pageController,
              itemCount: packages.length,
              itemBuilder: (context, index) {
                final package = packages[index];
                return PlanCard(
                  package: package,
                  gradient: gradients[index % gradients.length],
                  isPopular: index == 1, // Make second item popular
                );
              },
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// Updated Package model class with better type handling
class Package {
  final int id;
  final String name;
  final String duration;
  final String description;
  final dynamic price; // Can be int, double, or string

  Package({
    required this.id,
    required this.name,
    required this.duration,
    required this.description,
    required this.price,
  });

  factory Package.fromJson(Map<String, dynamic> json) {
    return Package(
      id: _parseInt(json['id']),
      name: _parseString(json['name']),
      duration: _parseString(json['duration']),
      description: _parseString(json['description']),
      price: json['price'] ?? 0,
    );
  }

  // Helper method to safely parse integer
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    if (value is double) {
      return value.toInt();
    }
    return 0;
  }

  // Helper method to safely parse string
  static String _parseString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  // Get price as string for display
  String get priceString {
    if (price is int) {
      return 'Rs. $price';
    } else if (price is double) {
      return 'Rs. ${price.toStringAsFixed(2)}';
    } else {
      return 'Rs. ${price.toString()}';
    }
  }

  // Get price as double for calculations
  double get priceDouble {
    if (price is int) {
      return (price as int).toDouble();
    } else if (price is double) {
      return price as double;
    } else if (price is String) {
      return double.tryParse(price) ?? 0.0;
    }
    return 0.0;
  }
}

class PlanCard extends StatelessWidget {
  final Package package;
  final bool isPopular;
  final Gradient gradient;

  const PlanCard({
    super.key,
    required this.package,
    required this.gradient,
    this.isPopular = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 25,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 26),
              Text(
                package.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                package.duration,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              const Divider(color: Colors.white54, thickness: 1),
              const SizedBox(height: 16),
              Text(
                package.description,
                style: const TextStyle(color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 28),
              _feature('Unlimited request'),
              _feature('Unlimited chats'),
              _feature('Priority support'),
              _feature(package.duration),
              const Spacer(),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 36),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    package.priceString,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () {
                    // Navigate directly to payment page
                    _navigateToPayment(context, package);
                  },
                  child: const Text(
                    'Subscribe Now',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isPopular)
          Positioned(
            top: 6,
            left: 60,
            right: 60,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Text(
                  'Most Popular',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
      ],
    );
  }

  static Widget _feature(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  void _showPurchaseDialog(BuildContext context, Package package) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Subscription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Package: ${package.name}'),
            Text('Duration: ${package.duration}'),
            Text('Price: ${package.priceString}'),
            const SizedBox(height: 20),
            const Text('Do you want to proceed with this subscription?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _navigateToPayment(context, package); // Navigate to payment
            },
            child: const Text('Proceed to Pay'),
          ),
        ],
      ),
    );
  }

  void _navigateToPayment(BuildContext context, Package package) {
    // Calculate discount based on package
    double discount = 0;


    // Navigate to PaymentPage
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaymentPage(
          amount: package.priceDouble,
          discount: discount,
          packageName: package.name,
          packageId: package.id,
          packageDuration: package.duration,
        ),
      ),
    );
  }
}

// ============================
// PAYMENT PAGE WITH KHALTI INTEGRATION
// ============================

