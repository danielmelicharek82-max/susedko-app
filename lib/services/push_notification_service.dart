// lib/services/push_notification_service.dart
// ♻️  RECYCLE z push_notification_service.dart (Inkmaker)
// Zmeny: artist_bookings → craftsman_bookings, artist_requests → craftsman_requests

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final GlobalKey<NavigatorState> navigatorKey;

  PushNotificationService({required this.navigatorKey});

  Future<void> init() async {
    final settings = await _fcm.requestPermission(alert: true, badge: true, sound: true);
    if (settings.authorizationStatus != AuthorizationStatus.authorized) return;

    const bookingsChannel = AndroidNotificationChannel(
      'bookings_channel', 'Rezervácie',
      description: 'Notifikácie o rezerváciách', importance: Importance.max);
    const requestsChannel = AndroidNotificationChannel(
      'requests_channel', 'Požiadavky',
      description: 'Notifikácie o nových požiadavkách', importance: Importance.high);
    const chatChannel = AndroidNotificationChannel(
      'chat_channel', 'Správy',
      description: 'Správy od remeselníkov a zákazníkov', importance: Importance.high);

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(bookingsChannel);
    await androidPlugin?.createNotificationChannel(requestsChannel);
    await androidPlugin?.createNotificationChannel(chatChannel);

    await _localNotifications.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (details) => _handleNotificationTap(details.payload));

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;
      final type = message.data['type'] as String? ?? '';
      String channelId = 'bookings_channel';
      String channelName = 'Rezervácie';
      if (type == 'new_request') { channelId = 'requests_channel'; channelName = 'Požiadavky'; }
      else if (type == 'new_message') { channelId = 'chat_channel'; channelName = 'Správy'; }
      _localNotifications.show(notification.hashCode, notification.title, notification.body,
        NotificationDetails(android: AndroidNotificationDetails(channelId, channelName,
            importance: Importance.max, priority: Priority.high)),
        payload: _buildPayload(message.data));
    });

    FirebaseMessaging.onMessageOpenedApp.listen((msg) => _handleNotificationTap(_buildPayload(msg.data)));
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) _handleNotificationTap(_buildPayload(initialMessage.data));
  }

  String? _buildPayload(Map<String, dynamic> data) {
    final screen    = data['screen']    as String?;
    final bookingId = data['bookingId'] as String?;
    final requestId = data['requestId'] as String?;
    if (screen == 'booking_detail' && bookingId != null) return 'booking_detail:$bookingId';
    if (screen == 'service_request' && requestId != null) return 'service_request:$requestId';
    if (screen != null && screen.startsWith('chat:')) return screen;
    return screen;
  }

  void _handleNotificationTap(String? payload) {
    if (payload == null) return;
    if (payload.startsWith('booking_detail:')) {
      navigatorKey.currentState?.pushNamed('/booking_detail', arguments: payload.split(':').last);
      return;
    }
    if (payload.startsWith('service_request:')) {
      navigatorKey.currentState?.pushNamed('/craftsman_requests');
      return;
    }
    switch (payload) {
      case 'customer_bookings':   navigatorKey.currentState?.pushNamed('/customer_bookings'); break;
      case 'craftsman_bookings':  navigatorKey.currentState?.pushNamed('/craftsman_bookings'); break;
      case 'craftsman_requests':  navigatorKey.currentState?.pushNamed('/craftsman_requests'); break;
      case 'chat':                navigatorKey.currentState?.pushNamed('/chat'); break;
    }
  }
}
