import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRtcManager {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  Function(MediaStream stream)? onAddRemoteStream;

  Future<void> initializeRenderers(RTCVideoRenderer localRenderer, RTCVideoRenderer remoteRenderer) async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  Future<void> openUserMedia(RTCVideoRenderer localRenderer, RTCVideoRenderer remoteRenderer) async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });

    localRenderer.srcObject = _localStream;

    _peerConnection = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    });

    _peerConnection!.addStream(_localStream!);

    _peerConnection!.onAddStream = (stream) {
      onAddRemoteStream?.call(stream);
      remoteRenderer.srcObject = stream;
    };
  }

  Future<String> createRoom(RTCVideoRenderer remoteRenderer) async {
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    // Send this offer to the remote peer via your signaling server

    return 'room_id'; // Replace with the actual room ID from your signaling server
  }

  void joinRoom(String roomId, RTCVideoRenderer remoteRenderer) {
    // Implement the logic to join a room with the given roomId via your signaling server
  }

  void hangUp(RTCVideoRenderer localRenderer) {
    _localStream?.getTracks().forEach((track) {
      track.stop();
    });
    _peerConnection?.close();
    _peerConnection = null;
    localRenderer.srcObject = null;
  }
}
