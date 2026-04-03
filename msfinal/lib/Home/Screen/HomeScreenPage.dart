import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:ms2026/Home/Screen/premiummember.dart';
import 'package:ms2026/Home/Screen/profilecard.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Auth/Screen/signupscreen10.dart';
import '../../Auth/SuignupModel/signup_model.dart';
import '../../Chat/ChatlistScreen.dart';
import '../../Models/masterdata.dart';
import 'package:http/http.dart' as http;

import '../../Notification/notificationscreen.dart';
import '../../Package/PackageScreen.dart';
import '../../Search/SearchPage.dart';
import '../../main.dart';
import '../../online/onlineservice.dart';
import '../../otherprofile/otherprofileview.dart';
import '../../profile/myprofile.dart';
import '../../purposal/purposalScreen.dart';
import '../../pushnotification/pushservice.dart';
import '../../service/Service_chat.dart';
import 'machprofilescreen.dart';


class MatrimonyHomeScreen extends StatefulWidget {
  const MatrimonyHomeScreen({super.key});

  @override
  State<MatrimonyHomeScreen> createState() => _MatrimonyHomeScreenState();
}

class _MatrimonyHomeScreenState extends State<MatrimonyHomeScreen> {
  int _currentIndex = 0;

  List<dynamic> _matchedProfilesApi = [];
  bool _isLoading = true;
  String _errorMessage = '';
  List<Map<String, dynamic>> _premiumMembers = [];
  List<Map<String, dynamic>> _otherServices = [];
  bool _loading = true;

late int userid;


  bool _isCheckingStatus = false;


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
      print("Error checking document status: $e");
      // Show error snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to check document status: $e"),
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

