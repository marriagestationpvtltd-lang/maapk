import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ms2026/pushnotification/pushservice.dart';
import 'package:provider/provider.dart';

import 'Calling/incomingvideocall.dart';
import 'Calling/incommingcall.dart';
import 'Startup/SplashScreen.dart';
import 'Auth/SuignupModel/signup_model.dart';
import 'Startup/onboarding.dart';
import 'otherenew/modelfile.dart';
import 'otherenew/othernew.dart';
import 'otherenew/service.dart';
import 'constant/app_theme.dart';
import 'service/connectivity_service.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// Notification channel IDs
const String callChannelId = 'calls_channel';
const String callChannelName = 'Calls';
const String callChannelDescription = 'Channel for WhatsApp-like call notifications';

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final data = message.data;
  NotificationService.triggerCallResponse(data);

  if (defaultTargetPlatform == TargetPlatform.android) {
    await _displayWhatsAppCallNotification(data, message.notification);
  }
}

// WhatsApp-like call notification display
Future<void> _displayWhatsAppCallNotification(
    Map<String, dynamic> data,
    RemoteNotification? notification, {
      FlutterLocalNotificationsPlugin? localPlugin,
    }) async {
  final plugin = localPlugin ?? flutterLocalNotificationsPlugin;

  final isVideoCall = data['type'] == 'video_call' || data['isVideoCall'] == 'true';
  final callerName = data['callerName'] ?? 'Unknown';

  // Create notification ID based on call type
  final notificationId = isVideoCall ? 1002 : 1001;

  // WhatsApp-like action buttons using built-in Android icons
  final acceptAction = AndroidNotificationAction(
    'accept_call',
    'Accept',
    icon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    showsUserInterface: true,
    cancelNotification: false,
  );

  final declineAction = AndroidNotificationAction(
    'decline_call',
    'Decline',
    icon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    showsUserInterface: true,
    cancelNotification: true,
  );

  // Use simpler notification style without custom icons
  final androidDetails = AndroidNotificationDetails(
    callChannelId,
    callChannelName,
    channelDescription: callChannelDescription,
    importance: Importance.max,
    priority: Priority.max,
    ticker: 'Incoming ${isVideoCall ? 'video' : 'voice'} call',
    playSound: true,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
    enableLights: true,
   ledColor: const Color(0xFF25D366), // REQUIRED if lights enabled

  //isVideoCall ? 0xFF25D366 : 0xFF34B7F1,
    ledOnMs: 1000,
    ledOffMs: 500,
    fullScreenIntent: true,
    category: AndroidNotificationCategory.call,
    visibility: NotificationVisibility.public,
    color: isVideoCall ? const Color(0xFF25D366) : const Color(0xFF34B7F1),
    colorized: true,
    actions: [acceptAction, declineAction],
    styleInformation: BigTextStyleInformation(
      'Incoming ${isVideoCall ? 'video' : 'voice'} call from $callerName',
      contentTitle: isVideoCall ? '📹 Video Call' : '📞 Voice Call',
      summaryText: callerName,
      htmlFormatContent: true,
      htmlFormatTitle: true,
    ),
    tag: 'incoming_call_$notificationId',
    groupKey: 'calls',
    setAsGroupSummary: false,
    onlyAlertOnce: false,
    channelShowBadge: true,
    autoCancel: false,
    ongoing: true,
    timeoutAfter: 60000,
    showWhen: true,
    usesChronometer: true,
    when: DateTime.now().millisecondsSinceEpoch,
    subText: isVideoCall ? 'Video calling...' : 'Calling...',
  );

  final iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    presentBanner: true,
    presentList: true,
    categoryIdentifier: 'incoming_call',
    interruptionLevel: InterruptionLevel.critical,
    threadIdentifier: 'calls',
  );

  final details = NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
  );

  debugPrint('📞 Showing WhatsApp-like call notification for: $callerName');

  await plugin.show(
    notificationId,
    isVideoCall ? '📹 Video Call' : '📞 Voice Call',
    callerName,
    details,
    payload: json.encode(data),
  );
}

