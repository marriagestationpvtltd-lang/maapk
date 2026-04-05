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
  bool _ending = false;
  bool _connecting = false;

  Timer? _ringTimer;
  Timer? _callTimer;
  Duration _duration = Duration.zero;
  StreamSubscription<Map<String, dynamic>>? _cancelSubscription;

  final _ringtonePlayer = FlutterRingtonePlayer();

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
      // Cancel the audio call notification (ID: 1001)
      final plugin = FlutterLocalNotificationsPlugin();
      plugin.cancel(1001);
      debugPrint('✅ Cancelled call notification after screen mounted');
    } catch (e) {
      debugPrint('Error cancelling call notification: $e');
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
      debugPrint('✅ Incoming call ringtone started');
    } catch (e) {
      debugPrint('Error playing incoming call ringtone: $e');
    }
  }

  Future<void> _stopRingtone() async {
    try {
      await _ringtonePlayer.stop();
      debugPrint('✅ Incoming call ringtone stopped');
    } catch (e) {
      debugPrint('Error stopping incoming call ringtone: $e');
    }
  }

  void _listenForCallCancelled() {
    _cancelSubscription = NotificationService.callResponses.listen((data) {
      final type = data['type']?.toString();
      if (type == 'call_cancelled' || type == 'call_ended') {
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
    _chatRoomId = widget.callData['chatRoomId']?.toString() ?? '';
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
      await _stopRingtone();

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
            if (mounted) setState(() => _joined = true);
            unawaited(_startForegroundService());
          },
          onUserJoined: (_, uid, __) {
            if (mounted) {
              setState(() {
                _remoteUid = uid;
                _callActive = true;
                _connecting = false;
              });
            }
            _startCallTimer();
            _syncOverlayState();
          },
          onUserOffline: (_, __, ___) {
            _endCall();
          },
          onError: (c, m) {
            debugPrint('Agora error $c $m');
            if (_remoteUid == null && !_ending) {
              _endCall();
            }
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

      if (mounted) setState(() => _connecting = true);
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
    await _stopRingtone();
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
    await _stopRingtone();
    await NotificationService.sendMissedCallNotification(
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
        callType: 'audio',
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
        callType: 'audio',
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

    // Write inline call message to chat (recipient side backup)
    if (_chatRoomId.isNotEmpty) {
      unawaited(CallHistoryService.logCallMessageInChat(
        callerId: _callerId,
        callType: 'audio',
        callStatus: _callActive ? 'completed' : 'missed',
        duration: _duration.inSeconds,
        chatRoomId: _chatRoomId,
        messageDocId: _channel.isNotEmpty ? 'call_$_channel' : null,
      ));
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
        } else if (_connecting) {
          // If still connecting, end the call
          await _endCall();
        } else {
          // If call is not yet accepted, reject it
          await _rejectCall();
        }
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _callActive
                  ? [
                      const Color(0xFF1A237E), // Deep indigo
                      const Color(0xFF0D47A1), // Deep blue
                      const Color(0xFF01579B), // Darker blue
                    ]
                  : [
                      const Color(0xFF6A1B9A), // Deep purple
                      const Color(0xFF4A148C), // Darker purple
                      const Color(0xFF1A237E), // Deep indigo
                    ],
            ),
          ),
          child: SafeArea(
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
                  child: _callActive
                      ? _buildActiveCallUI()
                      : (_connecting ? _buildConnectingUI() : _buildIncomingCallUI()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectingUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.phone_in_talk, color: Colors.white, size: 80),
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
    );
  }

  Widget _buildIncomingCallUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const SizedBox(height: 40),
        // Top section with caller info
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated avatar with pulse effect
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
                            Color(0xFF00E5FF), // Cyan
                            Color(0xFF2979FF), // Blue
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2979FF).withOpacity(0.5),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.person,
                          size: 80,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
              // Caller name with fade-in animation
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
                  _callerName,
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
              // Call type with icon
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 800),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: child,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
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
                  ],
                ),
              ),
              const SizedBox(height: 30),
              // Incoming call text with pulse animation
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 1000),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: 0.7 + (value * 0.3),
                    child: child,
                  );
                },
                child: const Text(
                  'Incoming Call...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Bottom section with buttons
        Padding(
          padding: const EdgeInsets.only(bottom: 50.0, left: 20, right: 20),
          child: _incomingControls(),
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
                _callerName,
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
          child: _activeControls(),
        ),
      ],
    );
  }

  Widget _incomingControls() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      _modernCallBtn(
        icon: Icons.call,
        color: const Color(0xFF4CAF50), // Green
        onPressed: _acceptCall,
        loading: _processing,
        label: 'Accept',
      ),
      _modernCallBtn(
        icon: Icons.call_end,
        color: const Color(0xFFF44336), // Red
        onPressed: _rejectCall,
        label: 'Decline',
      ),
    ],
  );

  Widget _activeControls() => Row(
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
        onPressed: _engineInitialized
            ? () {
                setState(() => _speakerOn = !_speakerOn);
                _engine.setEnableSpeakerphone(_speakerOn);
              }
            : null,
        active: _speakerOn,
      ),
    ],
  );

  Widget _modernCallBtn({
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    bool loading = false,
    String? label,
    double size = 72,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
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
                  child: loading
                      ? const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          ),
                        )
                      : Icon(icon, color: Colors.white, size: size * 0.45),
                ),
              );
            },
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
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
          color: active
              ? color.withOpacity(0.3)
              : Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(
            color: color,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: color,
          size: size * 0.5,
        ),
      ),
    );
  }

  String _format(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  void dispose() {
    WakelockPlus.disable();
    _ringTimer?.cancel();
    _callTimer?.cancel();
    _cancelSubscription?.cancel();
    // FlutterRingtonePlayer doesn't have a dispose method, stop is called in _endCall
    // Release Agora engine if not already released
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
