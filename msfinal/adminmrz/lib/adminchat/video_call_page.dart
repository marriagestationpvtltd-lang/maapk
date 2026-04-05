import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:adminmrz/adminchat/services/pushservice.dart';
import 'package:adminmrz/settings/call_settings_provider.dart';
import 'package:characters/characters.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'tokengenerator.dart';

// No need for dart:html import

// Video call state progression: calling → ringing → connected
enum _VCallStatus { calling, ringing, connected }

const _kPrimary = Color(0xFF6366F1);
const _kPrimaryDark = Color(0xFF4F46E5);
const _kViolet = Color(0xFF8B5CF6);
const _kEmerald = Color(0xFF10B981);
const _kAmber = Color(0xFFF59E0B);
const _kRose = Color(0xFFEF4444);
const _kSlate = Color(0xFF0F172A);
const _kSlateDark = Color(0xFF1E293B);
const _kHdVideoWidth = 1280;
const _kHdVideoHeight = 720;
const _kLocalPreviewWidthRatio = 0.28;
const _kLocalPreviewAspectRatio = 1.35;
const _kMinLocalPreviewWidth = 120.0;
const _kMaxLocalPreviewWidth = 200.0;
const _kMinLocalPreviewHeight = 170.0;
const _kMaxLocalPreviewHeight = 280.0;
const _kCompactLayoutBreakpoint = 520.0;

class VideoCallScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final String otherUserId;
  final String otherUserName;
  final bool isOutgoingCall;
  /// Called when the user taps the minimize button.  When provided the screen
  /// is assumed to be hosted in an overlay and will NOT call Navigator.pop.
  final VoidCallback? onMinimize;
  /// Called when the call ends.  When provided Navigator.pop is skipped.
  final VoidCallback? onEnd;
  /// Called when the call ends with (callType, status, durationSeconds).
  /// callType is always 'video'. status is 'answered' or 'missed'.
  final void Function(String callType, String status, int durationSeconds)? onCallEnded;

  const VideoCallScreen({
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
  bool _videoEnabled = true;
  bool _cameraFront = true;
  bool _ending = false;
  bool _controlsVisible = false;

  _VCallStatus _callStatus = _VCallStatus.calling;

  Timer? _timeoutTimer;
  Timer? _callTimer;
  Duration _duration = Duration.zero;

  late AudioPlayer _ringtonePlayer;
  Timer? _ringtoneRepeatTimer;

  StreamSubscription<DocumentSnapshot>? _callSignalSubscription;

  // Video renderers
  Widget? _localVideoView;
  Widget? _remoteVideoView;

  @override
  void initState() {
    super.initState();
    _ringtonePlayer = AudioPlayer();
    _setupAudioPlayer();
    _startCall();
  }

  void _setupAudioPlayer() {
    _ringtonePlayer.setReleaseMode(ReleaseMode.stop);
    _ringtonePlayer.onPlayerStateChanged.listen((PlayerState state) {
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
      await _ringtonePlayer.setVolume(_speakerOn ? 1.0 : 0.8);
      await _ringtonePlayer.play(AssetSource(settings.selectedTone.asset));
    } catch (_) {}
  }

  Future<void> _playRingtone() async {
    if (!widget.isOutgoingCall) return;
    try {
      await _stopRingtone();
      final settings = context.read<CallSettingsProvider>();
      await _ringtonePlayer.setVolume(_speakerOn ? 1.0 : 0.8);
      await _ringtonePlayer.play(AssetSource(settings.selectedTone.asset));
    } catch (e) {
    }
  }

  Future<void> _stopRingtone() async {
    try {
      _ringtoneRepeatTimer?.cancel();
      await _ringtonePlayer.stop();
    } catch (_) {}
  }

  Future<void> _startCall() async {
    try {
      // Ringtone for outgoing calls
      if (widget.isOutgoingCall) {
        _playRingtone();
      }

      // Generate channel and token
      _localUid = Random().nextInt(999999);
      _channel =
      'call_${widget.currentUserId.substring(0, min(4, widget.currentUserId.length))}'
          '_${widget.otherUserId.substring(0, min(4, widget.otherUserId.length))}'
          '_${DateTime.now().millisecondsSinceEpoch}';

      if (_channel.length > 64) {
        _channel = _channel.substring(0, 64);
      }

      _token = await AgoraTokenService.getToken(
        channelName: _channel,
        uid: _localUid,
      );

      // Send call notification for outgoing calls
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

        // Write call signal to Firestore so the user app can signal rejection in real-time.
        await FirebaseFirestore.instance
            .collection('call_signals')
            .doc(_channel)
            .set({
          'status': 'ringing',
          'callerId': widget.currentUserId,
          'receiverId': widget.otherUserId,
          'type': 'video',
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Transition to "Ringing" — remote phone is now ringing
        if (mounted) {
          setState(() => _callStatus = _VCallStatus.ringing);
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
          onError: (_) {/* Firestore errors are non-fatal; timeout will still fire */},
        );
      }

      // Initialize Agora engine
      _engine = createAgoraRtcEngine();
      await _engine.initialize(RtcEngineContext(
        appId: AgoraTokenService.appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      // Enable audio and video
      await _engine.enableAudio();
      await _engine.enableVideo();
      await _engine.setVideoEncoderConfiguration(
        VideoEncoderConfiguration(
          dimensions: VideoDimensions(
            width: _kHdVideoWidth,
            height: _kHdVideoHeight,
          ),
        ),
      );

      // Start preview – triggers camera permission prompt
      await _engine.startPreview();

      // Register event handlers
      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (_, __) {
            if (mounted) {
              setState(() => _joined = true);
              _setupLocalVideo();
            }
          },
          onUserJoined: (_, uid, __) {
            if (mounted) {
              setState(() {
                _remoteUid = uid;
                _callStatus = _VCallStatus.connected;
              });
              _setupRemoteVideo(uid);
            }
            _stopRingtone();
            _startCallTimer();
          },
          onUserOffline: (_, __, ___) {
            _endCall();
          },
          onError: (code, msg) {},
        ),
      );

      // Set client role
      await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      // Join channel
      await _engine.joinChannel(
        token: _token,
        channelId: _channel,
        uid: _localUid,
        options: const ChannelMediaOptions(
          publishMicrophoneTrack: true,
          publishCameraTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );

      // Timeout after 30 seconds if no answer
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
      _exit();
    }
  }

  void _setupLocalVideo() {
    // Create a local video view
    final videoSurface = AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: _engine,
        canvas: VideoCanvas(uid: 0), // 0 means local
      ),
    );
    setState(() {
      _localVideoView = videoSurface;
    });
  }

  void _setupRemoteVideo(int uid) {
    final videoSurface = AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: _engine,
        canvas: VideoCanvas(uid: uid),
        connection: RtcConnection(channelId: _channel),
      ),
    );
    setState(() {
      _remoteVideoView = videoSurface;
    });
  }

  void _startCallTimer() {
    _timeoutTimer?.cancel();
    _callActive = true;

    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _duration += const Duration(seconds: 1));
    });
  }

  Future<void> _endCall() async {
    if (_ending) return;
    _ending = true;

    _callTimer?.cancel();
    _timeoutTimer?.cancel();

    await _callSignalSubscription?.cancel();
    _callSignalSubscription = null;

    // Clean up the Firestore call signal document.
    if (widget.isOutgoingCall) {
      FirebaseFirestore.instance
          .collection('call_signals')
          .doc(_channel)
          .delete()
          .catchError((_) {});
    }

    await _stopRingtone();

    if (_callActive) {
      await NotificationService.sendCallEndedNotification(
        recipientUserId: widget.otherUserId,
        callerName: widget.currentUserName,
        reason: 'ended',
        duration: _duration.inSeconds,
      );
    }

    // Fire call-ended callback so the chat can save history.
    final String callStatus = _callActive ? 'answered' : 'missed';
    widget.onCallEnded?.call('video', callStatus, _duration.inSeconds);

    if (_joined) {
      await _engine.leaveChannel();
      await _engine.release();
    }

    _exit();
  }

  void _exit() {
    if (widget.onEnd != null) {
      widget.onEnd!();
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  // Control methods
  Future<void> _toggleSpeaker() async {
    setState(() => _speakerOn = !_speakerOn);
    await _engine.setEnableSpeakerphone(_speakerOn);
    await _ringtonePlayer.setVolume(_speakerOn ? 1.0 : 0.8);
  }

  void _toggleMute() {
    setState(() => _micMuted = !_micMuted);
    _engine.muteLocalAudioStream(_micMuted);
  }

  void _toggleVideo() {
    setState(() => _videoEnabled = !_videoEnabled);
    _engine.muteLocalVideoStream(!_videoEnabled);
    if (_videoEnabled) {
      // Restart preview if turning video on (sometimes needed after mute)
      _engine.startPreview();
    } else {
      _engine.stopPreview();
    }
  }

  void _switchCamera() {
    setState(() => _cameraFront = !_cameraFront);
    _engine.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double localWidth = (size.width * _kLocalPreviewWidthRatio)
        .clamp(_kMinLocalPreviewWidth, _kMaxLocalPreviewWidth)
        .toDouble();
    final double localHeight =
        (localWidth * _kLocalPreviewAspectRatio)
            .clamp(_kMinLocalPreviewHeight, _kMaxLocalPreviewHeight)
            .toDouble();
    final double topBarRightInset = _videoEnabled ? localWidth + 32 : 16;

    return Scaffold(
      backgroundColor: _kSlate,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child:
                  _remoteVideoView ?? _buildRemotePlaceholder(),
            ),
            Positioned.fill(child: IgnorePointer(child: _buildVignette())),
            Positioned(
              top: 12,
              left: 16,
              right: topBarRightInset,
              child: _buildTopBar(),
            ),
            if (_videoEnabled)
              Positioned(
                top: 84,
                right: 16,
                width: localWidth,
                height: localHeight,
                child: _buildLocalPreview(),
              ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleControlsVisibility,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _controlsVisible ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: _buildControls(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleControlsVisibility() {
    if (!mounted) return;
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
  }

  Widget _buildTopBar() {
    final String statusLabel = switch (_callStatus) {
      _VCallStatus.calling => 'Calling',
      _VCallStatus.ringing => 'Ringing',
      _VCallStatus.connected => 'Live',
    };
    final String subtitle = switch (_callStatus) {
      _VCallStatus.calling => 'Connecting…',
      _VCallStatus.ringing => 'Ringing…',
      _VCallStatus.connected => _format(_duration),
    };
    final Color statusColor =
        _callStatus == _VCallStatus.connected ? _kEmerald : _kAmber;
    final String trimmedName = widget.otherUserName.trim();
    final String initial = trimmedName.isNotEmpty
        ? trimmedName.characters.first.toUpperCase()
        : '?';

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [_kPrimary, _kViolet],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _kPrimaryDark.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.otherUserName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: statusColor.withOpacity(0.45)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _buildRemotePlaceholder() {
    final String label = _callStatus == _VCallStatus.connected
        ? 'Reconnecting video…'
        : 'Connecting video…';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kSlate, _kSlateDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam, color: Colors.white24, size: 72),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalPreview() {
    return Container(
      decoration: BoxDecoration(
        color: _kSlateDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: _localVideoView ??
            Container(
              color: _kSlateDark,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videocam, color: Colors.white54, size: 36),
                  const SizedBox(height: 8),
                  const Text(
                    'Camera starting…',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildVignette() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.2),
            Colors.black.withOpacity(0.55),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.9],
        ),
      ),
    );
  }

  Widget _buildControls() {
    final bool controlsEnabled = _callStatus != _VCallStatus.calling;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool useCompactLayout =
            constraints.maxWidth < _kCompactLayoutBreakpoint;
        final double buttonSize = useCompactLayout ? 52 : 60;
        final double endSize = useCompactLayout ? 66 : 74;
        final double spacing = useCompactLayout ? 12 : 16;

        final List<Widget> buttons = [
          if (widget.onMinimize != null)
            _controlButton(
              icon: Icons.picture_in_picture_alt,
              onPressed: widget.onMinimize,
              size: buttonSize,
              backgroundColor: _kPrimary.withOpacity(0.22),
              iconColor: Colors.white,
            ),
          _controlButton(
            icon: _micMuted ? Icons.mic_off : Icons.mic,
            onPressed: controlsEnabled ? _toggleMute : null,
            size: buttonSize,
            iconColor: _micMuted ? _kAmber : Colors.white,
          ),
          _controlButton(
            icon: _videoEnabled ? Icons.videocam : Icons.videocam_off,
            onPressed: controlsEnabled ? _toggleVideo : null,
            size: buttonSize,
            iconColor: _videoEnabled ? Colors.white : _kAmber,
          ),
          _controlButton(
            icon: Icons.call_end,
            onPressed: _endCall,
            size: endSize,
            backgroundColor: _kRose,
            iconColor: Colors.white,
          ),
          _controlButton(
            icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
            onPressed: controlsEnabled ? _toggleSpeaker : null,
            size: buttonSize,
            iconColor: _speakerOn ? _kEmerald : Colors.white,
          ),
          _controlButton(
            icon: Icons.flip_camera_android,
            onPressed: (_videoEnabled && controlsEnabled) ? _switchCamera : null,
            size: buttonSize,
            iconColor: _videoEnabled ? Colors.white : Colors.white54,
          ),
        ];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: EdgeInsets.symmetric(
                  vertical: useCompactLayout ? 12 : 16,
                  horizontal: useCompactLayout ? 12 : 18,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: spacing,
                  runSpacing: 12,
                  children: buttons,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _controlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required double size,
    Color? backgroundColor,
    Color? iconColor,
  }) {
    final bool enabled = onPressed != null;
    final Color resolvedBackground = backgroundColor ??
        (enabled
            ? Colors.black.withOpacity(0.35)
            : Colors.black.withOpacity(0.2));
    final Color resolvedIcon = iconColor ?? Colors.white;

    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: resolvedBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(size / 2),
          side: BorderSide(
            color: Colors.white.withOpacity(enabled ? 0.16 : 0.08),
          ),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(size / 2),
          child: Icon(
            icon,
            color: enabled ? resolvedIcon : Colors.white38,
            size: size * 0.45,
          ),
        ),
      ),
    );
  }

  String _format(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  void dispose() {
   // _callTimer?.cancel();
    _timeoutTimer?.cancel();
    _ringtoneRepeatTimer?.cancel();
    _callSignalSubscription?.cancel();
    _ringtonePlayer.dispose();
    super.dispose();
  }
}
