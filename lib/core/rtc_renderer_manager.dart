import 'package:flutter_webrtc/flutter_webrtc.dart';

class RtcRendererManager {
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  /// Initializes both local and remote renderers.
  Future<void> initialize() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  /// Disposes both renderers safely.
  void dispose() {
    localRenderer.dispose();
    remoteRenderer.dispose();
  }
}
