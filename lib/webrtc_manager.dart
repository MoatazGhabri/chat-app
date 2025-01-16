import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_database/firebase_database.dart';

typedef StreamStateCallback = void Function(MediaStream stream);

class WebRtcManager {
  Map<String, dynamic> configuration = {
    'iceServers': [
      {
        'urls': [
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302'
        ]
      }
    ]
  };

  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;
  String? roomId;
  String? currentRoomText;
  StreamStateCallback? onAddRemoteStream;

  Future<String> createRoom(RTCVideoRenderer remoteRenderer) async {
    DatabaseReference db = FirebaseDatabase.instance.ref();
    DatabaseReference roomRef = db.child('rooms').push();

    peerConnection = await createPeerConnection(configuration);

    registerPeerConnectionListeners();

    localStream?.getTracks().forEach((track) {
      peerConnection?.addTrack(track, localStream!);
    });

    // Code for collecting ICE candidates
    DatabaseReference callerCandidatesRef = roomRef.child('callerCandidates');

    peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate != null) {
        callerCandidatesRef.push().set(candidate.toMap());
      }
    };

    // Create and set the offer
    RTCSessionDescription offer = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(offer);

    Map<String, dynamic> roomWithOffer = {'offer': offer.toMap()};
    await roomRef.set(roomWithOffer);

    roomId = roomRef.key;
    currentRoomText = 'Current room is $roomId - You are the caller!';

    peerConnection?.onTrack = (RTCTrackEvent event) {
      remoteStream = event.streams[0];
      remoteStream?.getTracks().forEach((track) {
        remoteRenderer.srcObject?.addTrack(track);
      });
      onAddRemoteStream?.call(event.streams[0]);
    };

    // Listen for remote session description
    roomRef.onValue.listen((event) async {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null && data['answer'] != null && peerConnection?.getRemoteDescription() == null) {
        var answer = RTCSessionDescription(
          data['answer']['sdp'],
          data['answer']['type'],
        );
        await peerConnection?.setRemoteDescription(answer);
      }
    });

    // Listen for remote ICE candidates
    roomRef.child('calleeCandidates').onChildAdded.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      peerConnection!.addCandidate(
        RTCIceCandidate(
          data['candidate'],
          data['sdpMid'],
          data['sdpMLineIndex'],
        ),
      );
    });

    return roomId!;
  }

  Future<void> joinRoom(String roomId, RTCVideoRenderer remoteVideo) async {
    DatabaseReference db = FirebaseDatabase.instance.ref();
    DatabaseReference roomRef = db.child('rooms').child(roomId);
    DatabaseEvent roomSnapshot = await roomRef.once();

    if (roomSnapshot.snapshot.exists) {
      peerConnection = await createPeerConnection(configuration);

      registerPeerConnectionListeners();

      localStream?.getTracks().forEach((track) {
        peerConnection?.addTrack(track, localStream!);
      });

      // Code for collecting ICE candidates
      DatabaseReference calleeCandidatesRef = roomRef.child('calleeCandidates');
      peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate != null) {
          calleeCandidatesRef.push().set(candidate.toMap());
        }
      };

      peerConnection?.onTrack = (RTCTrackEvent event) {
        remoteStream = event.streams[0];
        remoteStream?.getTracks().forEach((track) {
          remoteVideo.srcObject?.addTrack(track);
        });
        onAddRemoteStream?.call(event.streams[0]);
      };

      // Retrieve and set the offer
      final data = roomSnapshot.snapshot.value as Map<dynamic, dynamic>;
      var offer = data['offer'];
      await peerConnection?.setRemoteDescription(
        RTCSessionDescription(offer['sdp'], offer['type']),
      );

      // Create and send the answer
      var answer = await peerConnection!.createAnswer();
      await peerConnection!.setLocalDescription(answer);

      Map<String, dynamic> roomWithAnswer = {
        'answer': {'type': answer.type, 'sdp': answer.sdp}
      };
      await roomRef.update(roomWithAnswer);

      // Listen for remote ICE candidates
      roomRef.child('callerCandidates').onChildAdded.listen((event) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        peerConnection!.addCandidate(
          RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          ),
        );
      });
    }
  }

  Future<void> openUserMedia(
      RTCVideoRenderer localVideo,
      RTCVideoRenderer remoteVideo,
      ) async {
    var stream = await navigator.mediaDevices.getUserMedia({'video': true, 'audio': true});
    localStream = stream;
    localVideo.srcObject = stream;

    remoteStream = await createLocalMediaStream('key');
    remoteVideo.srcObject = remoteStream;
  }

  Future<void> hangUp(RTCVideoRenderer localVideo) async {
    localVideo.srcObject?.getTracks().forEach((track) {
      track.stop();
    });

    remoteStream?.getTracks().forEach((track) => track.stop());

    if (peerConnection != null) {
      await peerConnection!.close();
      peerConnection = null;
    }

    if (roomId != null) {
      DatabaseReference db = FirebaseDatabase.instance.ref();
      DatabaseReference roomRef = db.child('rooms').child(roomId!);
      await roomRef.remove();
      roomId = null;
    }

    localStream?.dispose();
    remoteStream?.dispose();
  }

  void registerPeerConnectionListeners() {
    peerConnection?.onIceGatheringState = (RTCIceGatheringState state) {
      print('ICE gathering state changed: $state');
    };

    peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
      print('Connection state change: $state');
    };

    peerConnection?.onSignalingState = (RTCSignalingState state) {
      print('Signaling state change: $state');
    };

    peerConnection?.onIceConnectionState = (RTCIceConnectionState state) {
      print('ICE connection state change: $state');
    };

    peerConnection?.onAddStream = (MediaStream stream) {
      onAddRemoteStream?.call(stream);
      remoteStream = stream;
    };
  }
}
