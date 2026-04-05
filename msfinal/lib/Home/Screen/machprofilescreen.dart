import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../Auth/Screen/signupscreen10.dart';
import '../../main.dart';
import '../../otherprofile/otherprofileview.dart';
import '../../pushnotification/pushservice.dart';
import '../../ReUsable/loading_widgets.dart';
import '../../utils/privacy_utils.dart';

class MatchedProfilesPagee extends StatefulWidget {
  final int currentUserId;
  final String docstatus;

  const MatchedProfilesPagee({
    Key? key,
    required this.currentUserId,
    required this.docstatus,
  }) : super(key: key);

  @override
  State<MatchedProfilesPagee> createState() => _MatchedProfilesPageeState();
}

class _MatchedProfilesPageeState extends State<MatchedProfilesPagee> {
  List<dynamic> _matchedProfiles = [];
  bool _isLoading = false;
  bool _isRefreshing = false;
  String _errorMessage = '';
  bool _isBlurred = true;
  final String _apiUrl = 'https://digitallami.com/Api2/match.php';
  String _userName = '';
  String _userLastName = '';
  int _userId = 0;
  bool _showPopup = false;
  String _popupMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchMatchedProfiles();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      if (userDataString != null) {
        final userData = jsonDecode(userDataString);
        setState(() {
          _userId = int.tryParse(userData["id"].toString()) ?? 0;
          _userName = userData["firstName"] ?? '';
          _userLastName = userData["lastName"] ?? '';
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _fetchMatchedProfiles({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    } else {
      setState(() => _errorMessage = '');
    }

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        body: {'userid': widget.currentUserId.toString()},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _matchedProfiles = data['matched_users'] ?? [];
          });
        } else {
          setState(() {
            _errorMessage = data['message'] ?? 'Failed to fetch profiles';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'HTTP Error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }



  void _showRequestSentPopup(String message) {
    setState(() {
      _popupMessage = message;
      _showPopup = true;
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showPopup = false;
        });
      }
    });
  }


  Future<void> _handleLikeProfile(int profileId, bool isCurrentlyLiked) async {
    try {
      final response = await http.post(
        Uri.parse('https://digitallami.com/Api2/like_profile.php'),
        body: {
          'sender_id': widget.currentUserId.toString(),
          'receiver_id': profileId.toString(),
          'action': isCurrentlyLiked ? 'delete' : 'add',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            final index = _matchedProfiles.indexWhere((p) => p['userid'] == profileId);
            if (index != -1) {
              _matchedProfiles[index]['like'] = !isCurrentlyLiked;
            }
          });

          _showRequestSentPopup(isCurrentlyLiked ? 'Removed from likes' : 'Added to likes');
        } else {
          _showRequestSentPopup('Failed: ${data['message']}');
        }
      }
    } catch (e) {
      _showRequestSentPopup('Error: $e');
    }
  }




  Widget _buildProfileCard(int index) {
    final profile = _matchedProfiles[index];

    // Extract data from API response
    final userId = profile['userid']?.toString() ?? 'null';
    final lastName = profile['lastName'] ?? '';
    final name = userId != 'null'
        ? '$userId $lastName'.trim()
        : lastName.isNotEmpty
        ? lastName
        : 'User';

    final age = profile['age']?.toString() ?? '';
    final height = profile['height_name'] ?? '';
    final profession = profile['designation'] ?? '';
    final city = profile['city'] ?? '';
    final country = profile['country'] ?? '';
    final location = '$city${city.isNotEmpty && country.isNotEmpty ? ', ' : ''}$country';
    final matchPercent = profile['matchPercent'] ?? 0;
    final isVerified = profile['isVerified'] == 1;
    final isLiked = profile['like'] == true;
    final privacy = profile['privacy']?.toString().toLowerCase() ?? 'free';
    final photoRequestStatus = profile['photo_request']?.toString().toLowerCase() ?? 'not_sent';

    // Construct image URL
    final baseImageUrl = 'https://digitallami.com/Api2/';
    final profilePicture = profile['profile_picture'] ?? '';
    final imageUrl = profilePicture.isNotEmpty
        ? baseImageUrl + profilePicture
        : 'https://via.placeholder.com/300x200?text=No+Image';

    // Check if should show clear image using PrivacyUtils
    final shouldShowClearImage = PrivacyUtils.shouldShowClearImage(
      privacy: privacy,
      photoRequest: photoRequestStatus,
    );
    final isActuallyBlurred = _isBlurred && !shouldShowClearImage;

    return Container(
      margin: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 1,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min, // FIX: Use min instead of max
        children: [
          // Image Section - Fixed height
          Container(
            height: 180, // Fixed height
            child: Stack(
              children: [
                // Main image container
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  child: Stack(
                    children: [
                      // Image with blur logic
                      if (isActuallyBlurred)
                      // Blurred image with lock overlay
                        Stack(
                          children: [
                            ImageFiltered(
                              imageFilter: ui.ImageFilter.blur(
                                sigmaX: PrivacyUtils.kStandardBlurSigmaX,
                                sigmaY: PrivacyUtils.kStandardBlurSigmaY,
                              ),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[100],
                                    child: Center(
                                      child: Icon(Icons.person, color: Colors.grey[300], size: 60),
                                    ),
                                  );
                                },
                              ),
                            ),
                            // Lock overlay for blurred images
                            Container(
                              color: Colors.black.withOpacity(0.4),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(15),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.red.shade600.withOpacity(0.9),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.3),
                                            blurRadius: 20,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.lock,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      'Photo Protected',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 5),
                                    if (photoRequestStatus == 'pending')
                                      Text(
                                        'Request Pending',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange[200],
                                        ),
                                      ),
                                    if (photoRequestStatus == 'rejected')
                                      Text(
                                        'Request Rejected',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.red[200],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                      // Clear image
                        Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey[100],
                              child: Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEA4935)),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[100],
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.person, color: Colors.grey[300], size: 60),
                                    SizedBox(height: 8),
                                    Text(
                                      'No Image',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),

                // Gradient overlay for name
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Name and badges overlay
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Ms $name",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isVerified)
                              Container(
                                margin: EdgeInsets.only(left: 8),
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.verified, size: 16, color: Colors.white),
                              ),
                          ],
                        ),
                        SizedBox(height: 4),
                        if (age.isNotEmpty || height.isNotEmpty)
                          Text(
                            '${age.isNotEmpty ? '$age yrs' : ''}${age.isNotEmpty && height.isNotEmpty ? ' • ' : ''}${height.isNotEmpty ? height : ''}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Top right match percentage
                if (matchPercent > 0)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getMatchColor(matchPercent),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Text(
                        '$matchPercent% Match',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                // Like button top left
                Positioned(
                  top: 12,
                  left: 12,
                  child: GestureDetector(
                    onTap: () => _handleLikeProfile(profile['userid'], isLiked),
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 20,
                        color: isLiked ? Colors.red : Colors.grey[700],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Info Section - Using Flexible to constrain height
          Flexible(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, // FIX: Use min
                children: [
                  // Profession
                  if (profession.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.work_outline, size: 16, color: Colors.grey[600]),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            profession,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                  SizedBox(height: profession.isNotEmpty ? 8 : 0),

                  // Location
                  if (location.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            location,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                  SizedBox(height: location.isNotEmpty ? 16 : 8),

                  // Photo request statu
                  Container(
                    //  height: 45, // Fixed height
                    child: ElevatedButton(
                      onPressed: () {
                        _navigateToProfile(profile['userid']);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.remove_red_eye, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'View',
                            style: TextStyle(
                              fontSize: 13,
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
    );
  }

  Color _getMatchColor(int percent) {
    if (percent >= 80) return Colors.green;
    if (percent >= 60) return Colors.blue;
    if (percent >= 40) return Colors.orange;
    return Colors.red;
  }






  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEA4935)),
            strokeWidth: 3,
          ),
          SizedBox(height: 20),
          Text(
            'Finding your perfect matches...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 60),
            SizedBox(height: 20),
            Text(
              'Unable to load matches',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 10),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _fetchMatchedProfiles,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFEA4935),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group, color: Colors.grey[400], size: 80),
            SizedBox(height: 20),
            Text(
              'No matches yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Adjust your preferences to find more matches',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFEA4935),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Edit Preferences'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopupMessage() {
    return AnimatedOpacity(
      opacity: _showPopup ? 1.0 : 0.0,
      duration: Duration(milliseconds: 300),
      child: Container(
        margin: EdgeInsets.all(20),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                _popupMessage,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: Colors.white, size: 18),
              onPressed: () {
                setState(() {
                  _showPopup = false;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToProfile(int userId) {
    switch (widget.docstatus) {
      case 'approved':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileLoader(userId: userId.toString(), myId: userId.toString(),),
          ),
        );
        break;
      case 'not_uploaded':
      case 'pending':
      case 'rejected':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => IDVerificationScreen(),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Matched Profiles',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.grey[800],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,

      ),
      body: Stack(
        children: [
          // Main content
          _isLoading
              ? _buildLoadingState()
              : _errorMessage.isNotEmpty
              ? _buildErrorState()
              : _matchedProfiles.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
            onRefresh: () async {
              setState(() => _isRefreshing = true);
              await _fetchMatchedProfiles(isRefresh: true);
              if (mounted) setState(() => _isRefreshing = false);
            },
            color: Color(0xFFEA4935),
            child: ShimmerLoading(
              isLoading: _isRefreshing,
              child: SingleChildScrollView(
              child: Column(
                children: [
                  // Header with stats
                  Container(
                    padding: EdgeInsets.all(20),
                    color: Colors.white,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Matches',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[900],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '${_matchedProfiles.length} profiles found',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),

                      ],
                    ),
                  ),



                  // Grid of profiles - FIXED: Use mainAxisExtent for fixed card height
                  GridView.builder(
                    physics: NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 1,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                      childAspectRatio: 0.7,
                      mainAxisExtent: 359, // Fixed height for each card
                    ),
                    padding: EdgeInsets.all(16),
                    itemCount: _matchedProfiles.length,
                    itemBuilder: (context, index) {
                      return _buildProfileCard(index);
                    },
                  ),

                  SizedBox(height: 40),

                  // Footer
                  if (widget.docstatus != 'approved')
                    Container(
                      margin: EdgeInsets.all(16),
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.verified_user, color: Colors.orange, size: 24),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Verify Your Identity',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Complete ID verification to access all features',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.arrow_forward, color: Color(0xFFEA4935)),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => IDVerificationScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                  SizedBox(height: 60),
                ],
              ),
            ),
          ),
          ),

          // Popup message
          if (_showPopup)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildPopupMessage(),
            ),
        ],
      ),
    );
  }
}