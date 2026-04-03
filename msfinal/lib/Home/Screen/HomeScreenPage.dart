import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ms2026/Home/Screen/premiummember.dart';
import 'package:ms2026/Home/Screen/profilecard.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../Auth/Screen/signupscreen10.dart';
import '../../Auth/SuignupModel/signup_model.dart';
import '../../Chat/ChatdetailsScreen.dart';
import '../../Chat/ChatlistScreen.dart';
import '../../liked/liked.dart';
import '../../Models/masterdata.dart';
import 'package:http/http.dart' as http;

import '../../Notification/notificationscreen.dart';
import '../../Notification/notification_inbox_service.dart';
import '../../Package/PackageScreen.dart';
import '../../Search/SearchPage.dart';
import '../../main.dart';
import '../../online/onlineservice.dart';
import '../../otherprofile/otherprofileview.dart';
import '../../profile/myprofile.dart';
import '../../purposal/Purposalmodel.dart';
import '../../purposal/purposalScreen.dart';
import '../../purposal/purposalservice.dart';
import '../../purposal/requestcard.dart' show showUpgradeDialog;
import '../../service/Service_chat.dart';
import '../../ReUsable/loading_widgets.dart';
import 'machprofilescreen.dart';

// Cache data structure for better performance
class CachedData {
  final dynamic data;
  final DateTime timestamp;

  CachedData(this.data, this.timestamp);

  bool isExpired(Duration maxAge) {
    return DateTime.now().difference(timestamp) > maxAge;
  }
}

class MatrimonyHomeScreen extends StatefulWidget {
  const MatrimonyHomeScreen({super.key});

  @override
  State<MatrimonyHomeScreen> createState() => _MatrimonyHomeScreenState();
}

class _MatrimonyHomeScreenState extends State<MatrimonyHomeScreen> {
  static const String _apiBaseUrl = 'https://digitallami.com/Api2';
  static const String _placeholderProfileImage =
      'https://via.placeholder.com/150';
  static const Color _brandRed = Color(0xFFF90E18);
  int _currentIndex = 0;

  List<dynamic> _matchedProfilesApi = [];
  bool _isLoading = true;
  String _errorMessage = '';
  List<Map<String, dynamic>> _premiumMembers = [];
  List<Map<String, dynamic>> _otherServices = [];
  List<MatchedUser> _photoRequestProfiles = [];
  List<ProposalModel> _chatRequestProfiles = [];
  bool _loading = true;
  bool _photoRequestsLoading = true;
  bool _chatRequestsLoading = true;
  int _proposalRequestCount = 0;
  int _messageRequestCount = 0;

  List<dynamic> _shortlistedProfiles = [];
  bool _isLoadingShortlist = false;

  int userid = 0;
  String _userId = '';
  String docstatus = 'not_uploaded';

  bool _isCheckingStatus = false;

  // Cache management
  Map<String, CachedData> _cache = {};

  // Lazy loading flags
  bool _premiumMembersLoaded = false;
  bool _otherServicesLoaded = false;

  // Notification count
  int _unreadNotificationCount = 0;

  // Pull-to-refresh shimmer flag
  bool _isRefreshing = false;


