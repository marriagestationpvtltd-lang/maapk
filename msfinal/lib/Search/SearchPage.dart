import 'package:flutter/material.dart';
import 'dart:ui' as ui; // Add this import for ImageFilter
import 'package:http/http.dart' as http;
import 'package:ms2026/otherprofile/otherprofileview.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../pushnotification/pushservice.dart';
import 'SearchResult.dart';
import 'filterPage.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final List<String> recentSearches = [];

  // Variables for API integration
  List<dynamic> _recommendedProfiles = [];
  bool _isLoading = true;
  String _errorMessage = '';
  int _currentUserId = 0;
  String docstatus = 'not_uploaded'; // Add document status variable

  @override
  void initState() {
    super.initState();
    _loadUserDataAndFetchProfiles();
  }

  // Method to load user data and fetch recommended profiles
  Future<void> _loadUserDataAndFetchProfiles() async {
    try {
      // Get user ID from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');

      if (userDataString == null) {
        setState(() {
          _errorMessage = 'User data not found';
          _isLoading = false;
        });
        return;
      }

      final userData = jsonDecode(userDataString);
      final userId = int.tryParse(userData["id"].toString()) ?? 0;

      setState(() {
        _currentUserId = userId;
      });

      if (userId > 0) {
        await _checkDocumentStatus(userId); // Check document status
        await _fetchRecommendedProfiles(userId);
      } else {
        setState(() {
          _errorMessage = 'Invalid user ID';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load user data: $e';
        _isLoading = false;
      });
    }
  }

  // Check document status
  Future<void> _checkDocumentStatus(int userId) async {
    try {
      final response = await http.post(
        Uri.parse("https://digitallami.com/Api2/check_document_status.php"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          setState(() {
            docstatus = result['status'] ?? 'not_uploaded';
          });
        }
      }
    } catch (e) {
      print("Error checking document status: $e");
    }
  }

  // Method to fetch recommended profiles from API
  Future<void> _fetchRecommendedProfiles(int userId) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final url = Uri.parse('https://digitallami.com/Api2/match.php?userid=$userId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          setState(() {
            _recommendedProfiles = result['matched_users'] ?? [];
            _isLoading = false;
          });
        } else {
          throw Exception(result['message'] ?? 'Failed to load recommended profiles');
        }
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      print('Error fetching recommended profiles: $e');
    }
  }

  // Helper function to check if photo should be blurred
  bool _shouldShowClearImage(Map<String, dynamic> profile) {
    // Check if privacy is free or photo request is accepted
    final privacy = profile['privacy']?.toString().toLowerCase() ?? 'free';
    final photoRequest = profile['photo_request']?.toString().toLowerCase() ?? '';

    return privacy == 'free' || photoRequest == 'accepted';
  }

  // Helper function to get photo request status
  String _getPhotoRequestStatus(Map<String, dynamic> profile) {
    final photoRequest = profile['photo_request']?.toString().toLowerCase() ?? '';
    if (photoRequest.isEmpty || photoRequest == 'null') return 'not_sent';
    return photoRequest;
  }

  // Method to send request

  // Handle document not approved status
  void _handleDocumentNotApproved() {
    if (docstatus == 'not_uploaded') {
      // Navigate to ID verification screen
      // Navigator.push(context, MaterialPageRoute(builder: (context) => IDVerificationScreen()));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please upload your documents first'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    } else if (docstatus == 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Your documents are pending approval'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    } else if (docstatus == 'rejected') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Your documents were rejected. Please re-upload'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Show request type dialog with document status check




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      _buildRecentSearch(),
                      const SizedBox(height: 20),
                      _buildSectionTitle("Recommended For You"),
                      const SizedBox(height: 10),
                      _buildGrid(),
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 70, bottom: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xffFF1500), Color(0xfff88fb1)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children:  [
                  SizedBox(width: 15),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SearchResultPage()),
                      );
                    },
                    child: Icon(Icons.search, color: Colors.grey),
                  ),

                  SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                          hintText: "Search by profile id",
                          border: InputBorder.none),
                    ),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          _circleIcon(Icons.person),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FilterPage()),
              );
            },
            child: _circleIcon(Icons.tune),
          ),
        ],
      ),
    );
  }

  Widget _circleIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: Icon(icon, color: Colors.black, size: 20),
    );
  }

  Widget _buildRecentSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text("Recent search",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text("Clear all",
                style: TextStyle(fontSize: 14, color: Colors.red)),
          ],
        ),
        const SizedBox(height: 10),

        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: recentSearches
              .map((e) => Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xfff2f2f2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(e,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ))
              .toList(),
        )
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
          fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildGrid() {
    if (_isLoading) {
      return SizedBox(
        height: 400,
        child: Center(
          child: CircularProgressIndicator(color: Colors.red),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return SizedBox(
        height: 400,
        child: Center(
          child: Text(
            _errorMessage,
            style: TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_recommendedProfiles.isEmpty) {
      return SizedBox(
        height: 400,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 50, color: Colors.grey),
              SizedBox(height: 10),
              Text(
                'No recommendations found',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: _loadUserDataAndFetchProfiles,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    // Calculate how many items to show (max 4 or all if less than 4)
    final itemCount = _recommendedProfiles.length > 4 ? 4 : _recommendedProfiles.length;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.63,
      ),
      itemBuilder: (context, index) => _buildProfileCard(_recommendedProfiles[index]),
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> profile) {
    // Extract data from API response
    final firstName = profile['firstName'] ?? '';
    final lastName = profile['lastName'] ?? '';
    final name = '${profile['userid']} $lastName'.trim();
    final age = profile['age']?.toString() ?? '25';
    final height = profile['height_name']?.toString() ?? '165 cm';
    final profession = profile['designation']?.toString() ?? 'Fashion Designer';
    final city = profile['city']?.toString() ?? '';
    final country = profile['country']?.toString() ?? '';
    final location = city.isNotEmpty ? city : 'Kathmandu';
    final userId = profile['userid'] ?? 0;

    // Construct image URL
    final baseImageUrl = 'https://digitallami.com/Api2/';
    final profilePicture = profile['profile_picture']?.toString() ?? '';
    final imageUrl = profilePicture.isNotEmpty
        ? baseImageUrl + profilePicture
        : 'https://placehold.co/600x800/png';

    // Calculate match percentage if available
    final matchPercent = profile['matchPercent'] ?? 0;
    Color matchColor = Colors.grey;
    if (matchPercent >= 80) {
      matchColor = Colors.green;
    } else if (matchPercent >= 50) {
      matchColor = Colors.orange;
    } else if (matchPercent > 0) {
      matchColor = Colors.red;
    }

    // Check if photo should be blurred
    final shouldShowClearImage = _shouldShowClearImage(profile);
    final photoRequestStatus = _getPhotoRequestStatus(profile);

    return GestureDetector(
      onTap: () {
        // Check document status before navigating to profile
        if (docstatus == 'approved') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileLoader(userId: userId.toString(), myId: userId.toString(),),
            ),
          );
        } else {
          _handleDocumentNotApproved();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section - Conditional blur based on privacy/photo request
            Container(
              height: 140,
              width: double.infinity,
              child: Stack(
                children: [
                  // Image Container with ClipRRect to ensure blur stays within bounds
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: _buildImageWithBlur(
                      imageUrl: imageUrl,
                      shouldShowClearImage: shouldShowClearImage,
                      photoRequestStatus: photoRequestStatus,
                      profile: profile,
                    ),
                  ),

                  // Photo Request Status Indicator
                  if (!shouldShowClearImage)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock,
                              size: 12,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              _getBlurIndicatorText(photoRequestStatus),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Verification Badge
                  if (profile['isVerified'] == 1)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(Icons.verified, size: 16, color: Colors.white),
                      ),
                    ),

                  // Match Percentage
                  if (matchPercent > 0)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: matchColor.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '$matchPercent% Match',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Profile Information
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name with elegant style
                        Container(
                          margin: EdgeInsets.only(bottom: 6),
                          child: Text(
                            "MS:$name",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Age and Height
                        Row(
                          children: [
                            Icon(Icons.person_outline, size: 12, color: Colors.grey),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                "Age $age yrs, $height",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),

                        // Profession
                        Row(
                          children: [
                            Icon(Icons.work_outline, size: 12, color: Colors.grey),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                profession,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),

                        // Location
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 12,
                              color: Color(0xfffb5f6a),
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                location,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Send Request Button

                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWithBlur({
    required String imageUrl,
    required bool shouldShowClearImage,
    required String photoRequestStatus,
    required Map<String, dynamic> profile,
  }) {
    if (shouldShowClearImage) {
      // Show clear image
      return Image.network(
        imageUrl,
        width: double.infinity,
        height: 140,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: double.infinity,
            height: 140,
            color: Colors.grey[200],
            child: Center(
              child: Icon(
                Icons.person,
                size: 50,
                color: Colors.grey,
              ),
            ),
          );
        },
      );
    } else {
      // Show blurred image
      return Stack(
        children: [
          // Original Image
          Image.network(
            imageUrl,
            width: double.infinity,
            height: 140,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: double.infinity,
                height: 140,
                color: Colors.grey[200],
                child: Center(
                  child: Icon(
                    Icons.person,
                    size: 50,
                    color: Colors.grey,
                  ),
                ),
              );
            },
          ),

          // Blur Overlay
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
          ),

          // Lock icon overlay (centered)
          Positioned.fill(
            child: Center(
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withOpacity(0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.lock,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  String _getBlurIndicatorText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'rejected':
        return 'Rejected';
      case 'accepted':
        return 'Access';
      default:
        return 'Private';
    }
  }
}