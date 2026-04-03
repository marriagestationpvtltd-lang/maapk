import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart'; // Add this import
import '../pushnotification/pushservice.dart';
import 'tokengenerator.dart';

class VideoCallScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final String otherUserId;
  final String otherUserName;
  final bool isOutgoingCall; // Add this

  const VideoCallScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.otherUserId,
    required this.otherUserName,
    this.isOutgoingCall = true, // Default to outgoing
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late RtcEngine _engine;

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

  Timer? _timeoutTimer;
  Timer? _callTimer;
  Duration _duration = Duration.zero;

  StreamSubscription? _responseSubscription;

  // Audio player for ringtone
  late AudioPlayer _ringtonePlayer;
  bool _isPlayingRingtone = false;

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
      if (data['recipientUid'] == _localUid.toString()) {
        final accepted = data['accepted'] == 'true';
        setState(() => _remoteAccepted = accepted);

        if (!accepted) {
          _endCall();
        }
      }
    });
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
      }

      // Agora init
      _engine = createAgoraRtcEngine();

      await _engine.initialize(
        RtcEngineContext(
          appId: AgoraTokenService.appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (_, __) {
            setState(() => _joined = true);
          },
          onUserJoined: (_, uid, __) {
            setState(() {
              _remoteUid = uid;
              _isCallRinging = false;
              _callActive = true;
            });
            _stopRingtone();
            _startCallTimer();
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
      _exit();
    }
  }


  // ================= CALL TIMER =================
  void _startCallTimer() {
    _timeoutTimer?.cancel();
    setState(() => _callActive = true);

    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _duration += const Duration(seconds: 1));
    });
  }

  // ================= END CALL =================
  Future<void> _endCall() async {
    if (_ending) return;
    _ending = true;

    _callTimer?.cancel();
    _timeoutTimer?.cancel();
    _responseSubscription?.cancel();

    // Always stop ringtone when ending call
    await _stopRingtone();

    if (_callActive) {
      await NotificationService.sendVideoCallEndedNotification(
        recipientUserId: widget.otherUserId,
        callerName: widget.currentUserName,
        reason: 'ended',
        duration: _duration.inSeconds,
      );
    }

    if (_joined) {
      await _engine.leaveChannel();
    }
    await _engine.release();

    _exit();
  }

  void _exit() {
    if (mounted) Navigator.pop(context);
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
    await _engine.setEnableSpeakerphone(_speakerOn);

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
    return Scaffold(
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
              child: Container(
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
    super.dispose();
  }
}