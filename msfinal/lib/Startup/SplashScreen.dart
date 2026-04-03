import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Auth/Screen/signupscreen10.dart';
import '../Auth/Screen/signupscreen2.dart';
import '../Auth/Screen/signupscreen3.dart';
import '../Auth/Screen/signupscreen4.dart';
import '../Auth/Screen/signupscreen5.dart';
import '../Auth/Screen/signupscreen6.dart';
import '../Auth/Screen/signupscreen7.dart';
import '../Auth/Screen/signupscreen8.dart';
import '../Auth/Screen/signupscreen9.dart';
import '../Auth/SuignupModel/signup_model.dart';
import '../Chat/ChatlistScreen.dart';
import '../Home/Screen/HomeScreenPage.dart';
import '../ReUsable/Navbar.dart';
import '../online/onlineservice.dart';
import '../profile/myprofile.dart';
import '../purposal/purposalScreen.dart';
import '../pushnotification/pushservice.dart';
import '../service/pagenocheck.dart';
import '../webrtc/webrtc.dart';
import 'MainControllere.dart';
import 'onboarding.dart';

import 'dart:convert';
import 'dart:io' show Platform;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Map<String, dynamic>? _versionData;
  bool _isCheckingVersion = true;
  String? _errorMessage;

  // Current app versions - Update these with your actual current versions
  final String currentAndroidVersion = '24.0.0'; // Your current Android version
  final String currentIOSVersion = '1.0.0';     // Your current iOS version

  @override
  void initState() {
    super.initState();
    _checkAppVersion();
  }

  Future<void> _checkAppVersion() async {
    try {
      final response = await http.get(
        Uri.parse('https://digitallami.com/app.php'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _versionData = data['data'];
            _isCheckingVersion = false;
          });

          // Check if update is needed
          await _checkUpdateNeeded();
        } else {
          setState(() {
            _errorMessage = 'Invalid response from server';
            _isCheckingVersion = false;
          });
          _proceedWithNavigation();
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load version info';
          _isCheckingVersion = false;
        });
        _proceedWithNavigation();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
        _isCheckingVersion = false;
      });
      _proceedWithNavigation();
    }
  }

  Future<void> _checkUpdateNeeded() async {
    if (_versionData == null) {
      _proceedWithNavigation();
      return;
    }

    final String serverAndroidVersion = _versionData!['android_version'];
    final String serverIOSVersion = _versionData!['ios_version'];
    final bool forceUpdate = _versionData!['force_update'];
    final String description = _versionData!['description'];
    final String appLink = _versionData!['app_link'];

    bool updateNeeded = false;
    String? platformVersion;

    if (Platform.isAndroid) {
      updateNeeded = _compareVersions(currentAndroidVersion, serverAndroidVersion);
      platformVersion = serverAndroidVersion;
    } else if (Platform.isIOS) {
      updateNeeded = _compareVersions(currentIOSVersion, serverIOSVersion);
      platformVersion = serverIOSVersion;
    }

    if (updateNeeded) {
      _showUpdateDialog(forceUpdate, description, appLink, platformVersion!);
    } else {
      _proceedWithNavigation();
    }
  }

  bool _compareVersions(String current, String server) {
    // Simple version comparison (can be enhanced for more complex versioning)
    List<int> currentParts = current.split('.').map(int.parse).toList();
    List<int> serverParts = server.split('.').map(int.parse).toList();

    for (int i = 0; i < currentParts.length; i++) {
      if (i >= serverParts.length) return false;
      if (serverParts[i] > currentParts[i]) return true;
      if (serverParts[i] < currentParts[i]) return false;
    }
    return serverParts.length > currentParts.length;
  }

  void _showUpdateDialog(bool forceUpdate, String description, String appLink, String newVersion) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate, // Can't dismiss if force update
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => !forceUpdate, // Prevent back button if force update
          child: AlertDialog(
            title: Text(
              forceUpdate ? 'Update Required' : 'New Update Available',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Version $newVersion is now available',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                Text(description),
                if (forceUpdate)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'You must update to continue using the app.',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
              ],
            ),
            actions: [
              if (!forceUpdate)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _proceedWithNavigation();
                  },
                  child: const Text('Later'),
                ),
              TextButton(
                onPressed: () async {
                  final Uri url = Uri.parse(appLink);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                    if (forceUpdate) {
                      // If force update, close the app or keep dialog open
                      // You might want to exit the app here
                    }
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFF90E18),
                ),
                child: const Text('Update Now'),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      // If dialog is dismissed (only possible for non-force update)
      if (!forceUpdate) {
        _proceedWithNavigation();
      }
    });
  }

  Future<void> _proceedWithNavigation() async {
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    await context.read<SignupModel>().loadUserData();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('bearer_token');
    final userDataString = prefs.getString('user_data');

    // NO TOKEN → GO TO ONBOARDING
    if (token == null || userDataString == null) {
      _goTo(const OnboardingScreen());
      return;
    }

    // Decode stored signup response
    final userData = jsonDecode(userDataString);
    final userId = int.tryParse(userData["id"].toString());
    final name = userData['firstName'];

    if (userId == null) {
      _goTo(const OnboardingScreen());
      return;
    }

    _initFCM();

    // HIT PAGENO API
    final pageNo = await PageService.getPageNo(userId);

    if (!mounted) return;

    if (pageNo == null) {
      // API failed → go home
      _goTo(const OnboardingScreen());
      return;
    }

    // Navigate based on pageno value
    switch (pageNo) {
      case 0:
        _goTo(const PersonalDetailsPage());
        break;
      case 1:
        _goTo(const CommunityDetailsPage());
        break;
      case 2:
        _goTo(const LivingStatusPage());
        break;
      case 3:
        _goTo(FamilyDetailsPage());
        break;
      case 4:
        _goTo(EducationCareerPage());
        break;
      case 5:
        _goTo(AstrologicDetailsPage());
        break;
      case 6:
        _goTo(LifestylePage());
        break;
      case 7:
        _goTo(PartnerPreferencesPage());
        break;
      case 8:
        _goTo(IDVerificationScreen());
        break;
      case 9:
        _goTo(const IDVerificationScreen());
        break;
      case 10:
        _goTo(const MainControllerScreen(initialIndex: 0));
        break;
      default:
        _goTo(const OnboardingScreen());
    }
  }

  Future<void> _initFCM() async {
    final prefs = await SharedPreferences.getInstance();

    final userDataString = prefs.getString('user_data');
    if (userDataString == null) return;

    final userData = jsonDecode(userDataString);
    final String userId = userData["id"].toString();

    try {
      NotificationSettings settings =
      await FirebaseMessaging.instance.requestPermission();

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        print("Push permission not granted");
        return;
      }

      await Future.delayed(const Duration(seconds: 1));

      String? fcmToken = await FirebaseMessaging.instance.getToken();

      if (fcmToken == null) {
        await Future.delayed(const Duration(seconds: 1));
        fcmToken = await FirebaseMessaging.instance.getToken();
      }

      if (fcmToken == null) {
        print("FCM token still null after retry");
        return;
      }

      print("FCM TOKEN => $fcmToken");

      String? savedToken = prefs.getString('fcm_token');

      if (savedToken != fcmToken) {
        await prefs.setString('fcm_token', fcmToken);
        await updateFcmToken(userId, fcmToken);
        print("FCM TOKEN saved & updated");
      } else {
        print("FCM TOKEN already up to date");
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        await prefs.setString('fcm_token', newToken);
        await updateFcmToken(userId, newToken);
        print("FCM TOKEN refreshed => $newToken");
      });
    } catch (e) {
      print("FCM ERROR => $e");
    }
  OnlineStatusService().start();

  }

  Future<void> updateFcmToken(String userId, String token) async {
    final response = await http.post(
      Uri.parse("https://digitallami.com/Api2/update_token.php"),
      body: {
        "user_id": userId,
        "fcm_token": token,
      },
    );
    print(response.body);
  }

  void _goTo(Widget screen) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              child: const Image(image: AssetImage('assets/images/Mslogo.gif')),
            ),
            const SizedBox(height: 20),
            const Text(
              'Marriage Station',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Welcome to Nepal #1 Matrimony.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            if (_isCheckingVersion)
              const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Color(0xFFF90E18)),
              )
            else if (_errorMessage != null)
              Column(
                children: [
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isCheckingVersion = true;
                        _errorMessage = null;
                      });
                      _checkAppVersion();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF90E18),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}