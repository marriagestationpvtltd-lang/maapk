import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Chat/call_overlay_manager.dart';
import '../navigation/app_navigation.dart';
import '../pushnotification/pushservice.dart';
import 'tokengenerator.dart';
import 'call_history_model.dart';
import 'call_history_service.dart';
import 'call_foreground_service.dart';
import 'widgets/connection_status_overlay.dart';

class CallScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final String currentUserImage;
  final String otherUserId;
  final String otherUserName;
  final String otherUserImage;
  final bool isOutgoingCall; // Add this to identify outgoing call
  final String? chatRoomId; // For writing inline call message to chat
  final bool isAdminChat; // True when called from AdminChatScreen
  final String? adminChatReceiverId; // Receiver ID for admin chat call messages

  const CallScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserImage,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserImage,
    this.isOutgoingCall = true, // Default to outgoing call
    this.chatRoomId,
    this.isAdminChat = false,
    this.adminChatReceiverId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with WidgetsBindingObserver {
  late RtcEngine _engine;
  bool _engineInitialized = false;

  int _localUid = 0;
  int? _remoteUid;

  String _channel = '';
  String _token = '';

  bool _joined = false;
  bool _callActive = false;
  bool _micMuted = false;
  bool _speakerOn = false;
  bool _ending = false;
  bool _isCallRinging = true; // New state for ringing
  bool _foregroundServiceStarted = false;

  Timer? _timeoutTimer;
  Timer? _callTimer;
  Duration _duration = Duration.zero;

  // Ringtone state
  final AudioPlayer _ringtonePlayer = AudioPlayer();
  bool _isPlayingRingtone = false;
  StreamSubscription<Map<String, dynamic>>? _responseSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  String? _connectionStatus;
  bool _remoteAccepted = false;

  static const Duration _kConnectivityLossTimeout = Duration(seconds: 30);
  static const Duration _kOutgoingCallTimeout = Duration(seconds: 45);
  static const Duration _kPostAcceptConnectionTimeout = Duration(seconds: 20);

  // Call history tracking
  String? _callHistoryId;
  DateTime? _callStartTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenForCallResponse();
    _startCall();
    _listenConnectivity();
  }

  bool _callDeclined = false; // true when remote explicitly rejected

  void _listenForCallResponse() {
    _responseSubscription = NotificationService.callResponses.listen((data) {
      final type = data['type']?.toString();
      final channelName = data['channelName']?.toString();
      if (_channel.isNotEmpty &&
          channelName != null &&
          channelName.isNotEmpty &&
          channelName != _channel) {
        return;
      }

      if (type == 'call_response') {
        final accepted = data['accepted'] == 'true';
        if (accepted) {
          if (mounted) {
            setState(() {
              _remoteAccepted = true;
              _isCallRinging = false;
            });
          }
          unawaited(_stopRingtone());
          _armOutgoingTimeout(_kPostAcceptConnectionTimeout);
          _syncOverlayState();
        } else {
          if (mounted) {
            setState(() {
              _remoteAccepted = false;
              _callDeclined = true;
            });
          }
          unawaited(_stopRingtone());
          _endCall();
        }
      } else if (type == 'call_ended') {
        _endCall();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_ending) {
      _checkPendingCallEvent();
    }
  }

  static const int _kCallEventExpiryMs = 300000; // 5 minutes

  /// Reads any call-termination event that was saved by the background isolate
  /// and processes it to close the call screen.
  Future<void> _checkPendingCallEvent() async {
    if (_ending) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final eventStr = prefs.getString('pending_call_event');
      if (eventStr == null) return;

      final event = json.decode(eventStr) as Map<String, dynamic>;
      final receivedAt = event['_receivedAt'] as int?;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Always remove stale / expired events to prevent re-processing
      if (receivedAt == null || now - receivedAt > _kCallEventExpiryMs) {
        await prefs.remove('pending_call_event');
        return;
      }

      final eventType = event['type']?.toString() ?? '';
      final eventChannel = event['channelName']?.toString() ?? '';

      // If we know our channel, make sure this event belongs to it
      if (_channel.isNotEmpty && eventChannel.isNotEmpty && eventChannel != _channel) {
        return;
      }

      // Remove the event before acting on it
      await prefs.remove('pending_call_event');

      // Don't process rejection if call is already connected
      if (_callActive) return;

      if ((eventType == 'call_response' || eventType == 'video_call_response') &&
          event['accepted'] == 'false') {
        if (mounted) setState(() => _callDeclined = true);
        unawaited(_stopRingtone());
        _endCall();
      } else if (eventType == 'call_ended' ||
          eventType == 'video_call_ended' ||
          eventType == 'call_cancelled' ||
          eventType == 'video_call_cancelled') {
        _endCall();
      }
    } catch (e) {
      debugPrint('❌ Error checking pending call event: $e');
    }
  }

  void _initializeOverlay() {
    CallOverlayManager().startCall(
      callType: 'audio',
      otherUserName: widget.otherUserName,
      otherUserId: widget.otherUserId,
      currentUserId: widget.currentUserId,
      currentUserName: widget.currentUserName,
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
    final statusText = _callActive
        ? 'Connected'
        : (_isCallRinging && !_remoteAccepted ? 'Calling...' : 'Connecting...');
    CallOverlayManager().updateCallState(
      statusText: statusText,
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
  // ================= PLAY RINGTONE =================
  Future<void> _playRingtone() async {
    if (!widget.isOutgoingCall) return;

    try {
      await _stopRingtone();

      await _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
      await _ringtonePlayer.play(AssetSource('images/outcall.mp3'));

      if (mounted) {
        setState(() => _isPlayingRingtone = true);
      }
      debugPrint('Started playing calling tone');
    } catch (e) {
      debugPrint('Error playing calling tone: $e');
    }
  }



  // ================= STOP RINGTONE =================
  Future<void> _stopRingtone() async {
    try {
      await _ringtonePlayer.stop();

      if (!mounted) return;

      setState(() {
        _isPlayingRingtone = false;
      });

      debugPrint('Stopped ringtone');
    } catch (e) {
      debugPrint('Error stopping ringtone: $e');
    }
  }


  // ================= START CALL =================
  Future<void> _startCall() async {
    try {
      // Start ringing immediately for outgoing calls
      if (widget.isOutgoingCall) {
        await _playRingtone();

      }

      // Permissions
      final micStatus = await Permission.microphone.status;

      if (micStatus.isDenied) {
        final result = await Permission.microphone.request();
        if (!result.isGranted) {
          debugPrint("Microphone permission denied");
          return; // ❌ DO NOT call _exit()
        }
      } else if (micStatus.isPermanentlyDenied) {
        debugPrint("Microphone permanently denied");
        await openAppSettings();
        return; // ❌ DO NOT call _exit()
      }


      // Channel + UID
      _localUid = Random().nextInt(999999);
      _channel =
      'call_${widget.currentUserId.substring(0, min(4, widget.currentUserId.length))}'
          '_${widget.otherUserId.substring(0, min(4, widget.otherUserId.length))}'
          '_${DateTime.now().millisecondsSinceEpoch}';

      if (_channel.length > 64) {
        _channel = _channel.substring(0, 64);
      }

      _initializeOverlay();

      // Token
      _token = await AgoraTokenService.getToken(
        channelName: _channel,
        uid: _localUid,
      );

      // Send notification for outgoing calls
      if (widget.isOutgoingCall) {
        await NotificationService.sendCallNotification(
          recipientUserId: widget.otherUserId,
          callerName: widget.currentUserName,
          channelName: _channel,
          callerId: widget.currentUserId,
          callerUid: _localUid.toString(),
          agoraAppId: AgoraTokenService.appId,
          agoraCertificate: 'SERVER_ONLY',
          chatRoomId: widget.chatRoomId,
        );

        // Log call to history
        _callHistoryId = await CallHistoryService.logCall(
          callerId: widget.currentUserId,
          callerName: widget.currentUserName,
          callerImage: widget.currentUserImage,
          recipientId: widget.otherUserId,
          recipientName: widget.otherUserName,
          recipientImage: widget.otherUserImage,
          callType: CallType.audio,
          initiatedBy: widget.currentUserId,
        );
        _callStartTime = DateTime.now();
      }

      // Init Agora
      _engine = createAgoraRtcEngine();
      await _engine.initialize(RtcEngineContext(
        appId: AgoraTokenService.appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));
      _engineInitialized = true;

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (_, __) {
            if (mounted) setState(() => _joined = true);
            _syncOverlayState();
            unawaited(_startForegroundService());
          },
          onUserJoined: (_, uid, __) {
            if (mounted) {
              setState(() {
                _remoteUid = uid;
                _isCallRinging = false; // Stop ringing state
                _callActive = true;
              });
            }
            _stopRingtone(); // Stop ringtone when user joins
            _startCallTimer(); // Start call duration timer
            _syncOverlayState();
          },
          onUserOffline: (_, __, ___) {
            _endCall();
          },
          onError: (code, msg) {
            debugPrint('Agora error: $code $msg');
          },
        ),
      );

      await _engine.enableAudio();
      await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      await _engine.joinChannel(
        token: _token,
        channelId: _channel,
        uid: _localUid,
        options: const ChannelMediaOptions(
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
        ),
      );

      _armOutgoingTimeout(_kOutgoingCallTimeout);
    } catch (e) {
      debugPrint('Init error: $e');
      await _exit();
    }
  }

  void _armOutgoingTimeout(Duration duration) {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(duration, () {
      if (_remoteUid == null) {
        if (widget.isOutgoingCall) {
          NotificationService.sendMissedCallNotification(
            callerId: widget.otherUserId,
            callerName: widget.currentUserName,
            senderId: widget.currentUserId,
          );
        }
        _endCall();
      }
    });
  }

  // ================= CALL TIMER =================
  void _startCallTimer() {
    _timeoutTimer?.cancel();
    _callActive = true;
    _syncOverlayState();

    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _duration += const Duration(seconds: 1));
        _syncOverlayState();
      }
    });
  }

  // ================= END CALL =================
  Future<void> _endCall() async {
    if (_ending) return;
    _ending = true;
    final wasMinimized = CallOverlayManager().isMinimized;
    final wasDeclined = _callDeclined;
    final wasNoAnswer = !_callActive && !_callDeclined;

    _callTimer?.cancel();
    _timeoutTimer?.cancel();
    _responseSubscription?.cancel();

    await _stopRingtone();

    // If the call was never answered, notify the receiver to dismiss their incoming call screen
    if (!_callActive && widget.isOutgoingCall && _channel.isNotEmpty) {
      unawaited(NotificationService.sendCallCancelledNotification(
        recipientUserId: widget.otherUserId,
        callerName: widget.currentUserName,
        channelName: _channel,
        callerId: widget.currentUserId,
      ));
    }

    // Update call history record and write inline call message to chat (outgoing only)
    if (widget.isOutgoingCall && _callHistoryId != null && _callHistoryId!.isNotEmpty) {
      final callStatus = _callActive
          ? CallStatus.completed
          : wasDeclined
              ? CallStatus.declined
              : CallStatus.missed;
      await CallHistoryService.updateCallEnd(
        callId: _callHistoryId!,
        status: callStatus,
        duration: _duration.inSeconds,
      );
      unawaited(CallHistoryService.logCallMessageInChat(
        callerId: widget.currentUserId,
        callType: 'audio',
        callStatus: callStatus.toString().split('.').last,
        duration: _duration.inSeconds,
        chatRoomId: widget.chatRoomId,
        isAdminChat: widget.isAdminChat,
        adminChatSenderId: widget.isAdminChat ? widget.currentUserId : null,
        adminChatReceiverId: widget.isAdminChat ? widget.adminChatReceiverId : null,
        messageDocId: _channel.isNotEmpty ? 'call_$_channel' : null,
      ));
    }

    // Navigate away FIRST so the user never sees the black AgoraRTC screen
    if (wasMinimized) {
      navigatorKey.currentState?.popUntil(
        (route) => route.settings.name == activeCallRouteName || route.isFirst,
      );
    }
    CallOverlayManager().reset();

    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      // Show feedback snackbar after pop
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final scaffoldCtx = navigatorKey.currentContext;
        if (scaffoldCtx != null) {
          ScaffoldMessenger.of(scaffoldCtx).showSnackBar(
            SnackBar(
              content: Text(
                wasDeclined ? 'Call declined' : (wasNoAnswer ? 'No answer' : 'Call ended'),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      });
    }

    // Release engine resources after navigation (fire-and-forget)
    if (_engineInitialized) {
      unawaited(_releaseEngineAsync());
    }
    unawaited(_stopForegroundService());
  }


  Future<void> _exit() async {
    CallOverlayManager().reset();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    unawaited(_stopForegroundService());
  }

  /// Releases the Agora engine; safe to call fire-and-forget from dispose().
  Future<void> _releaseEngineAsync() async {
    try {
      if (_joined) await _engine.leaveChannel();
      await _engine.release();
    } catch (e) {
      debugPrint("Engine cleanup error: $e");
    }
  }

  Future<void> _startForegroundService() async {
    if (_channel.isEmpty) return;
    if (_foregroundServiceStarted) return;
    _foregroundServiceStarted = true;
    await CallForegroundServiceManager.startOngoingCall(
      callType: 'audio',
      otherUserName: widget.otherUserName,
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

  // ================= TOGGLE SPEAKER =================
  Future<void> _toggleSpeaker() async {
    setState(() => _speakerOn = !_speakerOn);
    if (_engineInitialized) {
      await _engine.setEnableSpeakerphone(_speakerOn);
    }
  }

  // ================= CONNECTIVITY =================
  void _listenConnectivity() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      if (!mounted) return;
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      setState(() {
        _connectionStatus = hasConnection ? null : 'Reconnecting...';
      });
      if (!hasConnection && _callActive) {
        // Auto-end if connectivity fully drops for too long
        Future.delayed(_kConnectivityLossTimeout, () {
          if (mounted && _connectionStatus != null) _endCall();
        });
      }
    });
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        // When back button is pressed, minimize the call instead of closing
        await _minimizeCall();
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _callActive
                  ? [
                      const Color(0xFF0D47A1), // Deep blue
                      const Color(0xFF1565C0), // Medium blue
                      const Color(0xFF1976D2), // Lighter blue
                    ]
                  : [
                      const Color(0xFF880E4F), // Deep pink
                      const Color(0xFF6A1B9A), // Purple
                      const Color(0xFF4A148C), // Deep purple
                    ],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    // Top minimize button
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16, top: 12),
                        child: CallMinimizeButton(onPressed: _minimizeCall),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Main content
                    Expanded(
                      child: _callActive ? _buildActiveCallUI() : _buildOutgoingCallUI(),
                    ),
                  ],
                ),
                // Connectivity overlay banner
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: ConnectionStatusOverlay(message: _connectionStatus),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOutgoingCallUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Top section with receiver info
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated phone icon with pulse effect
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 1500),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 0.9 + (value * 0.1),
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFF6B6B), // Coral red
                            Color(0xFFEE5A6F), // Dark coral
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B6B).withOpacity(0.5),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.phone_forwarded,
                          size: 80,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
              // Receiver name with fade-in animation
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 600),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: child,
                  );
                },
                child: Text(
                  widget.otherUserName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              // Call type badge
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.phone,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Voice Call',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              // Ringing status with animated dots
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 1000),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: 0.7 + (value * 0.3),
                    child: child,
                  );
                },
                child: Text(
                  _isCallRinging && !_remoteAccepted ? 'Calling...' : 'Connecting...',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              if (_isCallRinging && widget.isOutgoingCall) ...[
                const SizedBox(height: 20),
                _buildModernRingingAnimation(),
              ],
            ],
          ),
        ),
        // Bottom controls
        Padding(
          padding: const EdgeInsets.only(bottom: 50.0),
          child: _buildOutgoingControls(),
        ),
      ],
    );
  }

  Widget _buildActiveCallUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const SizedBox(height: 60),
        // Active call info
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.phone_in_talk,
                color: Colors.white,
                size: 100,
              ),
              const SizedBox(height: 30),
              const Text(
                'Connected',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.otherUserName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  _format(_duration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Control buttons
        Padding(
          padding: const EdgeInsets.only(bottom: 50.0),
          child: _buildActiveControls(),
        ),
      ],
    );
  }

  Widget _buildOutgoingControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _modernControlBtn(
          icon: _micMuted ? Icons.mic_off : Icons.mic,
          color: _micMuted ? const Color(0xFFFF9800) : Colors.white,
          onPressed: _callActive ? _toggleMute : null,
          active: !_micMuted && _callActive,
        ),
        _modernCallBtn(
          icon: Icons.call_end,
          color: const Color(0xFFF44336),
          onPressed: _endCall,
          size: 72,
        ),
        _modernControlBtn(
          icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
          color: _speakerOn ? const Color(0xFF2196F3) : Colors.white,
          onPressed: (_callActive || _isCallRinging) ? _toggleSpeaker : null,
          active: _speakerOn,
        ),
      ],
    );
  }

  Widget _buildActiveControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _modernControlBtn(
          icon: _micMuted ? Icons.mic_off : Icons.mic,
          color: _micMuted ? const Color(0xFFFF9800) : Colors.white,
          onPressed: _toggleMute,
          active: !_micMuted,
        ),
        _modernCallBtn(
          icon: Icons.call_end,
          color: const Color(0xFFF44336),
          onPressed: _endCall,
          size: 72,
        ),
        _modernControlBtn(
          icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
          color: _speakerOn ? const Color(0xFF2196F3) : Colors.white,
          onPressed: _toggleSpeaker,
          active: _speakerOn,
        ),
      ],
    );
  }

  Widget _modernCallBtn({
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    double size = 72,
  }) {
    return GestureDetector(
      onTap: onPressed,
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
                    color.withOpacity(0.8),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: size * 0.45),
            ),
          );
        },
      ),
    );
  }

  Widget _modernControlBtn({
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    bool active = false,
    double size = 64,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.3) : Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(
            color: onPressed == null ? Colors.white30 : color,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: (onPressed == null ? Colors.white30 : color).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: onPressed == null ? Colors.white30 : color,
          size: size * 0.5,
        ),
      ),
    );
  }

  // Modern pulsing animation for ringing state
  Widget _buildModernRingingAnimation() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return TweenAnimationBuilder<double>(
          key: ValueKey(index),
          duration: Duration(milliseconds: 800 + (index * 150)),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            final double scale = 0.5 + (value * 0.5);
            final double opacity = 1.0 - (value * 0.6);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(opacity),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(opacity * 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              transform: Matrix4.identity()..scale(scale),
            );
          },
          onEnd: () {
            if (mounted) setState(() {});
          },
        );
      }),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timeoutTimer?.cancel();
    _callTimer?.cancel();
    _responseSubscription?.cancel();
    _connectivitySubscription?.cancel();
    // Release Agora engine if not already released by _endCall
    if (_engineInitialized) {
      unawaited(_releaseEngineAsync());
    }
    unawaited(_stopForegroundService());
    super.dispose();
  }

  String _format(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}
