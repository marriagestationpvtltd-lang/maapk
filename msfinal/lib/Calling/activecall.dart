import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'tokengenerator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../Chat/ChatlistScreen.dart';
import '../Chat/call_overlay_manager.dart';
import '../navigation/app_navigation.dart';

class ActiveCallScreen extends StatefulWidget {
  final String channel;
  final int localUid;
  final int remoteUid;
  final String currentUserId;
  final String otherUserId;
  final String callerName;
  final String recipientName;

  const ActiveCallScreen({
    super.key,
    required this.channel,
    required this.localUid,
    required this.remoteUid,
    required this.currentUserId,
    required this.otherUserId,
    required this.callerName,
    required this.recipientName,
  });

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> {
  late RtcEngine _engine;
  bool _joined = false;
  bool _micMuted = false;
  bool _speakerOn = false;
  Timer? _callTimer;
  Duration _duration = Duration.zero;
  int _callStartTime = 0;

  @override
  void initState() {
    super.initState();
    _callStartTime = DateTime.now().millisecondsSinceEpoch;
    _initEngine();
    _startCallTimer();
    _initializeOverlay();
  }

  void _initializeOverlay() {
    CallOverlayManager().startCall(
      callType: 'audio',
      otherUserName: widget.recipientName,
      otherUserId: widget.otherUserId,
      currentUserId: widget.currentUserId,
      currentUserName: widget.callerName,
      onMaximize: () {
        navigatorKey.currentState?.popUntil(
          (route) => route.settings.name == activeCallRouteName || route.isFirst,
        );
      },
      onEnd: _endCall,
    );
    _syncOverlayState();
  }

  void _syncOverlayState() {
    final statusText = _joined ? 'Connected' : 'Connecting...';
    CallOverlayManager().updateCallState(
      statusText: statusText,
      duration: _duration,
    );
  }

  Future<void> _minimizeCall() async {
    CallOverlayManager().minimizeCall();
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: minimizedCallHostRouteName),
        builder: (_) => ChatListScreen(),
      ),
    );
  }

  Future<void> _initEngine() async {
    try {
      // Check microphone permission
      if (!(await Permission.microphone.request()).isGranted) {
        print('❌ No mic permission');
        _endCall();
        return;
      }

      // Create Agora engine
      _engine = createAgoraRtcEngine();
      await _engine.initialize(RtcEngineContext(
        appId: AgoraTokenService.appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      // Event handlers
      _engine.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (conn, elapsed) {
          print('✅ Active call joined');
          setState(() => _joined = true);
          _syncOverlayState();
        },
        onUserOffline: (conn, remoteUid, reason) {
          print('👋 Remote user left');
          _endCall();
        },
        onError: (err, msg) {
          print('❌ Active call error: $err - $msg');
          _endCall();
        },
      ));

      // Enable audio
      await _engine.enableAudio();
      await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      // Fetch token from your server
      final token = await AgoraTokenService.getToken(
        channelName: widget.channel,
        uid: widget.localUid,
      );
      print('🔑 Token received: ${token.substring(0, 20)}...');

      // Join channel with token
      await _engine.joinChannel(
        token: token,
        channelId: widget.channel,
        uid: widget.localUid,
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true,
        ),
      );

    } catch (e) {
      print('❌ Init engine error: $e');
      _endCall();
    }
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _duration += const Duration(seconds: 1));
        _syncOverlayState();
      }
    });
  }

  Future<void> _endCall() async {
    final wasMinimized = CallOverlayManager().isMinimized;

    _callTimer?.cancel();
    if (_joined) await _engine.leaveChannel();
    await _engine.release();

    if (wasMinimized) {
      navigatorKey.currentState?.popUntil(
        (route) => route.settings.name == activeCallRouteName || route.isFirst,
      );
    }

    CallOverlayManager().reset();

    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Minimize button at the top
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16, top: 12),
                child: IconButton(
                  onPressed: _minimizeCall,
                  icon: const Icon(Icons.minimize, color: Colors.white, size: 28),
                  tooltip: 'Minimize call',
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.phone_in_talk, color: Colors.white, size: 80),
                    const SizedBox(height: 20),
                    Text(
                      'Call with ${widget.callerName}',
                      style: const TextStyle(color: Colors.white, fontSize: 24),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _formatDuration(_duration),
                      style: const TextStyle(color: Colors.white70, fontSize: 18),
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: Icon(_micMuted ? Icons.mic_off : Icons.mic,
                              color: Colors.white, size: 40),
                          onPressed: () {
                            setState(() => _micMuted = !_micMuted);
                            _engine.muteLocalAudioStream(_micMuted);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.call_end, color: Colors.red, size: 60),
                          onPressed: _endCall,
                        ),
                        IconButton(
                          icon: Icon(_speakerOn ? Icons.volume_up : Icons.volume_off,
                              color: Colors.white, size: 40),
                          onPressed: () {
                            setState(() => _speakerOn = !_speakerOn);
                            _engine.setEnableSpeakerphone(_speakerOn);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(duration.inMinutes)}:${twoDigits(duration.inSeconds % 60)}';
  }
}