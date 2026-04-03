import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'Paymentscreen.dart';
import 'historypage.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController(viewportFraction: 0.85);
  List<Package> packages = [];
  bool isLoading = true;
  String errorMessage = '';
  int _currentPage = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Current active package info
  String? _activePackageName;
  String? _activePackageExpiry;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    fetchPackages();
    _fetchActivePackage();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchActivePackage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      if (userDataString == null) return;
      final userData = jsonDecode(userDataString);
      final userId = userData["id"].toString();

      final response = await http.get(
        Uri.parse('http://digitallami.com/Api2/user_package.php?userid=$userId'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true &&
            data['data'] != null &&
            (data['data'] as List).isNotEmpty) {
          final latest = (data['data'] as List).first;
          if (mounted) {
            setState(() {
              _activePackageName = latest['package_name'];
              final expiry = latest['expiredate']?.toString() ?? '';
              _activePackageExpiry = expiry.length >= 10 ? expiry.substring(0, 10) : expiry;
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> fetchPackages() async {
    try {
      final response = await http.get(
        Uri.parse('https://digitallami.com/Api2/packagelist.php'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            packages = (data['data'] as List)
                .map((item) => Package.fromJson(item))
                .toList();
            isLoading = false;
          });
          _animationController.forward();
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
      setState(() {
        errorMessage = 'Network error: $e';
        isLoading = false;
      });
    }
  }

  // Tier config: color palette per card index
  static const List<_TierConfig> _tierConfigs = [
    _TierConfig(
      gradient: [Color(0xFF1C1C2E), Color(0xFF2D2D44)],
      accentColor: Color(0xFFB0BEC5),
      label: 'Basic',
      icon: Icons.star_border_rounded,
    ),
    _TierConfig(
      gradient: [Color(0xFFB71C1C), Color(0xFFF90E18)],
      accentColor: Color(0xFFFFD700),
      label: 'Popular',
      icon: Icons.workspace_premium_rounded,
    ),
    _TierConfig(
      gradient: [Color(0xFF004D40), Color(0xFF00897B)],
      accentColor: Color(0xFFA5D6A7),
      label: 'Value',
      icon: Icons.diamond_rounded,
    ),
    _TierConfig(
      gradient: [Color(0xFF311B92), Color(0xFF6A1B9A)],
      accentColor: Color(0xFFCE93D8),
      label: 'Premium',
      icon: Icons.military_tech_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: CustomScrollView(
        slivers: [
          _buildSliverHeader(context),
          SliverToBoxAdapter(
            child: Column(
              children: [
                if (_activePackageName != null) _buildActivePackageBanner(),
                const SizedBox(height: 24),
                _buildSectionTitle(),
                const SizedBox(height: 16),
                _buildPackageCarousel(),
                const SizedBox(height: 12),
                if (!isLoading && errorMessage.isEmpty && packages.isNotEmpty)
                  _buildPageIndicator(),
                const SizedBox(height: 32),
                _buildWhyPremiumSection(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverHeader(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: const Color(0xFFF90E18),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            final userDataString = prefs.getString('user_data');
            if (userDataString == null) return;
            final userData = jsonDecode(userDataString);
            final userId = userData["id"].toString();
            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PackageHistoryPage(userid: userId),
                ),
              );
            }
          },
          icon: const Icon(Icons.history_rounded, color: Colors.white, size: 18),
          label: const Text(
            'History',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFD00D15), Color(0xFFF90E18)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 48),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Upgrade to Premium',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Unlock all features and find your perfect match',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        title: const Text(
          'Subscription Plans',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
        collapseMode: CollapseMode.parallax,
      ),
    );
  }

  Widget _buildActivePackageBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF90E18), Color(0xFFD00D15)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF90E18).withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, color: Color(0xFFFFD700), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Plan: $_activePackageName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (_activePackageExpiry != null)
                  Text(
                    'Expires: $_activePackageExpiry',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFFF90E18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Choose Your Plan',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1C1C2E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCarousel() {
    if (isLoading) {
      return const SizedBox(
        height: 460,
        child: Center(child: CircularProgressIndicator(color: Color(0xFFF90E18))),
      );
    }
    if (errorMessage.isNotEmpty) {
      return SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(errorMessage,
                  style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    isLoading = true;
                    errorMessage = '';
                  });
                  fetchPackages();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF90E18),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (packages.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No subscription packages available')),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SizedBox(
        height: 480,
        child: PageView.builder(
          controller: _pageController,
          itemCount: packages.length,
          onPageChanged: (index) => setState(() => _currentPage = index),
          itemBuilder: (context, index) {
            final package = packages[index];
            final config = _tierConfigs[index % _tierConfigs.length];
            final isSelected = _currentPage == index;
            return AnimatedScale(
              scale: isSelected ? 1.0 : 0.92,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: _PackagePlanCard(
                package: package,
                config: config,
                isPopular: index == 1,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(packages.length, (index) {
        final isActive = _currentPage == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFF90E18) : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildWhyPremiumSection() {
    const features = [
      _FeatureItem(Icons.favorite_rounded, 'Unlimited Proposals',
          'Send and receive unlimited marriage proposals'),
      _FeatureItem(Icons.chat_bubble_rounded, 'Unlimited Chats',
          'Chat with all matched profiles without limits'),
      _FeatureItem(Icons.visibility_rounded, 'Profile Boost',
          'Your profile gets more visibility to suitable matches'),
      _FeatureItem(Icons.support_agent_rounded, 'Priority Support',
          'Get dedicated customer support for your journey'),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stars_rounded, color: Color(0xFFF90E18), size: 22),
              const SizedBox(width: 8),
              const Text(
                'Why go Premium?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1C1C2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF90E18).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(f.icon, color: const Color(0xFFF90E18), size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF1C1C2E),
                        ),
                      ),
                      Text(
                        f.subtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ============================
// Package data model
// ============================
class Package {
  final int id;
  final String name;
  final String duration;
  final String description;
  final dynamic price;

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

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static String _parseString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  String get priceString {
    if (price is int) return 'Rs. $price';
    if (price is double) return 'Rs. ${(price as double).toStringAsFixed(0)}';
    final parsed = double.tryParse(price.toString());
    return parsed != null ? 'Rs. ${parsed.toStringAsFixed(0)}' : 'Rs. ${price}';
  }

  double get priceDouble {
    if (price is int) return (price as int).toDouble();
    if (price is double) return price as double;
    return double.tryParse(price.toString()) ?? 0.0;
  }
}

// ============================
// Tier configuration
// ============================
class _TierConfig {
  final List<Color> gradient;
  final Color accentColor;
  final String label;
  final IconData icon;

  const _TierConfig({
    required this.gradient,
    required this.accentColor,
    required this.label,
    required this.icon,
  });
}

class _FeatureItem {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureItem(this.icon, this.title, this.subtitle);
}

// ============================
// Pro Package Plan Card
// ============================
class _PackagePlanCard extends StatelessWidget {
  final Package package;
  final _TierConfig config;
  final bool isPopular;

  const _PackagePlanCard({
    required this.package,
    required this.config,
    this.isPopular = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: config.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: config.gradient.first.withOpacity(0.45),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background decorative circles
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: tier icon + popular badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(config.icon, color: config.accentColor, size: 26),
                    ),
                    if (isPopular)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: config.accentColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt_rounded,
                                size: 14,
                                color: config.gradient.first),
                            const SizedBox(width: 4),
                            Text(
                              'Most Popular',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: config.gradient.first,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                // Package name
                Text(
                  package.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                // Duration badge
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    package.duration,
                    style: TextStyle(
                      color: config.accentColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Price display
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      package.priceString,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '/ plan',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.white.withOpacity(0.2), height: 1),
                const SizedBox(height: 14),
                // Description
                if (package.description.isNotEmpty)
                  Text(
                    package.description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 13,
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 12),
                // Features
                _featureRow(config.accentColor, 'Unlimited Proposals'),
                _featureRow(config.accentColor, 'Unlimited Chats'),
                _featureRow(config.accentColor, 'Priority Support'),
                _featureRow(config.accentColor, package.duration),
                const Spacer(),
                // Subscribe button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: config.accentColor,
                      foregroundColor: config.gradient.first,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PaymentPage(
                            amount: package.priceDouble,
                            discount: 0,
                            packageName: package.name,
                            packageId: package.id,
                            packageDuration: package.duration,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      'Subscribe Now',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: config.gradient.first,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureRow(Color accentColor, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: accentColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
