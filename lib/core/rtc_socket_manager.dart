import 'package:socket_io_client/socket_io_client.dart' as io;

typedef VoidCallback = void Function();
typedef MessageCallback = void Function(dynamic data);

class RtcSocketManager {
  late final io.Socket _socket;

  io.Socket get socket => _socket;

  /// Connects to the signaling server and registers event handlers.
  void connect({
    required String serverUrl,
    required String name,
    required String room,
    required VoidCallback onConnect,
    required VoidCallback onStart,
    required MessageCallback onOffer,
    required MessageCallback onAnswer,
    required MessageCallback onIceCandidate,
    required VoidCallback onDisconnect,
  }) {
    _socket = io.io(serverUrl, {
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket.connect();

    _socket.on('connect', (_) {
      onConnect();
      _socket.emit('join', {'name': name, 'room': room});
    });

    _socket.on('start', (_) => onStart());
    _socket.on('offer', onOffer);
    _socket.on('answer', onAnswer);
    _socket.on('ice_candidate', onIceCandidate);
    _socket.on('disconnect', (_) => onDisconnect());
  }

  /// Emits an event with given data.
  void emit(String event, dynamic data) {
    _socket.emit(event, data);
  }

  /// Disconnects and removes all listeners.
  void dispose() {
    _socket.dispose();
  }
}
