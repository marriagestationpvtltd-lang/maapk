import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ms2026/Notification/notification_inbox_service.dart';
import 'package:ms2026/pushnotification/pushservice.dart';
import 'package:provider/provider.dart';

import 'Calling/incomingvideocall.dart';
import 'Calling/incommingcall.dart';
import 'Calling/call_state_recovery_manager.dart';
import 'Calling/unified_call_manager.dart';
import 'Chat/call_overlay_manager.dart';
import 'Chat/ChatdetailsScreen.dart';
import 'Chat/adminchat.dart';
import 'Chat/screen_state_manager.dart';
import 'Startup/SplashScreen.dart';
import 'Auth/SuignupModel/signup_model.dart';
import 'Startup/onboarding.dart';
import 'otherenew/modelfile.dart';
import 'otherenew/othernew.dart';
import 'otherenew/service.dart';
import 'otherprofile/otherprofileview.dart';
import 'constant/app_theme.dart';
import 'navigation/app_navigation.dart';
import 'online/onlineservice.dart';
import 'service/connectivity_service.dart';
import 'widgets/global_connectivity_handler.dart';
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// Notification channel IDs
const String callChannelId = 'calls_channel';
const String callChannelName = 'Calls';
const String callChannelDescription = 'Channel for WhatsApp-like call notifications';
const String messagesChannelId = 'messages_channel';
const String messagesChannelName = 'Messages';
const String messagesChannelDescription = 'Channel for chat messages';
const String generalChannelId = 'general_notifications';
const String generalChannelName = 'General Notifications';
const String generalChannelDescription = 'Channel for general app notifications';

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  // Initialize local notifications plugin so we can show custom notifications
  // (e.g. full-screen call intent) from this background isolate.
  await initLocalNotifications();

  final data = message.data;
  final type = data['type']?.toString() ?? '';

  // Trigger call response for response notifications.
  // NOTE: This runs in a background Dart isolate – the stream event will NOT
  // reach the main isolate's listeners. We persist the event to SharedPreferences
  // so that the main isolate can process it when the app resumes.
  NotificationService.triggerCallResponse(data);

  // Trigger incoming call for new call notifications (stream call for same reason)
  if (type == 'call' || type == 'video_call') {
    NotificationService.triggerIncomingCall(data);
  }

  // Persist events that the main isolate must process on resume
  try {
    final prefs = await SharedPreferences.getInstance();
    final ts = DateTime.now().millisecondsSinceEpoch;

    if (type == 'call' || type == 'video_call') {
      // Save incoming call so CallOverlayWrapper can show the screen on resume
      await prefs.setString(
        'pending_incoming_call',
        json.encode({...data, '_receivedAt': ts}),
      );
    } else if (type == 'call_response' ||
        type == 'video_call_response' ||
        type == 'call_ended' ||
        type == 'video_call_ended' ||
        type == 'call_cancelled' ||
        type == 'video_call_cancelled') {
      // Save call termination event so OutgoingCall/VideoCall screens can close on resume
      await prefs.setString(
        'pending_call_event',
        json.encode({...data, '_receivedAt': ts}),
      );
    }
  } catch (_) {}

  // Always record notification in inbox
  await NotificationInboxService.recordIncomingRemoteNotification(
    data: data,
    fallbackTitle: message.notification?.title,
    fallbackBody: message.notification?.body,
  );

  // Silent notifications (Type 2): No user alert, only update app state
  const silentTypes = {
    'call_response',
    'video_call_response',
    'call_ended',
    'video_call_ended',
    'call_cancelled',
    'video_call_cancelled',
    'missed_call',
    'missed_video_call',
  };

  if (silentTypes.contains(type)) {
    // Silent notification - no visual alert needed
    debugPrint('🔕 Silent notification received: $type');
    return;
  }

  // Real-time interactive notifications (Type 1): Incoming calls
  if (defaultTargetPlatform == TargetPlatform.android &&
      (type == 'call' || type == 'video_call')) {
    await _displayWhatsAppCallNotification(data, message.notification);
    return;
  }

  // Standard notifications (Type 3 & 4): Chat messages, requests, etc.
  // Show notification for all other types when in background
  // Admin messages are handled silently – no system notification stored.
  if (type == 'chat_message' || type == 'chat' ||
      type == 'request' || type == 'request_accepted' ||
      type == 'request_rejected' || type == 'profile_view') {
    if (!_isAdminMessage(data)) {
      await _displayStandardNotification(message);
    }
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

// Display standard notification for messages, requests, etc.
Future<void> _displayStandardNotification(RemoteMessage message) async {
  final data = message.data;
  final type = data['type']?.toString() ?? '';
  final content = NotificationInboxService.buildNotificationContent(
    type: type,
    actorName: data['senderName']?.toString() ??
        data['viewerName']?.toString() ??
        data['callerName']?.toString(),
    requestType: data['requestType']?.toString() ?? data['request_type']?.toString(),
    messagePreview: data['message']?.toString() ?? message.notification?.body,
  );

  // Use different channel based on notification type
  final isMessage = type == 'chat_message' || type == 'chat';
  final channelId = isMessage ? messagesChannelId : generalChannelId;
  final channelName = isMessage ? messagesChannelName : generalChannelName;
  final channelDescription = isMessage ? messagesChannelDescription : generalChannelDescription;

  final androidDetails = AndroidNotificationDetails(
    channelId,
    channelName,
    channelDescription: channelDescription,
    importance: isMessage ? Importance.high : Importance.defaultImportance,
    priority: isMessage ? Priority.high : Priority.defaultPriority,
    playSound: true,
    enableVibration: true,
  );

  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    presentBanner: true,
    presentList: true,
  );

  final details = NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
  );

  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    message.notification?.title ?? content['title'],
    message.notification?.body ?? content['body'],
    details,
    payload: json.encode(data),
  );
}

