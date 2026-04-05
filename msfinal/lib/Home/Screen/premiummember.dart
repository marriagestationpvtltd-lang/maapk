import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:ms2026/constant/app_colors.dart';
import 'package:ms2026/constant/status_bar_utils.dart';
import 'package:ms2026/otherprofile/otherprofileview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Models/masterdata.dart';
import '../../main.dart';
import '../../ReUsable/loading_widgets.dart';
import '../../utils/privacy_utils.dart';

class PaidUsersListPage extends StatefulWidget {
  final int userId;
  const PaidUsersListPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<PaidUsersListPage> createState() => _PaidUsersListPageState();
}

class _PaidUsersListPageState extends State<PaidUsersListPage> {
  List<dynamic> _users = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _errorMessage = '';
  bool _hasMore = true;
  int _currentPage = 1;
  final int _perPage = 20;
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  String _selectedCity = '';
  List<String> _availableCities = [];
  String usertye = '';

  // Filter variables
  String _selectedGender = '';
  String _selectedAgeRange = '';
  List<String> _selectedInterests = [];
  List<String> _availableInterests = [];

  // Layout variables
  late double _screenWidth;
  bool get _isMobile => _screenWidth < 768;
  bool get _isTablet => _screenWidth >= 768 && _screenWidth < 1024;
  bool get _isDesktop => _screenWidth >= 1024;

  // Responsive grid configuration
  int get _gridCrossAxisCount {
    if (_isMobile) return 2;
    if (_isTablet) return 3;
    return 4;
  }

  double get _cardAspectRatio {
    if (_isMobile) return 0.85;
    if (_isTablet) return 0.9;
    return 0.95;
  }

