import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
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
  bool _ending = false;
  bool _remoteVideoStopped = false;
  bool _connecting = false;

  Timer? _ringTimer;
  Timer? _callTimer;
  Duration _duration = Duration.zero;
  StreamSubscription<Map<String, dynamic>>? _cancelSubscription;

  final _ringtonePlayer = FlutterRingtonePlayer();

  // Network quality tracking
  int _networkQuality = 0; // 0=unknown, 1=excellent, 2=good, 3=poor, 4=bad, 5=very bad, 6=down
  String _networkQualityText = 'Unknown';
  Timer? _qualityUpdateTimer;

  // Call history tracking
  String? _callHistoryId;
  String _currentUserId = '';
  String _currentUserName = '';
  String _currentUserImage = '';
  String _chatRoomId = '';  // chat room for inline call messages

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _parseData();
    _localUid = Random().nextInt(999998) + 1;
    _ringTimer = Timer(const Duration(seconds: 60), _missedCall);
    _loadUserDataAndLogCall();
    _listenForCallCancelled();

    // Cancel the call notification once the screen is mounted and visible,
    // then start the looping ringtone
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cancelCallNotification();
      _playRingtone();
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

  Future<void> _playRingtone() async {
    try {
      await _ringtonePlayer.play(
        android: AndroidSounds.ringtone,
        ios: IosSounds.electronic,
        looping: true,
        asAlarm: true,
      );
      debugPrint('✅ Incoming video call ringtone started');
    } catch (e) {
      debugPrint('Error playing incoming video call ringtone: $e');
    }
  }

  Future<void> _stopRingtone() async {
    try {
      await _ringtonePlayer.stop();
      debugPrint('✅ Incoming video call ringtone stopped');
    } catch (e) {
      debugPrint('Error stopping incoming video call ringtone: $e');
    }
  }

  void _listenForCallCancelled() {
    _cancelSubscription = NotificationService.callResponses.listen((data) {
      final type = data['type']?.toString();
      if (type == 'video_call_cancelled' || type == 'video_call_ended') {
        final channelName = data['channelName']?.toString();
        if (channelName == _channel) {
          if (_remoteUid == null) {
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
    _chatRoomId = widget.callData['chatRoomId']?.toString() ?? '';
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
      await _stopRingtone();

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
            if (mounted) {
              setState(() {
                _remoteUid = remoteUid;
                _callActive = true;
                _remoteVideoStopped = false;
                _connecting = false;
              });
            }
            _startCallTimer();
            _syncOverlayState();
          },
          onUserOffline: (connection, remoteUid, reason) {
            print('👤 Remote user offline: $remoteUid, reason: $reason');
            _endCall();
          },
          onRemoteVideoStateChanged: (connection, remoteUid, state, reason, elapsed) {
            print('📹 Remote video state changed: uid=$remoteUid, state=$state, reason=$reason');
            if (state == RemoteVideoState.remoteVideoStateStopped ||
                state == RemoteVideoState.remoteVideoStateFailed) {
              print('❌ Remote video stopped/failed');
              if (mounted) setState(() => _remoteVideoStopped = true);
            } else if (state == RemoteVideoState.remoteVideoStateDecoding) {
              print('✅ Remote video started decoding');
              if (mounted) {
                setState(() {
                  _remoteUid = remoteUid;
                  _remoteVideoStopped = false;
                });
              }
            }
          },
          onError: (errorCode, errorMsg) {
            print('❌ Agora error $errorCode $errorMsg');
            if (_remoteUid == null && !_ending) {
              _endCall();
            }
          },
          onNetworkQuality: (connection, remoteUid, txQuality, rxQuality) {
            // Track network quality for adaptive bitrate
            final quality = max(txQuality.index, rxQuality.index);
            if (mounted && quality != _networkQuality) {
              setState(() {
                _networkQuality = quality;
                _networkQualityText = _getQualityText(quality);
              });
              _adaptVideoQuality(quality);
            }
          },
          onConnectionStateChanged: (connection, state, reason) {
            debugPrint('Connection state: $state, reason: $reason');
            // Handle reconnection scenarios - call stays active during network switches
            if (state == ConnectionStateType.connectionStateReconnecting) {
              debugPrint('📶 Reconnecting to call...');
            } else if (state == ConnectionStateType.connectionStateConnected) {
              debugPrint('📶 Connected to call');
            } else if (state == ConnectionStateType.connectionStateFailed) {
              debugPrint('❌ Connection failed');
            }
          },
        ),
      );

      await _engine.enableAudio();
      await _engine.setEnableSpeakerphone(_speakerOn);
      if (_isVideoCall) {
        print('📹 Enabling video...');
        await _engine.enableVideo();

        // Configure video encoder with adaptive bitrate support
        await _engine.setVideoEncoderConfiguration(const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 640, height: 480),
          frameRate: 15,
          bitrate: 0, // 0 = let SDK determine based on resolution
          minBitrate: -1, // -1 = SDK default minimum
          orientationMode: OrientationMode.orientationModeAdaptive,
          degradationPreference: DegradationPreference.maintainBalanced, // Balance quality and framerate
          mirrorMode: VideoMirrorModeType.videoMirrorModeAuto,
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

      print('✅ Joined channel, waiting for remote user...');
      if (mounted) setState(() => _connecting = true);
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
    await _stopRingtone();
    await NotificationService.sendVideoCallResponseNotification(
      callerId: _callerId,
      recipientName: _recipientName,
      accepted: false,
      recipientUid: '0',
      channelName: _channel,
    );

    // Write inline call message to chat (recipient side backup)
    if (_chatRoomId.isNotEmpty) {
      unawaited(CallHistoryService.logCallMessageInChat(
        callerId: _callerId,
        callType: 'video',
        callStatus: 'declined',
        duration: 0,
        chatRoomId: _chatRoomId,
        messageDocId: _channel.isNotEmpty ? 'call_$_channel' : null,
      ));
    }

    await _end();
  }

  // ================= MISSED =================
  Future<void> _missedCall() async {
    await _stopRingtone();
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

    // Write inline call message to chat (recipient side backup)
    if (_chatRoomId.isNotEmpty) {
      unawaited(CallHistoryService.logCallMessageInChat(
        callerId: _callerId,
        callType: 'video',
        callStatus: 'missed',
        duration: 0,
        chatRoomId: _chatRoomId,
        messageDocId: _channel.isNotEmpty ? 'call_$_channel' : null,
      ));
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

    // Write inline call message to chat (recipient side backup)
    if (_chatRoomId.isNotEmpty) {
      unawaited(CallHistoryService.logCallMessageInChat(
        callerId: _callerId,
        callType: 'video',
        callStatus: 'declined',
        duration: 0,
        chatRoomId: _chatRoomId,
        messageDocId: _channel.isNotEmpty ? 'call_$_channel' : null,
      ));
    }

    await _end();
  }

  // ================= END =================
  Future<void> _endCall() async {
    if (_ending) return;
    _ending = true;
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

    // Write inline call message to chat (recipient side backup)
    if (_chatRoomId.isNotEmpty) {
      unawaited(CallHistoryService.logCallMessageInChat(
        callerId: _callerId,
        callType: 'video',
        callStatus: _callActive ? 'completed' : 'missed',
        duration: _duration.inSeconds,
        chatRoomId: _chatRoomId,
        messageDocId: _channel.isNotEmpty ? 'call_$_channel' : null,
      ));
    }

    // Navigate away FIRST so the user never sees the black AgoraRTC screen
    await _end();

    // Release engine resources after navigation (fire-and-forget)
    if (_engineInitialized) unawaited(_releaseEngineAsync());
  }

  Future<void> _end() async {
    await _stopRingtone();
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
        } else if (_connecting) {
          // If still connecting, end the call
          await _endCall();
        } else {
          // If call is not yet accepted, reject it
          await _rejectCall();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: _callActive
              ? _buildActiveCallUI()
              : (_connecting ? _buildConnectingUI() : _buildIncomingCallUI()),
        ),
      ),
    );
  }

  Widget _buildConnectingUI() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam, color: Colors.white, size: 80),
            const SizedBox(height: 30),
            Text(
              _callerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: Colors.white70, strokeWidth: 3),
            const SizedBox(height: 20),
            const Text(
              'Connecting...',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingCallUI() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A237E), // Deep indigo (different from audio)
            Color(0xFF283593), // Medium indigo
            Color(0xFF3949AB), // Lighter indigo
          ],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 60),
          // Top section with caller info
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated video camera icon with glow effect
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 1500),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 0.9 + (value * 0.1),
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF00C853), // Bright green
                              Color(0xFF64DD17), // Lime green
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00C853).withOpacity(0.6),
                              blurRadius: 35,
                              spreadRadius: 12,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.videocam,
                            size: 90,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 50),
                // Caller name with slide-in animation
                TweenAnimationBuilder<Offset>(
                  duration: const Duration(milliseconds: 600),
                  tween: Tween(begin: const Offset(0, -0.5), end: Offset.zero),
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: value * 50,
                      child: Opacity(
                        opacity: 1.0 - value.dy.abs(),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    _callerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                // Video call badge
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: child,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.25),
                          Colors.white.withOpacity(0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.videocam,
                          color: Colors.white,
                          size: 22,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Video Call',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 35),
                // Incoming text with pulsing animation
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 1200),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: 0.65 + (value * 0.35),
                      child: child,
                    );
                  },
                  child: const Text(
                    'Incoming Video Call...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 19,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Accept/Reject buttons at the bottom
          Padding(
            padding: const EdgeInsets.only(bottom: 60.0, left: 24, right: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _modernAcceptRejectButton(
                  icon: Icons.videocam,
                  color: const Color(0xFF4CAF50), // Green
                  onPressed: _acceptCall,
                  size: 76,
                  loading: _processing,
                  label: 'Accept',
                ),
                _modernAcceptRejectButton(
                  icon: Icons.call_end,
                  color: const Color(0xFFF44336), // Red
                  onPressed: _rejectCall,
                  size: 76,
                  label: 'Decline',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCallUI() {
    return Stack(
      children: [
        // Remote video (when active and video not stopped)
        if (_remoteUid != null && _isVideoCall && !_remoteVideoStopped)
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

  Widget _modernAcceptRejectButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    double size = 72,
    bool loading = false,
    String? label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: loading ? null : onPressed,
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 150),
            tween: Tween(begin: 1.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color,
                        color.withOpacity(0.75),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.6),
                        blurRadius: 25,
                        spreadRadius: 3,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: loading
                      ? const Center(
                          child: SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          ),
                        )
                      : Icon(
                          icon,
                          color: Colors.white,
                          size: size * 0.48,
                        ),
                ),
              );
            },
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 14),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _modernControlButton({
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
          color: Colors.white.withOpacity(0.25),
          shape: BoxShape.circle,
          border: Border.all(
            color: color,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: color,
          size: size * 0.55,
        ),
      ),
    );
  }

  Widget _activeControls() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      _modernControlButton(
        icon: _micMuted ? Icons.mic_off : Icons.mic,
        color: _micMuted ? const Color(0xFFFF9800) : Colors.white,
        onPressed: _toggleMute,
      ),
      if (_isVideoCall)
        _modernControlButton(
          icon: _cameraOn ? Icons.videocam : Icons.videocam_off,
          color: _cameraOn ? Colors.white : const Color(0xFFFF9800),
          onPressed: _toggleVideo,
        ),
      _modernAcceptRejectButton(
        icon: Icons.call_end,
        color: const Color(0xFFF44336),
        onPressed: _endCall,
        size: 68,
      ),
      if (_isVideoCall)
        _modernControlButton(
          icon: Icons.switch_camera,
          color: Colors.white,
          onPressed: _toggleCamera,
        ),
      _modernControlButton(
        icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
        color: _speakerOn ? const Color(0xFF2196F3) : Colors.white,
        onPressed: () {
          setState(() => _speakerOn = !_speakerOn);
          if (_engineInitialized) {
            _engine.setEnableSpeakerphone(_speakerOn);
          }
        },
      ),
    ],
  );

  String _format(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  // ================= ADAPTIVE VIDEO QUALITY =================
  String _getQualityText(int quality) {
    switch (quality) {
      case 0: return 'Unknown';
      case 1: return 'Excellent';
      case 2: return 'Good';
      case 3: return 'Poor';
      case 4: return 'Bad';
      case 5: return 'Very Bad';
      case 6: return 'Disconnected';
      default: return 'Unknown';
    }
  }

  Future<void> _adaptVideoQuality(int quality) async {
    if (!_engineInitialized || !_joined || !_isVideoCall) return;

    try {
      // Adaptive bitrate based on network quality
      // Quality: 1=excellent, 2=good, 3=poor, 4=bad, 5=very bad, 6=down
      VideoEncoderConfiguration config;

      if (quality <= 2) {
        // Excellent or Good - HD quality
        config = const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 640, height: 480),
          frameRate: 15,
          bitrate: 0, // SDK determines optimal
          minBitrate: -1,
          orientationMode: OrientationMode.orientationModeAdaptive,
          degradationPreference: DegradationPreference.maintainBalanced,
          mirrorMode: VideoMirrorModeType.videoMirrorModeAuto,
        );
        debugPrint('📶 Network quality $quality: Maintaining HD video (640x480@15fps)');
      } else if (quality == 3) {
        // Poor - Reduce to standard quality
        config = const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 480, height: 360),
          frameRate: 12,
          bitrate: 0,
          minBitrate: -1,
          orientationMode: OrientationMode.orientationModeAdaptive,
          degradationPreference: DegradationPreference.maintainBalanced,
          mirrorMode: VideoMirrorModeType.videoMirrorModeAuto,
        );
        debugPrint('📶 Network quality $quality: Reducing to standard video (480x360@12fps)');
      } else if (quality >= 4) {
        // Bad or Very Bad - Reduce to low quality
        config = const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 320, height: 240),
          frameRate: 10,
          bitrate: 0,
          minBitrate: -1,
          orientationMode: OrientationMode.orientationModeAdaptive,
          degradationPreference: DegradationPreference.maintainFramerate, // Prioritize smooth video
          mirrorMode: VideoMirrorModeType.videoMirrorModeAuto,
        );
        debugPrint('📶 Network quality $quality: Reducing to low video (320x240@10fps)');
      } else {
        return; // Unknown quality
      }

      await _engine.setVideoEncoderConfiguration(config);
    } catch (e) {
      debugPrint('Error adapting video quality: $e');
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _ringTimer?.cancel();
    _callTimer?.cancel();
    _qualityUpdateTimer?.cancel();
    _cancelSubscription?.cancel();
    // FlutterRingtonePlayer doesn't have a dispose method, stop is called in _endCall
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
