# flutter-webrtc-client

A lightweight, cross-platform WebRTC video calling client built with **Flutter** and **Socket.IO** for signaling.

---

## ✨ Features

- 📹 Real-time video and audio call using WebRTC
- 🧭 Join a room by name (room-based signaling)
- 🔗 Socket.IO-based signaling server support
- 🌓 Dark UI with responsive layout (portrait & landscape)
- 🚀 Works on Android (iOS & Web support possible with few changes)

---

## 🚀 Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/csc7545/flutter-webrtc-client.git
cd flutter-webrtc-client
```

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Run on device
```bash
flutter run
```

### 🛑 Make sure your signaling server is running at http://<your-ip>:3000.

---

## 🔧 Configuration

Update the signaling server URL in rtc_screen.dart:

```bash
const String socketUrl = 'http://192.168.0.100:3000'; // your server IP
```

---

## 📦 Dependencies

- flutter_webrtc
-	socket_io_client
-	permission_handler

---