  // Animation controllers
  late AnimationController _filterAnimationController;
  late Animation<double> _filterAnimation;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _scrollController.addListener(_scrollListener);
    loadMasterData();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Will be initialized in build context
  }

  Future<UserMasterData> fetchUserMasterData(String userId) async {
    final url = Uri.parse(
      "https://digitallami.com/Api2/masterdata.php?userid=$userId",
    );
    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception("Failed: ${response.statusCode}");
    }
    final res = json.decode(response.body);
    if (res['success'] != true) {
      throw Exception(res['message'] ?? "API error");
    }
    return UserMasterData.fromJson(res['data']);
  }

  void loadMasterData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    final userData = jsonDecode(userDataString!);
    final userId = int.tryParse(userData["id"].toString());
    try {
      UserMasterData user = await fetchUserMasterData(userId.toString());
      setState(() {
        usertye = user.usertype;
      });
    } catch (e) {
      print("Error: $e");
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers({bool reset = false}) async {
    if (reset) {
      setState(() {
        _currentPage = 1;
        _users = [];
        _hasMore = true;
      });
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('https://digitallami.com/Api2/premiuimmember.php?user_id=${widget.userId}&page=$_currentPage'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final newUsers = data['data'] ?? [];

          // Extract cities and interests from new users
          final cities = <String>{};
          final interests = <String>{};

          for (var user in newUsers) {
            if (user['city'] != null && user['city'].toString().isNotEmpty) {
              cities.add(user['city'].toString());
            }
            if (user['interests'] != null && user['interests'].toString().isNotEmpty) {
              final userInterests = user['interests'].toString().split(',');
              interests.addAll(userInterests);
            }
          }

          setState(() {
            if (reset) {
              _users = newUsers;
            } else {
              _users.addAll(newUsers);
            }
            _hasMore = newUsers.length == _perPage;
            _isLoading = false;
            _availableCities = cities.toList()..sort();
            _availableInterests = interests.toList()..sort();
          });
        } else {
          setState(() {
            _errorMessage = data['message'] ?? 'Failed to fetch users';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'HTTP Error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      if (_hasMore && !_isLoading) {
        setState(() {
          _currentPage++;
        });
        _fetchUsers();
      }
    }
  }

  List<dynamic> _getFilteredUsers() {
    List<dynamic> filtered = _users;

    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((user) {
        final name = 'MS:${user['id']} ${user['lastName']}'.toLowerCase();
        final city = (user['city'] ?? '').toLowerCase();
        final email = (user['email'] ?? '').toLowerCase();
        return name.contains(_searchQuery.toLowerCase()) ||
            city.contains(_searchQuery.toLowerCase()) ||
            email.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // City filter
    if (_selectedCity.isNotEmpty) {
      filtered = filtered.where((user) {
        return (user['city'] ?? '').toString() == _selectedCity;
      }).toList();
    }

    // Gender filter
    if (_selectedGender.isNotEmpty) {
      filtered = filtered.where((user) {
        return (user['gender'] ?? '').toString().toLowerCase() == _selectedGender.toLowerCase();
      }).toList();
    }

    // Interests filter
    if (_selectedInterests.isNotEmpty) {
      filtered = filtered.where((user) {
        final userInterests = (user['interests'] ?? '').toString().split(',');
        return _selectedInterests.any((interest) => userInterests.contains(interest));
      }).toList();
    }

    // Age range filter
    if (_selectedAgeRange.isNotEmpty) {
      filtered = filtered.where((user) {
        final age = int.tryParse(user['age']?.toString() ?? '0') ?? 0;
        switch (_selectedAgeRange) {
          case '18-25':
            return age >= 18 && age <= 25;
          case '26-35':
            return age >= 26 && age <= 35;
          case '36-45':
            return age >= 36 && age <= 45;
          case '46+':
            return age >= 46;
          default:
            return true;
        }
      }).toList();
    }

    return filtered;
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final name = 'MS:${user['id'] ?? ''} ${user['lastName'] ?? ''}'.trim();
    final age = user['age']?.toString() ?? '';
    final city = user['city'] ?? '';
    final isVerified = user['isVerified'] == 1;
    final profilePic = user['profile_picture'];
    final imageUrl = profilePic != null && profilePic.toString().isNotEmpty
        ? 'https://digitallami.com/Api2/$profilePic'
        : 'https://via.placeholder.com/150?text=No+Image';

    // Use profile owner's privacy setting, not viewer's subscription
    final privacy = user['privacy']?.toString().toLowerCase() ?? '';
    final photoRequest = user['photo_request']?.toString().toLowerCase() ?? '';
    final shouldBlurPhoto = !PrivacyUtils.shouldShowClearImage(
      privacy: privacy,
      photoRequest: photoRequest,
    );
    final interests = (user['interests']?.toString() ?? '').split(',').take(2).toList();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileLoader(userId: user['id'].toString(), myId: widget.userId.toString(),),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Section
              Stack(
                children: [
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.grey[100]!, Colors.grey[300]!],
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Profile Image
                          if (shouldBlurPhoto)
                            ClipRect(
                              child: ImageFiltered(
                                imageFilter: ui.ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEA4935)),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[200],
                                      child: Center(
                                        child: Icon(Icons.person, size: 60, color: Colors.grey[400]),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            )
                          else
                            Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEA4935)),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: Center(
                                    child: Icon(Icons.person, size: 60, color: Colors.grey[400]),
                                  ),
                                );
                              },
                            ),

                          // Gradient Overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.center,
                                colors: [
                                  Colors.black.withOpacity(0.8),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),

                          // Lock Overlay for Free Users
                          if (shouldBlurPhoto)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.lock, color: Colors.white, size: 32),
                                    SizedBox(height: 8),

                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Premium Badge
                  if (!shouldBlurPhoto)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Premium',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Verified Badge
                  if (isVerified && !shouldBlurPhoto)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Verified',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // User Info Overlay (Bottom)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              if (age.isNotEmpty)
                                Row(
                                  children: [
                                    Icon(Icons.cake, size: 14, color: Colors.white.withOpacity(0.9)),
                                    SizedBox(width: 4),
                                    Text(
                                      '$age yrs',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              if (age.isNotEmpty && city.isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: CircleAvatar(radius: 3, backgroundColor: Colors.white),
                                ),
                              if (city.isNotEmpty)
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(Icons.location_on, size: 14, color: Colors.white.withOpacity(0.9)),
                                      SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          city,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Content Section
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Interests
                      if (interests.isNotEmpty && !shouldBlurPhoto)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: interests.map((interest) {
                            return Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Color(0xFFEA4935).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                interest.trim(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFEA4935),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        )
                      else
                        SizedBox(height: 8),

                      Spacer(),

                      // Action Button
                      Container(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileLoader(userId: user['id'].toString(), myId: widget.userId.toString(),),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFEA4935),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.visibility, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'View Profile',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Gender Filter


        // Age Range Filter
        ExcludeFocus(
          excluding: true,
          child: DropdownButtonHideUnderline(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: _selectedAgeRange.isEmpty ? Colors.grey[100] : Color(0xFFEA4935).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _selectedAgeRange.isEmpty ? Colors.grey[300]! : Color(0xFFEA4935),
                ),
              ),
              child: DropdownButton<String>(
                value: _selectedAgeRange.isEmpty ? null : _selectedAgeRange,
                hint: Row(
                  children: [
                    Icon(Icons.timeline, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 6),
                    Text('Age Range', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
                items: [
                  DropdownMenuItem(value: '', child: Text('All Ages')),
                  DropdownMenuItem(value: '18-25', child: Text('18-25')),
                  DropdownMenuItem(value: '26-35', child: Text('26-35')),
                  DropdownMenuItem(value: '36-45', child: Text('36-45')),
                  DropdownMenuItem(value: '46+', child: Text('46+')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedAgeRange = value ?? '';
                  });
                },
                icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                isDense: true,
              ),
            ),
          ),
        ),

        // City Filter
        if (_availableCities.isNotEmpty)
          ExcludeFocus(
            excluding: true,
            child: DropdownButtonHideUnderline(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: _selectedCity.isEmpty ? Colors.grey[100] : Color(0xFFEA4935).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _selectedCity.isEmpty ? Colors.grey[300]! : Color(0xFFEA4935),
                  ),
                ),
                child: DropdownButton<String>(
                  value: _selectedCity.isEmpty ? null : _selectedCity,
                  hint: Row(
                    children: [
                      Icon(Icons.location_city, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 6),
                      Text('City', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                  items: [
                    DropdownMenuItem(value: '', child: Text('All Cities')),
                    ..._availableCities.map((city) {
                      return DropdownMenuItem(value: city, child: Text(city));
                    }).toList(),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCity = value ?? '';
                    });
                  },
                  icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                  isDense: true,
                ),
              ),
            ),
          ),

        // Clear Filters Button
        if (_selectedGender.isNotEmpty || _selectedAgeRange.isNotEmpty || _selectedCity.isNotEmpty || _selectedInterests.isNotEmpty)
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedGender = '';
                _selectedAgeRange = '';
                _selectedCity = '';
                _selectedInterests = [];
              });
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.clear_all, size: 16, color: Colors.grey[700]),
                  SizedBox(width: 6),
                  Text('Clear All', style: TextStyle(color: Colors.grey[700])),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMobileLayout(List<dynamic> filteredUsers, bool hasUsers) {
    return CustomScrollView(
      slivers: [
        // Header
        SliverAppBar(
          floating: true,
          pinned: true,
          snap: true,
          expandedHeight: 180,
          systemOverlayStyle: setStatusBar(Colors.transparent, Brightness.light),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFEA4935),
                    Color(0xFFFF6B6B),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 60),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Premium Members',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Connect with verified premium users',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Search Bar
        SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by name, city, or email...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  prefixIcon: Icon(Icons.search, color: Color(0xFFEA4935)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey[500]),
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
          ),
        ),

        // Filter Chips
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: _buildFilterChips(),
          ),
        ),

        // Results Count
        if (hasUsers)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Text(
                    '${filteredUsers.length} users found',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.filter_list, color: Color(0xFFEA4935)),
                    onPressed: () {
                      // Show filter bottom sheet
                      _showFilterBottomSheet();
                    },
                  ),
                ],
              ),
            ),
          ),

        // Loading State
        if (_isLoading && _users.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEA4935)),
              ),
            ),
          ),

        // Error State
        if (_errorMessage.isNotEmpty && _users.isEmpty)
          SliverFillRemaining(
            child: _buildErrorState(),
          ),

        // Empty State
        if (!hasUsers && !_isLoading && _errorMessage.isEmpty)
          SliverFillRemaining(
            child: _buildEmptyState(),
          ),

        // Users Grid
        if (hasUsers)
          SliverPadding(
            padding: EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _gridCrossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: _cardAspectRatio,
              ),
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  if (index >= filteredUsers.length) {
                    return _hasMore
                        ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEA4935)),
                      ),
                    )
                        : SizedBox.shrink();
                  }
                  return _buildUserCard(filteredUsers[index]);
                },
                childCount: filteredUsers.length + (_hasMore ? 1 : 0),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDesktopLayout(List<dynamic> filteredUsers, bool hasUsers) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sidebar Filters
        Container(
          width: 300,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              right: BorderSide(color: Colors.grey[200]!),
            ),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search
                Text(
                  'Search',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search premium users...',
                    prefixIcon: Icon(Icons.search, color: Color(0xFFEA4935)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Color(0xFFEA4935)),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),

                SizedBox(height: 24),

                // Filters Title
                Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
                SizedBox(height: 16),

                // Gender Filter


                SizedBox(height: 24),

                // Age Range
                Text(
                  'Age Range',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ...['18-25', '26-35', '36-45', '46+'].map((range) {
                      return FilterChip(
                        label: Text(range),
                        selected: _selectedAgeRange == range,
                        onSelected: (selected) {
                          setState(() {
                            _selectedAgeRange = selected ? range : '';
                          });
                        },
                        selectedColor: Color(0xFFEA4935),
                        checkmarkColor: Colors.white,
                      );
                    }).toList(),
                  ],
                ),

                SizedBox(height: 24),

                // City Filter
                if (_availableCities.isNotEmpty) ...[
                  Text(
                    'City',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: Text('All Cities'),
                        selected: _selectedCity.isEmpty,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCity = '';
                          });
                        },
                        selectedColor: Color(0xFFEA4935),
                        checkmarkColor: Colors.white,
                      ),
                      ..._availableCities.take(10).map((city) {
                        return FilterChip(
                          label: Text(city),
                          selected: _selectedCity == city,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCity = selected ? city : '';
                            });
                          },
                          selectedColor: Color(0xFFEA4935),
                          checkmarkColor: Colors.white,
                        );
                      }).toList(),
                    ],
                  ),
                ],

                Spacer(),

                // Stats Card
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Statistics',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  '${filteredUsers.length}',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFEA4935),
                                  ),
                                ),
                                Text(
                                  'Filtered',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.grey[300],
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  '${_users.length}',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                Text(
                                  'Total',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      if (_selectedGender.isNotEmpty || _selectedAgeRange.isNotEmpty || _selectedCity.isNotEmpty)
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedGender = '';
                              _selectedAgeRange = '';
                              _selectedCity = '';
                              _selectedInterests = [];
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Color(0xFFEA4935),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Color(0xFFEA4935)),
                            ),
                            minimumSize: Size(double.infinity, 40),
                          ),
                          child: Text('Clear All Filters'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Main Content
        Expanded(
          child: Column(
            children: [
              // Header with Actions
              Container(
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Premium Members',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[900],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Discover and connect with verified premium users',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => _fetchUsers(reset: true),
                      icon: Icon(Icons.refresh, size: 18),
                      label: Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFEA4935),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Grid Content
              Expanded(
                child: _isLoading && _users.isEmpty
                    ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEA4935)),
                  ),
                )
                    : _errorMessage.isNotEmpty
                    ? _buildErrorState()
                    : !hasUsers
                    ? _buildEmptyState()
                    : Padding(
                  padding: EdgeInsets.all(24),
                  child: GridView.builder(
                    controller: _scrollController,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _gridCrossAxisCount,
                      crossAxisSpacing: 24,
                      mainAxisSpacing: 24,
                      childAspectRatio: _cardAspectRatio,
                    ),
                    itemCount: filteredUsers.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= filteredUsers.length) {
                        return _hasMore
                            ? Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEA4935)),
                          ),
                        )
                            : SizedBox.shrink();
                      }
                      return _buildUserCard(filteredUsers[index]);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[900],
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close),
                  ),
                ],
              ),
              SizedBox(height: 24),

              // Gender Filter


              SizedBox(height: 24),

              // Age Range
              Text(
                'Age Range',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 12),
              Wrap(
                spacing: 12,
                children: [
                  ...['18-25', '26-35', '36-45', '46+'].map((range) {
                    return ChoiceChip(
                      label: Text(range),
                      selected: _selectedAgeRange == range,
                      onSelected: (selected) {
                        setState(() {
                          _selectedAgeRange = selected ? range : '';
                        });
                      },
                      selectedColor: Color(0xFFEA4935),
                      labelStyle: TextStyle(
                        color: _selectedAgeRange == range ? Colors.white : Colors.grey[700],
                      ),
                    );
                  }).toList(),
                ],
              ),

              SizedBox(height: 24),

              // City Filter
              if (_availableCities.isNotEmpty) ...[
                Text(
                  'City',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  children: [
                    ChoiceChip(
                      label: Text('All Cities'),
                      selected: _selectedCity.isEmpty,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCity = '';
                        });
                      },
                      selectedColor: Color(0xFFEA4935),
                      labelStyle: TextStyle(
                        color: _selectedCity.isEmpty ? Colors.white : Colors.grey[700],
                      ),
                    ),
                    ..._availableCities.take(8).map((city) {
                      return ChoiceChip(
                        label: Text(city),
                        selected: _selectedCity == city,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCity = selected ? city : '';
                          });
                        },
                        selectedColor: Color(0xFFEA4935),
                        labelStyle: TextStyle(
                          color: _selectedCity == city ? Colors.white : Colors.grey[700],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ],

              Spacer(),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _selectedGender = '';
                          _selectedAgeRange = '';
                          _selectedCity = '';
                          _selectedInterests = [];
                        });
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        'Clear All',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFEA4935),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Apply Filters',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: 400),
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, color: Colors.red, size: 48),
            ),
            SizedBox(height: 24),
            Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
              ),
            ),
            SizedBox(height: 12),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _fetchUsers(reset: true),
              icon: Icon(Icons.refresh),
              label: Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFEA4935),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: 400),
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.group_off, color: Colors.grey[400], size: 48),
            ),
            SizedBox(height: 24),
            Text(
              'No Users Found',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
              ),
            ),
            SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty || _selectedCity.isNotEmpty || _selectedGender.isNotEmpty
                  ? 'Try adjusting your search criteria'
                  : 'No premium users available at the moment',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 32),
            if (_searchQuery.isNotEmpty || _selectedCity.isNotEmpty || _selectedGender.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _selectedCity = '';
                    _selectedGender = '';
                    _selectedAgeRange = '';
                    _selectedInterests = [];
                  });
                },
                icon: Icon(Icons.clear_all),
                label: Text('Clear All Filters'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.grey[800],
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _screenWidth = MediaQuery.of(context).size.width;
    final filteredUsers = _getFilteredUsers();
    final hasUsers = filteredUsers.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        color: Color(0xFFEA4935),
        onRefresh: () async {
          setState(() => _isRefreshing = true);
          await _fetchUsers(reset: true);
          if (mounted) setState(() => _isRefreshing = false);
        },
        child: ShimmerLoading(
          isLoading: _isRefreshing,
          child: _isDesktop
              ? _buildDesktopLayout(filteredUsers, hasUsers)
              : _buildMobileLayout(filteredUsers, hasUsers),
        ),
      ),
      floatingActionButton: _isDesktop
          ? null
          : FloatingActionButton.extended(
        onPressed: _showFilterBottomSheet,
        icon: Icon(Icons.filter_list),
        label: Text('Filters'),
        backgroundColor: Color(0xFFEA4935),
        foregroundColor: Colors.white,
      ),
    );
  }
}