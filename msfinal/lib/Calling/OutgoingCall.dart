import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart'; // Add this import
import '../Chat/ChatlistScreen.dart';
import '../Chat/call_overlay_manager.dart';
import '../navigation/app_navigation.dart';
import '../pushnotification/pushservice.dart';
import 'tokengenerator.dart';
import 'call_history_model.dart';
import 'call_history_service.dart';

class CallScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final String currentUserImage;
  final String otherUserId;
  final String otherUserName;
  final String otherUserImage;
  final bool isOutgoingCall; // Add this to identify outgoing call

  const CallScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserImage,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserImage,
    this.isOutgoingCall = true, // Default to outgoing call
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
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

  Timer? _timeoutTimer;
  Timer? _callTimer;
  Duration _duration = Duration.zero;

  // Audio player for ringtone
  late AudioPlayer _ringtonePlayer;
  bool _isPlayingRingtone = false;
  StreamSubscription<Map<String, dynamic>>? _responseSubscription;

  // Call history tracking
  String? _callHistoryId;
  DateTime? _callStartTime;

  @override
  void initState() {
    super.initState();
    _ringtonePlayer = AudioPlayer();
    _setupAudioPlayer();
    _listenForCallResponse();
    _startCall();
  }

  // ================= SETUP AUDIO PLAYER =================
