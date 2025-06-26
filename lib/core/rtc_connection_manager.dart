import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef OnIceCandidateCallback = void Function(RTCIceCandidate candidate);
typedef OnTrackCallback = void Function(MediaStream stream);

class RtcConnectionManager {
  RTCPeerConnection? _peerConnection;

  RTCPeerConnection? get connection => _peerConnection;

  /// Creates a new RTCPeerConnection and sets up callbacks.
  Future<void> createConnection({
    required OnIceCandidateCallback onIceCandidate,
    required OnTrackCallback onTrack,
  }) async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    };

    _peerConnection = await createPeerConnection(config);

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      onIceCandidate(candidate);
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        onTrack(event.streams[0]);
      }
    };
  }

  /// Adds local media stream tracks to the connection.
  void addLocalTracks(MediaStream stream) {
    for (var track in stream.getTracks()) {
      _peerConnection?.addTrack(track, stream);
    }
  }

  /// Creates an offer and sets it as the local description.
  Future<RTCSessionDescription> createOffer() async {
    final offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true,
    });
    await _peerConnection!.setLocalDescription(offer);
    return offer;
  }

  /// Creates an answer and sets it as the local description.
  Future<RTCSessionDescription> createAnswer() async {
    final answer = await _peerConnection!.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true,
    });
    await _peerConnection!.setLocalDescription(answer);
    return answer;
  }

  /// Sets the given SDP as the remote description.
  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    await _peerConnection?.setRemoteDescription(description);
  }

  /// Adds an ICE candidate to the connection.
  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    await _peerConnection?.addCandidate(candidate);
  }

  /// Closes and disposes the connection.
  Future<void> dispose() async {
    await _peerConnection?.close();
    _peerConnection = null;
  }
}
