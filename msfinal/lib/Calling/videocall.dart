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
import 'call_foreground_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final String currentUserImage;
  final String otherUserId;
  final String otherUserName;
  final String otherUserImage;
  final bool isOutgoingCall; // Add this

  const VideoCallScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserImage,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserImage,
    this.isOutgoingCall = true, // Default to outgoing
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
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
  bool _cameraOn = true;
  bool _frontCamera = true;
  bool _ending = false;
  bool _remoteAccepted = false;
  bool _isCallRinging = true; // Add ringing state
  bool _foregroundServiceStarted = false;

  Timer? _timeoutTimer;
  Timer? _callTimer;
  Duration _duration = Duration.zero;

  StreamSubscription? _responseSubscription;

  // Audio player for ringtone
  late AudioPlayer _ringtonePlayer;
  bool _isPlayingRingtone = false;

  // Call history tracking
  String? _callHistoryId;
  DateTime? _callStartTime;

  @override
  void initState() {
    super.initState();
    _ringtonePlayer = AudioPlayer();
    _setupAudioPlayer();
    _startCall();
    _listenForCallResponse();
  }

  // ================= SETUP AUDIO PLAYER =================
  void _setupAudioPlayer() {
    // Listen for player state changes
    _ringtonePlayer.onPlayerStateChanged.listen((PlayerState state) {
      debugPrint('Player state changed: $state');
      if (state == PlayerState.playing) {
        setState(() => _isPlayingRingtone = true);
      } else {
        setState(() => _isPlayingRingtone = false);
      }
    });

    // Listen for playback completion
    _ringtonePlayer.onPlayerComplete.listen((_) {
      debugPrint('Ringtone playback completed');
    });

    // Log listener
    _ringtonePlayer.onLog.listen((log) {
      if (log == null) {
        debugPrint('Audio player error: ${log}');
      }
    });
  }

  // ================= PLAY RINGTONE =================
  Future<void> _playRingtone() async {
    if (!widget.isOutgoingCall) return;

    try {
      await _stopRingtone();

      await _ringtonePlayer.play(
        AssetSource('images/outcall.mp3'),
        volume: _speakerOn ? 1.0 : 0.8,
      );

      await _ringtonePlayer.setReleaseMode(ReleaseMode.loop);

    } catch (e) {
      debugPrint('Error playing ringtone: $e');
    }
  }

  Future<void> _stopRingtone() async {
    try {
      await _ringtonePlayer.stop();
      await _ringtonePlayer.release(); // important

      if (!mounted) return;
      setState(() => _isPlayingRingtone = false);
    } catch (e) {
      debugPrint('Error stopping ringtone: $e');
    }
  }

  // ================= STOP RINGTONE =================


  // ================= LISTEN FOR CALL RESPONSE =================
  void _listenForCallResponse() {
    _responseSubscription = NotificationService.callResponses.listen((data) {
      final type = data['type']?.toString();
      final channelName = data['channelName']?.toString();
      if (channelName != null && channelName.isNotEmpty && channelName != _channel) {
        return;
      }

      if (type == 'video_call_response') {
        final accepted = data['accepted'] == 'true';
        if (mounted) {
          setState(() {
            _remoteAccepted = accepted;
            if (!accepted) {
              _isCallRinging = false;
            }
          });
        }

        if (!accepted) {
          _endCall();
        } else {
          _syncOverlayState();
        }
      } else if (type == 'video_call_ended') {
        _endCall();
      }
    });
  }

  void _initializeOverlay() {
    CallOverlayManager().startCall(
      callType: 'video',
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
        : (_isCallRinging
            ? (_remoteAccepted ? 'Connecting video...' : 'Calling...')
            : 'Connecting...');

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

  // ================= START CALL =================
  Future<void> _startCall() async {
    try {
      if (widget.isOutgoingCall) {
        await _playRingtone();
      }

      // Permissions
      if (!(await Permission.microphone.request()).isGranted) return;
      if (!(await Permission.camera.request()).isGranted) return;

      // ✅ UID FIRST
      _localUid = Random().nextInt(999999);

      // ✅ CHANNEL FIRST
      _channel =
      'videocall_${widget.currentUserId.substring(0, min(4, widget.currentUserId.length))}'
          '_${widget.otherUserId.substring(0, min(4, widget.otherUserId.length))}'
          '_${DateTime.now().millisecondsSinceEpoch}';

      if (_channel.length > 64) {
        _channel = _channel.substring(0, 64);
      }

      _initializeOverlay();

      // ✅ TOKEN
      _token = await AgoraTokenService.getToken(
        channelName: _channel,
        uid: _localUid,
      );

      // ✅ SEND NOTIFICATION AFTER CHANNEL EXISTS
      if (widget.isOutgoingCall) {
        await NotificationService.sendVideoCallNotification(
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
          callType: CallType.video,
          initiatedBy: widget.currentUserId,
        );
        _callStartTime = DateTime.now();
      }

      // Agora init
      _engine = createAgoraRtcEngine();

      await _engine.initialize(
        RtcEngineContext(
          appId: AgoraTokenService.appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
      _engineInitialized = true;

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (_, __) {
            setState(() => _joined = true);
            _syncOverlayState();
            unawaited(_startForegroundService());
          },
          onUserJoined: (_, uid, __) {
            setState(() {
              _remoteUid = uid;
              _isCallRinging = false;
              _callActive = true;
            });
            _stopRingtone();
            _startCallTimer();
            _syncOverlayState();
          },
          onUserOffline: (_, __, ___) => _endCall(),
          onError: (code, msg) => debugPrint('Agora error: $code $msg'),
        ),
      );

      await _engine.enableVideo();
      await _engine.enableAudio();
      await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      await _engine.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 640, height: 480),
          frameRate: 15,
        ),
      );

      await _engine.startPreview();

      await _engine.joinChannel(
        token: _token,
        channelId: _channel,
        uid: _localUid,
        options: const ChannelMediaOptions(
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );

      // Timeout
      _timeoutTimer = Timer(const Duration(seconds: 30), () {
        if (_remoteUid == null) _endCall();
      });

    } catch (e) {
      debugPrint("Video call init error: $e");
      await _exit();
    }
  }


  // ================= CALL TIMER =================
  void _startCallTimer() {
    _timeoutTimer?.cancel();
    setState(() => _callActive = true);
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

    // Always stop ringtone when ending call
    await _stopRingtone();
    await _stopForegroundService();

    // Update call history
    if (_callHistoryId != null && _callHistoryId!.isNotEmpty) {
      CallStatus callStatus;
      if (_callActive && _remoteUid != null) {
        // Call was connected
        callStatus = CallStatus.completed;
      } else if (_remoteUid == null) {
        // Call was not answered
        callStatus = CallStatus.missed;
      } else {
        // Call was cancelled
        callStatus = CallStatus.cancelled;
      }

      await CallHistoryService.updateCallEnd(
        callId: _callHistoryId!,
        status: callStatus,
        duration: _duration.inSeconds,
      );
    }

    if (_callActive) {
      await NotificationService.sendVideoCallEndedNotification(
        recipientUserId: widget.otherUserId,
        callerName: widget.currentUserName,
        reason: 'ended',
        duration: _duration.inSeconds,
        channelName: _channel,
      );
    }

    if (_joined) {
      await _engine.leaveChannel();
    }
    if (_engineInitialized) {
      await _engine.release();
    }

    if (wasMinimized) {
      navigatorKey.currentState?.popUntil(
        (route) => route.settings.name == activeCallRouteName || route.isFirst,
      );
    }

    CallOverlayManager().reset();

    await _exit();
  }

  Future<void> _exit() async {
    await _stopForegroundService();
    CallOverlayManager().reset();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _startForegroundService() async {
    if (_channel.isEmpty) return;
    if (_foregroundServiceStarted) return;
    _foregroundServiceStarted = true;
    await CallForegroundServiceManager.startOngoingCall(
      callType: 'video',
      otherUserName: widget.otherUserName,
      callId: _channel,
    );
  }

  Future<void> _stopForegroundService() async {
    if (!_foregroundServiceStarted) return;
    try {
      _foregroundServiceStarted = false;
      await CallForegroundServiceManager.stopCallService();
    } catch (e) {
      debugPrint('Error stopping call foreground service: $e');
    }
  }

  // ================= TOGGLE CAMERA =================
  Future<void> _toggleCamera() async {
    if (_joined) {
      await _engine.switchCamera();
      setState(() => _frontCamera = !_frontCamera);
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
          child: Stack(
            children: [
            // Remote video (full screen)
            if (_remoteUid != null)
              AgoraVideoView(
                controller: VideoViewController.remote(
                  rtcEngine: _engine,
                  canvas: VideoCanvas(uid: _remoteUid),
                  connection: RtcConnection(channelId: _channel),
                ),
              )
            else if (_callActive)
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
                        widget.otherUserName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _remoteAccepted ? 'Connecting video...' : 'Calling...',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Ringing animation for outgoing calls
                      if (_isCallRinging && widget.isOutgoingCall)
                        _buildRingingAnimation(),

                      Icon(
                        _isCallRinging ? Icons.videocam_outlined : Icons.videocam,
                        color: Colors.white54,
                        size: 100,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.otherUserName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isCallRinging ? 'Calling...' : 'Connecting...',
                        style: const TextStyle(color: Colors.white70, fontSize: 18),
                      ),
                      const SizedBox(height: 10),
                      if (_isCallRinging && _joined)
                        Text(
                          'Waiting for answer...',
                          style: TextStyle(color: Colors.orange.shade300),
                        ),

                      // Ringtone status indicator
                      if (_isPlayingRingtone && widget.isOutgoingCall)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.music_note, color: Colors.green, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Playing ringtone ${_speakerOn ? '(Speaker)' : '(Earpiece)'}',
                                style: const TextStyle(color: Colors.green, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            // Local video preview (small overlay)
            if (_cameraOn && _joined)
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

            // Top info bar
             Positioned(
               top: 40,
               left: 20,
               child: Row(
                 children: [
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                     decoration: BoxDecoration(
                       color: Colors.black54,
                       borderRadius: BorderRadius.circular(20),
                     ),
                     child: Row(
                       children: [
                         Icon(
                           _callActive ? Icons.videocam :
                           (_isCallRinging ? Icons.videocam_outlined : Icons.videocam),
                           color: Colors.white,
                           size: 20,
                         ),
                         const SizedBox(width: 8),
                         Text(
                           _callActive
                               ? _format(_duration)
                               : (_isCallRinging ? 'Calling...' : 'Connecting...'),
                           style: const TextStyle(color: Colors.white),
                         ),
                       ],
                     ),
                   ),
                   const SizedBox(width: 12),
                   Container(
                     decoration: BoxDecoration(
                       color: Colors.black54,
                       borderRadius: BorderRadius.circular(20),
                     ),
                     child: IconButton(
                       onPressed: _minimizeCall,
                       icon: const Icon(Icons.minimize, color: Colors.white, size: 24),
                       tooltip: 'Minimize call',
                     ),
                   ),
                 ],
               ),
             ),

            // Bottom controls
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _controlButton(
                    icon: _micMuted ? Icons.mic_off : Icons.mic,
                    color: Colors.white,
                    onPressed: _callActive ? () {
                      setState(() => _micMuted = !_micMuted);
                      _engine.muteLocalAudioStream(_micMuted);
                    } : null,
                  ),
                  _controlButton(
                    icon: _cameraOn ? Icons.videocam : Icons.videocam_off,
                    color: Colors.white,
                    onPressed: _joined ? () {
                      setState(() => _cameraOn = !_cameraOn);
                      _engine.enableLocalVideo(_cameraOn);
                    } : null,
                  ),
                  _controlButton(
                    icon: Icons.call_end,
                    color: Colors.red,
                    onPressed: _endCall,
                    size: 56,
                  ),
                  _controlButton(
                    icon: Icons.switch_camera,
                    color: Colors.white,
                    onPressed: _joined ? _toggleCamera : null,
                  ),
                  _controlButton(
                    icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
                    color: Colors.white,
                    onPressed: (_joined || _isCallRinging) ? _toggleSpeaker : null,
                  ),
                ],
              ),
            ),
            ],
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
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 8.0, end: 12.0),
            duration: Duration(milliseconds: 600 + (index * 200)),
            curve: Curves.easeInOut,
            builder: (context, size, child) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(size / 2),
                ),
              );
            },
            child: null,
          );
        }),
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    double size = 48,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: onPressed != null ? Colors.black54 : Colors.black26,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: onPressed != null ? color : Colors.white30, size: size * 0.6),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
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
    unawaited(_stopForegroundService());
    super.dispose();
  }
}
