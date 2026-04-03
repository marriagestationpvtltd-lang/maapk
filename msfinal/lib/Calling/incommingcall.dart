import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../pushnotification/pushservice.dart';
import 'tokengenerator.dart';

class IncomingCallScreen extends StatefulWidget {
  final Map<String, dynamic> callData;
  const IncomingCallScreen({super.key, required this.callData});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  late RtcEngine _engine;

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

  Timer? _ringTimer;
  Timer? _callTimer;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _parseData();
    _localUid = Random().nextInt(999999);
    _ringTimer = Timer(const Duration(seconds: 60), _missedCall);
  }

  void _parseData() {
    _channel = widget.callData['channelName'];
    _callerId = widget.callData['callerId'];
    _callerName = widget.callData['callerName'];
    _recipientName = widget.callData['recipientName'] ?? 'You';
  }

  // ================= ACCEPT CALL =================
  Future<void> _acceptCall() async {
    if (_processing) return;
    _processing = true;

    try {
      _ringTimer?.cancel();

      if (!(await Permission.microphone.request()).isGranted) {
        _end();
        return;
      }

      // Notify caller
      await NotificationService.sendCallResponseNotification(
        callerId: _callerId,
        recipientName: _recipientName,
        accepted: true,
        recipientUid: _localUid.toString(),
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

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (_, __) {
            _joined = true;
          },
          onUserJoined: (_, uid, __) {
            _remoteUid = uid;
            _startCallTimer();
          },
          onUserOffline: (_, __, ___) {
            _endCall();
          },
          onError: (c, m) {
            debugPrint('Agora error $c $m');
          },
        ),
      );

      await _engine.enableAudio();
      await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      await _engine.joinChannel(
        token: token,
        channelId: _channel,
        uid: _localUid,
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true,
        ),
      );

      setState(() => _callActive = true);
    } catch (e) {
      debugPrint('Accept error $e');
      _end();
    } finally {
      _processing = false;
    }
  }

  // ================= TIMERS =================
  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _duration += const Duration(seconds: 1));
    });
  }

  // ================= MISSED =================
  Future<void> _missedCall() async {
    await NotificationService.sendMissedCallNotification(
      callerId: _callerId,
      callerName: _callerName,
    );
    _end();
  }

  // ================= END =================
  Future<void> _endCall() async {
    _callTimer?.cancel();

    if (_callActive) {
      await NotificationService.sendCallEndedNotification(
        recipientUserId: _callerId,
        callerName: _recipientName,
        reason: 'ended',
        duration: _duration.inSeconds,
      );
    }

    if (_joined) {
      await _engine.leaveChannel();
      await _engine.release();
    }

    _end();
  }

  void _end() {
    if (mounted) Navigator.pop(context);
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _callActive ? Icons.phone_in_talk : Icons.phone,
                color: Colors.white,
                size: 80,
              ),
              const SizedBox(height: 20),
              Text(
                _callActive ? 'Connected' : 'Incoming call',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                _callerName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Text(
                _callActive
                    ? _format(_duration)
                    : 'Voice Call',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 40),
              _callActive ? _activeControls() : _incomingControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _incomingControls() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      _btn(Icons.call, Colors.green, _acceptCall),
      _btn(Icons.call_end, Colors.red, _end),
    ],
  );

  Widget _activeControls() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      _btn(
        _micMuted ? Icons.mic_off : Icons.mic,
        Colors.white,
            () {
          _micMuted = !_micMuted;
          _engine.muteLocalAudioStream(_micMuted);
          setState(() {});
        },
      ),
      _btn(Icons.call_end, Colors.red, _endCall),
      _btn(
        _speakerOn ? Icons.volume_up : Icons.volume_off,
        Colors.white,
            () {
          _speakerOn = !_speakerOn;
          _engine.setEnableSpeakerphone(_speakerOn);
          setState(() {});
        },
      ),
    ],
  );

  Widget _btn(IconData i, Color c, VoidCallback f) =>
      IconButton(icon: Icon(i, color: c, size: 48), onPressed: f);

  String _format(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _ringTimer?.cancel();
    _callTimer?.cancel();
    super.dispose();
  }
}