  Future<void> _checkDocumentStatus() async {
    if (_isCheckingStatus) return;

    setState(() {
      _isCheckingStatus = true;
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');


      final userData = jsonDecode(userDataString!);
      final userId = int.tryParse(userData["id"].toString());



      print("Checking document status for user ID: $userId");

      final response = await http.post(
        Uri.parse("https://digitallami.com/Api2/check_document_status.php"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );

      print("Status check response: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          setState(() {
            docstatus = result['status'] ?? 'not_uploaded';
            //  _rejectReason = result['reject_reason'] ?? '';
          });
          //  print("Document status: $_documentStatus");
          // print("Reject reason: $_rejectReason");
        } else {
          print("API returned success: false");
          print("Message: ${result['message']}");
        }
      } else {
        print("HTTP error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error checking document status: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Unable to check document status right now. Please try again later.",
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _isCheckingStatus = false;
      });
    }
  }

  Future<void> _loadUnreadNotificationCount() async {
    try {
      final notifications = await NotificationInboxService.loadNotifications();
      final count = notifications.where((n) {
        final isRead = n['is_read'];
        return isRead == null || isRead == 0 || isRead == false;
      }).length;
      if (mounted) {
        setState(() => _unreadNotificationCount = count);
      }
    } catch (e) {
      debugPrint('Failed to load notification count: $e');
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    // Clear cache so fresh data is fetched
    _cache.clear();
    try {
      await Future.wait([
        fetchMatchedProfiles(),
        _fetchQuickActionCounts(forceRefresh: true),
        _checkDocumentStatus(),
        _fetchPremiumMembers(),
        _fetchOtherServices(),
        _fetchShortlistedProfiles(),
        _loadUnreadNotificationCount(),
      ]);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> fetchMatchedProfiles() async {
    // Check cache first
    final cacheKey = 'matched_profiles';
    if (_cache.containsKey(cacheKey) &&
        !_cache[cacheKey]!.isExpired(const Duration(minutes: 2))) {
      final cachedData = _cache[cacheKey]!.data as Map<String, dynamic>;
      setState(() {
        _matchedProfilesApi = cachedData['raw'] as List<dynamic>;
        _photoRequestProfiles = cachedData['photo'] as List<MatchedUser>;
        _isLoading = false;
        _photoRequestsLoading = false;
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _photoRequestsLoading = true;
        _errorMessage = '';
      });

      // Get user ID from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      if (userDataString == null) {
        throw Exception('User data not found');
      }

      final userData = jsonDecode(userDataString);
      final userId = userData["id"].toString();
      userid = int.tryParse(userData['id']?.toString() ?? '') ?? 0;


      // Make API call
      final url = Uri.parse('https://digitallami.com/Api2/match.php?userid=$userId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          final rawProfiles = List<dynamic>.from(result['matched_users'] ?? []);
          final photoProfiles = rawProfiles
              .map((item) => MatchedUser.fromJson(Map<String, dynamic>.from(item)))
              .where((profile) {
            final status = profile.photoRequestStatus.toLowerCase();
            return status == 'accepted' || status == 'pending';
          }).toList()
            ..sort((a, b) => _requestStatusPriority(a.photoRequestStatus)
                .compareTo(_requestStatusPriority(b.photoRequestStatus)));

          // Cache the data
          _cache[cacheKey] = CachedData({
            'raw': rawProfiles,
            'photo': photoProfiles,
          }, DateTime.now());

          setState(() {
            _matchedProfilesApi = rawProfiles;
            _photoRequestProfiles = photoProfiles;
            _isLoading = false;
            _photoRequestsLoading = false;
          });
        } else {
          throw Exception(result['message'] ?? 'Failed to load matched profiles');
        }
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _photoRequestProfiles = [];
        _photoRequestsLoading = false;
      });
      print('Error fetching matched profiles: $e');
    }
  }

  Future<void> _fetchShortlistedProfiles() async {
    // Check cache first
    final cacheKey = 'shortlisted_profiles';
    if (_cache.containsKey(cacheKey) &&
        !_cache[cacheKey]!.isExpired(const Duration(minutes: 2))) {
      setState(() {
        _shortlistedProfiles = _cache[cacheKey]!.data as List<dynamic>;
        _isLoadingShortlist = false;
      });
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      if (userDataString == null) return;
      final userData = jsonDecode(userDataString);
      final userId = userData['id']?.toString() ?? '';
      if (userId.isEmpty) return;

      setState(() => _isLoadingShortlist = true);

      final url = Uri.https('digitallami.com', '/Api2/likelist.php', {'user_id': userId});
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final profiles = data['data'] ?? [];

          // Cache the data
          _cache[cacheKey] = CachedData(profiles, DateTime.now());

          setState(() {
            _shortlistedProfiles = profiles;
            _isLoadingShortlist = false;
          });
        } else {
          setState(() => _isLoadingShortlist = false);
        }
      } else {
        setState(() => _isLoadingShortlist = false);
      }
    } catch (e) {
      setState(() => _isLoadingShortlist = false);
      debugPrint('Error fetching shortlisted profiles: $e');
    }
  }

  Future<void> _fetchQuickActionCounts({bool forceRefresh = false}) async {
    const cacheKey = 'quick_action_counts';

    if (!forceRefresh &&
        _cache.containsKey(cacheKey) &&
        !_cache[cacheKey]!.isExpired(const Duration(minutes: 2))) {
      final cachedData = _cache[cacheKey]!.data as Map<String, int>;
      setState(() {
        _proposalRequestCount = cachedData['proposal'] ?? 0;
        _messageRequestCount = cachedData['message'] ?? 0;
      });
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      if (userDataString == null) return;

      final userData = jsonDecode(userDataString);
      final currentUserId = userData['id']?.toString() ?? '';
      if (currentUserId.isEmpty) return;

      final receivedRequests =
          await ProposalService.fetchProposals(currentUserId, 'received');
      final proposalRequestCount = receivedRequests
          .where((proposal) =>
              proposal.requestType?.toLowerCase() != 'chat' &&
              proposal.status?.toLowerCase() == 'pending')
          .length;
      final messageRequestCount = receivedRequests
          .where((proposal) =>
              proposal.requestType?.toLowerCase() == 'chat' &&
              proposal.status?.toLowerCase() == 'pending')
          .length;

      final counts = {
        'proposal': proposalRequestCount,
        'message': messageRequestCount,
      };

      _cache[cacheKey] = CachedData(counts, DateTime.now());

      if (!mounted) return;
      setState(() {
        _proposalRequestCount = counts['proposal'] ?? 0;
        _messageRequestCount = counts['message'] ?? 0;
      });
    } catch (e) {
      debugPrint('Error fetching quick action counts: $e');
    }
  }

  Future<void> _fetchPremiumMembers() async {
    // Check cache first
    final cacheKey = 'premium_members';
    if (_cache.containsKey(cacheKey) &&
        !_cache[cacheKey]!.isExpired(const Duration(minutes: 2))) {
      setState(() {
        _premiumMembers = _cache[cacheKey]!.data as List<Map<String, dynamic>>;
        _isLoading = false;
        _premiumMembersLoaded = true;
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    final userData = jsonDecode(userDataString!);
    final userid = userData["id"];

    try {
      final url = Uri.parse('https://digitallami.com/Api2/premiuimmember.php?user_id=${userid}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final List members = data['data'];

          final membersList = members.map<Map<String, dynamic>>((member) {
            // Construct full profile picture URL
            final rawImage = member['profile_picture'] ?? '';
            final imageUrl = rawImage.startsWith('http')
                ? rawImage
                : 'https://digitallami.com/Api2/$rawImage';

            return {
              'firstName': member['firstName'] ?? '',
              'lastName': member['lastName'] ?? '',
              'age': member['age'] ?? '',
              'city': member['city'] ?? '',
              'image': imageUrl,
              'isVerified': member['isVerified'] ?? '0',
              'id': member['id'],
            };
          }).toList();

          // Cache the data
          _cache[cacheKey] = CachedData(membersList, DateTime.now());

          setState(() {
            _premiumMembers = membersList;
            _isLoading = false;
            _premiumMembersLoaded = true;
          });
        } else {
          setState(() {
            _isLoading = false;
            _premiumMembersLoaded = true;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _premiumMembersLoaded = true;
        });
        debugPrint('Error fetching premium members: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _premiumMembersLoaded = true;
      });
      debugPrint('Exception: $e');
    }
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
  Future<void> _fetchOtherServices() async {
    // Check cache first
    final cacheKey = 'other_services';
    if (_cache.containsKey(cacheKey) &&
        !_cache[cacheKey]!.isExpired(const Duration(minutes: 2))) {
      setState(() {
        _otherServices = _cache[cacheKey]!.data as List<Map<String, dynamic>>;
        _loading = false;
        _otherServicesLoaded = true;
      });
      return;
    }

    try {
      final url = Uri.parse('https://digitallami.com/Api2/services_api.php');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final List services = data['data'];

          final servicesList = services.map<Map<String, dynamic>>((service) {
            // Build full image URL
            final rawImage = service['profile_picture'] ?? '';
            final imageUrl = rawImage.startsWith('http')
                ? rawImage
                : 'https://digitallami.com/$rawImage';

            return {
              'category': service['servicetype'] ?? '',
              'name': '${service['firstname'] ?? ''} ${service['lastname'] ?? ''}',
              'age': service['age']?.toString() ?? '',
              'location': service['city'] ?? '',
              'experience': service['experience'] ?? '',
              'image': imageUrl,
              'id': service['id'],
            };
          }).toList();

          // Cache the data
          _cache[cacheKey] = CachedData(servicesList, DateTime.now());

          setState(() {
            _otherServices = servicesList;
            _loading = false;
            _otherServicesLoaded = true;
          });
        } else {
          setState(() {
            _loading = false;
            _otherServicesLoaded = true;
          });
        }
      } else {
        setState(() {
          _loading = false;
          _otherServicesLoaded = true;
        });
        debugPrint('Error fetching services: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _otherServicesLoaded = true;
      });
      debugPrint('Exception: $e');
    }
  }

  Future<void> _fetchChatRequestProfiles() async {
    try {
      setState(() {
        _chatRequestsLoading = true;
      });

      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      if (userDataString == null) {
        setState(() {
          _chatRequestProfiles = [];
          _chatRequestsLoading = false;
        });
        return;
      }

      final userData = jsonDecode(userDataString);
      final currentUserId = userData['id'].toString();

      final results = await Future.wait([
        ProposalService.fetchProposals(currentUserId, 'sent'),
        ProposalService.fetchProposals(currentUserId, 'accepted'),
      ]);

      setState(() {
        _chatRequestProfiles = _mergeChatRequests(
          currentUserId: currentUserId,
          sentRequests: results[0],
          acceptedRequests: results[1],
        );
        _chatRequestsLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching chat request profiles: $e');
      setState(() {
        _chatRequestProfiles = [];
        _chatRequestsLoading = false;
      });
    }
  }






String usertye = '';
  String userimage = '';
  var  pageno;
  String name = '';

 // int _currentIndex = 0;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
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
        userimage = user.profilePicture;
        pageno = user.pageno;
        name = "${user.firstName} ${user.lastName}";
        _userId = userId?.toString() ?? '';
        userid = userId ?? 0;
       // docstatus = user.docStatus;
      });
    } catch (e) {
      print("Error: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    // Load only essential data on init
    loadMasterData();
    fetchMatchedProfiles();
    _fetchQuickActionCounts();
    _checkDocumentStatus();
    _fetchShortlistedProfiles();
    _loadUnreadNotificationCount();
    OnlineStatusService().start();
    // Removed auto-refresh timer for better performance
    // User can manually refresh using pull-to-refresh
  }

  @override
  void dispose() {
    // Clean up resources
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Consumer<SignupModel>(
      builder: (context, model, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: _buildAppBar(),
          body: RefreshIndicator(
            color: const Color(0xFFF90E18),
            onRefresh: _refreshData,
            child: ShimmerLoading(
              isLoading: _isRefreshing,
              child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  if (pageno != 10)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildProfileCompletenessCard(),
                    ),
                  const SizedBox(height: 16),
                  const ImageBannerSlider(),
                  const SizedBox(height: 20),
                  _buildStatsBanner(),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildSectionHeader('Quick Actions', showSeeAll: false),
                  ),
                  const SizedBox(height: 14),
                  _buildQuickActions(),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildSectionHeader('Suggested Profiles', showSeeAll: false),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.63,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: ProfileSwipeUI(
                          userId: userid,
                          matchApiUrl: 'https://digitallami.com/Api2/match.php',
                          baseUrl: 'https://digitallami.com/Api2',
                          sendRequestApiUrl: 'https://digitallami.com/Api2/send_request.php',
                          likeApiUrl: 'https://digitallami.com/Api2/like_action.php',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  VisibilityDetector(
                    key: const Key('premium-members-section'),
                    onVisibilityChanged: (info) {
                      // Load data when section becomes visible (>10% visible)
                      if (info.visibleFraction > 0.1 && !_premiumMembersLoaded) {
                        _fetchPremiumMembers();
                      }
                    },
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: GestureDetector(
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => PaidUsersListPage(userId: userid))),
                            child: _buildSectionHeader('Premium Members', showSeeAll: true),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildPremiumMembers(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const ImageBannerSlider(),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GestureDetector(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => MatchedProfilesPagee(
                            currentUserId: userid, docstatus: docstatus))),
                      child: _buildSectionHeader('Matched Profiles', showSeeAll: true),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildMatchedProfilesFromApi(),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GestureDetector(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => FavoritePeoplePage())),
                      child: _buildSectionHeader('Shortlisted Profiles', showSeeAll: true),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildShortlistedProfiles(),
                  const SizedBox(height: 24),
                  VisibilityDetector(
                    key: const Key('other-services-section'),
                    onVisibilityChanged: (info) {
                      // Load data when section becomes visible (>10% visible)
                      if (info.visibleFraction > 0.1 && !_otherServicesLoaded) {
                        _fetchOtherServices();
                      }
                    },
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildSectionHeader('Other Services', showSeeAll: false),
                        ),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildOtherServices(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      shadowColor: Colors.black.withOpacity(0.08),
      scrolledUnderElevation: 2,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFF90E18), Color(0xFFD00D15)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF90E18).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage('https://digitallami.com/Api2/$userimage'),
                onBackgroundImageError: (_, __) {},
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_getGreeting()}! 👋',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  name.isNotEmpty ? name : 'Welcome',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    if (_userId.isNotEmpty) ...[
                      Text(
                        'MS: $_userId',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFF90E18),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      usertye.isEmpty ? 'Member' : (usertye == 'free' ? 'Free Member' : 'Premium Member'),
                      style: TextStyle(
                        fontSize: 11,
                        color: usertye == 'free'
                            ? Colors.grey.shade600
                            : const Color(0xFFFFD700),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (usertye == 'free')
          Container(
            margin: const EdgeInsets.only(right: 4),
            child: TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                backgroundColor: const Color(0xFFF90E18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                minimumSize: const Size(0, 32),
              ),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => SubscriptionPage())),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Upgrade',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        _buildAppBarIcon(
          icon: Icons.search_rounded,
          onPressed: () {
            if (docstatus == 'approved') {
              Navigator.push(context, MaterialPageRoute(builder: (_) => SearchPage()));
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (_) => IDVerificationScreen()));
            }
          },
        ),
        const SizedBox(width: 6),
        _buildNotificationBell(),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildAppBarIcon({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFF90E18).withOpacity(0.08),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: const Color(0xFFF90E18), size: 20),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildNotificationBell() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _buildAppBarIcon(
          icon: Icons.notifications_rounded,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MatrimonyNotificationPage()),
          ).then((_) => _loadUnreadNotificationCount()),
        ),
        if (_unreadNotificationCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: const BoxDecoration(
                color: Color(0xFFF90E18),
                shape: BoxShape.circle,
              ),
              child: Text(
                _unreadNotificationCount > 99
                    ? '99+'
                    : '$_unreadNotificationCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProfileCompletenessCard() {
    final double progress = (pageno != null ? (pageno * 10) / 100.0 : 0.0).clamp(0.0, 1.0);
    final int percent = (progress * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF90E18), Color(0xFFD81B60)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF90E18).withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Complete Your Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'More complete = better matches',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white.withOpacity(0.25),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$percent%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => IDVerificationScreen())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Continue',
                          style: TextStyle(
                            color: Color(0xFFF90E18),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded,
                            color: Color(0xFFF90E18), size: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.favorite_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Icon(
                Icons.diamond_outlined,
                color: Colors.white70,
                size: 28,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBanner() {
    final int matchCount = _matchedProfilesApi.length;
    final int premiumCount = _premiumMembers.length;
    final int profilePercent = ((pageno ?? 0) * 10).clamp(0, 100);
    final int servicesCount = _otherServices.length;

    final stats = [
      {'icon': Icons.favorite_rounded, 'value': '$matchCount', 'label': 'Matches', 'color': const Color(0xFFF90E18)},
      {'icon': Icons.star_rounded, 'value': '$premiumCount', 'label': 'Premium', 'color': const Color(0xFFFFD700)},
      {'icon': Icons.person_rounded, 'value': '$profilePercent%', 'label': 'Profile', 'color': const Color(0xFF2196F3)},
      {'icon': Icons.handshake_rounded, 'value': '$servicesCount', 'label': 'Services', 'color': const Color(0xFF2196F3)},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: stats.map((stat) {
          final color = stat['color'] as Color;
          return Column(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(stat['icon'] as IconData, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                stat['value'] as String,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                stat['label'] as String,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {
        'icon': Icons.search_rounded,
        'label': 'Search',
        'count': null,
        'gradient': [const Color(0xFF6C63FF), const Color(0xFF4834D4)],
        'onTap': () {
          if (docstatus == 'approved') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => SearchPage()));
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => IDVerificationScreen()));
          }
        },
      },
      {
        'icon': Icons.send_rounded,
        'label': 'Proposals',
        'count': _proposalRequestCount,
        'gradient': [const Color(0xFFF90E18), const Color(0xFFD00D15)],
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => ProposalsPage())),
      },
      {
        'icon': Icons.favorite_rounded,
        'label': 'Favorites',
        'count': _shortlistedProfiles.length,
        'gradient': [const Color(0xFFE91E63), const Color(0xFFC2185B)],
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => FavoritePeoplePage())),
      },
      {
        'icon': Icons.chat_bubble_rounded,
        'label': 'Messages',
        'count': _messageRequestCount,
        'gradient': [const Color(0xFF2196F3), const Color(0xFF1565C0)],
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => ChatListScreen())),
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: actions.map((action) {
          final gradient = action['gradient'] as List<Color>;
          final onTap = action['onTap'] as VoidCallback;
          final int? count = action['count'] as int?;

          return Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: gradient[0].withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          action['icon'] as IconData,
                          color: Colors.white,
                          size: 26,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          action['label'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    if (count != null)
                      Positioned(
                        top: -6,
                        right: -2,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 24),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '$count',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: gradient.last,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMatchedProfilesFromApi() {
    if (_isLoading) {
      return SizedBox(
        height: 260,
        child: Center(
          child: CircularProgressIndicator(
            color: const Color(0xFFF90E18),
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return SizedBox(
        height: 260,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  color: Colors.red.shade300, size: 40),
              const SizedBox(height: 8),
              Text('Failed to load profiles',
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 14)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: fetchMatchedProfiles,
                child: const Text('Retry',
                    style: TextStyle(color: Color(0xFFF90E18))),
              ),
            ],
          ),
        ),
      );
    }

    if (_matchedProfilesApi.isEmpty) {
      return SizedBox(
        height: 260,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_border_rounded,
                  size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text('No matched profiles found',
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 270,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _matchedProfilesApi.length,
        padding: const EdgeInsets.only(left: 16, right: 8),
        itemBuilder: (context, index) {
          final profile = _matchedProfilesApi[index];
          final userId = profile['userid']?.toString() ?? '';
          final lastName = profile['lastName'] ?? '';
          final displayName = userId.isNotEmpty
              ? '$userId $lastName'.trim()
              : lastName.isNotEmpty ? lastName : 'User';
          final age = profile['age']?.toString() ?? '';
          final height = profile['height_name'] ?? '';
          final profession = profile['designation'] ?? '';
          final city = profile['city'] ?? '';
          final country = profile['country'] ?? '';
          final location =
              '$city${city.isNotEmpty && country.isNotEmpty ? ', ' : ''}$country';
          final profilePicture = profile['profile_picture'] ?? '';
          final imageUrl = profilePicture.isNotEmpty
              ? 'https://digitallami.com/Api2/$profilePicture'
              : '';
          final matchPercent = profile['matchPercent'];
          final isVerified = profile['isVerified'] == 1;

          Color matchColor = Colors.green;
          if (matchPercent != null) {
            matchColor = matchPercent >= 80
                ? Colors.green
                : matchPercent >= 50
                    ? Colors.orange
                    : const Color(0xFFF90E18);
          }

          return GestureDetector(
            onTap: () {
              final profileUserId = profile['userid'];
              if (profileUserId != null) {
                if (docstatus == 'approved') {
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ProfileLoader(
                          userId: profileUserId.toString(),
                          myId: userid.toString())));
                } else {
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => IDVerificationScreen()));
                }
              }
            },
            child: Container(
              width: 190,
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20)),
                        child: Stack(
                          children: [
                            imageUrl.isNotEmpty
                                ? Image.network(
                                    imageUrl,
                                    width: double.infinity,
                                    height: 155,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        Container(
                                          height: 155,
                                          color: Colors.grey.shade100,
                                          child: const Center(
                                            child: Icon(Icons.person_rounded,
                                                size: 60,
                                                color: Colors.grey),
                                          ),
                                        ),
                                  )
                                : Container(
                                    height: 155,
                                    color: Colors.grey.shade100,
                                    child: const Center(
                                      child: Icon(Icons.person_rounded,
                                          size: 60, color: Colors.grey),
                                    ),
                                  ),
                            Container(
                              width: double.infinity,
                              height: 155,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                              ),
                              child: BackdropFilter(
                                filter: ui.ImageFilter.blur(
                                    sigmaX: 14, sigmaY: 14),
                                child: Container(
                                  color: Colors.transparent,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 50,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.black54
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 6,
                              left: 10,
                              right: 10,
                              child: Text(
                                'Ms $displayName',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  shadows: [
                                    Shadow(
                                        color: Colors.black45,
                                        blurRadius: 4)
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isVerified)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.verified_rounded,
                                color: Color(0xFF2196F3), size: 16),
                          ),
                        ),
                      if (matchPercent != null)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: matchColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$matchPercent%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (age.isNotEmpty || height.isNotEmpty)
                                Text(
                                  '${age.isNotEmpty ? '$age yrs' : ''}${age.isNotEmpty && height.isNotEmpty ? ', ' : ''}$height',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              if (profession.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Icon(Icons.work_outline_rounded,
                                        size: 11,
                                        color: Colors.grey.shade500),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        profession,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (location.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Icon(Icons.location_on_outlined,
                                        size: 11,
                                        color: Colors.grey.shade500),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        location,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          SizedBox(
                            width: double.infinity,
                            height: 30,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                side: const BorderSide(
                                    color: Color(0xFFF90E18), width: 1.5),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () {
                                final profileUserId = profile['userid'];
                                if (profileUserId != null) {
                                  if (docstatus == 'approved') {
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => ProfileLoader(
                                                userId: profileUserId
                                                    .toString(),
                                                myId: userid.toString())));
                                  } else {
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                IDVerificationScreen()));
                                  }
                                }
                              },
                              child: const Text(
                                'Connect',
                                style: TextStyle(
                                  color: Color(0xFFF90E18),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
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
          );
        },
      ),
    );
  }

  Widget _buildShortlistedProfiles() {
    if (_isLoadingShortlist) {
      return const SizedBox(
        height: 220,
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFF90E18),
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_shortlistedProfiles.isEmpty) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bookmark_border_rounded,
                  size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text('No shortlisted profiles yet',
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _shortlistedProfiles.length,
        padding: const EdgeInsets.only(left: 16, right: 8),
        itemBuilder: (context, index) {
          final person = _shortlistedProfiles[index];
          final firstName = person['firstName']?.toString() ?? '';
          final lastName = person['lastName']?.toString() ?? '';
          final fullName = '$firstName $lastName'.trim();
          final displayName = fullName.isNotEmpty ? fullName : 'User';
          final city = person['city']?.toString() ?? '';
          final profilePicture = person['profile_picture']?.toString() ?? '';
          final imageUrl = profilePicture.isNotEmpty
              ? (profilePicture.startsWith('http')
                  ? profilePicture
                  : 'https://digitallami.com/Api2/$profilePicture')
              : '';
          final isVerified =
              person['isVerified'] == 1 || person['isVerified'] == '1';
          final receiverId = person['userid'];

          return GestureDetector(
            onTap: () {
              if (receiverId != null) {
                if (docstatus == 'approved') {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ProfileLoader(
                              userId: receiverId.toString(),
                              myId: userid.toString())));
                } else {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => IDVerificationScreen()));
                }
              }
            },
            child: Container(
              width: 160,
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                width: double.infinity,
                                height: 130,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 130,
                                  color: Colors.grey.shade100,
                                  child: const Center(
                                      child: Icon(Icons.person_rounded,
                                          size: 50, color: Colors.grey)),
                                ),
                              )
                            : Container(
                                height: 130,
                                color: Colors.grey.shade100,
                                child: const Center(
                                    child: Icon(Icons.person_rounded,
                                        size: 50, color: Colors.grey)),
                              ),
                      ),
                      if (isVerified)
                        const Positioned(
                          top: 8,
                          right: 8,
                          child: Icon(Icons.verified,
                              color: Colors.red, size: 18),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (city.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on,
                                  size: 12, color: Colors.grey),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  city,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPremiumMembers() {
    if (_premiumMembers.isEmpty) {
      return SizedBox(
        height: 240,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_outline_rounded,
                  size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text('No premium members yet',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 260,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _premiumMembers.length,
        padding: const EdgeInsets.only(left: 16, right: 8),
        itemBuilder: (context, index) {
          final profile = _premiumMembers[index];
          final lastName = profile['lastName'] ?? '';
          final userIdd = profile['id'];
          final age = profile['age'] ?? '';
          final location = profile['city'] ?? '';
          final imageUrl = profile['image'] ?? '';
          final isVerified = profile['isVerified']?.toString() == '1';

          return GestureDetector(
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              final userDataString = prefs.getString('user_data');
              if (userDataString == null) return;
              final userData = jsonDecode(userDataString);
              final myUserId = int.tryParse(userData['id'].toString());
              if (docstatus == 'approved') {
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ProfileLoader(
                        userId: userIdd.toString(), myId: myUserId.toString())));
              } else {
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => IDVerificationScreen()));
              }
            },
            child: Container(
              width: 180,
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20)),
                        child: Stack(
                          children: [
                            Image.network(
                              imageUrl,
                              width: double.infinity,
                              height: 160,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 160,
                                color: Colors.grey.shade100,
                                child: const Center(
                                  child: Icon(Icons.person_rounded,
                                      size: 60, color: Colors.grey),
                                ),
                              ),
                            ),
                            Container(
                              width: double.infinity,
                              height: 160,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.25),
                              ),
                              child: BackdropFilter(
                                filter: ui.ImageFilter.blur(
                                    sigmaX: 14, sigmaY: 14),
                                child: Container(
                                  color: Colors.black.withOpacity(0.05),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 60,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.black54
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded,
                                  color: Colors.white, size: 10),
                              SizedBox(width: 3),
                              Text(
                                'Premium',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isVerified)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.verified_rounded,
                                color: Color(0xFF2196F3), size: 18),
                          ),
                        ),
                    ],
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MS $userIdd $lastName',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A2E),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Icon(Icons.location_on_rounded,
                                      size: 12, color: Colors.grey.shade500),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: Text(
                                      '$age yrs · $location',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(
                            width: double.infinity,
                            height: 32,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF90E18),
                                elevation: 0,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () async {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                final userDataString =
                                    prefs.getString('user_data');
                                if (userDataString == null) return;
                                final userData = jsonDecode(userDataString);
                                final myUserId = int.tryParse(
                                    userData['id'].toString());
                                if (docstatus == 'approved') {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => ProfileLoader(
                                              userId: userIdd.toString(),
                                              myId: myUserId.toString())));
                                } else {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              IDVerificationScreen()));
                                }
                              },
                              child: const Text(
                                'View Profile',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
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
          );
        },
      ),
    );
  }