// ================= SETUP AUDIO PLAYER =================
  void _setupAudioPlayer() {
    // Listen for player state changes
    _ringtonePlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (!mounted) return;

      setState(() {
        _isPlayingRingtone = state == PlayerState.playing;
      });
    });


    // Handle errors (new way in audioplayers ^5.4.2)
    _ringtonePlayer.onPlayerComplete.listen((_) {
      // When ringtone completes (won't happen with loop, but good to have)
      debugPrint('Ringtone playback completed');
    });

    // For error handling in newer versions


  }

  void _listenForCallResponse() {
    _responseSubscription = NotificationService.callResponses.listen((data) {
      final type = data['type']?.toString();
      final channelName = data['channelName']?.toString();
      if (channelName != null && channelName.isNotEmpty && channelName != _channel) {
        return;
      }

      if (type == 'call_response') {
        final accepted = data['accepted'] == 'true';
        if (!accepted) {
          _endCall();
        }
      } else if (type == 'call_ended') {
        _endCall();
      }
    });
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
    );
    _syncOverlayState();
  }

  void _syncOverlayState() {
    final statusText = _callActive
        ? 'Connected'
        : (_isCallRinging ? 'Calling...' : 'Connecting...');
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
  // ================= PLAY RINGTONE =================
  Future<void> _playRingtone() async {
    if (!widget.isOutgoingCall) return;

    try {
      await _stopRingtone();

      // 🔥 PLAY FIRST (important for iOS)
      await _ringtonePlayer.play(
        AssetSource('images/outcall.mp3'),
        volume: _speakerOn ? 1.0 : 0.8,
      );

      // 🔥 THEN enable looping
      await _ringtonePlayer.setReleaseMode(ReleaseMode.loop);

      debugPrint('Started playing ringtone');
    } catch (e) {
      debugPrint('Error playing ringtone: $e');
    }
  }



  // ================= STOP RINGTONE =================
  Future<void> _stopRingtone() async {
    try {
      await _ringtonePlayer.stop();
      await _ringtonePlayer.release(); // 🔥 important for iOS

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
            setState(() => _joined = true);
            _syncOverlayState();
          },
          onUserJoined: (_, uid, __) {
            setState(() {
              _remoteUid = uid;
              _isCallRinging = false; // Stop ringing state
              _callActive = true;
            });
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

      // Timeout if no answer
      _timeoutTimer = Timer(const Duration(seconds: 30), () {
        if (_remoteUid == null) {
          if (widget.isOutgoingCall) {
            NotificationService.sendMissedCallNotification(
              callerId: widget.currentUserId,
              callerName: widget.otherUserName,
            );
          }
          _endCall();
        }
      });
    } catch (e) {
      debugPrint('Init error: $e');
      _exit();
    }
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

    _callTimer?.cancel();
    _timeoutTimer?.cancel();
    _responseSubscription?.cancel();

    await _stopRingtone();

    if (_engineInitialized) {
      try {
        await _engine.leaveChannel();
        await _engine.release();
      } catch (e) {
        debugPrint("Engine cleanup error: $e");
      }
    }

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


  void _exit() {
    CallOverlayManager().reset();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  // ================= TOGGLE SPEAKER =================
  Future<void> _toggleSpeaker() async {
    setState(() => _speakerOn = !_speakerOn);
    if (_engineInitialized) {
      await _engine.setEnableSpeakerphone(_speakerOn);
    }

    // Update ringtone volume based on speaker mode
    if (_isPlayingRingtone) {
      if (_speakerOn) {
        await _ringtonePlayer.setVolume(1.0); // Louder for speaker
      } else {
        await _ringtonePlayer.setVolume(0.8); // Softer for earpiece
      }
    }
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
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16, bottom: 24),
                    child: IconButton(
                      onPressed: _minimizeCall,
                      icon: const Icon(Icons.minimize, color: Colors.white, size: 32),
                      tooltip: 'Minimize call',
                    ),
                  ),
                ),
                // Ringing animation when call is ringing
                if (_isCallRinging && widget.isOutgoingCall)
                  _buildRingingAnimation(),

                Icon(
                  _callActive
                      ? Icons.phone_in_talk
                      : (_isCallRinging ? Icons.phone_forwarded : Icons.phone),
                  color: Colors.white,
                  size: 80,
                ),
                const SizedBox(height: 20),
                Text(
                  _callActive
                      ? 'Connected with ${widget.otherUserName}'
                      : (_isCallRinging
                      ? 'Calling ${widget.otherUserName}...'
                      : 'Connecting...'),
                  style: const TextStyle(color: Colors.white, fontSize: 22),
                ),
                const SizedBox(height: 10),
                Text(
                  _callActive
                      ? _format(_duration)
                      : (_isCallRinging ? 'Ringing...' : 'Connecting...'),
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute button (only enabled when call is active)
                    IconButton(
                      icon: Icon(
                        _micMuted ? Icons.mic_off : Icons.mic,
                        color: _callActive ? Colors.white : Colors.white30,
                        size: 36,
                      ),
                      onPressed: _callActive ? () {
                        setState(() => _micMuted = !_micMuted);
                        _engine.muteLocalAudioStream(_micMuted);
                      } : null,
                    ),
                    // End call button
                    IconButton(
                      icon: const Icon(Icons.call_end,
                          color: Colors.red, size: 56),
                      onPressed: _endCall,
                    ),
                    // Speaker button
                    IconButton(
                      icon: Icon(
                        _speakerOn
                            ? Icons.volume_up
                            : Icons.volume_off,
                        color: _callActive || _isCallRinging ? Colors.white : Colors.white30,
                        size: 36,
                      ),
                      onPressed: (_callActive || _isCallRinging) ? _toggleSpeaker : null,
                    ),
                  ],
                ),
                // Ringtone status indicator (optional)
                if (_isPlayingRingtone && widget.isOutgoingCall)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(
                      'Playing ringtone ${_speakerOn ? '(Speaker)' : '(Earpiece)'}',
                      style: const TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= RINGING ANIMATION =================
  Widget _buildRingingAnimation() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(6),
            ),
            curve: Curves.easeInOut,
          );
        }),
      ),
    );
  }

  String _format(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _callTimer?.cancel();
    _timeoutTimer?.cancel();
    _responseSubscription?.cancel();
    _ringtonePlayer.dispose(); // Dispose audio player
    super.dispose();
  }
}
