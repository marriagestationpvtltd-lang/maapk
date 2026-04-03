import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;

import 'package:ms2026/Auth/Screen/signupscreen10.dart';
import 'package:ms2026/Notification/notification_inbox_service.dart';
import 'package:ms2026/otherprofile/otherprofileview.dart';
import 'package:ms2026/ReUsable/loading_widgets.dart';
import '../Models/masterdata.dart';
import '../main.dart';
import '../pushnotification/pushservice.dart';

class FavoritePeoplePage extends StatefulWidget {
  const FavoritePeoplePage({super.key});

  @override
  State<FavoritePeoplePage> createState() => _FavoritePeoplePageState();
}

class _FavoritePeoplePageState extends State<FavoritePeoplePage> {
  List<dynamic> favoritePeople = [];
  bool isLoading = true;
  bool _isRefreshing = false;
  String errorMessage = '';
  String? token;
  int? userId;
  String? userName;
  String? userLastName;
  bool _showPopup = false;
  String _popupMessage = '';
  String _selectedRequestType = 'Profile';
  String docstatus = 'not_uploaded';
  bool _isCheckingStatus = false;
  String usertye = '';

  @override
  void initState() {
    super.initState();
    _initializeUserData();
    loadMasterData();
  }

  Future<void> _initializeUserData() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('bearer_token');
    final userDataString = prefs.getString('user_data');