// Helper method to show blur popup

// Helper method to show blur popup





  Widget _buildOtherServices() {
    if (_loading) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFF90E18)),
        ),
      );
    }

    if (_otherServices.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.handshake_outlined,
                  size: 40, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text('No services available',
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _otherServices.map((service) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
                child: Stack(
                  children: [
                    Image.network(
                      service['image'],
                      width: 120,
                      height: 175,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 120,
                        height: 175,
                        color: Colors.grey.shade100,
                        child: const Center(
                          child: Icon(Icons.person_rounded,
                              size: 50, color: Colors.grey),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      left: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF90E18), Color(0xFFD81B60)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          service['category'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              service['name'],
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1A1A2E),
                                letterSpacing: -0.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF90E18).withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.favorite_border_rounded,
                                color: Color(0xFFF90E18), size: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.cake_outlined,
                              size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            'Age ${service['age']}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(Icons.location_on_outlined,
                              size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              service['location'],
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF90E18).withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Exp: ${service['experience']}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFF90E18),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF90E18),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          icon: const Icon(Icons.chat_bubble_outline_rounded,
                              color: Colors.white, size: 16),
                          label: const Text(
                            'Start Conversation',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ServiceChatPage(
                                      senderId: userid.toString(),
                                      receiverId: service['id'].toString(),
                                      name: service['name'],
                                      exp: service['experience'],
                                      cat: service['category']))),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  List<ProposalModel> _mergeChatRequests({
    required String currentUserId,
    required List<ProposalModel> sentRequests,
    required List<ProposalModel> acceptedRequests,
  }) {
    final Map<String, ProposalModel> mergedRequests = {};

    void addRequests(List<ProposalModel> requests) {
      for (final request in requests) {
        final requestType = (request.requestType ?? '').toLowerCase();
        final status = (request.status ?? '').toLowerCase();
        final isSentByCurrentUser = request.senderId?.toString() == currentUserId;

        if (requestType != 'chat' || !isSentByCurrentUser) {
          continue;
        }

        if (status != 'accepted' && status != 'pending') {
          continue;
        }

        final key = request.proposalId ??
            '${request.senderId}_${request.receiverId}_${request.requestType}';
        final existing = mergedRequests[key];

        if (existing == null ||
            _requestStatusPriority(status) <
                _requestStatusPriority(existing.status)) {
          mergedRequests[key] = request;
        }
      }
    }

    addRequests(sentRequests);
    addRequests(acceptedRequests);

    final requests = mergedRequests.values.toList()
      ..sort((a, b) {
        final statusCompare = _requestStatusPriority(a.status)
            .compareTo(_requestStatusPriority(b.status));
        if (statusCompare != 0) {
          return statusCompare;
        }

        final aName = '${a.firstName ?? ''} ${a.lastName ?? ''}'.trim();
        final bName = '${b.firstName ?? ''} ${b.lastName ?? ''}'.trim();
        return aName.compareTo(bName);
      });

    return requests;
  }

  int _requestStatusPriority(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'accepted':
        return 0;
      case 'pending':
        return 1;
      default:
        return 2;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return const Color(0xFF2E7D32);
      case 'pending':
        return const Color(0xFFF9A825);
      default:
        return _brandRed;
    }
  }

  String _resolveApiImageUrl(String rawImage) {
    if (rawImage.isEmpty) {
      return '';
    }

    if (rawImage.startsWith('http')) {
      return rawImage;
    }

    final normalizedPath = rawImage.startsWith('/')
        ? rawImage.substring(1)
        : rawImage;
    return '$_apiBaseUrl/$normalizedPath';
  }

  Widget _buildRequestLoadingState() {
    return SizedBox(
      height: 250,
      child: Center(
        child: CircularProgressIndicator(
          color: _brandRed,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildRequestEmptyState({
    required IconData icon,
    required String message,
  }) {
    return SizedBox(
      height: 250,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestFallbackImage() {
    return Container(
      width: double.infinity,
      height: 160,
      color: Colors.grey.shade100,
      child: const Center(
        child: Icon(Icons.person_rounded, size: 60, color: Colors.grey),
      ),
    );
  }

  Widget _buildRequestStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  void _openProfile(String profileUserId) {
    if (docstatus == 'approved') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileLoader(
            userId: profileUserId,
            myId: userid.toString(),
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => IDVerificationScreen()),
      );
    }
  }

  void _openPhotoRequestProfile(String profileUserId) {
    if (docstatus != 'approved') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => IDVerificationScreen()),
      );
      return;
    }

    if (usertye == 'free') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SubscriptionPage()),
      );
      return;
    }

    _openProfile(profileUserId);
  }

  Future<void> _openChatRequest(ProposalModel request) async {
    try {
      if (docstatus == "not_uploaded" ||
          docstatus == "rejected" ||
          docstatus == "pending") {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => IDVerificationScreen()),
        );
        return;
      }

      if (usertye == "free") {
        showUpgradeDialog(context);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      if (userDataString == null) {
        return;
      }

      final userData = jsonDecode(userDataString);
      final currentUserIdStr = userData['id'].toString();
      final currentUserName =
          '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
      final currentUserImage =
          _resolveApiImageUrl(userData['profilePicture']?.toString() ?? '');

      final isCurrentUserSender = currentUserIdStr == request.senderId;
      final otherUserId = isCurrentUserSender
          ? (request.receiverId ?? '')
          : (request.senderId ?? '');

      if (otherUserId.isEmpty) {
        return;
      }

      final otherUserName =
          'MS ${request.memberid ?? ''} ${request.firstName ?? ''} ${request.lastName ?? ''}'
              .trim();
      final otherUserImage = _resolveApiImageUrl(request.profilePicture ?? '');

      final userIds = [currentUserIdStr, otherUserId]..sort();
      final chatRoomId = userIds.join('_');

      final chatRoomDoc = await FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(chatRoomId)
          .get();

      if (!chatRoomDoc.exists) {
        await FirebaseFirestore.instance
            .collection('chatRooms')
            .doc(chatRoomId)
            .set({
          'chatRoomId': chatRoomId,
          'participants': [currentUserIdStr, otherUserId],
          'participantNames': {
            currentUserIdStr: currentUserName,
            otherUserId: otherUserName,
          },
          'participantImages': {
            currentUserIdStr: currentUserImage,
            otherUserId: otherUserImage,
          },
          'unreadCount': {
            currentUserIdStr: 0,
            otherUserId: 0,
          },
          'lastMessage': '',
          'lastMessageType': 'text',
          'lastMessageTime': DateTime.now(),
          'lastMessageSenderId': '',
          'createdAt': DateTime.now(),
          'updatedAt': DateTime.now(),
        });
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            chatRoomId: chatRoomId,
            receiverId: otherUserId,
            receiverName:
                otherUserName.isNotEmpty ? otherUserName : 'User $otherUserId',
            receiverImage: otherUserImage.isNotEmpty
                ? otherUserImage
                : _placeholderProfileImage,
            currentUserId: currentUserIdStr,
            currentUserName: currentUserName.isNotEmpty
                ? currentUserName
                : 'User $currentUserIdStr',
            currentUserImage: currentUserImage.isNotEmpty
                ? currentUserImage
                : _placeholderProfileImage,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error opening chat request: $e');
    }
  }



  Widget _buildSectionHeader(String title, {bool showSeeAll = true}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF90E18), Color(0xFFD81B60)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A2E),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        if (showSeeAll)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF90E18).withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'See All',
                  style: TextStyle(
                    color: Color(0xFFF90E18),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded,
                    color: Color(0xFFF90E18), size: 14),
              ],
            ),
          ),
      ],
    );
  }
}