// Returns true when the notification was sent by the admin (senderId == '1').
// Admin messages should be handled silently – navigate to AdminChatScreen
// instead of showing a persistent system notification.
// NOTE: '1' matches AdminChatScreen._adminUserId which is a fixed constant in this app.
bool _isAdminMessage(Map<String, dynamic> data) {
  const adminUserId = '1'; // Same constant as AdminChatScreen._adminUserId
  final senderId = data['senderId']?.toString() ??
      data['sender_id']?.toString() ??
      '';
  return senderId == adminUserId;
}

// Navigate to AdminChatScreen when an admin-sent message notification arrives.
Future<void> _navigateToAdminChatFromNotification(Map<String, dynamic> data) async {
  debugPrint('🔔 Admin message notification – opening AdminChatScreen');
  try {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString == null) {
      debugPrint('⚠️ Admin chat navigation: no user_data in prefs');
      return;
    }

    final userData = json.decode(userDataString);
    final currentUserId = userData['id']?.toString() ?? '';
    if (currentUserId.isEmpty) {
      debugPrint('⚠️ Admin chat navigation: currentUserId is empty');
      return;
    }

    final firstName = userData['firstName']?.toString().trim() ?? '';
    final lastName = userData['lastName']?.toString().trim() ?? '';
    final currentUserName =
        [firstName, lastName].where((s) => s.isNotEmpty).join(' ').trim();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentState = navigatorKey.currentState;
      if (currentState != null) {
        currentState.push(MaterialPageRoute(
          builder: (context) => AdminChatScreen(
            senderID: currentUserId,
            userName: currentUserName.isEmpty ? 'User' : currentUserName,
            isAdmin: false,
          ),
        ));
      }
    });
  } catch (e) {
    debugPrint('❌ Error navigating to admin chat from notification: $e');
  }
}

