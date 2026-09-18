import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Firebase Cloud Messaging - low-stock alerts, debt reminders, day-close
/// nudges.
///
/// The repo intentionally ships WITHOUT google-services.json /
/// GoogleService-Info.plist (no secrets in git). Until you drop your own
/// config in (see README → Push Notifications), every call here is a
/// graceful no-op and the app runs normally.
abstract final class FcmService {
  static bool _configured = false;
  static bool get isConfigured => _configured;
  static final _tokenCtrl = StreamController<String>.broadcast();
  static Stream<String> get tokenStream => _tokenCtrl.stream;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp(); // throws when no native config present
      _configured = true;
      final messaging = FirebaseMessaging.instance;

      // Foreground messages → local banner via stream (UI subscribes).
      FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
        debugPrint('FCM foreground: ${msg.notification?.title}');
      });

      // Ask for permission (no-op if already granted / not configured).
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null) _tokenCtrl.add(token);
    } on Exception catch (_) {
      _configured = false; // no Firebase config - fine, keep running
    }
  }
}
