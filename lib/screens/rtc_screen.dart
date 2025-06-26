import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:simple_web_rtc_client/core/rtc_connection_manager.dart';
import 'package:simple_web_rtc_client/core/rtc_permission_helper.dart';
import 'package:simple_web_rtc_client/core/rtc_renderer_manager.dart';
import 'package:simple_web_rtc_client/core/rtc_socket_manager.dart';

class RtcScreen extends StatefulWidget {
  final String name;
  final String room;

  const RtcScreen({super.key, required this.name, required this.room});

  @override
  State<RtcScreen> createState() => _RtcScreenState();
}

class _RtcScreenState extends State<RtcScreen> {
  final _rendererManager = RtcRendererManager();
  final _connectionManager = RtcConnectionManager();
  final _socketManager = RtcSocketManager();
  MediaStream? _localStream;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _rendererManager.initialize();
    await _connectionManager.createConnection(
      onIceCandidate: _handleIceCandidate,
      onTrack: _handleRemoteStream,
    );

    final permissionGranted =
        await RtcPermissionHelper.requestMediaPermissions();
    if (!permissionGranted) return;

    await _createLocalStream();
    _connectSocket();
  }

  Future<void> _createLocalStream() async {
    final mediaConstraints = {
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

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _rendererManager.localRenderer.srcObject = _localStream;
    _connectionManager.addLocalTracks(_localStream!);

    setState(() {});
  }

  void _connectSocket() {
    // TODO: Put you own IP address or URL
    const socketUrl = 'http://YOUR_SIGNALING_SERVER:3000';

    _socketManager.connect(
      serverUrl: socketUrl,
      name: widget.name,
      room: widget.room,
      onConnect: () => debugPrint('Connected to signaling server'),
      onStart: _createOffer,
      onOffer: (data) async {
        await _connectionManager.setRemoteDescription(
          RTCSessionDescription(data['sdp'], data['type']),
        );
        await _createAnswer();
      },
      onAnswer: (data) async {
        await _connectionManager.setRemoteDescription(
          RTCSessionDescription(data['sdp'], data['type']),
        );
      },
      onIceCandidate: (data) async {
        final candidate = RTCIceCandidate(
          data['candidate'],
          data['sdpMid'],
          data['sdpMLineIndex'],
        );
        await _connectionManager.addIceCandidate(candidate);
      },
      onDisconnect: () => debugPrint('Disconnected from signaling server'),
    );
  }

  void _handleIceCandidate(RTCIceCandidate candidate) {
    _socketManager.emit('ice_candidate', {
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    });
  }

  void _handleRemoteStream(MediaStream stream) {
    _rendererManager.remoteRenderer.srcObject = stream;
    setState(() {});
  }

  Future<void> _createOffer() async {
    final offer = await _connectionManager.createOffer();
    _socketManager.emit('offer', {
      'sdp': offer.sdp,
      'type': offer.type,
      'room': widget.room,
    });
  }

  Future<void> _createAnswer() async {
    final answer = await _connectionManager.createAnswer();
    _socketManager.emit('answer', {
      'sdp': answer.sdp,
      'type': answer.type,
      'room': widget.room,
    });
  }

  void _hangUp() {
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _connectionManager.dispose();
    _rendererManager.dispose();
    _socketManager.dispose();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _hangUp();
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
          Positioned.fill(
            child: RTCVideoView(
              _rendererManager.remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),
          Positioned(
            left: 16.0,
            top: 16.0,
            child: Container(
              width: isPortrait ? 100.0 : 140.0,
              height: isPortrait ? 140.0 : 100.0,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: Colors.white70, width: 2.0),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: RTCVideoView(
                  _rendererManager.localRenderer,
                  mirror: true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),
          ),
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
}