  Future<void> fetchMatchedProfiles() async {
    try {
      setState(() {
        _isLoading = true;
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
          setState(() {
            _matchedProfilesApi = result['matched_users'] ?? [];
            _isLoading = false;
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
      });
      print('Error fetching matched profiles: $e');
    }
  }
  Future<void> sendRequest(int receiverId, String requestType) async {
    try {
      // Get sender ID from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      if (userDataString == null) {
        throw Exception('User data not found');
      }

      final userData = jsonDecode(userDataString);
      final senderId = userData["id"];

      // Prepare the payload
      final payload = {
        "sender_id": senderId,
        "receiver_id": receiverId,
        "request_type": requestType,
      };

      // Make API call
      final url = Uri.parse('https://digitallami.com/Api2/send_request.php');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          bool success = await NotificationService.sendRequestNotification(
            recipientUserId: receiverId.toString(),       // ID of the user receiving the request
            senderName: "MS:${senderId} ${userData['lastName']}",       // Name of the sender
            senderId: senderId.toString(),              // ID of the sender
          );

          if(success) {
            print("Request notification sent!");
          } else {
            print("Failed to send notification.");
          }
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Request sent successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception(result['message'] ?? 'Failed to send request');
        }
      } else {
        throw Exception('Failed to send request: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      print('Error sending request: $e');
    }
  }

  Future<void> _fetchPremiumMembers() async {
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

          setState(() {
            _premiumMembers = members.map<Map<String, dynamic>>((member) {
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
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
        debugPrint('Error fetching premium members: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
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
    try {
      final url = Uri.parse('https://digitallami.com/Api2/services_api.php');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final List services = data['data'];

          setState(() {
            _otherServices = services.map<Map<String, dynamic>>((service) {
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
            _loading = false;
          });
        } else {
          setState(() => _loading = false);
        }
      } else {
        setState(() => _loading = false);
        debugPrint('Error fetching services: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _loading = false);
      debugPrint('Exception: $e');
    }}






String usertye = '';
  String userimage = '';
  var  pageno;
  var docstatus = 'not_uploaded';
  String name = '';

 // int _currentIndex = 0;

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
       // docstatus = user.docStatus;
      });
    } catch (e) {
      print("Error: $e");
    }
  }

@override
  void initState() {
  loadMasterData();
    // TODO: implement initState
    super.initState();
  fetchMatchedProfiles();
  _checkDocumentStatus();
  _fetchPremiumMembers();
  _fetchOtherServices();
  OnlineStatusService().start();

// Add this line

}


  @override
  Widget build(BuildContext context) {




    return Consumer<SignupModel>(
        builder: (context, model, child) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,

        iconTheme: IconThemeData(
          color: Colors.transparent
        ),
        backgroundColor: Colors.white,
       // elevation: 0,
       // leading:


        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
          Container(
            padding: EdgeInsets.all(1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(35),
                border: Border.all(
                  width: 1.0,

              color: Colors.red,

            )),
            child:
            CircleAvatar(
              radius: 25,
              backgroundImage: NetworkImage("https://digitallami.com/Api2/${userimage}"),
            )

          ),
            SizedBox(width: 10,),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${name ?? 'null'}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
                Text(
                  "${usertye}",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if(usertye =='free') ...[ Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFffffff),
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                      color: Colors.red
                  ),
                  borderRadius: BorderRadius.circular(44),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: const Size(70, 32),
              ),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => SubscriptionPage(),));
              },
              child: Text(
                'Upgrade',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),],

          SizedBox(width: 5,),
          Container(
           // padding: EdgeInsets.all(5),
            height: 36,
            width: 36,
            decoration: BoxDecoration(
               borderRadius: BorderRadius.circular(35),
              border: Border.all(color: Colors.red, width: 1)
            ),
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.search, color: Colors.red, size: 20,),
                onPressed: () {
                  if(docstatus == 'approved')
                  Navigator.push(context, MaterialPageRoute(builder: (context) => SearchPage(),));
                  if(docstatus == 'not_uploaded' )
                    Navigator.push(context, MaterialPageRoute(builder: (context) => IDVerificationScreen(),));
                  if(docstatus == 'pending' )
                    Navigator.push(context, MaterialPageRoute(builder: (context) => IDVerificationScreen(),));
                  if(docstatus == 'rejected' )
                    Navigator.push(context, MaterialPageRoute(builder: (context) => IDVerificationScreen(),));
                },
              ),
            ),
          ),
          SizedBox(width: 8,),
          Container(
            margin: EdgeInsets.only(right: 20),
            // padding: EdgeInsets.all(5),
            height: 36,
            width: 36,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(35),
                border: Border.all(color: Colors.red, width: 1)
            ),
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.notifications, color: Colors.red, size: 20,),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder:   (context) => MatrimonyNotificationPage(),));
                },
              ),
            ),
          ),
        ],
      ),
      body:
      SingleChildScrollView(
       // padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              if(pageno != 10) ...[ Container(
                  margin: EdgeInsets.only(left: 10, right: 10),
                  child: _buildProfileCompletenessCard()),],
              // Profile Completeness Card

              const SizedBox(height: 10),
              ImageBannerSlider(),
              // First Banner
          SizedBox(height: 10,),
            //  const SizedBox(height: 20),
              Container(
                margin: EdgeInsets.all(10),

                height: MediaQuery.of(context).size.height * 0.6, // or fixed height like 600
                child:ProfileSwipeUI(
                  userId: userid, // Replace with actual user ID
                  matchApiUrl: 'https://digitallami.com/Api2/match.php', // Your API endpoint
                  baseUrl: 'https://digitallami.com/Api2', sendRequestApiUrl: 'https://digitallami.com/Api2/send_request.php', likeApiUrl: 'https://digitallami.com/Api2/like_action.php', // Base URL for images
                ),

              ),
              // Large Featured Profile with Action Buttons
            //  _buildLargeFeaturedProfileWithActions(),
             // const SizedBox(height: 20),
              // Recently Viewed Section
            //  const SizedBox(height: 12),
          //recently viewd
              const SizedBox(height: 20),
              // Premium Members Section
              Container(
                margin: EdgeInsets.all(10),
                  child: GestureDetector(
                    onTap: (){
                      Navigator.push(context, MaterialPageRoute(builder: (context) => PaidUsersListPage(userId: userid,)));
                    }
                      ,
                      child: _buildSectionHeader('Premium Members', showSeeAll: true))),
              const SizedBox(height: 12),
              Container(
                margin: EdgeInsets.all(10),
                  child: _buildPremiumMembers()),
           //   const SizedBox(height: 20),
              // Second Banner
              ImageBannerSlider(),
              const SizedBox(height: 20),
              // Matched Profiles Section
              Container(
                margin: EdgeInsets.all(10),
                  child: GestureDetector(
                    onTap: (){
                      Navigator.push(context, MaterialPageRoute(builder: (context) => MatchedProfilesPagee(currentUserId: userid, docstatus: docstatus,),));
                    },
                      child: _buildSectionHeader('Matched Profiles', showSeeAll: true))),
              const SizedBox(height: 12),

      Container(
                margin: EdgeInsets.all(10),
                  child: _buildMatchedProfilesFromApi()),
              const SizedBox(height: 20),
              // Other Services Section
              Container(
                margin: EdgeInsets.all(10),
                  child: _buildSectionHeader('Other Services', showSeeAll: false)),
              const SizedBox(height: 12),
              Container(
                margin:  EdgeInsets.all(10),
                  child: _buildOtherServices()),

              // Success Stories Section

              const SizedBox(height: 12),

              const SizedBox(height: 30),
            ],
          ),
        ),


    );});}


  Widget _buildProfileCompletenessCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE64B37),
            Color(0xFFE62255),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
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
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Profile Completeness Score',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: 0.90,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(width: 8),
                     Text(
                      '${pageno}0%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: (){
              Navigator.push(context, MaterialPageRoute(builder: (context) => IDVerificationScreen(),));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(
                  color: Color(0xFFE64B37),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchedProfilesFromApi() {
    if (_isLoading) {
      return SizedBox(
        height: 276,
        child: Center(
          child: CircularProgressIndicator(color: Colors.red),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return SizedBox(
        height: 276,
        child: Center(
          child: Text(
            'Error: $_errorMessage',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (_matchedProfilesApi.isEmpty) {
      return SizedBox(
        height: 276,
        child: Center(
          child: Text(
            'No matched profiles found',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return SizedBox(
      height: 276,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _matchedProfilesApi.length,
        padding: const EdgeInsets.only(left: 12),
        itemBuilder: (context, index) {
          final profile = _matchedProfilesApi[index];

          // Extract data from API response
          final userId = profile['userid']?.toString() ?? 'null';
          final lastName = profile['lastName'] ?? '';
          // Updated: Show id + lastName
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

          // Construct image URL
          final baseImageUrl = 'https://digitallami.com/Api2/';
          final profilePicture = profile['profile_picture'] ?? '';
          final imageUrl = profilePicture.isNotEmpty
              ? baseImageUrl + profilePicture
              : 'https://via.placeholder.com/200x140?text=No+Image';

          // Blur control variable
          final isBlurred = true; // Change this to control blur

          return GestureDetector(
            onTap: () {


              // Navigate to OtherProfileScreen when blur is disabled
              final profileUserId = profile['userid'];
              if (profileUserId != null) {
                if(docstatus == 'approved')
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileLoader(userId: profileUserId.toString(), myId: userId.toString(),),
                    ),
                  );
                if(docstatus == 'not_uploaded')
                  Navigator.push(context, MaterialPageRoute(builder: (context) => IDVerificationScreen(),));
                if(docstatus == 'pending')
                  Navigator.push(context, MaterialPageRoute(builder: (context) => IDVerificationScreen(),));
                if(docstatus == 'rejected')
                  Navigator.push(context, MaterialPageRoute(builder: (context) => IDVerificationScreen(),));
              }
            },
            child: Container(
              padding: EdgeInsets.all(5),
              width: 200,
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.red),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 🔹 Top Image with Name Overlay
                  Stack(
                    children: [
                      SizedBox(
                        height: 140,
                        child: Stack(
                          children: [
                            Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 140,
                                  color: Colors.grey[200],
                                  child: Center(
                                    child: Icon(Icons.person, color: Colors.grey, size: 50),
                                  ),
                                );
                              },
                            ),
                            // Apply blur overlay if enabled
                            if (isBlurred)
                              Container(
                                width: double.infinity,
                                height: 140,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                ),
                                child: BackdropFilter(
                                  filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                  child: Container(
                                    color: Colors.black.withOpacity(0.1),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          color: Colors.black.withOpacity(0.55),
                          child: Text(
                            "Ms $name",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (profile['isVerified'] == 1)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.verified, size: 16, color: Colors.white),
                          ),
                        ),
                    ],
                  ),

                  // 🔹 Information Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Age $age yrs, $height',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),

                        Row(
                          children: [
                            Icon(Icons.work_outline, size: 13, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
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

                        const SizedBox(height: 4),

                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 13, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
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

                        const SizedBox(height: 10),

                        // Match percentage indicator
                        if (profile['matchPercent'] != null)
                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value: profile['matchPercent'] / 100,
                                      backgroundColor: Colors.grey[300],
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        profile['matchPercent'] >= 80
                                            ? Colors.green
                                            : profile['matchPercent'] >= 50
                                            ? Colors.orange
                                            : Colors.red,
                                      ),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '${profile['matchPercent']}%',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                            ],
                          ),

                        // 🔹 Send Request Button

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
  void showRequestTypeDialog(int receiverId, String receiverName) {
    String selectedRequestType = 'Profile'; // Default selection

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'Send Request to $receiverName',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Select Request Type:',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: 20),

                  // Request Type Options
                  _buildRequestTypeOption(
                    'Profile',
                    'View Full Profile Details',
                    Icons.person_outline,
                    selectedRequestType == 'Profile',
                        () => setState(() => selectedRequestType = 'Profile'),
                  ),
                  SizedBox(height: 12),

                  _buildRequestTypeOption(
                    'Photo',
                    'Request Profile Photos',
                    Icons.photo_library_outlined,
                    selectedRequestType == 'Photo',
                        () => setState(() => selectedRequestType = 'Photo'),
                  ),
                  SizedBox(height: 12),

                  _buildRequestTypeOption(
                    'Chat',
                    'Start a Conversation',
                    Icons.chat_bubble_outline,
                    selectedRequestType == 'Chat',
                        () => setState(() => selectedRequestType = 'Chat'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context); // Close dialog
                    await sendRequest(receiverId, selectedRequestType);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFEA4935),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Send Request',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRequestTypeOption(
      String title,
      String subtitle,
      IconData icon,
      bool isSelected,
      VoidCallback onTap,
      ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFFEA4935).withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Color(0xFFEA4935) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? Color(0xFFEA4935) : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Color(0xFFEA4935) : Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Color(0xFFEA4935),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }





  Widget _buildPremiumMembers() {
    return SizedBox(
      height: 300,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _premiumMembers.length,
        itemBuilder: (context, index) {
          final profile = _premiumMembers[index];

          final firstName = profile['firstName'] ?? '';
          final lastName = profile['lastName'] ?? '';
          final userIdd = profile['id']; // Get id instead of memberid
          // Updated: Show id + lastName


          final age = profile['age'] ?? '';
          final location = profile['city'] ?? '';
          final imageUrl = profile['image'] ?? '';
          final isVerified = profile['isVerified']?.toString() == '1';

          // Check if blur should be applied (you can set this as a variable)
          final isBlurred = true; // Change this to false to disable blur

          return Container(
            width: 210,
            margin: EdgeInsets.only(right: index == _premiumMembers.length - 1 ? 0 : 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE64B37), width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        topRight: Radius.circular(14),
                      ),
                      child: Stack(
                        children: [
                          Image.network(
                            imageUrl,
                            width: double.infinity,
                            height: 180,
                            fit: BoxFit.cover,
                          ),
                          // Apply blur overlay if enabled
                          if (isBlurred)
                            Container(
                              width: double.infinity,
                              height: 180,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                              ),
                              child: BackdropFilter(
                                filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                child: Container(
                                  color: Colors.black.withOpacity(0.1),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE64B37), width: 1.6),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.favorite_border,
                            color: const Color(0xFFE64B37),
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "MS $userIdd ${lastName}",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(width: 6),
                                if (isVerified)
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.verified,
                                      color: Color(0xFFE64B37),
                                      size: 15,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$age Yrs, $location',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                        Container(
                          width: double.infinity,
                          height: 35,
                          margin: const EdgeInsets.only(top: 6),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFFEA4935), Color(0xFFEB3D82)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                              ),
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                  backgroundColor: Colors.transparent,
                                ),
                                onPressed: () async {
                                  final prefs = await SharedPreferences.getInstance();
                                  final userDataString = prefs.getString('user_data');
                                  final userData = jsonDecode(userDataString!);
                                  final userId = int.tryParse(userData["id"].toString());


                                  if(docstatus == 'approved')
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProfileLoader(userId: userIdd.toString(), myId: userId.toString(),),
                                      ),
                                    );
                                  if(docstatus == 'not_uploaded')
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => IDVerificationScreen(),));
                                  if(docstatus == 'pending')
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => IDVerificationScreen(),));
                                  if(docstatus == 'rejected')
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => IDVerificationScreen(),));
                                },

                                child: const Center(
                                  child: Text(
                                    'View Profile',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }

// Helper method to show blur popup

// Helper method to show blur popup





  Widget _buildOtherServices() {
    return Column(
      children: _otherServices.map((service) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(0),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.red),
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------------- LEFT IMAGE ----------------
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  bottomLeft: Radius.circular(22),
                ),
                child: Stack(
                  children: [
                    Image.network(
                      service['image'],
                      width: 130,
                      height: 185,
                      fit: BoxFit.cover,
                    ),

                    // Category Tag
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE64B37),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Text(
                          service['category'], // Lawyer, Jotis etc.
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ---------------- RIGHT SIDE CONTENT ----------------
              Expanded(
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // NAME + HEART
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              service['name'],
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Color(0xFFE64B37), width: 1.8),
                            ),
                            child: const Icon(
                              Icons.favorite_border,
                              color: Color(0xFFE64B37),
                              size: 18,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      Text(
                        "Age ${service['age']}, ${service['location']}",
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade700,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        "Experience: ${service['experience']}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // START CONVERSATION button
                      InkWell(
                        onTap: (){
                          Navigator.push(context, MaterialPageRoute(builder: (context) => ServiceChatPage(senderId: userid.toString(), receiverId: service['id'].toString(), name: service['name'], exp: service['experience'], cat: service['category']),));
                        },
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Color(0xFFE64B37),
                              width: 1.8,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.chat_bubble_outline,
                                  color: Color(0xFFE64B37), size: 20),
                              SizedBox(width: 8),
                              Text(
                                "Start Conversation",
                                style: TextStyle(
                                  color: Color(0xFFE64B37),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              )
            ],
          ),
        );
      }).toList(),
    );
  }



  Widget _buildSectionHeader(String title, {bool showSeeAll = true}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            // Blue dotted vertical line
            Container(
              width: 2,
              height: 35,
              decoration: const BoxDecoration(

              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Flex(
                    direction: Axis.vertical,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      8,
                          (index) => Container(
                        width: 0,
                        height: 0,
                        color: index.isOdd ? Colors.transparent : Colors.blue,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(width: 8),

            // Title text with gradient
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFE53935), Color(0xFFD81B60)],
                  ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white, // Needed for ShaderMask
                    ),
                  ),
                ),

                const SizedBox(height: 2),

                // Red underline
                Container(
                  width: 120,
                  height: 4,
                  color: const Color(0xFFE53935),
                ),
              ],
            ),
          ],
        ),

        if (showSeeAll)
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFE53935), Color(0xFFD81B60)],
            ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
            child: const Text(
              "see all >",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white, // required for shader mask
              ),
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