// Create notification channels and configure actions
Future<void> initLocalNotifications() async {
  // Create Android notification channel for calls
  final callChannel = AndroidNotificationChannel(
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

  // Create Android notification channel for messages
  final messagesChannel = AndroidNotificationChannel(
    messagesChannelId,
    messagesChannelName,
    description: messagesChannelDescription,
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  // Create Android notification channel for general notifications
  final generalChannel = AndroidNotificationChannel(
    generalChannelId,
    generalChannelName,
    description: generalChannelDescription,
    importance: Importance.defaultImportance,
    playSound: true,
    showBadge: true,
  );

  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  await androidPlugin?.createNotificationChannel(callChannel);
  await androidPlugin?.createNotificationChannel(messagesChannel);
  await androidPlugin?.createNotificationChannel(generalChannel);

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

Future<String> _resolveCurrentUserName() async {
  final prefs = await SharedPreferences.getInstance();
  final cachedFirstName = prefs.getString('user_firstName')?.trim();
  if (cachedFirstName != null && cachedFirstName.isNotEmpty) {
    return cachedFirstName;
  }

  final rawUserData = prefs.getString('user_data');
  if (rawUserData == null || rawUserData.isEmpty) {
    return 'User';
  }

  try {
    final userData = json.decode(rawUserData) as Map<String, dynamic>;
    final firstName = userData['firstName']?.toString().trim() ?? '';
    final lastName = userData['lastName']?.toString().trim() ?? '';
    final fullName = [firstName, lastName]
        .where((value) => value.isNotEmpty)
        .join(' ')
        .trim();
    return fullName.isEmpty ? 'User' : fullName;
  } catch (_) {
    return 'User';
  }
}

// Handle notification actions (Accept/Decline from notification)
Future<void> _handleNotificationAction(NotificationResponse response) async {
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

      // Navigate to call page first
      _navigateToCallPage(data);

      // Delay notification cancellation to ensure call screen is visible
      Future.delayed(const Duration(milliseconds: 800), () {
        flutterLocalNotificationsPlugin.cancel(notificationId);
      });

    } else if (actionId == 'decline_call') {
      debugPrint('❌ Call declined from notification');

      // Cancel the ringing notification
      flutterLocalNotificationsPlugin.cancel(notificationId);

      final callerId = data['callerId']?.toString();
      if (callerId != null && callerId.isNotEmpty) {
        final recipientName = await _resolveCurrentUserName();
        if (isVideoCall) {
          await NotificationService.sendVideoCallResponseNotification(
            callerId: callerId,
            recipientName: recipientName,
            accepted: false,
            recipientUid: '0',
            channelName: data['channelName']?.toString(),
          );
        } else {
          await NotificationService.sendCallResponseNotification(
            callerId: callerId,
            recipientName: recipientName,
            accepted: false,
            recipientUid: '0',
            channelName: data['channelName']?.toString(),
          );
        }
      }

    } else if (type == 'call' || type == 'video_call') {
      // Regular notification tap (for missed calls)
      _navigateToCallPage(data);

      // Delay notification cancellation to ensure call screen is visible
      Future.delayed(const Duration(milliseconds: 800), () {
        flutterLocalNotificationsPlugin.cancel(notificationId);
      });
    } else {
      // Regular notification tap (chat messages, requests, profile views, etc.)
      _handleNotificationTap(payload);
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
      // For call notifications (especially missed calls), navigate to chat instead
      _navigateToChatFromCallNotification(data);
    } else if (type == 'chat_message' || type == 'chat') {
      _navigateToChatFromMessageNotification(data);
    } else {
      _navigateToUserProfileFromNotification(data);
    }
  } catch (e) {
    debugPrint('❌ Error handling notification tap: $e');
  }
}

void _navigateToChatFromCallNotification(Map<String, dynamic> data) async {
  debugPrint('🚀 Navigating to chat from call notification');

  try {
    // Get current user data
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');

    if (userDataString == null) {
      debugPrint('❌ No user data found');
      return;
    }

    final userData = json.decode(userDataString);
    final currentUserId = userData['id']?.toString() ?? '';
    final currentUserName = userData['name']?.toString() ?? '';
    final currentUserImage = userData['image']?.toString() ?? '';

    if (currentUserId.isEmpty) {
      debugPrint('❌ Current user ID is empty');
      return;
    }

    // Extract caller/recipient info from notification
    final callerId = data['callerId'] ?? data['senderId'] ?? '';
    final callerName = data['callerName'] ?? data['senderName'] ?? 'Unknown';
    final callerImage = data['callerImage'] ?? '';

    if (callerId.isEmpty) {
      debugPrint('❌ Caller ID is empty');
      return;
    }

    // Generate chat room ID
    final chatRoomId = currentUserId.compareTo(callerId) < 0
        ? '${currentUserId}_$callerId'
        : '${callerId}_$currentUserId';

    debugPrint('💬 Opening chat with: $callerName (ID: $callerId)');
    debugPrint('💬 Chat room ID: $chatRoomId');

    // Navigate to chat screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentState = navigatorKey.currentState;

      if (currentState != null) {
        currentState.push(
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              chatRoomId: chatRoomId,
              receiverId: callerId,
              receiverName: callerName,
              receiverImage: callerImage,
              currentUserId: currentUserId,
              currentUserName: currentUserName,
              currentUserImage: currentUserImage,
            ),
          ),
        );
      } else {
        debugPrint('❌ Navigator state is null, cannot navigate');
      }
    });
  } catch (e) {
    debugPrint('❌ Error navigating to chat from call notification: $e');
  }
}

