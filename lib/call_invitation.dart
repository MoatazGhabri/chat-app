import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import 'package:new_app/Statics.dart';

class AudioCallScreen extends StatefulWidget {
  final String currentUserUid;
  final String otherUserUid;

  const AudioCallScreen({
    Key? key,
    required this.currentUserUid,
    required this.otherUserUid,
  }) : super(key: key);

  @override
  _AudioCallScreenState createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends State<AudioCallScreen> {
  late RTCPeerConnection _peerConnection;
  MediaStream? _localStream;

  @override
  void initState() {
    super.initState();
    _initializeWebRTC();
  }

  Future<void> _initializeWebRTC() async {
    // Create the peer connection
    _peerConnection = await createPeerConnection({
      'iceServers': [
        {
          'urls': 'stun:stun.l.google.com:19302',
        },
      ],
    });

    // Create the local audio stream
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });

    // Add the local stream to the peer connection
    _peerConnection.addStream(_localStream!);

    // Handle the other user's stream
    _peerConnection.onAddStream = (MediaStream stream) {
      // Here you can set the remote audio stream, etc.
    };

    // Handle other peer connection events like onIceCandidate, onTrack, etc.
  }

  @override
  void dispose() {
    _localStream?.dispose();
    _peerConnection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Audio Call with ${widget.otherUserUid}'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _hangUp,
              child: Text('Hang Up'),
            ),
          ],
        ),
      ),
    );
  }

  void _hangUp() async {
    await _peerConnection.close();
    Navigator.pop(context);
  }
}