// Create notification channels and configure actions
Future<void> initLocalNotifications() async {
  // Create Android notification channel for calls
  final androidChannel = AndroidNotificationChannel(
    callChannelId,
    callChannelName,
    description: callChannelDescription,
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    enableLights: true,
    ledColor: Colors.blue,
    showBadge: true,
    vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(androidChannel);

  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
    requestCriticalPermission: true,
    defaultPresentAlert: true,
    defaultPresentBadge: true,
    defaultPresentSound: true,
    defaultPresentBanner: true,
    defaultPresentList: true,
  );

  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: android, iOS: ios),
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      _handleNotificationAction(response);
    },
  );

  // Configure iOS notification categories - using the correct method
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    await _configureIOSNotifications();
  }
}

// Configure iOS notification categories with actions
Future<void> _configureIOSNotifications() async {
  final DarwinNotificationCategory callCategory = DarwinNotificationCategory(
    'incoming_call',
    actions: [
      DarwinNotificationAction.plain(
        'accept_call',
        'Accept',
        options: {
          DarwinNotificationActionOption.foreground,
          DarwinNotificationActionOption.destructive,
        },
      ),
      DarwinNotificationAction.plain(
        'decline_call',
        'Decline',
        options: {
          DarwinNotificationActionOption.destructive,
          DarwinNotificationActionOption.authenticationRequired,
        },
      ),
    ],
    options: {
      DarwinNotificationCategoryOption.customDismissAction,
      DarwinNotificationCategoryOption.allowInCarPlay,
    },
  );

  // For newer versions of flutter_local_notifications, use this method
  final iosPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  if (iosPlugin != null) {
   // await iosPlugin.noSuchMethod([callCategory]);
  }
}

// Handle notification actions (Accept/Decline from notification)
void _handleNotificationAction(NotificationResponse response) {
  final payload = response.payload;
  final actionId = response.actionId;

  if (payload == null) return;

  try {
    final data = json.decode(payload);
    final type = data['type'];
    final isVideoCall = type == 'video_call' || data['isVideoCall'] == 'true';
    final notificationId = isVideoCall ? 1002 : 1001;

    debugPrint('📱 Notification action: $actionId');
    debugPrint('📱 Payload data: $data');

    if (actionId == 'accept_call') {
      debugPrint('✅ Call accepted from notification');

      // Cancel the ringing notification
      flutterLocalNotificationsPlugin.cancel(notificationId);

      // Navigate to call page
      _navigateToCallPage(data);

      // Notify the system that call was accepted
      NotificationService.triggerCallResponse({
        ...data,
        'action': 'accept',
      });

    } else if (actionId == 'decline_call') {
      debugPrint('❌ Call declined from notification');

      // Cancel the ringing notification
      flutterLocalNotificationsPlugin.cancel(notificationId);

      // Notify the system that call was declined
      NotificationService.triggerCallResponse({
        ...data,
        'action': 'decline',
      });

    } else if (type == 'call' || type == 'video_call') {
      // Regular notification tap (for missed calls)
      _navigateToCallPage(data);
    }
  } catch (e) {
    debugPrint('❌ Error handling notification action: $e');
  }
}

void _handleNotificationTap(String? payload) {
  if (payload == null) return;

  try {
    final data = json.decode(payload);
    final type = data['type'];

    debugPrint('📱 Notification tapped with type: $type');
    debugPrint('📱 Payload data: $data');

    // Navigate based on notification type
    if (type == 'call' || type == 'video_call') {
      _navigateToCallPage(data);
    }
  } catch (e) {
    debugPrint('❌ Error handling notification tap: $e');
  }
}

