import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Auth/Screen/Edit/3edit.dart';
import '../Auth/Screen/Edit/Community.dart';
import '../Auth/Screen/Edit/Personal.dart';
import '../Auth/Screen/Edit/edit5.dart';
import '../Auth/Screen/Edit/edit6.dart';
import '../Auth/Screen/Edit/edit7.dart';
import '../Auth/Screen/Edit/edit8.dart';
import '../Auth/Screen/signupscreen2.dart';
import '../Auth/Screen/signupscreen5.dart';
import '../Auth/Screen/signupscreen6.dart';
import '../Auth/Screen/signupscreen9.dart';
import '../Auth/SuignupModel/signup_model.dart';
import '../DeleteAccount/deleteAccointScreen.dart';
import '../Models/masterdata.dart';
import '../Package/PackageScreen.dart';
import '../Startup/onboarding.dart';
import '../otherenew/blocked_users_screen.dart';

class MatrimonyProfilePage extends StatefulWidget {
  @override
  _MatrimonyProfilePageState createState() => _MatrimonyProfilePageState();
}

class _MatrimonyProfilePageState extends State<MatrimonyProfilePage> {
  Map<String, dynamic>? profileData;
  String usertype = '';
  bool isLoading = true;
  bool isProfileVerified = false;
  bool isShortlisted = false;
  String memberType = 'Free'; // Can be 'Free', 'Premium', 'Gold', 'Platinum'
  int _profilePictureTimestamp = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    fetchProfileData();
    loadMasterData();
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
        usertype = user.usertype;

