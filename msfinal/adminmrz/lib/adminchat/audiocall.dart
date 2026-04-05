import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'chatprovider.dart';

const appId = "7750d283e6794eebba06e7d021e8a01c";
const channel = "channelname";

class AudioCall extends StatefulWidget {
  final int remoteUid;
  AudioCall(this.remoteUid);

  @override
  State<AudioCall> createState() => _AudioCallState();
}

class _AudioCallState extends State<AudioCall> {
  int? _remoteUidd;
  bool _muted = false;
  bool _speakerEnabled = true;
  late RtcEngine _engine;

  @override
  void initState() {
    super.initState();
    initAgora();
  }

  Future<void> initAgora() async {
    await Permission.microphone.request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          setState(() {
            _remoteUidd = remoteUid;
          });
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          setState(() {
            _remoteUidd = null;
          });
        },
      ),
    );

    await _engine.enableAudio();
    await _engine.joinChannel(
      token: '',
      channelId: channel,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  Future<void> _dispose() async {
    await _engine.leaveChannel();
    await _engine.release();
  }

  void _toggleMute() {
    setState(() {
      _muted = !_muted;
    });
    _engine.muteLocalAudioStream(_muted);
  }

  void _toggleSpeaker() {
    setState(() {
      _speakerEnabled = !_speakerEnabled;
    });
    _engine.setEnableSpeakerphone(_speakerEnabled);
  }

  void _endCall() {
    _dispose();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);

    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(
          size: 0
        ),
          title: Text(chatProvider.namee.toString())),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.call, size: 100, color: Colors.blue),
            SizedBox(height: 20),
            Text(
              _remoteUidd != null
                  ? "Connected to \${chatProvider.namee}"
                  : "Waiting for ${chatProvider.namee} to join",
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _controlButton(Icons.mic, _muted, _toggleMute),
                _controlButton(Icons.volume_up, !_speakerEnabled, _toggleSpeaker),
                _controlButton(Icons.call_end, true, _endCall, color: Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlButton(IconData icon, bool active, VoidCallback onPressed, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: FloatingActionButton(
        backgroundColor: color ?? (active ? Colors.red : Colors.blue),
        onPressed: onPressed,
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