void _navigateToCallPage(Map<String, dynamic> data) {
  final isVideoCall = data['isVideoCall'] == 'true' || data['type'] == 'video_call';

  debugPrint('🚀 Navigating to ${isVideoCall ? 'Video' : 'Voice'} Call Page');

  // Ensure we're on the main thread
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final currentContext = navigatorKey.currentContext;
    final currentState = navigatorKey.currentState;

    if (currentState != null) {
      // Check if we're already on a call page to avoid duplicates
      bool isAlreadyOnCallPage = false;
      if (currentContext != null) {
        // Check if the current route is a call page
        final route = ModalRoute.of(currentContext);
        if (route != null) {
          final settings = route.settings;
          if (settings.name?.contains('call') ?? false) {
            isAlreadyOnCallPage = true;
          }
        }
      }

      if (!isAlreadyOnCallPage) {
        if (isVideoCall) {
          currentState.push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (context) => IncomingVideoCallScreen(
                callData: data,
              ),
            ),
          );
        } else {
          currentState.push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (context) => IncomingCallScreen(
                callData: data,
              ),
            ),
          );
        }
      } else {
        debugPrint('⚠️ Already on a call page, skipping navigation');
      }
    } else {
      debugPrint('❌ Navigator state is null, cannot navigate');
    }
  });
}

Future<void> setupFirebaseMessaging() async {
  // Set up iOS foreground notification presentation
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    criticalAlert: true,
    provisional: false,
    announcement: true,
    carPlay: true,
  );

  try {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await FirebaseMessaging.instance.getAPNSToken();
    }
    final token = await FirebaseMessaging.instance.getToken();
    debugPrint("🎯 FCM TOKEN: $token");
  } catch (e) {
    debugPrint("⚠️ FCM token not ready yet: $e");
  }

  // Set up foreground message handlers
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    final data = message.data;
    debugPrint('📱 Foreground message received: ${message.notification?.title}');
    debugPrint('📱 Message data: $data');

    NotificationService.triggerCallResponse(data);

    // Show WhatsApp-like notification for calls
    if (data['type'] == 'call' || data['type'] == 'video_call') {
      await _displayWhatsAppCallNotification(
        data,
        message.notification,
        localPlugin: flutterLocalNotificationsPlugin,
      );

      // Auto-navigate for call notifications when app is in foreground
      _navigateToCallPage(data);
    }
  });

  Future<void> _showChatNotification(Map<String, dynamic> data) async {
    const androidDetails = AndroidNotificationDetails(
      'chat_channel',
      'Chats',
      channelDescription: 'Chat message notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      data['senderName'] ?? 'New Message',
      data['message'] ?? '',
      details,
      payload: json.encode(data),
    );
  }

  // Handle messages when app is in background but opened via notification
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    final data = message.data;
    debugPrint('📱 App opened from background via notification');
    debugPrint('📱 Message data: $data');

    if (data['type'] == 'call' || data['type'] == 'video_call') {
      _navigateToCallPage(data);
    }
  });

  // Handle initial message if app was opened from terminated state
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      final data = message.data;
      debugPrint('📱 App opened from terminated state via notification');
      debugPrint('📱 Message data: $data');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (data['type'] == 'call' || data['type'] == 'video_call') {
          _navigateToCallPage(data);
        }
      });
    }
  });

  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await Firebase.initializeApp();
  await initLocalNotifications();

  // Initialize connectivity service
  final connectivityService = ConnectivityService();
  await connectivityService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SignupModel()),
        ChangeNotifierProvider<UserProfile>(
          create: (_) => UserProfile.empty(),
        ),
        ChangeNotifierProvider.value(value: connectivityService),
      ],
      child: const MyApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    setupFirebaseMessaging();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Marriage Station',
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const OnboardingScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
      },
    );
  }
}

class ProfileLoader extends StatefulWidget {
  final String myId;
  final String userId;

  const ProfileLoader({
    super.key,
    required this.myId,
    required this.userId,
  });

  @override
  State<ProfileLoader> createState() => _ProfileLoaderState();
}

class _ProfileLoaderState extends State<ProfileLoader> {
  bool _isLoading = true;
  String? _error;
  final ProfileService _profileService = ProfileService();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _profileService.fetchProfile(
        myId: widget.myId,
        userId: widget.userId,
      );

      if (mounted) {
        Provider.of<UserProfile>(context, listen: false).updateFromResponse(response);
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading profile...',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error Loading Profile',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _loadProfile,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Go Back'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ProfileScreen(userId: widget.userId.toString());
  }
}