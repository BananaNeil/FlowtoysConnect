import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:app/authentication.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/client.dart';
import 'dart:convert';

import 'package:url_launcher/url_launcher.dart'
  if (dart.library.html) 'package:app/web_launcher.dart';

class PushNotificationsManager {

  bool _initialized = false;
  PushNotificationsManager._();
  factory PushNotificationsManager() => _instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final PushNotificationsManager _instance = PushNotificationsManager._();


  Future<void> init() async {
    if (_initialized) return;

    if (!kIsWeb)
      await _initializeFireBase();

    _initialized = true;
  }

  void _initializeFireBase() async {
    print("INIT FIREBASE");
    // For iOS request permission first.
    await _firebaseMessaging.requestPermission();
    FirebaseMessaging.onBackgroundMessage((RemoteMessage message) async {
      // var data = message['data'] ?? message;
      // AppController.openPath(data['path']);
    });
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // var data = message['data'] ?? message;
      // AppController.openPath(data['path']);
    });

    String token = await _firebaseMessaging.getToken();
    print("FirebaseMessaging token: $token");
    await Client.setFireBaseToken(token);
  }

}

