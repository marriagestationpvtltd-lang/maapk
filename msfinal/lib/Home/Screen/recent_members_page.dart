import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:ms2026/constant/app_colors.dart';
import 'package:ms2026/constant/app_dimensions.dart';
import 'package:ms2026/constant/app_text_styles.dart';
import 'package:ms2026/constant/status_bar_utils.dart';
import 'package:ms2026/otherprofile/otherprofileview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Auth/Screen/signupscreen10.dart';
import '../../main.dart';
import '../../ReUsable/loading_widgets.dart';
import '../../utils/privacy_utils.dart';

class RecentMembersPage extends StatefulWidget {
  final int userId;
  const RecentMembersPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<RecentMembersPage> createState() => _RecentMembersPageState();
}

class _RecentMembersPageState extends State<RecentMembersPage> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _errorMessage = '';
  bool _hasMore = true;
  int _currentPage = 1;
  final int _perPage = 20;
  final ScrollController _scrollController = ScrollController();
  String _userCreatedDate = '';
  String docstatus = 'not_uploaded';

  @override
  void initState() {
    super.initState();
    _fetchMembers();
    _scrollController.addListener(_scrollListener);
    _checkDocumentStatus();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkDocumentStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      if (userDataString == null) return;

      final userData = jsonDecode(userDataString);
      final userId = int.tryParse(userData["id"].toString());

      final response = await http.post(
        Uri.parse("https://digitallami.com/Api2/check_document_status.php"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true && mounted) {
          setState(() {
            docstatus = result['status'] ?? 'not_uploaded';
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking document status: $e');
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        !_isLoading &&
        _hasMore) {
      _fetchMembers(loadMore: true);
    }
  }

  Future<void> _fetchMembers({bool loadMore = false}) async {
    if (loadMore) {
      _currentPage++;
    } else {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _members.clear();
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      if (userDataString == null) return;

      final userData = jsonDecode(userDataString);
      final userid = userData["id"];
      _userCreatedDate = userData["created_at"] ?? "";

      final url = Uri.parse(
          'https://digitallami.com/Api2/search_opposite_gender.php?user_id=$userid&sort_by=recent&limit=${_perPage * _currentPage}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final List members = data['data'];

          // Filter members registered after current user
          final membersList = members.where((member) {
            final memberCreatedDate = member['created_at'] ?? '';
            if (memberCreatedDate.isEmpty || _userCreatedDate.isEmpty) {
              return true;
            }

            try {
              final memberDate = DateTime.parse(memberCreatedDate);
              final userDate = DateTime.parse(_userCreatedDate);
              return memberDate.isAfter(userDate);
            } catch (e) {
              return true; // Include if date parsing fails
            }
          }).map<Map<String, dynamic>>((member) {
            // Construct full profile picture URL
            final rawImage = member['profile_picture'] ?? '';
            final imageUrl = rawImage.startsWith('http')
                ? rawImage
                : 'https://digitallami.com/Api2/$rawImage';

            return {
              'userId': member['userid'] ?? member['id'],
              'memberid': member['memberid'] ?? 'N/A',
              'firstName': member['firstName'] ?? '',
              'lastName': member['lastName'] ?? '',
              'age': member['age'] ?? '',
              'city': member['city'] ?? '',
              'country': member['country'] ?? '',
              'heightName': member['height_name'] ?? '',
              'designation': member['designation'] ?? '',
              'image': imageUrl,
              'isVerified': member['isVerified'] ?? '0',
              'id': member['id'],
              'privacy': member['privacy']?.toString().toLowerCase() ?? '',
              'photo_request':
                  member['photo_request']?.toString().toLowerCase() ?? '',
              'created_at': member['created_at'] ?? '',
            };
          }).toList();

          if (!mounted) return;
          setState(() {
            _members = membersList;
            _isLoading = false;
            _isRefreshing = false;
            _hasMore = membersList.length >= _perPage * _currentPage;
          });
        } else {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _isRefreshing = false;
          });
        }
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Failed to load members';
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
        _isRefreshing = false;
      });
      debugPrint('Exception fetching recent members: $e');
    }
  }

  Future<void> _refreshMembers() async {
    setState(() => _isRefreshing = true);
    await _fetchMembers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Recently Registered',
          style: AppTextStyles.heading3,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemStatusBarContrastEnforced: false,
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _members.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage.isNotEmpty && _members.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(_errorMessage, style: AppTextStyles.bodyMedium),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshMembers,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: AppDimensions.borderRadiusLG,
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_members.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add_alt_1_rounded,
                size: 80, color: AppColors.border),
            const SizedBox(height: 16),
            Text(
              'No recent members found',
              style: AppTextStyles.bodyLarge
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for new members',
              style:
                  AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshMembers,
      color: AppColors.primary,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.68,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _members.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _members.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }

          return _buildMemberCard(_members[index]);
        },
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> profile) {
    final lastName = profile['lastName'] ?? '';
    final memberid = profile['memberid'] ?? 'MS';
    final userIdd = profile['userId'] ?? profile['id'];
    final age = profile['age'] ?? '';
    final location = profile['city'] ?? '';
    final country = profile['country'] ?? '';
    final heightName = profile['heightName'] ?? '';
    final designation = profile['designation'] ?? '';
    final imageUrl = profile['image'] ?? '';
    final isVerified = profile['isVerified']?.toString() == '1';
    final privacy = profile['privacy']?.toString().toLowerCase() ?? '';
    final photoRequest = profile['photo_request']?.toString().toLowerCase() ?? '';

    // Use PrivacyUtils for consistent privacy enforcement
    final shouldShowClearImage = PrivacyUtils.shouldShowClearImage(
      privacy: privacy,
      photoRequest: photoRequest,
    );

    return GestureDetector(
      onTap: () async {
        final prefs = await SharedPreferences.getInstance();
        final userDataString = prefs.getString('user_data');
        if (userDataString == null) return;
        final userData = jsonDecode(userDataString);
        final myUserId = int.tryParse(userData['id'].toString());
        if (docstatus == 'approved') {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ProfileLoader(
                      userId: userIdd.toString(), myId: myUserId.toString())));
        } else {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => IDVerificationScreen()));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: AppDimensions.borderRadiusXL,
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withOpacity(0.08),
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
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  child: shouldShowClearImage
                      ? Image.network(
                          imageUrl,
                          width: double.infinity,
                          height: 180,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 180,
                            color: AppColors.background,
                            child: const Center(
                              child: Icon(Icons.person_rounded,
                                  size: 60, color: AppColors.textHint),
                            ),
                          ),
                        )
                      : ImageFiltered(
                          imageFilter: ui.ImageFilter.blur(
                            sigmaX: PrivacyUtils.kStandardBlurSigmaX,
                            sigmaY: PrivacyUtils.kStandardBlurSigmaY,
                          ),
                          child: Image.network(
                            imageUrl,
                            width: double.infinity,
                            height: 180,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 180,
                              color: AppColors.background,
                              child: const Center(
                                child: Icon(Icons.person_rounded,
                                    size: 60, color: AppColors.textHint),
                              ),
                            ),
                          ),
                        ),
                ),
                // New member badge
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                      ),
                      borderRadius: AppDimensions.borderRadiusMD,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.fiber_new_rounded,
                            color: AppColors.white, size: 10),
                        const SizedBox(width: 4),
                        Text(
                          'New',
                          style: AppTextStyles.captionSmall.copyWith(
                            color: AppColors.white,
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
                        color: AppColors.white,
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
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          memberid != 'N/A' && memberid.isNotEmpty
                              ? '$memberid $lastName'
                              : 'MS $userIdd $lastName',
                          style: AppTextStyles.labelMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$age yrs · ${heightName.isNotEmpty ? heightName.replaceAll(RegExp(r'\s*cm.*'), ' cm') : ''}',
                          style: AppTextStyles.captionSmall.copyWith(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (designation.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            designation,
                            style: AppTextStyles.captionSmall.copyWith(
                              fontSize: 10,
                              color: AppColors.textHint,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded,
                                size: 11, color: AppColors.textHint),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '$location${country.isNotEmpty ? ', $country' : ''}',
                                style: AppTextStyles.captionSmall.copyWith(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