        // docstatus = user.docStatus;
      });
    } catch (e) {
      print("Error: $e");
    }
  }

  Future<void> fetchProfileData() async {
    setState(() {
      isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    final userData = jsonDecode(userDataString!);
    final userId = int.tryParse(userData["id"].toString());

    try {
      final response = await http.get(
        Uri.parse('https://digitallami.com/Api2/myprofile.php?userid=${userId}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            profileData = data['data'];
            isProfileVerified = profileData?['personalDetail']?['isVerified'] == 1;
            memberType = _getMemberType(profileData?['personalDetail']?['usertype'] ?? 'free');
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load profile data'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getMemberType(String userType) {
    switch (userType.toLowerCase()) {
      case 'premium':
        return 'Premium';
      case 'gold':
        return 'Gold';
      case 'platinum':
        return 'Platinum';
      default:
        return 'Free';
    }
  }

  String _getFullImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return 'https://via.placeholder.com/150?text=No+Image';
    }

    String baseUrl;
    if (imagePath.startsWith('http')) {
      baseUrl = imagePath;
    } else {
      baseUrl = 'https://digitallami.com/Api2/$imagePath';
    }

    // Add timestamp to prevent caching
    return '$baseUrl?t=$_profilePictureTimestamp';
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. BLOCKED USERS (First option)
                ListTile(
                  leading: Icon(Icons.block, color: Colors.red),
                  title: Text(
                    'Blocked Users',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BlockedUsersScreen(),
                      ),
                    );
                  },
                ),
                Divider(),

                // 2. PRIVACY SETTINGS
                ListTile(
                  leading: Icon(Icons.settings, color: Color(0xFFD32F2F)),
                  title: Text(
                    'Privacy Settings',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(context);
                    _showPrivacySettings(context);
                  },
                ),
                Divider(),

                // 3. DELETE ACCOUNT
                ListTile(
                  leading: Icon(Icons.delete_outline, color: Colors.red),
                  title: Text(
                    'Delete Account',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DeleteAccountPage(),
                      ),
                    );
                  },
                ),
                Divider(),

                // 4. LOGOUT
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.orange),
                  title: Text(
                    'Logout',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(context);
                    _showLogoutConfirmation(context);
                  },
                ),
                SizedBox(height: 20),

                // 5. CANCEL BUTTON
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                ),
                SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPrivacySettings(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString == null) return;

    final userData = jsonDecode(userDataString);
    final int userId = int.parse(userData['id'].toString());

    // Step 1: Fetch current privacy from API
    String currentPrivacy = 'Private';
    try {
      final Uri getUrl = Uri.parse(
          'https://digitallami.com/Api3/get_privacy.php?userid=$userId');
      final response = await http.get(getUrl);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final privacy = data['data']['privacy']?.toString().toLowerCase();
          // Map API value to dropdown label
          switch (privacy) {
            case 'free':
              currentPrivacy = 'All Users';
              break;
            case 'paid':
              currentPrivacy = 'Premium Users Only';
              break;
            case 'verified':
              currentPrivacy = 'Verified Users Only';
              break;
            case 'private':
            default:
              currentPrivacy = 'private';
          }
        }
      }
    } catch (e) {
      print("Error fetching privacy: $e");
    }

    // Step 2: Show dialog with dropdown
    String selectedPrivacy = currentPrivacy;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(
              'Privacy Settings',
              style: TextStyle(color: Color(0xFFD32F2F)),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 20),
                  Text(
                    'Profile Picture Visibility',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  DropdownButtonFormField<String>(
                    value: selectedPrivacy,
                    items: [
                      'All Users',
                      'Premium Users Only',
                      'Verified Users Only',
                      'Private'
                    ].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setStateDialog(() {
                        selectedPrivacy = value ?? 'Private';
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFD32F2F), Color(0xFFEF5350)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextButton(
                  onPressed: () async {
                    Navigator.pop(context);

                    // Step 3: Map dropdown value back to API value
                    String privacyValue = 'private';
                    switch (selectedPrivacy) {
                      case 'All Users':
                        privacyValue = 'free';
                        break;
                      case 'Premium Users Only':
                        privacyValue = 'paid';
                        break;
                      case 'Verified Users Only':
                        privacyValue = 'verified';
                        break;
                      case 'Private':
                      default:
                        privacyValue = 'private';
                    }

                    // Step 4: Call update_privacy API
                    try {
                      final Uri updateUrl = Uri.parse(
                          'https://digitallami.com/Api3/privacy.php?userid=$userId&privacy=$privacyValue');
                      final response = await http.get(updateUrl);

                      if (response.statusCode == 200) {
                        final data = jsonDecode(response.body);
                        if (data['status'] == 'success') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Privacy settings updated successfully!'),
                              backgroundColor: Color(0xFFD32F2F),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed: ${data['message']}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      print("Error updating privacy: $e");
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error updating privacy'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: Text('Save Changes', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }





  void _showLogoutConfirmation(BuildContext context) {
    final model = context.read<SignupModel>();


    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Logout',
          style: TextStyle(color: Color(0xFFD32F2F)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.logout, color: Colors.orange, size: 60),
            SizedBox(height: 20),
            Text(
              'Are you sure you want to logout?',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await context.read<SignupModel>().logout();

              if (!mounted) return;

              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => OnboardingScreen()),
                    (route) => false,
              );
            },

            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFD32F2F), Color(0xFFEF5350)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _logout();
              },
              child: Text('Logout', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();

    // Clear all local data
    await prefs.clear();

    // Navigate to login screen
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Logged out successfully'),
        backgroundColor: Color(0xFFD32F2F),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = context.read<SignupModel>();

    if (isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD32F2F)),
          ),
        ),
      );
    }

    if (profileData == null) {
      final model = context.read<SignupModel>();

      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 50),
              SizedBox(height: 20),
              Text('No profile data found'),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: fetchProfileData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFD32F2F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final personalDetail = profileData!['personalDetail'];
    final familyDetail = profileData!['familyDetail'];
    final lifestyle = profileData!['lifestyle'];
    final partner = profileData!['partner'];

    return
      Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with Gradient
            _buildHeader(personalDetail),