    if (userDataString != null) {
      final userData = jsonDecode(userDataString);
      userId = int.tryParse(userData["id"].toString());
      userName = userData['firstName']?.toString();
      userLastName = userData['lastName']?.toString();
      await _checkDocumentStatus();
      _fetchFavoritePeople();
    } else {
      setState(() {
        isLoading = false;
        errorMessage = 'User data not found. Please login again.';
      });
    }
  }

  Future<void> _checkDocumentStatus() async {
    if (_isCheckingStatus || userId == null) return;

    setState(() {
      _isCheckingStatus = true;
    });

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
    } finally {
      setState(() {
        _isCheckingStatus = false;
      });
    }
  }

  Future<void> _fetchFavoritePeople({bool isRefresh = false}) async {
    if (userId == null) {
      setState(() {
        isLoading = false;
        errorMessage = 'User ID not found';
      });
      return;
    }

    if (!isRefresh) {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });
    } else {
      setState(() => errorMessage = '');
    }

    try {
      final url = Uri.parse(
          'http://digitallami.com/Api2/likelist.php?user_id=$userId');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'success') {
          setState(() {
            favoritePeople = data['data'];
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = data['message'] ?? 'Failed to fetch data';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Failed to load data. Status code: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _removeFavorite(dynamic receiverId) async {
    if (userId == null) {
     // _showPopupMessage('User ID not found', isError: true);
      return;
    }

    try {
      final url = Uri.parse(
          'https://digitallami.com/Api2/likelist.php?user_id=$userId&action=delete&receiver_id=$receiverId');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'success') {
          // FIXED: Use 'userid' instead of 'id'
          setState(() {
            favoritePeople.removeWhere((person) => person['userid'] == receiverId);
          });
       //   _showPopupMessage('Removed from favorites');
        } else {
       //   _showPopupMessage(data['message'] ?? 'Failed to remove', isError: true);
        }
      } else {
      //  _showPopupMessage('Failed to remove. Please try again.', isError: true);
      }
    } catch (e) {
     // _showPopupMessage('Error: $e', isError: true);
    }
  }
  // EXACT SAME METHOD AS MatchedProfilesPagee
  Future<void> _sendRequest(int receiverId, String receiverName, String requestType) async {
    try {
      // Ensure requestType has proper capitalization
      String formattedRequestType = requestType;
      if (requestType.toLowerCase() == 'profile') formattedRequestType = 'Profile';
      if (requestType.toLowerCase() == 'photo') formattedRequestType = 'Photo';
      if (requestType.toLowerCase() == 'chat') formattedRequestType = 'Chat';

      print('Sending request: sender_id=$userId, receiver_id=$receiverId, request_type=$formattedRequestType');

      // Try with JSON encoding
      final Map<String, dynamic> requestData = {
        'sender_id': userId,
        'receiver_id': receiverId,
        'request_type': formattedRequestType,
      };

      print('Request data (JSON): $requestData');

      final response = await http.post(
        Uri.parse('https://digitallami.com/Api2/send_request.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestData),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Send notification
          final success = await NotificationService.sendRequestNotification(
            recipientUserId: receiverId.toString(),
            senderName: "MS:$userId ${userLastName ?? ''}",
            senderId: userId.toString(),
            requestType: formattedRequestType,
          );

          if (success) {
            print("Request notification sent!");
          } else {
            print("Failed to send notification.");
          }

          await NotificationInboxService.recordOutgoingRequest(
            recipientUserId: receiverId.toString(),
            requestType: formattedRequestType,
            recipientName: receiverName,
          );

          _showRequestSentPopup('$formattedRequestType request sent to $receiverName');
        } else {
          _showRequestSentPopup('Failed: ${data['message']}');
        }
      } else {
        _showRequestSentPopup('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      _showRequestSentPopup('Error: $e');
    }
  }  void _showRequestSentPopup(String message) {
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

  void _handleSendRequest(BuildContext context, int receiverId, String receiverName) {
    if (docstatus == 'approved') {
      _showSendRequestDialog(context, receiverId, receiverName);
    } else {
      _handleDocumentNotApproved();
    }
  }

  void _handleViewProfile(BuildContext context, int receiverId) {
    if (docstatus == 'approved') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileLoader(userId: receiverId.toString(), myId: userId.toString(),),
        ),
      );
    } else {
      _handleDocumentNotApproved();
    }
  }

  void _handleDocumentNotApproved() {
    if (docstatus == 'not_uploaded') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => IDVerificationScreen()),
      );
    } else if (docstatus == 'pending') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => IDVerificationScreen()),
      );
    } else if (docstatus == 'rejected') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => IDVerificationScreen()),
      );
    }
  }

  // EXACT SAME DIALOG AS MatchedProfilesPagee
  void _showSendRequestDialog(
      BuildContext context,
      int receiverId,
      String receiverName,
      {String defaultRequestType = 'Profile'}) {

    String dialogSelectedRequestType = defaultRequestType;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text(
                'Send Request',
                style: TextStyle(
                  color: Color(0xFFEA4935),
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'To: $receiverName',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Request Type:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildRequestTypeOption(
                    context,
                    setState,
                    dialogSelectedRequestType,
                    'Profile',
                    Icons.person_outline,
                    'View',
                        (newValue) {
                      setState(() {
                        dialogSelectedRequestType = newValue;
                      });
                    },
                  ),
                  _buildRequestTypeOption(
                    context,
                    setState,
                    dialogSelectedRequestType,
                    'Photo',
                    Icons.photo_library_outlined,
                    'Request More Photos',
                        (newValue) {
                      setState(() {
                        dialogSelectedRequestType = newValue;
                      });
                    },
                  ),
                  _buildRequestTypeOption(
                    context,
                    setState,
                    dialogSelectedRequestType,
                    'Chat',
                    Icons.chat_outlined,
                    'Start a Conversation',
                        (newValue) {
                      setState(() {
                        dialogSelectedRequestType = newValue;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _sendRequest(receiverId, receiverName, dialogSelectedRequestType);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFEA4935),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Send Request'),
                ),
              ],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            );
          },
        );
      },
    );
  }

  // EXACT SAME WIDGET AS MatchedProfilesPagee
  Widget _buildRequestTypeOption(
      BuildContext context,
      StateSetter setState,
      String currentSelection,
      String value,
      IconData icon,
      String description,
      Function(String) onSelected,
      ) {
    final isSelected = currentSelection == value;

    return GestureDetector(
      onTap: () {
        onSelected(value);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFFEA4935).withOpacity(0.1) : Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Color(0xFFEA4935) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? Color(0xFFEA4935) : Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[700],
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isSelected ? Color(0xFFEA4935) : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFFEA4935),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopupMessage() {
    return AnimatedOpacity(
      opacity: _showPopup ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _popupMessage.contains('Failed') || _popupMessage.contains('Error')
              ? Colors.red
              : Colors.green,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              _popupMessage.contains('Failed') || _popupMessage.contains('Error')
                  ? Icons.error_outline
                  : Icons.check_circle,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _popupMessage,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
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

  // Check if image should be clear or blurred
  bool _shouldShowClearImage(Map<String, dynamic> person) {
    final privacy = person['privacy']?.toString().toLowerCase() ?? '';
    final photoRequest = person['photo_request']?.toString().toLowerCase() ?? '';

    if (privacy == 'free' || photoRequest == 'accepted') {
      return true;
    }
    return false;
  }

  String _getPhotoRequestStatus(Map<String, dynamic> person) {
    final photoRequest = person['photo_request']?.toString().toLowerCase() ?? '';
    if (photoRequest.isEmpty || photoRequest == 'null') return 'not_sent';
    return photoRequest;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        title: const Text(
          'Favorite People',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _fetchFavoritePeople,
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              setState(() => _isRefreshing = true);
              await _fetchFavoritePeople(isRefresh: true);
              if (mounted) setState(() => _isRefreshing = false);
            },
            child: isLoading
                ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
              ),
            )
                : errorMessage.isNotEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    errorMessage,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchFavoritePeople,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
                : ShimmerLoading(
                  isLoading: _isRefreshing,
                  child: favoritePeople.isEmpty
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No favorite people yet',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              itemCount: favoritePeople.length,
              itemBuilder: (context, index) {
                return _favoriteCard(
                    context, favoritePeople[index], index);
              },
            ),
                ),
          ),
          if (_showPopup)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: _buildPopupMessage(),
            ),
        ],
      ),
    );
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

      print("Name: ${user.firstName} ${user.lastName}");
      print("Usertype: ${user.usertype}");
      print("Page No: ${user.pageno}");
      print("Profile: ${user.profilePicture}");
      setState(() {
        usertye = user.usertype;
      });
    } catch (e) {
      print("Error: $e");
    }
  }

  Widget _favoriteCard(BuildContext context, Map<String, dynamic> person, int index) {
    final firstName = person['firstName']?.toString() ?? '';
    final lastName = person['lastName']?.toString() ?? '';
    final fullName = '$firstName $lastName';
    final isVerified = person['isVerified'] == 1 || person['isVerified'] == '1';
    final city = person['city']?.toString() ?? 'Location not available';
    final designation = person['designation']?.toString() ?? 'Profession not available';
    final profileImage = person['profile_picture']?.toString() ??
        'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e';

    // FIXED: Use 'userid' instead of 'id'
    final receiverIdStr = person['userid']?.toString() ?? '0';
    final receiverId = int.tryParse(receiverIdStr) ?? 0;

    print('Favorite Card Debug:');
    print('  Person userid: ${person['userid']}');
    print('  Person ID: ${person['id']}'); // Check if 'id' exists
    print('  Parsed receiverId: $receiverId');
    print('  Full name: $fullName');

    // Determine if image should be blurred
    final shouldShowClearImage = _shouldShowClearImage(person);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// LEFT DETAILS
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// NAME + VERIFIED
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        fullName.isNotEmpty ? fullName : 'Unknown User',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, color: Colors.red, size: 18),
                    ],
                  ],
                ),
                const SizedBox(height: 6),

                /// LOCATION
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        city,
                        style: const TextStyle(color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                /// PROFESSION
                Row(
                  children: [
                    const Icon(Icons.work, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        designation,
                        style: const TextStyle(color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                /// RATING
                Row(
                  children: [
                    ...List.generate(
                      4,
                          (index) => const Icon(Icons.star, size: 18, color: Colors.amber),
                    ),
                    const Icon(Icons.star_half, size: 18, color: Colors.amber),
                    const SizedBox(width: 6),
                    const Text('4.5', style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 12),

                /// BUTTONS with Document Status Check
                Row(
                  children: [
                    _actionButton(
                      text: 'Send Request',
                      icon: Icons.send,
                      gradient: const LinearGradient(
                        colors: [Color(0xffFF3D57), Color(0xffFF6A00)],
                      ),
                      onPressed: () {
                        print('Send Request pressed for: $fullName (userid: $receiverId)');
                        _handleSendRequest(context, receiverId, fullName);
                      },
                    ),
                    const SizedBox(width: 10),
                    _actionButton(
                      text: 'View Profile',
                      icon: Icons.remove_red_eye,
                      gradient: const LinearGradient(
                        colors: [Color(0xffFF3D57), Color(0xffFF6A00)],
                      ),
                      onPressed: () {
                        print('View Profile pressed for: $fullName (userid: $receiverId)');
                        _handleViewProfile(context, receiverId);
                      },
                    ),
                  ],
                )
              ],
            ),
          ),

          /// RIGHT IMAGE + HEART
          Stack(
            children: [
              // Profile image
              ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: Stack(
                  children: [
                    // Main image
                    CachedNetworkImage(
                      imageUrl: profileImage,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.grey,
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Icon(
                          Icons.error,
                          size: 40,
                          color: Colors.grey,
                        ),
                      ),
                    ),

                    // Apply blur overlay if needed
                    if (!shouldShowClearImage)
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () {
                            // Show photo request overlay if image is blurred
                            _showPhotoRequestOverlay(context, person, fullName);
                          },
                          child: Container(
                            color: Colors.black.withOpacity(0.3),
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                              child: Container(
                                color: Colors.black.withOpacity(0.1),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.lock,
                                        color: Colors.red.shade600,
                                        size: 24,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Photo Protected',
                                        style: TextStyle(
                                          color: Colors.red.shade800,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Heart icon overlay
              Positioned(
                right: -6,
                top: -6,
                child: GestureDetector(
                  onTap: () {
                    _showDeleteConfirmationDialog(receiverId, fullName);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                        )
                      ],
                    ),
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  void _showPhotoRequestOverlay(BuildContext context, Map<String, dynamic> person, String receiverName) {
    final photoRequestStatus = _getPhotoRequestStatus(person);
    final receiverId = int.tryParse(person['userid']?.toString() ?? '0') ?? 0;

    if (docstatus != 'approved') {
      _handleDocumentNotApproved();
      return;
    }

    if (photoRequestStatus == 'not_sent') {
      _showSendRequestDialog(context, receiverId, receiverName, defaultRequestType: 'Photo');
    } else if (photoRequestStatus == 'pending') {
      // _showPopupMessage('Your photo request is pending approval');
    } else if (photoRequestStatus == 'rejected') {
     //  _showPopupMessage('Your photo request was rejected');
    }
  }

  void _showDeleteConfirmationDialog(dynamic receiverId, String receiverName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove from Favorites'),
          content: Text('Are you sure you want to remove $receiverName from your favorites?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _removeFavorite(receiverId);
              },
              child: const Text(
                'Remove',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _actionButton({
    required String text,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(24),
        ),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          icon: Icon(icon, size: 16, color: Colors.white),
          label: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
