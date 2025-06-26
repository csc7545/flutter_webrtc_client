import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class RtcScreen extends StatefulWidget {
  final String name;
  final String room;

  const RtcScreen({
    super.key,
    required this.name,
    required this.room,
  });

  @override
  State<RtcScreen> createState() => _RtcScreenState();
}

class _RtcScreenState extends State<RtcScreen> {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  io.Socket? _socket;

  @override
  void initState() {
    super.initState();
    _initializeAsync();
    _connectSocket();
  }

  Future<void> _initializeAsync() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    await _createPeerConnection();
    await _createLocalStream();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    return Material(
      color: Colors.black,
      child: Stack(
        children: [
          // :video_camera: Remote Video
          Positioned.fill(
            child: RTCVideoView(
              _remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),

          // :movie_camera: Local Video (Top Left)
          Positioned(
            left: 16.0,
            top: 16.0,
            child: Container(
              width: isPortrait ? 100.0 : 140.0,
              height: isPortrait ? 140.0 : 100.0,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: Colors.white70, width: 2.0),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: RTCVideoView(
                  _localRenderer,
                  mirror: true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),
          ),

          // :telephone_receiver: Hang Up Button
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: GestureDetector(
                onTap: _hangUp,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.call_end,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<PermissionStatus> _checkCameraPermission() async {
    final PermissionStatus status = await Permission.camera.status;
    if (status.isDenied) {
      return await Permission.camera.request();
    }
    return status;
  }

  Future<PermissionStatus> _checkMicrophonePermission() async {
    final PermissionStatus status = await Permission.microphone.status;
    if (status.isDenied) {
      return await Permission.microphone.request();
    }
    return status;
  }

  Future<void> _createLocalStream() async {
    final PermissionStatus cameraPermission = await _checkCameraPermission();
    final PermissionStatus microphonePermission =
        await _checkMicrophonePermission();

    if (cameraPermission.isGranted && microphonePermission.isGranted) {
      final Map<String, Object> mediaConstraints = {
        'audio': true,
        'video': {
          'facingMode': 'user',
          'mandatory': {
            'minWidth': '640',
            'minHeight': '480',
            'minFrameRate': '30',
          },
        },
      };

      _localStream =
          await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _localRenderer.srcObject = _localStream;

      _localStream!.getTracks().forEach((track) {
        _peerConnection?.addTrack(track, _localStream!);
        track.onEnded = () {
          debugPrint('Local track ended: ${track.kind}');
        };
      });

      setState(() {});
    }
  }

  void _connectSocket() {
    debugPrint('Connecting to socket...');

    const String socketUrl = 'http://10.20.210.154:3000';
    _socket = io.io(socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket!.connect();
    _socket!.on('connect', (_) {
      debugPrint('Socket connected to Signaling server');
      _socket!.emit('join', {'name': widget.name, 'room': widget.room});
    });

    _socket!.on('start', (_) async {
      debugPrint('[SOCKET] Received start event');

      await _createOffer();
    });

    _socket!.on('offer', (data) async {
      debugPrint('Received offer: ${data['sdp']}');

      await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(data['sdp'], data['type']));
      await _createAnswer();
    });

    _socket!.on('answer', (data) async {
      debugPrint('Received answer: ${data['sdp']}');
      await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(data['sdp'], data['type']));
    });

    _socket!.on('ice_candidate', (data) async {
      debugPrint('Received ICE candidate: ${data['candidate']}');
      final RTCIceCandidate candidate = RTCIceCandidate(
        data['candidate'],
        data['sdpMid'],
        data['sdpMLineIndex'],
      );
      await _peerConnection!.addCandidate(candidate);
    });

    _socket!.on('disconnect', (_) {
      debugPrint('Socket disconnected from Signaling server');
    });
  }

  Future<void> _createPeerConnection() async {
    final Map<String, dynamic> configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'}
      ],
      'sdpSemantics': 'unified-plan',
    };

    _peerConnection = await createPeerConnection(configuration);

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      _socket!.emit('ice_candidate', {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      debugPrint(
          ":white_check_mark: onTrack: stream count = ${event.streams.length}");
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams[0];
        setState(() {});
      } else {
        debugPrint(":x: No remote stream received");
      }
    };
  }

  Future<void> _createOffer() async {
    RTCSessionDescription description = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true,
    });
    await _peerConnection!.setLocalDescription(description);
    _socket!.emit('offer', {
      'sdp': description.sdp,
      'type': description.type,
      'room': widget.room,
    });
  }

  Future<void> _createAnswer() async {
    RTCSessionDescription description = await _peerConnection!.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true,
    });
    await _peerConnection!.setLocalDescription(description);
    _socket!.emit('answer', {
      'sdp': description.sdp,
      'type': description.type,
      'room': widget.room,
    });
  }

  void _stopVideoRTC() {
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();

    _peerConnection?.close();
    _peerConnection = null;

    _socket?.disconnect();
    _socket?.off('connect');
    _socket?.off('start');
    _socket?.off('offer');
    _socket?.off('answer');
    _socket?.off('ice_candidate');
    _socket?.off('disconnect');
  }

  void _hangUp() {
    _stopVideoRTC();
    Navigator.pop(context);
  }
}
