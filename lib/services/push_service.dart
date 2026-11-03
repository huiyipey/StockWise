import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PushService {
  PushService._();
  static final instance = PushService._();
  final local = FlutterLocalNotificationsPlugin();
  String? token;
  StreamSubscription<User?>? authSubscription;
  StreamSubscription<String>? refresh;
  StreamSubscription<RemoteMessage>? foreground;
  Future<void> initialize() async {
    if (kIsWeb ||
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform)) {
      return;
    }
    await local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'stockwise_updates',
            'StockWise updates',
            description: 'Expiry, order and message alerts',
            importance: Importance.high,
          ),
        );
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: true,
          sound: false,
        );
    authSubscription = FirebaseAuth.instance.idTokenChanges().listen((
      user,
    ) async {
      if (user == null) return;
      try {
        final settings = await FirebaseMessaging.instance.requestPermission();
        if (settings.authorizationStatus == AuthorizationStatus.denied) return;
        token = await FirebaseMessaging.instance.getToken();
        if (token != null) await register(token!);
      } catch (_) {
        /* Device registration retries on token/account refresh. */
      }
    });
    refresh = FirebaseMessaging.instance.onTokenRefresh.listen((value) async {
      token = value;
      try {
        await register(value);
      } catch (_) {}
    });
    foreground = FirebaseMessaging.onMessage.listen((message) async {
      if (message.data['recipientUid'] !=
          FirebaseAuth.instance.currentUser?.uid) {
        return;
      }
      final notice = message.notification;
      if (notice == null) return;
      await local.show(
        id:
            (message.messageId ?? DateTime.now().toString()).hashCode &
            0x7fffffff,
        title: notice.title,
        body: notice.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'stockwise_updates',
            'StockWise updates',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notification',
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    });
  }

  Future<void> register(String value) async {
    if (FirebaseAuth.instance.currentUser == null) return;
    await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
        .httpsCallable('registerPushToken')
        .call({'token': value, 'platform': defaultTargetPlatform.name});
  }

  Future<void> detach() async {
    if (kIsWeb ||
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform)) {
      return;
    }
    try {
      if (token != null) {
        await FirebaseFunctions.instanceFor(
          region: 'asia-southeast1',
        ).httpsCallable('unregisterPushToken').call({'token': token});
      }
    } catch (_) {}
    try {
      await FirebaseMessaging.instance.deleteToken();
      await local.cancelAll();
    } catch (_) {}
    token = null;
  }
}