class ImageBannerSlider extends StatefulWidget {
  const ImageBannerSlider({super.key});

  @override
  State<ImageBannerSlider> createState() => _ImageBannerSliderState();
}

class _ImageBannerSliderState extends State<ImageBannerSlider> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  // Add your image paths here
  final List<String> bannerImages = [
    "assets/images/ms.jpeg",
    "assets/images/ms.jpeg",
    "assets/images/ms.jpeg",
  ];

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    Future.delayed(const Duration(seconds: 3), () {
      if (_controller.hasClients) {
        int next = _currentPage + 1;
        if (next == bannerImages.length) next = 0;

        _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
      _startAutoSlide();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(

      margin: EdgeInsets.all(8),
      child: Column(
        children: [
          Container(
           // margin: EdgeInsets.only(left: 10, right: 10),
            height: 125,
            width: double.infinity,
            child: PageView.builder(
              controller: _controller,
              itemCount: bannerImages.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, index) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    bannerImages[index],
                    fit: BoxFit.cover,

                  ),
                );
              },
            ),
          ),
      
          const SizedBox(height: 10),
      
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              bannerImages.length,
                  (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: _currentPage == index ? 20 : 8,
                decoration: BoxDecoration(
                  color: Colors.red, // 🔴 red dot indicator
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
