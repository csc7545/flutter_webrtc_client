import 'package:permission_handler/permission_handler.dart';

class RtcPermissionHelper {
  /// Requests camera and microphone permissions and returns the result.
  static Future<bool> requestMediaPermissions() async {
    final camera = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    return camera.isGranted && mic.isGranted;
  }

  /// Checks the current camera permission status.
  static Future<PermissionStatus> checkCamera() => Permission.camera.status;

  /// Checks the current microphone permission status.
  static Future<PermissionStatus> checkMicrophone() =>
      Permission.microphone.status;
}
