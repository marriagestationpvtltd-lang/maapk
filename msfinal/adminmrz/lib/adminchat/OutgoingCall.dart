import 'dart:async';
import 'dart:math';
import 'package:adminmrz/adminchat/services/pushservice.dart';
import 'package:adminmrz/settings/call_settings_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'tokengenerator.dart';

// Call state progression: calling → ringing → connected
enum _CallStatus { calling, ringing, connected }

class CallScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final String otherUserId;
  final String otherUserName;
  final bool isOutgoingCall;
  final VoidCallback? onMinimize;
  final VoidCallback? onEnd;
  /// Called when the call ends with (callType, status, durationSeconds).
  /// callType is always 'audio'. status is 'answered' or 'missed'.
  final void Function(String callType, String status, int durationSeconds)? onCallEnded;

  const CallScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.otherUserId,
    required this.otherUserName,
    this.isOutgoingCall = true,
    this.onMinimize,
    this.onEnd,
    this.onCallEnded,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen>
    with TickerProviderStateMixin {
  late RtcEngine _engine;

  int _localUid = 0;
  int? _remoteUid;

  String _channel = '';
  String _token = '';

  bool _callActive = false;
  bool _micMuted = false;
  bool _speakerOn = true;
  bool _videoEnabled = false;
  bool _ending = false;

  // Video
  Widget? _localVideoView;

  _CallStatus _callStatus = _CallStatus.calling;

  Timer? _timeoutTimer;
  Timer? _callTimer;
  Duration _duration = Duration.zero;

  late AudioPlayer _ringtonePlayer;
  Timer? _ringtoneRepeatTimer;

  StreamSubscription<DocumentSnapshot>? _callSignalSubscription;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _signalController;
  late Animation<double> _pulseAnimation;

  // ================= INIT =================
  @override
  void initState() {
    super.initState();
    _ringtonePlayer = AudioPlayer();

    // Pulsing avatar scale animation (when calling/ringing)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Signal bars cycling animation (when calling/ringing)
    _signalController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _setupAudio();
    _startCall();
  }

  // ================= AUDIO =================
  void _setupAudio() {
    _ringtonePlayer.setReleaseMode(ReleaseMode.stop);
    _ringtonePlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      // Schedule repeat when tone completes — state tracking is not needed here
      if (state == PlayerState.completed && widget.isOutgoingCall && !_ending) {
        _scheduleRepeat();
      }
    });
  }

  void _scheduleRepeat() {
    if (!mounted || _ending) return;
    final settings = context.read<CallSettingsProvider>();
    final interval = settings.repeatIntervalSeconds;
    _ringtoneRepeatTimer = Timer(Duration(seconds: interval), () {
      if (!mounted || _ending) return;
      _playRingtoneSingle();
    });
  }

  Future<void> _playRingtoneSingle() async {
    if (!widget.isOutgoingCall || _ending) return;
    try {
      final settings = context.read<CallSettingsProvider>();
      await _ringtonePlayer.stop();
      await _ringtonePlayer.play(
        AssetSource(settings.selectedTone.asset),
        volume: 1.0,
      );
    } catch (_) {}
  }

  Future<void> _playRingtone() async {
    if (!widget.isOutgoingCall) return;
    try {
      await _ringtonePlayer.stop();
      final settings = context.read<CallSettingsProvider>();
      await _ringtonePlayer.play(
        AssetSource(settings.selectedTone.asset),
        volume: 1.0,
      );
    } catch (_) {}
  }

  Future<void> _stopRingtone() async {
    try {
      _ringtoneRepeatTimer?.cancel();
      await _ringtonePlayer.stop();
    } catch (_) {}
  }

  // ================= START CALL =================
  Future<void> _startCall() async {
    try {
      // Phase 1 – "Calling..." (before notification is sent)
      if (widget.isOutgoingCall) {
        await _playRingtone();
      }

      _localUid = Random().nextInt(999999);

      _channel =
          'call_${widget.currentUserId}_${widget.otherUserId}_${DateTime.now().millisecondsSinceEpoch}';

      _token = await AgoraTokenService.getToken(
        channelName: _channel,
        uid: _localUid,
      );

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
      }

      // ================= FIRESTORE SIGNAL =================
      if (widget.isOutgoingCall) {
        await FirebaseFirestore.instance
            .collection('call_signals')
            .doc(_channel)
            .set({
          'status': 'ringing',
          'callerId': widget.currentUserId,
          'receiverId': widget.otherUserId,
          'type': 'audio',
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Phase 2 – transition to "Ringing..." once notification+Firestore are set
        if (mounted) {
          setState(() => _callStatus = _CallStatus.ringing);
        }

        // Listen for rejection from the user's app.
        _callSignalSubscription = FirebaseFirestore.instance
            .collection('call_signals')
            .doc(_channel)
            .snapshots()
            .listen(
          (snap) async {
            if (!mounted || _ending) return;
            final data = snap.data();
            if (data != null && data['status'] == 'rejected') {
              await _endCall();
            }
          },
          onError: (_) {/* non-fatal; timeout will still fire */},
        );
      }

      // ================= AGORA =================
      _engine = createAgoraRtcEngine();

      await _engine.initialize(RtcEngineContext(
        appId: AgoraTokenService.appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onUserJoined: (_, uid, __) async {
            if (!mounted) return;
            // Phase 3 – "Connected"
            setState(() {
              _remoteUid = uid;
              _callActive = true;
              _callStatus = _CallStatus.connected;
            });
            _pulseController.stop();
            _pulseController.reset();
            _signalController.stop();
            _signalController.reset();
            await _stopRingtone();
            _startTimer();
          },

          onUserOffline: (_, __, ___) async {
            if (!_ending) {
              await _endCall();
            }
          },

          onError: (code, msg) {},
        ),
      );

      await _engine.enableAudio();

      await _engine.joinChannel(
        token: _token,
        channelId: _channel,
        uid: _localUid,
        options: const ChannelMediaOptions(
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );

      // ================= TIMEOUT =================
      _timeoutTimer = Timer(const Duration(seconds: 30), () async {
        if (_remoteUid == null && !_ending) {
          await NotificationService.sendMissedCallNotification(
            callerId: widget.currentUserId,
            callerName: widget.currentUserName,
          );
          await _endCall();
        }
      });
    } catch (_) {
      _exit();
    }
  }

  // ================= TIMER =================
  void _startTimer() {
    _timeoutTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _duration += const Duration(seconds: 1));
      }
    });
  }

  // ================= VIDEO TOGGLE =================
  Future<void> _toggleVideo() async {
    try {
      if (!_videoEnabled) {
        // Enable video: initialize video engine and start camera preview
        await _engine.enableVideo();
        await _engine.startPreview();
        await _engine.updateChannelMediaOptions(const ChannelMediaOptions(
          publishMicrophoneTrack: true,
          publishCameraTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ));
        final view = AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: _engine,
            canvas: const VideoCanvas(uid: 0),
          ),
        );
        if (mounted) {
          setState(() {
            _videoEnabled = true;
            _localVideoView = view;
          });
        }
      } else {
        // Disable video: stop camera
        await _engine.stopPreview();
        await _engine.disableVideo();
        await _engine.updateChannelMediaOptions(const ChannelMediaOptions(
          publishMicrophoneTrack: true,
          publishCameraTrack: false,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ));
        if (mounted) {
          setState(() {
            _videoEnabled = false;
            _localVideoView = null;
          });
        }
      }
    } catch (_) {}
  }

  // ================= END CALL =================
  Future<void> _endCall() async {
    if (_ending) return;
    _ending = true;

    try {
      _callTimer?.cancel();
      _timeoutTimer?.cancel();

      await _callSignalSubscription?.cancel();
      _callSignalSubscription = null;

      if (widget.isOutgoingCall) {
        FirebaseFirestore.instance
            .collection('call_signals')
            .doc(_channel)
            .delete()
            .catchError((_) {});
      }

      await _stopRingtone();
      await _engine.leaveChannel();
      await Future.delayed(const Duration(milliseconds: 300));
      await _engine.release();
    } catch (_) {}

    final String callStatus = _callActive ? 'answered' : 'missed';
    widget.onCallEnded?.call('audio', callStatus, _duration.inSeconds);

    if (!mounted) return;
    _exit();
  }

  void _exit() {
    if (widget.onEnd != null) {
      widget.onEnd!();
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Stack(
        children: [
          // ── Main call layout
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A1A2E), Color(0xFF0D1117)],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 48),
                  _buildAvatar(),
                  const SizedBox(height: 24),
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSubtitle(),
                  const SizedBox(height: 20),
                  if (_callStatus != _CallStatus.connected) _buildSignalBars(),
                  const Spacer(),
                  _buildControls(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // ── Local camera overlay (visible when video mode is on)
          if (_videoEnabled)
            Positioned(
              top: 56,
              right: 16,
              width: 130,
              height: 190,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _localVideoView ??
                    Container(
                      color: Colors.grey[900],
                      child: const Icon(Icons.videocam, color: Colors.white54, size: 36),
                    ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Status label chip at the top
  Widget _buildStatusLabel() {
    String label;
    Color color;
    switch (_callStatus) {
      case _CallStatus.calling:
        label = 'Calling';
        color = const Color(0xFF6366F1);
        break;
      case _CallStatus.ringing:
        label = 'Ringing';
        color = const Color(0xFF10B981);
        break;
      case _CallStatus.connected:
        label = 'Connected';
        color = const Color(0xFF10B981);
        break;
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Container(
        key: ValueKey(label),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  // ── Pulsing avatar circle
  Widget _buildAvatar() {
    final initials = widget.otherUserName.trim().isNotEmpty
        ? widget.otherUserName.trim()[0].toUpperCase()
        : '?';
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (_, child) {
        final scale = _callStatus == _CallStatus.connected ? 1.0 : _pulseAnimation.value;
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.45),
              blurRadius: 28,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Center(
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // ── Subtitle: "Calling…" / "Ringing…" / timer
  Widget _buildSubtitle() {
    String text;
    switch (_callStatus) {
      case _CallStatus.calling:
        text = 'Calling…';
        break;
      case _CallStatus.ringing:
        text = 'Ringing…';
        break;
      case _CallStatus.connected:
        text = _format(_duration);
        break;
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: Text(
        text,
        key: ValueKey(text),
        style: TextStyle(
          color: Colors.white.withOpacity(0.65),
          fontSize: 16,
        ),
      ),
    );
  }

  // ── Animated signal-strength bars (WhatsApp-style tower indicator)
  static const int _signalBarCount = 4;

  Widget _buildSignalBars() {
    return AnimatedBuilder(
      animation: _signalController,
      builder: (_, __) {
        // Cycle through 1–_signalBarCount active bars based on animation value
        final active = (_signalController.value * _signalBarCount).floor() % _signalBarCount + 1;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(_signalBarCount, (i) {
            final barActive = i < active;
            final height = 6.0 + i * 5.0; // 6, 11, 16, 21
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 6,
                height: height,
                decoration: BoxDecoration(
                  color: barActive
                      ? const Color(0xFF10B981)
                      : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // ── Bottom control buttons row
  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute mic
          _ControlButton(
            icon: _micMuted ? Icons.mic_off : Icons.mic,
            label: _micMuted ? 'Unmute' : 'Mute',
            isActive: _micMuted,
            onTap: () {
              setState(() => _micMuted = !_micMuted);
              _engine.muteLocalAudioStream(_micMuted);
            },
          ),

          // Speaker / Earpiece
          _ControlButton(
            icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
            label: _speakerOn ? 'Speaker' : 'Earpiece',
            isActive: _speakerOn,
            onTap: () {
              setState(() => _speakerOn = !_speakerOn);
              _engine.setEnableSpeakerphone(_speakerOn);
            },
          ),

          // Video mode enable
          _ControlButton(
            icon: _videoEnabled ? Icons.videocam : Icons.videocam_off,
            label: 'Video',
            isActive: _videoEnabled,
            onTap: _toggleVideo,
          ),

          // Minimize (optional)
          if (widget.onMinimize != null)
            _ControlButton(
              icon: Icons.picture_in_picture_alt,
              label: 'Minimize',
              onTap: widget.onMinimize!,
            ),

          // End call (prominent red)
          _EndCallButton(onTap: _endCall),
        ],
      ),
    );
  }

  String _format(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  // ================= DISPOSE =================
  @override
  void dispose() {
    _pulseController.dispose();
    _signalController.dispose();
    _callTimer?.cancel();
    _timeoutTimer?.cancel();
    _ringtoneRepeatTimer?.cancel();
    _callSignalSubscription?.cancel();

    try {
      _engine.leaveChannel();
      _engine.release();
    } catch (_) {}

    _ringtonePlayer.dispose();
    super.dispose();
  }
}

// ── Generic circular control button
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? const Color(0xFF6366F1).withOpacity(0.85)
                  : Colors.white.withOpacity(0.22),
              border: Border.all(
                color: isActive
                    ? const Color(0xFF6366F1)
                    : Colors.white.withOpacity(0.35),
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── End call button (larger, red)
class _EndCallButton extends StatelessWidget {
  final VoidCallback onTap;
  const _EndCallButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFEF4444),
              boxShadow: [
                BoxShadow(
                  color: Color(0x66EF4444),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.call_end, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 6),
          Text(
            'End',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}