void _navigateToChatFromMessageNotification(Map<String, dynamic> data) async {
  debugPrint('🚀 Navigating to chat from message notification');
  try {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString == null) return;

    final userData = json.decode(userDataString);
    final currentUserId = userData['id']?.toString() ?? '';
    final firstName = userData['firstName']?.toString().trim() ?? '';
    final lastName = userData['lastName']?.toString().trim() ?? '';
    final currentUserName =
        [firstName, lastName].where((s) => s.isNotEmpty).join(' ').trim();

    if (currentUserId.isEmpty) return;

    final senderId = data['senderId']?.toString() ??
        data['sender_id']?.toString() ??
        data['related_user_id']?.toString() ??
        '';
    if (senderId.isEmpty) return;

    final chatRoomId = currentUserId.compareTo(senderId) < 0
        ? '${currentUserId}_$senderId'
        : '${senderId}_$currentUserId';

    final senderName = data['senderName']?.toString() ??
        data['peer_name']?.toString() ??
        data['sender_name']?.toString() ??
        'User';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentState = navigatorKey.currentState;
      if (currentState != null) {
        currentState.push(MaterialPageRoute(
          builder: (context) => ChatDetailScreen(
            chatRoomId: chatRoomId,
            receiverId: senderId,
            receiverName: senderName,
            receiverImage: '',
            currentUserId: currentUserId,
            currentUserName: currentUserName.isEmpty ? 'User' : currentUserName,
            currentUserImage: '',
          ),
        ));
      } else {
        debugPrint('❌ Navigator state is null, cannot navigate to chat');
      }
    });
  } catch (e) {
    debugPrint('❌ Error navigating to chat from message notification: $e');
  }
}

