import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../Chat/ChatlistScreen.dart';
import '../Chat/call_overlay_manager.dart';
import '../navigation/app_navigation.dart';
import '../pushnotification/pushservice.dart';
import 'tokengenerator.dart';
import 'call_history_model.dart';
import 'call_history_service.dart';
import 'call_foreground_service.dart';

class IncomingCallScreen extends StatefulWidget {
  final Map<String, dynamic> callData;
  const IncomingCallScreen({super.key, required this.callData});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  late RtcEngine _engine;
  bool _engineInitialized = false;

  int _localUid = 0;
  int? _remoteUid;

  late String _channel;
  late String _callerId;
  late String _callerName;
  late String _recipientName;

  bool _joined = false;
  bool _callActive = false;
  bool _micMuted = false;
  bool _speakerOn = true;
  bool _processing = false;
  bool _foregroundServiceStarted = false;

  Timer? _ringTimer;
  Timer? _callTimer;
  Duration _duration = Duration.zero;
  StreamSubscription<Map<String, dynamic>>? _cancelSubscription;

  // Call history tracking
  String? _callHistoryId;
  String _currentUserId = '';
  String _currentUserName = '';
  String _currentUserImage = '';

  @override
  void initState() {
    super.initState();
    _parseData();
    _localUid = Random().nextInt(999999);
    _ringTimer = Timer(const Duration(seconds: 60), _missedCall);
    _loadUserDataAndLogCall();
    _listenForCallCancelled();

    // Cancel the call notification once the screen is mounted and visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cancelCallNotification();
    });
  }

  void _cancelCallNotification() {
    try {
      // Cancel the audio call notification (ID: 1001)
      final plugin = FlutterLocalNotificationsPlugin();
      plugin.cancel(1001);
      debugPrint('✅ Cancelled call notification after screen mounted');
    } catch (e) {
      debugPrint('Error cancelling call notification: $e');
    }
  }

  void _listenForCallCancelled() {
    _cancelSubscription = NotificationService.callResponses.listen((data) {
      final type = data['type']?.toString();
      if (type == 'call_cancelled' || type == 'call_ended') {
        final channelName = data['channelName']?.toString();
        if (channelName == _channel) {
          if (!_callActive) {
            _end();
          }
        }
      }
    });
  }

  Future<void> _loadUserDataAndLogCall() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      if (userDataString != null) {
        final userData = jsonDecode(userDataString);
        _currentUserId = userData['id']?.toString() ?? '';
        _currentUserName = userData['name']?.toString() ?? '';
        _currentUserImage = userData['image']?.toString() ?? '';

        // Log incoming call
        _callHistoryId = await CallHistoryService.logCall(
          callerId: _callerId,
          callerName: _callerName,
          callerImage: widget.callData['callerImage'] ?? '',
          recipientId: _currentUserId,
          recipientName: _currentUserName,
          recipientImage: _currentUserImage,
          callType: CallType.audio,
          initiatedBy: _callerId,
        );
      }
    } catch (e) {
      debugPrint('Error loading user data for call history: $e');
    }
  }

  void _parseData() {
    _channel = widget.callData['channelName'];
    _callerId = widget.callData['callerId'];
    _callerName = widget.callData['callerName'];
    _recipientName = widget.callData['recipientName'] ?? 'You';
  }

  void _initializeOverlay() {
    CallOverlayManager().startCall(
      callType: 'audio',
      otherUserName: _callerName,
      otherUserId: _callerId,
      currentUserId: '',
      currentUserName: _recipientName,
      onMaximize: () {
        navigatorKey.currentState?.popUntil(
          (route) => route.settings.name == activeCallRouteName || route.isFirst,
        );
      },
      onEnd: _endCall,
      onToggleMute: _toggleMute,
      isMicMuted: _micMuted,
    );
    _syncOverlayState();
  }

  void _syncOverlayState() {
    CallOverlayManager().updateCallState(
      statusText: _callActive ? 'Connected' : 'Incoming call',
      duration: _duration,
      isMicMuted: _micMuted,
    );
  }

  Future<void> _minimizeCall() async {
    await openMinimizedCallHost(context);
  }

  Future<void> _toggleMute() async {
    setState(() => _micMuted = !_micMuted);
    if (_engineInitialized) {
      await _engine.muteLocalAudioStream(_micMuted);
    }
    _syncOverlayState();
  }

  // ================= ACCEPT CALL =================
  Future<void> _acceptCall() async {
    if (_processing) return;
    _processing = true;

    try {
      _ringTimer?.cancel();

      if (!(await Permission.microphone.request()).isGranted) {
        await _end();
        return;
      }

      // Notify caller
      await NotificationService.sendCallResponseNotification(
        callerId: _callerId,
        recipientName: _recipientName,
        accepted: true,
        recipientUid: _localUid.toString(),
        channelName: _channel,
      );

      // Token
      final token = await AgoraTokenService.getToken(
        channelName: _channel,
        uid: _localUid,
      );

      // Engine
      _engine = createAgoraRtcEngine();
      await _engine.initialize(RtcEngineContext(
        appId: AgoraTokenService.appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));
      _engineInitialized = true;

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (_, __) {
            _joined = true;
            unawaited(_startForegroundService());
          },
          onUserJoined: (_, uid, __) {
            _remoteUid = uid;
            _startCallTimer();
          },
          onUserOffline: (_, __, ___) {
            _endCall();
          },
          onError: (c, m) {
            debugPrint('Agora error $c $m');
          },
        ),
      );

      await _engine.enableAudio();
      await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await _engine.setEnableSpeakerphone(_speakerOn);

      await _engine.joinChannel(
        token: token,
        channelId: _channel,
        uid: _localUid,
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true,
        ),
      );

      setState(() => _callActive = true);
      _initializeOverlay();
    } catch (e) {
      debugPrint('Accept error $e');
      await _end();
    } finally {
      _processing = false;
    }
  }

  // ================= TIMERS =================
  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _duration += const Duration(seconds: 1));
        _syncOverlayState();
      }
    });
  }

  Future<void> _rejectCall() async {
    _ringTimer?.cancel();
    await NotificationService.sendCallResponseNotification(
      callerId: _callerId,
      recipientName: _recipientName,
      accepted: false,
      recipientUid: '0',
      channelName: _channel,
    );
    await _end();
  }

  // ================= MISSED =================
  Future<void> _missedCall() async {
    await NotificationService.sendMissedCallNotification(
      callerId: _callerId,
      callerName: _callerName,
    );

    // Update call history as missed
    if (_callHistoryId != null && _callHistoryId!.isNotEmpty) {
      await CallHistoryService.updateCallEnd(
        callId: _callHistoryId!,
        status: CallStatus.missed,
        duration: 0,
      );
    }

    await _end();
  }

  // ================= DECLINE CALL =================
  Future<void> _declineCall() async {
    _ringTimer?.cancel();

    // Update call history as declined
    if (_callHistoryId != null && _callHistoryId!.isNotEmpty) {
      await CallHistoryService.updateCallEnd(
        callId: _callHistoryId!,
        status: CallStatus.declined,
        duration: 0,
      );
    }

    await _end();
  }

  // ================= END =================
  Future<void> _endCall() async {
    _callTimer?.cancel();

    if (_callActive) {
      await NotificationService.sendCallEndedNotification(
        recipientUserId: _callerId,
        callerName: _recipientName,
        reason: 'ended',
        duration: _duration.inSeconds,
        channelName: _channel,
      );
    }

    // Update call history
    if (_callHistoryId != null && _callHistoryId!.isNotEmpty) {
      await CallHistoryService.updateCallEnd(
        callId: _callHistoryId!,
        status: CallStatus.completed,
        duration: _duration.inSeconds,
      );
    }

    if (_joined) {
      await _engine.leaveChannel();
    }
    if (_engineInitialized) {
      await _engine.release();
    }
    await _stopForegroundService();

    await _end();
  }

  Future<void> _end() async {
    await _stopForegroundService();
    final wasMinimized = CallOverlayManager().isMinimized;
    if (wasMinimized) {
      navigatorKey.currentState?.popUntil(
        (route) => route.settings.name == activeCallRouteName || route.isFirst,
      );
    }
    CallOverlayManager().reset();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        // When back button is pressed during incoming call
        if (_callActive) {
          // If call is active, minimize it
          await _minimizeCall();
        } else {
          // If call is not yet accepted, reject it
          await _rejectCall();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              if (_callActive)
                Align(
                  alignment: Alignment.topRight,
                   child: Padding(
                     padding: const EdgeInsets.only(right: 16, top: 12),
                     child: CallMinimizeButton(onPressed: _minimizeCall),
                   ),
                 ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _callActive ? Icons.phone_in_talk : Icons.phone,
                        color: Colors.white,
                        size: 80,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _callActive ? 'Connected' : 'Incoming call',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _callerName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _callActive
                            ? _format(_duration)
                            : 'Voice Call',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 40),
                      _callActive ? _activeControls() : _incomingControls(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _incomingControls() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      _callBtn(Icons.call, Colors.green, _acceptCall, loading: _processing),
      _callBtn(Icons.call_end, Colors.red, _rejectCall),
    ],
  );

  Widget _activeControls() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
       _callBtn(
         _micMuted ? Icons.mic_off : Icons.mic,
         _micMuted ? Colors.orange : Colors.white,
         _toggleMute,
       ),
      _callBtn(Icons.call_end, Colors.red, _endCall),
       _callBtn(
         _speakerOn ? Icons.volume_up : Icons.volume_off,
         _speakerOn ? Colors.blue : Colors.white,
         _engineInitialized ? () {
           setState(() => _speakerOn = !_speakerOn);
           _engine.setEnableSpeakerphone(_speakerOn);
         } : null,
       ),
    ],
  );

  Widget _callBtn(IconData icon, Color color, VoidCallback? onPressed, {bool loading = false}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: color.withOpacity(0.85),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: loading
            ? const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)))
            : Icon(icon, color: Colors.white, size: 32),
      ),
    );
  }

  String _format(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _ringTimer?.cancel();
    _callTimer?.cancel();
    _cancelSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startForegroundService() async {
    if (_channel.isEmpty) return;
    if (_foregroundServiceStarted) return;
    _foregroundServiceStarted = true;
    await CallForegroundServiceManager.startOngoingCall(
      callType: 'audio',
      otherUserName: _callerName,
      callId: _channel,
    );
  }

  Future<void> _stopForegroundService() async {
    if (!_foregroundServiceStarted) return;
    try {
      await CallForegroundServiceManager.stopCallService();
      _foregroundServiceStarted = false;
    } catch (e) {
      debugPrint('Error stopping call foreground service: $e');
    }
  }
}