if(usertype == 'free') ...[  _buildMemberTypeSection(),],
            // Member Type & Upgrade Section


            // Profile Info Section
            _buildProfileInfo(personalDetail),

            // About Me Section
            _buildAboutMe(personalDetail),

            // Personal Details Section
            _buildPersonalDetails(personalDetail),

            // Professional Details Section
            _buildProfessionalDetails(personalDetail),

            // Family Details Section
            _buildFamilyDetails(familyDetail),

            // Lifestyle Section
            _buildLifestyle(lifestyle),

            // Partner Preferences
            _buildPartnerPreferences(partner),

            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> personalDetail) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFD32F2F), // Dark Red
            Color(0xFFEF5350), // Light Red
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                Text(
                  'My Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.more_vert, color: Colors.white),
                  onPressed: () => _showMoreOptions(context),
                ),
              ],
            ),
          ),

          // Profile Image and Basic Info
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        image: DecorationImage(
                          image: NetworkImage(_getFullImageUrl(personalDetail['profile_picture'])),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    if (isProfileVerified)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.verified, color: Colors.white, size: 20),
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: InkWell(
                        onTap: () => _editProfilePicture(context),
                        child: Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Color(0xFFD32F2F),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(Icons.camera_alt, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${personalDetail['firstName'] ?? ''} ${personalDetail['lastName'] ?? ''}, ${_calculateAge(personalDetail['birthDate'])}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    if (isProfileVerified)
                      Icon(Icons.verified, color: Colors.white, size: 20),
                  ],
                ),
                Text(
                  '${personalDetail['designation'] ?? ''}, ${personalDetail['city'] ?? ''}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (personalDetail['religionName'] != null)
                      _buildInfoBadge(personalDetail['religionName'], Icons.person),
                    SizedBox(width: 15),
                    if (personalDetail['communityName'] != null)
                      _buildInfoBadge(personalDetail['communityName'], Icons.castle),
                    SizedBox(width: 15),
                    if (personalDetail['degree'] != null)
                      _buildInfoBadge(personalDetail['degree'], Icons.school),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _calculateAge(String? birthDate) {
    if (birthDate == null) return 0;
    try {
      DateTime birth = DateTime.parse(birthDate);
      DateTime now = DateTime.now();
      int age = now.year - birth.year;
      if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return 0;
    }
  }

  Widget _buildMemberTypeSection() {
    Color memberColor;
    String memberIcon;

    switch(memberType) {
      case 'Premium':
        memberColor = Colors.amber[700]!;
        memberIcon = '👑';
        break;
      case 'Gold':
        memberColor = Colors.amber;
        memberIcon = '⭐';
        break;
      case 'Platinum':
        memberColor = Colors.blueGrey;
        memberIcon = '💎';
        break;
      default:
        memberColor = Colors.grey;
        memberIcon = '👤';
    }

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: memberColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: memberColor.withOpacity(0.3)),
                ),
                child: Center(
                  child: Text(
                    memberIcon,
                    style: TextStyle(fontSize: 24),
                  ),
                ),
              ),
              SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$memberType Member',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _getMemberBenefits(memberType),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
         Container(
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFD32F2F), Color(0xFFEF5350)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextButton(
              onPressed: (){
                Navigator.push(context, MaterialPageRoute(builder: (context) => SubscriptionPage(),));
              },
              child: Text(
                'UPGRADE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),]


      ),
    );
  }

  String _getMemberBenefits(String type) {
    switch(type) {
      case 'Premium':
        return 'Unlimited Chats, Profile Boost, Verified Badge';
      case 'Gold':
        return 'Priority Listing, Advanced Search';
      case 'Platinum':
        return 'All Features + Personal Matchmaking';
      default:
        return 'Basic Features Only';
    }
  }

  Widget _buildInfoBadge(String text, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 14),
          SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo(Map<String, dynamic> personalDetail) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFD32F2F), size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Basic Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _editBasicInfo(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFD32F2F), Color(0xFFEF5350)],
                    ),
                  ),
                  child: Icon(Icons.edit, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Profile ID: ${personalDetail['memberid'] ?? 'N/A'}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFD32F2F), Color(0xFFEF5350)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  memberType,
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          _buildInfoRow('Height', personalDetail['height_name'] ?? 'N/A'),
          _buildInfoRow('Marital Status', personalDetail['maritalStatusName'] ?? 'N/A'),
          _buildInfoRow('Mother Tongue', personalDetail['motherTongue'] ?? 'N/A'),
          _buildInfoRow('Location', '${personalDetail['city'] ?? ''}, ${personalDetail['country'] ?? ''}'),
          _buildInfoRow('Contact Privacy', 'Hidden'),
          _buildInfoRow('Profile Created', '15 Jan 2024'),
          _buildInfoRow('Last Active', 'Today, 10:30 AM'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutMe(Map<String, dynamic> personalDetail) {
    return _buildSection(
      title: 'About Me',
      icon: Icons.person_outline,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            personalDetail['aboutMe'] ?? 'No information provided',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
      onEdit: () => _editAboutMe(context, personalDetail['aboutMe'] ?? ''),
    );
  }

  Widget _buildPersonalDetails(Map<String, dynamic> personalDetail) {
    return _buildSection(
      title: 'Personal Details',
      icon: Icons.favorite_border,
      content: Column(
        children: [
          _buildDetailRow('Date of Birth', _formatDate(personalDetail['birthDate'])),
          _buildDetailRow('Age', '${_calculateAge(personalDetail['birthDate'])} Years'),
          _buildDetailRow('Gender', 'Male'),
          _buildDetailRow('Religion', personalDetail['religionName'] ?? 'N/A'),
          _buildDetailRow('Caste', personalDetail['communityName'] ?? 'N/A'),
          _buildDetailRow('Sub Caste', personalDetail['subCommunityName'] ?? 'N/A'),
          _buildDetailRow('Gotra', 'Kashyapa'),
          _buildDetailRow('Manglik', personalDetail['manglik'] ?? 'N/A'),
          _buildDetailRow('Diet', 'Vegetarian'),
          _buildDetailRow('Disability', personalDetail['Disability'] ?? 'None'),
          _buildDetailRow('Blood Group', personalDetail['bloodGroup'] ?? 'N/A'),
          _buildDetailRow('Birth Time', personalDetail['birthtime'] ?? 'N/A'),
          _buildDetailRow('Birth Place', personalDetail['birthcity'] ?? 'N/A'),
        ],
      ),
      onEdit: () => _editPersonalDetails(),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      DateTime date = DateTime.parse(dateString);
      return '${date.day} ${_getMonthName(date.month)} ${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  Widget _buildProfessionalDetails(Map<String, dynamic> personalDetail) {
    return _buildSection(
      title: 'Professional Details',
      icon: Icons.work_outline,
      content: Column(
        children: [
          _buildDetailRow('Education', personalDetail['degree'] ?? 'N/A'),
          _buildDetailRow('College', 'IIT Delhi'),
          _buildDetailRow('Occupation', personalDetail['designation'] ?? 'N/A'),
          _buildDetailRow('Employer', personalDetail['companyname'] ?? 'N/A'),
          _buildDetailRow('Annual Income', personalDetail['annualincome'] ?? 'N/A'),
          _buildDetailRow('Work Location', personalDetail['city'] ?? 'N/A'),
          _buildDetailRow('Job Sector', 'IT/Software'),
          _buildDetailRow('Experience', '5 Years'),
        ],
      ),
      onEdit: () => _editProfessionalDetails(),
    );
  }

  Widget _buildFamilyDetails(Map<String, dynamic> familyDetail) {
    return _buildSection(
      title: 'Family Details',
      icon: Icons.family_restroom,
      content: Column(
        children: [
          _buildDetailRow('Family Type', familyDetail['familytype'] ?? 'N/A'),
          _buildDetailRow('Family Status', familyDetail['familybackground'] ?? 'N/A'),
          _buildDetailRow('Father\'s Occupation', familyDetail['fatheroccupation'] ?? 'N/A'),
          _buildDetailRow('Mother\'s Occupation', familyDetail['motheroccupation'] ?? 'N/A'),
          _buildDetailRow('No. of Brothers', '1 (Married)'),
          _buildDetailRow('No. of Sisters', '1 (Unmarried)'),
          _buildDetailRow('Native Place', familyDetail['familyorigin'] ?? 'N/A'),
          _buildDetailRow('Family Values', 'Moderate'),
          _buildDetailRow('Family Based In', 'Janakpur'),
        ],
      ),
      onEdit: () => _editFamilyDetails(),
    );
  }

  void _editProfilePicture(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString == null) return;

    final userData = jsonDecode(userDataString);
    final userId = int.parse(userData['id'].toString());

    final ImagePicker picker = ImagePicker();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Edit Profile Picture',
          style: TextStyle(color: Color(0xFFD32F2F)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Upload a new profile picture'),
            const SizedBox(height: 20),

            /// Gallery
            ElevatedButton(
              onPressed: () async {
                final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                if (image != null) {
                  Navigator.pop(context);
                  await _uploadProfilePictureBackground(
                    context,
                    File(image.path),
                    userId,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFD32F2F),
              ),
              child: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
            ),

            const SizedBox(height: 10),

            /// Camera
            ElevatedButton(
              onPressed: () async {
                final XFile? image = await picker.pickImage(source: ImageSource.camera);
                if (image != null) {
                  Navigator.pop(context);
                  await _uploadProfilePictureBackground(
                    context,
                    File(image.path),
                    userId,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFD32F2F),
              ),
              child: const Text('Take a Photo', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadProfilePictureBackground(
      BuildContext context, File imageFile, int userId) async {
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(width: 10),
              Text('Uploading image...'),
            ],
          ),
          backgroundColor: Color(0xFFD32F2F),
          duration: Duration(seconds: 5),
        ),
      );

      final uri = Uri.parse('https://digitallami.com/Api2/profile_picture.php');

      final request = http.MultipartRequest('POST', uri)
        ..fields['userid'] = userId.toString()
        ..files.add(
          await http.MultipartFile.fromPath(
            'profile_picture',
            imageFile.path,
          ),
        );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        // Save new image path locally
        final prefs = await SharedPreferences.getInstance();
        final userData = jsonDecode(prefs.getString('user_data')!);
        userData['profile_picture'] = 'uploads/profile_pictures/profilepicture_$userId.jpg';
        prefs.setString('user_data', jsonEncode(userData));

        // Update timestamp to refresh image
        setState(() {
          _profilePictureTimestamp = DateTime.now().millisecondsSinceEpoch;
        });

        // Refresh profile data
        await fetchProfileData();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully'),
            backgroundColor: Color(0xFFD32F2F),
          ),
        );
      } else {
        throw responseBody;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _editBasicInfo() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => PersonalDetailsPagee()));
  }

  Future<void> _editAboutMe(BuildContext context, String currentAboutMe) async {
    final TextEditingController _controller = TextEditingController(text: currentAboutMe);
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    final userData = jsonDecode(userDataString!);
    final userId = int.tryParse(userData["id"].toString());

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          bool isSaving = false;

          return AlertDialog(
            title: Text(
              "Edit About Me",
              style: TextStyle(color: Color(0xFFD32F2F)),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Update your about me information"),
                SizedBox(height: 20),
                TextFormField(
                  controller: _controller,
                  decoration: InputDecoration(
                    labelText: "About Me",
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFD32F2F)),
                    ),
                  ),
                  maxLines: 5,
                  maxLength: 500,
                ),
                if (isSaving)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: CircularProgressIndicator(color: Color(0xFFD32F2F)),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFD32F2F), Color(0xFFEF5350)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextButton(
                  onPressed: isSaving ? null : () async {
                    if (_controller.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please enter some text'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    setStateDialog(() {
                      isSaving = true;
                    });

                    try {
                      var response = await http.post(
                        Uri.parse("https://digitallami.com/Api2/aboutme.php"),
                        body: {
                          "userid": userId.toString(),
                          "aboutMe": _controller.text.trim(),
                        },
                      );

                      if (response.statusCode == 200) {
                        Navigator.pop(context);

                        // Update local state immediately
                        setState(() {
                          if (profileData != null && profileData!['personalDetail'] != null) {
                            profileData!['personalDetail']['aboutMe'] = _controller.text.trim();
                          }
                        });

                        // Also refresh from server to ensure consistency
                        await fetchProfileData();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('About Me updated successfully!'),
                            backgroundColor: Color(0xFFD32F2F),
                          ),
                        );
                      } else {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to update About Me'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } catch (e) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _editPersonalDetails() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => PersonalDetailsPagee()));
  }

  void _editProfessionalDetails() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => EducationCareerPagee()));
  }

  void _editFamilyDetails() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => FamilyDetailsPagee()));
  }

  void _editLifestyle() {
Navigator.push(context, MaterialPageRoute(builder: (context) => LifestylePagee(),));  }

  void _editPartnerPreferences() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => PartnerPreferencesPagee()));
  }

  void _upgradeMembership() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Upgrade Membership',
          style: TextStyle(color: Color(0xFFD32F2F)),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMembershipOption('Free', '👤', 'Basic Features', 'Rs0/month', false),
              SizedBox(height: 10),
              _buildMembershipOption('Premium', '👑', 'Unlimited Chats + Profile Boost', 'Rs999/month', true),
              SizedBox(height: 10),
              _buildMembershipOption('Gold', '⭐', 'Priority Listing + Advanced Search', 'Rs1,999/month', false),
              SizedBox(height: 10),
              _buildMembershipOption('Platinum', '💎', 'All Features + Personal Matchmaking', 'rs2,999/month', false),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildMembershipOption(String name, String icon, String features, String price, bool isPopular) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: isPopular ? Color(0xFFD32F2F) : Colors.grey[300]!,
          width: isPopular ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(icon, style: TextStyle(fontSize: 24)),
                  SizedBox(width: 10),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (isPopular)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFFD32F2F),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'POPULAR',
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            features,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          SizedBox(height: 8),
          Text(
            price,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFFD32F2F),
            ),
          ),
          SizedBox(height: 8),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: isPopular ? LinearGradient(
                colors: [Color(0xFFD32F2F), Color(0xFFEF5350)],
              ) : null,
              color: isPopular ? null : Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextButton(
              onPressed: () {
                setState(() {
                  memberType = name;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Upgraded to $name Membership!'),
                    backgroundColor: Color(0xFFD32F2F),
                  ),
                );
              },
              child: Text(
                memberType == name ? 'CURRENT PLAN' : 'UPGRADE',
                style: TextStyle(
                  color: isPopular ? Colors.white : Colors.grey[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String text, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(String title, String description) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: TextStyle(color: Color(0xFFD32F2F)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(description),
            SizedBox(height: 20),
            TextFormField(
              decoration: InputDecoration(
                labelText: title ?? "Enter Your details",
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFD32F2F)),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFD32F2F), Color(0xFFEF5350)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$title updated successfully!'),
                    backgroundColor: Color(0xFFD32F2F),
                  ),
                );
              },
              child: Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLifestyle(Map<String, dynamic> lifestyle) {
    List<Widget> habitChips = [];

    if (lifestyle['smoke'] == 'Yes') {
      habitChips.add(_buildChip('Smoker (${lifestyle['smoketype']})', Icons.smoking_rooms, Colors.orange));
    } else {
      habitChips.add(_buildChip('Non-Smoker', Icons.smoke_free, Colors.green));
    }

    if (lifestyle['drinks'] == 'Yes') {
      habitChips.add(_buildChip('Drinker (${lifestyle['drinktype']})', Icons.local_bar, Colors.orange));
    } else {
      habitChips.add(_buildChip('Non-Drinker', Icons.no_drinks, Colors.green));
    }

    habitChips.add(_buildChip(lifestyle['diet'] ?? 'Vegetarian', Icons.eco, Colors.green));

    return _buildSection(
      title: 'Lifestyle',
      icon: Icons.self_improvement,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Habits:',
            style: TextStyle(
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: habitChips,
          ),
        ],
      ),
      onEdit: () => _editLifestyle(),
    );
  }

  Widget _buildPartnerPreferences(Map<String, dynamic> partner) {
    return _buildSection(
      title: 'Partner Preferences',
      icon: Icons.search,
      content: Column(
        children: [
          _buildPreferenceRow('Age', '${partner['minage']}-${partner['maxage']} Years'),
          _buildPreferenceRow('Marital Status', partner['maritalstatus'] ?? 'N/A'),
          _buildPreferenceRow('Religion', partner['religion'] ?? 'N/A'),
          _buildPreferenceRow('Caste', partner['caste'] ?? 'N/A'),
          _buildPreferenceRow('Education', partner['qualification'] ?? 'N/A'),
          _buildPreferenceRow('Occupation', partner['proffession'] ?? 'N/A'),
          _buildPreferenceRow('Income', partner['annualincome'] ?? 'N/A'),
          _buildPreferenceRow('Location', '${partner['city']}, ${partner['country']}'),
          _buildPreferenceRow('Diet', partner['diet'] ?? 'N/A'),
          _buildPreferenceRow('Family Values', partner['familytype'] ?? 'N/A'),
          _buildPreferenceRow('Other Expectations', partner['otherexpectation'] ?? 'N/A'),
        ],
      ),
      onEdit: () => _editPartnerPreferences(),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget content,
    required VoidCallback onEdit,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: Color(0xFFD32F2F), size: 20),
                  SizedBox(width: 10),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFD32F2F), Color(0xFFEF5350)],
                    ),
                  ),
                  child: Icon(Icons.edit, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          content,
        ],
      ),
    );
  }

  Widget _buildPreferenceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Color(0xFFD32F2F),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}