void _navigateToUserProfileFromNotification(Map<String, dynamic> data) {
  final userId = data['sender_id']?.toString() ??
      data['related_user_id']?.toString() ??
      data['recipient_id']?.toString() ??
      '';
  if (userId.isEmpty) {
    debugPrint('❌ User ID is empty, cannot navigate to profile');
    return;
  }
  debugPrint('🚀 Navigating to user profile: $userId');
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final currentState = navigatorKey.currentState;
    if (currentState != null) {
      currentState.push(MaterialPageRoute(
        builder: (context) => UserProfilePage(userId: userId),
      ));
    } else {
      debugPrint('❌ Navigator state is null, cannot navigate to profile');
    }
  });
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
              settings: const RouteSettings(name: activeCallRouteName),
              fullscreenDialog: true,
              builder: (context) => IncomingVideoCallScreen(
                callData: data,
              ),
            ),
          );
        } else {
          currentState.push(
            MaterialPageRoute(
              settings: const RouteSettings(name: activeCallRouteName),
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
  // Set up iOS foreground notification presentation.
  // For iOS, we enable selective presentation - show alerts for important notifications
  // like calls, but our onMessage handler controls when to show other notifications
  // (e.g. suppressing chat messages while user is on that chat screen).
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,  // Enable alerts for important notifications
      badge: true,  // Update badge count
      sound: true,  // Play sound for notifications
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

  Future<void> _showStandardNotification(RemoteMessage message) async {
    final data = message.data;
    final content = NotificationInboxService.buildNotificationContent(
      type: data['type']?.toString() ?? 'notification',
      actorName: data['senderName']?.toString() ??
          data['viewerName']?.toString() ??
          data['callerName']?.toString(),
      requestType: data['requestType']?.toString() ?? data['request_type']?.toString(),
      messagePreview: data['message']?.toString() ?? message.notification?.body,
    );

    const androidDetails = AndroidNotificationDetails(
      generalChannelId,
      generalChannelName,
      channelDescription: generalChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      message.notification?.title ?? content['title'],
      message.notification?.body ?? content['body'],
      details,
      payload: json.encode(data),
    );
  }

  // Set up foreground message handlers
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    final data = message.data;
    final type = data['type']?.toString() ?? '';
    debugPrint('📱 Foreground message received: ${message.notification?.title}');
    debugPrint('📱 Message data: $data');
    debugPrint('📱 Message type: $type');

    // Always record notification in inbox first
    await NotificationInboxService.recordIncomingRemoteNotification(
      data: data,
      fallbackTitle: message.notification?.title,
      fallbackBody: message.notification?.body,
    );

    // Trigger call response for response notifications
    NotificationService.triggerCallResponse(data);

    // Type 1: Real-time Interactive Notifications (Incoming Calls)
    if (type == 'call' || type == 'video_call') {
      NotificationService.triggerIncomingCall(data);
      // When app is in foreground, the calling UI opens directly via CallOverlayWrapper.
      // Do NOT show a notification banner — it would appear alongside the call screen.
      debugPrint('📞 Incoming call notification - UI handled by CallOverlayWrapper');
      return;
    }

    // Type 2: Silent Data Messages (No visual notification)
    const silentTypes = {
      'call_response',
      'video_call_response',
      'call_ended',
      'video_call_ended',
      'call_cancelled',
      'video_call_cancelled',
      'missed_call',
      'missed_video_call',
    };

    if (silentTypes.contains(type)) {
      // Silent notification - handled programmatically by call screen UI
      // No notification banner needed, just recorded in inbox above
      debugPrint('🔕 Silent notification - no banner shown: $type');
      return;
    }

    // Type 3: Context-Aware Messages (Chat)
    if (type == 'chat_message' || type == 'chat') {
      // Admin messages: navigate directly to AdminChatScreen – no notification banner.
      if (_isAdminMessage(data)) {
        debugPrint('🔔 Admin message received in foreground – opening AdminChatScreen');
        _navigateToAdminChatFromNotification(data);
        return;
      }
      // Suppress chat notifications when the recipient is actively viewing that chat
      if (!shouldShowChatNotification(data)) {
        debugPrint('💬 Chat notification suppressed - user viewing this chat');
        return;
      }
    }

    // Type 3 & 4: Show standard notification for chat messages, requests, profile views
    await _showStandardNotification(message);
  });

  // Handle messages when app is in background but opened via notification
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
    final data = message.data;
    debugPrint('📱 App opened from background via notification');
    debugPrint('📱 Message data: $data');
    await NotificationInboxService.recordIncomingRemoteNotification(
      data: data,
      fallbackTitle: message.notification?.title,
      fallbackBody: message.notification?.body,
    );

    final type = data['type']?.toString() ?? '';

    // Handle call termination events – trigger the stream so active call screens close
    const callTerminationTypes = {
      'call_response',
      'video_call_response',
      'call_ended',
      'video_call_ended',
      'call_cancelled',
      'video_call_cancelled',
    };
    if (callTerminationTypes.contains(type)) {
      NotificationService.triggerCallResponse(data);
      return;
    }

    // Navigate based on notification type
    if (data['type'] == 'call' || data['type'] == 'video_call') {
      // Clear the SharedPreferences-persisted call so the overlay doesn't double-push
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('pending_incoming_call');
      } catch (_) {}
      await CallStateRecoveryManager().handleNotificationTap(data);
    } else if (data['type'] == 'chat_message' || data['type'] == 'chat') {
      if (_isAdminMessage(data)) {
        _navigateToAdminChatFromNotification(data);
      } else {
        _navigateToChatFromMessageNotification(data);
      }
    } else {
      _navigateToUserProfileFromNotification(data);
    }
  });

  // Handle initial message if app was opened from terminated state
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) async {
    if (message != null) {
      final data = message.data;
      debugPrint('📱 App opened from terminated state via notification');
      debugPrint('📱 Message data: $data');
      await NotificationInboxService.recordIncomingRemoteNotification(
        data: data,
        fallbackTitle: message.notification?.title,
        fallbackBody: message.notification?.body,
      );

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Navigate based on notification type
        if (data['type'] == 'call' || data['type'] == 'video_call') {
          await CallStateRecoveryManager().handleNotificationTap(data);
        } else if (data['type'] == 'chat_message' || data['type'] == 'chat') {
          if (_isAdminMessage(data)) {
            _navigateToAdminChatFromNotification(data);
          } else {
            _navigateToChatFromMessageNotification(data);
          }
        } else {
          _navigateToUserProfileFromNotification(data);
        }
      });
    }
  });

  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await Firebase.initializeApp();

  // Sign in anonymously so Firestore security rules that require
  // request.auth != null are satisfied for chat and presence operations.
  // signInAnonymously() returns the existing anonymous user when already signed in.
  try {
    await FirebaseAuth.instance.signInAnonymously();
  } catch (e) {
    debugPrint('⚠️ Firebase anonymous sign-in failed: $e');
  }

  await initLocalNotifications();

  // Initialize connectivity service
  final connectivityService = ConnectivityService();
  await connectivityService.initialize();

  // Initialize call state recovery manager
  final callRecoveryManager = CallStateRecoveryManager();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SignupModel()),
        ChangeNotifierProvider<UserProfile>(
          create: (_) => UserProfile.empty(),
        ),
        ChangeNotifierProvider.value(value: connectivityService),
        ChangeNotifierProvider.value(value: UnifiedCallManager()),
      ],
      child: const MyApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    setupFirebaseMessaging();
    // Initialize call recovery after first frame
    callRecoveryManager.initialize();
    // Start online presence tracking if the user is already logged in
    // (handles app restarts without going through SplashScreen login)
    SharedPreferences.getInstance().then((prefs) {
      final userData = prefs.getString('user_data');
      if (userData != null && userData.isNotEmpty) {
        OnlineStatusService().start();
      }
    });
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      OnlineStatusService().start();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      OnlineStatusService().setOffline();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Marriage Station',
      theme: AppTheme.lightTheme,
      navigatorObservers: [appRouteTracker],
      builder: (context, child) {
        return CallOverlayWrapper(
          child: GlobalConnectivityHandler(
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
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
