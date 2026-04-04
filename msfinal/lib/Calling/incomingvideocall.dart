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

class IncomingVideoCallScreen extends StatefulWidget {
  final Map<String, dynamic> callData;
  const IncomingVideoCallScreen({super.key, required this.callData});

  @override
  State<IncomingVideoCallScreen> createState() => _IncomingVideoCallScreenState();
}

class _IncomingVideoCallScreenState extends State<IncomingVideoCallScreen> {
  late RtcEngine _engine;
  bool _engineInitialized = false;

  int _localUid = 0;
  int? _remoteUid;

  late String _channel;
  late String _callerId;
  late String _callerName;
  late String _recipientName;
  late bool _isVideoCall;

  bool _joined = false;
  bool _callActive = false;
  bool _micMuted = false;
  bool _speakerOn = true;
  bool _cameraOn = true;
  bool _frontCamera = true;
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
      // Cancel the video call notification (ID: 1002)
      final plugin = FlutterLocalNotificationsPlugin();
      plugin.cancel(1002);
      debugPrint('✅ Cancelled video call notification after screen mounted');
    } catch (e) {
      debugPrint('Error cancelling video call notification: $e');
    }
  }

  void _listenForCallCancelled() {
    _cancelSubscription = NotificationService.callResponses.listen((data) {
      final type = data['type']?.toString();
      if (type == 'video_call_cancelled' || type == 'video_call_ended') {
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

        // Log incoming video call
        _callHistoryId = await CallHistoryService.logCall(
          callerId: _callerId,
          callerName: _callerName,
          callerImage: widget.callData['callerImage'] ?? '',
          recipientId: _currentUserId,
          recipientName: _currentUserName,
          recipientImage: _currentUserImage,
          callType: CallType.video,
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
    _isVideoCall = widget.callData['type'] == 'video_call' ||
        (widget.callData['isVideoCall']?.toString() == 'true');
  }

  void _initializeOverlay() {
    CallOverlayManager().startCall(
      callType: _isVideoCall ? 'video' : 'audio',
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
      onToggleCamera: _toggleVideo,
      isMicMuted: _micMuted,
      isCameraEnabled: _cameraOn,
    );
    _syncOverlayState();
  }

  void _syncOverlayState() {
    CallOverlayManager().updateCallState(
      statusText: _callActive ? 'Connected' : 'Incoming call',
      duration: _duration,
      isMicMuted: _micMuted,
      isCameraEnabled: _cameraOn,
    );
  }

  Future<void> _minimizeCall() async {
    await openMinimizedCallHost(context);
  }

  // ================= ACCEPT CALL =================
// ================= ACCEPT CALL =================
  Future<void> _acceptCall() async {
    if (_processing) return;
    _processing = true;

    try {
      print('📞 ACCEPTING VIDEO CALL');
      print('📞 Channel: $_channel');
      print('📞 Local UID: $_localUid');
      print('📞 Is Video Call: $_isVideoCall');

      _ringTimer?.cancel();

      // Permissions
        if (!(await Permission.microphone.request()).isGranted) {
          print('❌ Microphone permission denied');
          await _end();
          return;
        }
        if (_isVideoCall && !(await Permission.camera.request()).isGranted) {
          print('❌ Camera permission denied');
          await _end();
          return;
        }

      print('✅ Permissions granted');

      // Notify caller
      print('📤 Notifying caller of acceptance...');
      await NotificationService.sendVideoCallResponseNotification(
        callerId: _callerId,
        recipientName: _recipientName,
        accepted: true,
        recipientUid: _localUid.toString(),
        channelName: _channel,
      );

      // Token
      print('🔐 Getting Agora token...');
      final token = await AgoraTokenService.getToken(
        channelName: _channel,
        uid: _localUid,
      );

      // Engine
      print('🚀 Initializing Agora engine...');
      _engine = createAgoraRtcEngine();
      await _engine.initialize(RtcEngineContext(
        appId: AgoraTokenService.appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));
      _engineInitialized = true;

      print('👂 Setting up event handlers...');
      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            print('✅ Joined channel successfully');
            setState(() => _joined = true);
            unawaited(_startForegroundService());
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            print('👤 Remote user joined: $remoteUid');
            setState(() {
              _remoteUid = remoteUid;
            });
            _startCallTimer();
          },
          onUserOffline: (connection, remoteUid, reason) {
            print('👤 Remote user offline: $remoteUid, reason: $reason');
            _endCall();
          },
          onRemoteVideoStateChanged: (connection, remoteUid, state, reason, elapsed) {
            print('📹 Remote video state changed: uid=$remoteUid, state=$state, reason=$reason');
            // Handle video state changes
            if (state == RemoteVideoState.remoteVideoStateStopped ||
                state == RemoteVideoState.remoteVideoStateFailed) {
              print('❌ Remote video stopped/failed');
              setState(() {
                if (_remoteUid == remoteUid) {
                  _remoteUid = null;
                }
              });
            } else if (state == RemoteVideoState.remoteVideoStateDecoding) {
              print('✅ Remote video started decoding');
              setState(() {
                _remoteUid = remoteUid;
              });
            }
          },
          onError: (errorCode, errorMsg) {
            print('❌ Agora error $errorCode $errorMsg');
          },
        ),
      );

      await _engine.enableAudio();
      await _engine.setEnableSpeakerphone(_speakerOn);
      if (_isVideoCall) {
        print('📹 Enabling video...');
        await _engine.enableVideo();
        await _engine.setVideoEncoderConfiguration(const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 640, height: 480),
          frameRate: 15,
          bitrate: 0,
        ));
        await _engine.startPreview();
        print('✅ Video enabled and preview started');
      }

      await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      print('🚪 Joining channel...');
      await _engine.joinChannel(
        token: token,
        channelId: _channel,
        uid: _localUid,
        options: ChannelMediaOptions(
          publishMicrophoneTrack: true,
          publishCameraTrack: _isVideoCall,
          autoSubscribeAudio: true,
          autoSubscribeVideo: _isVideoCall,
        ),
      );

      print('✅ Call active');
      setState(() => _callActive = true);
      _initializeOverlay();
    } catch (e) {
      print('❌ Accept error: $e');
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
    await NotificationService.sendVideoCallResponseNotification(
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
    await NotificationService.sendMissedVideoCallNotification(
      callerId: _callerId,
      callerName: _callerName,
      senderId: _currentUserId,
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
      unawaited(NotificationService.sendVideoCallEndedNotification(
        recipientUserId: _callerId,
        callerName: _recipientName,
        reason: 'ended',
        duration: _duration.inSeconds,
        channelName: _channel,
      ));
    }

    // Update call history
    if (_callHistoryId != null && _callHistoryId!.isNotEmpty) {
      await CallHistoryService.updateCallEnd(
        callId: _callHistoryId!,
        status: CallStatus.completed,
        duration: _duration.inSeconds,
      );
    }

    // Navigate away FIRST so the user never sees the black AgoraRTC screen
    await _end();

    // Release engine resources after navigation (fire-and-forget)
    if (_engineInitialized) unawaited(_releaseEngineAsync());
  }

  Future<void> _end() async {
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
    unawaited(_stopForegroundService());
  }

  // ================= TOGGLE CAMERA =================
  Future<void> _toggleCamera() async {
    if (_joined && _isVideoCall) {
      await _engine.switchCamera();
      setState(() => _frontCamera = !_frontCamera);
    }
  }

  Future<void> _toggleMute() async {
    setState(() => _micMuted = !_micMuted);
    if (_engineInitialized) {
      await _engine.muteLocalAudioStream(_micMuted);
    }
    _syncOverlayState();
  }

  Future<void> _toggleVideo() async {
    setState(() => _cameraOn = !_cameraOn);
    if (_engineInitialized && _isVideoCall) {
      await _engine.enableLocalVideo(_cameraOn);
    }
    _syncOverlayState();
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        // When back button is pressed during incoming video call
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
          child: _callActive ? _buildActiveCallUI() : _buildIncomingCallUI(),
        ),
      ),
    );
  }

  Widget _buildIncomingCallUI() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 70,
                  backgroundColor: Colors.blue.shade800,
                  child: const Icon(
                    Icons.person,
                    size: 100,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  _callerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _isVideoCall ? 'Video Call' : 'Voice Call',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isVideoCall ? Icons.videocam : Icons.call,
                      color: Colors.white70,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Incoming Call',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Accept/Reject buttons at the bottom
        Padding(
          padding: const EdgeInsets.only(bottom: 40.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _acceptRejectButton(
                icon: Icons.call,
                color: Colors.green,
                onPressed: _acceptCall,
                size: 72,
                loading: _processing,
              ),
              _acceptRejectButton(
                icon: Icons.call_end,
                color: Colors.red,
                onPressed: _rejectCall,
                size: 72,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveCallUI() {
    return Stack(
      children: [
        // Remote video (when active)
        if (_remoteUid != null && _isVideoCall)
          AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: _engine,
              canvas: VideoCanvas(uid: _remoteUid),
              connection: RtcConnection(channelId: _channel),
            ),
          )
        else
          Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blue.shade800,
                    child: const Icon(
                      Icons.person,
                      size: 60,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _callerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isVideoCall ? 'Video call connected' : 'Voice call',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _format(_duration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Local preview (when active and video)
        if (_isVideoCall && _cameraOn)
          Positioned(
            top: 40,
            right: 20,
            width: 120,
            height: 160,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _engine,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
              ),
            ),
          ),

        // Top info (when active)
        Positioned(
          top: 40,
          left: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  _isVideoCall ? Icons.videocam : Icons.call,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _format(_duration),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),

        Positioned(
          top: 40,
          right: 20,
          child: CallMinimizeButton(onPressed: _minimizeCall),
        ),

        // Bottom controls
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: _activeControls(),
        ),
      ],
    );
  }

  Widget _acceptRejectButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    double size = 72,
    bool loading = false,
  }) {
    return GestureDetector(
      onTap: loading ? null : onPressed,
      child: Container(
        width: size,
        height: size,
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
            : Icon(
                icon,
                color: Colors.white,
                size: size * 0.45,
              ),
      ),
    );
  }

  Widget _activeControls() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      _controlButton(
        icon: _micMuted ? Icons.mic_off : Icons.mic,
        color: Colors.white,
        onPressed: _toggleMute,
      ),
      if (_isVideoCall)
        _controlButton(
          icon: _cameraOn ? Icons.videocam : Icons.videocam_off,
          color: Colors.white,
          onPressed: _toggleVideo,
        ),
      _controlButton(
        icon: Icons.call_end,
        color: Colors.red,
        onPressed: _endCall,
        size: 56,
      ),
      if (_isVideoCall)
        _controlButton(
          icon: Icons.switch_camera,
          color: Colors.white,
          onPressed: _toggleCamera,
        ),
      _controlButton(
        icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
        color: Colors.white,
        onPressed: () {
          setState(() => _speakerOn = !_speakerOn);
          if (_engineInitialized) {
            _engine.setEnableSpeakerphone(_speakerOn);
          }
        },
      ),
    ],
  );

  Widget _controlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    double size = 56,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color == Colors.red ? Colors.red.withOpacity(0.85) : Colors.black54,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: color == Colors.red ? Colors.white : color,
          size: size * 0.55,
        ),
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
    // Release Agora engine if not already released by _endCall
    if (_engineInitialized) {
      unawaited(_releaseEngineAsync());
    }
    unawaited(_stopForegroundService());
    super.dispose();
  }

  /// Releases the Agora engine; safe to call fire-and-forget from dispose().
  Future<void> _releaseEngineAsync() async {
    try {
      if (_joined) await _engine.leaveChannel();
      await _engine.release();
    } catch (_) {}
  }

  Future<void> _startForegroundService() async {
    if (_channel.isEmpty) return;
    if (_foregroundServiceStarted) return;
    _foregroundServiceStarted = true;
    await CallForegroundServiceManager.startOngoingCall(
      callType: _isVideoCall ? 'video' : 'audio',
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
