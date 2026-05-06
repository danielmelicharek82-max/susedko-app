import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _cachedToken;
  String? _cachedUid;

  // ── INIT ─────────────────────────────────────────────────────────────
  Future<void> init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await saveToken(user.uid);

    _fcm.onTokenRefresh.listen((newToken) async {
      _cachedToken = null;
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await saveToken(currentUser.uid, token: newToken);
      }
    });
  }

  // ── SAVE TOKEN ───────────────────────────────────────────────────────
  Future<void> saveToken(String uid, {String? token}) async {
    try {
      final fcmToken = token ?? await _fcm.getToken();

      if (fcmToken == null) {
        debugPrint('FCM: token je null pre uid: $uid');
        return;
      }

      if (fcmToken == _cachedToken && uid == _cachedUid) {
        return;
      }

      _cachedToken = fcmToken;
      _cachedUid = uid;

      final tokenData = {
        'fcmToken': fcmToken,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      };

      // ── ALWAYS SAVE TO USERS ─────────────────────────────
      await _db.collection('users')
          .doc(uid)
          .set(tokenData, SetOptions(merge: true));

      // ── GET ROLE ─────────────────────────────────────────
      final userDoc = await _db.collection('users').doc(uid).get();
      final role = (userDoc.data()?['role'] as String?)
              ?.trim()
              .toLowerCase() ?? '';

      // ── CRAFTSMAN ────────────────────────────────────────
      if (role == 'craftsman') {
        await _db.collection('craftsmen')
            .doc(uid)
            .set(tokenData, SetOptions(merge: true));
      }

      // ── CUSTOMER (🔥 TOTO CHÝBALO) ───────────────────────
      if (role == 'customer') {
        await _db.collection('customers')
            .doc(uid)
            .set(tokenData, SetOptions(merge: true));
      }

      debugPrint('FCM: token uložený pre $uid (role: $role)');
    } catch (e) {
      debugPrint('FCM: chyba pri ukladaní tokenu: $e');
    }
  }

  // ── CLEAR TOKEN ─────────────────────────────────────────────────────
  Future<void> clearToken(String uid) async {
    try {
      _cachedToken = null;
      _cachedUid = null;

      await _db.collection('users')
          .doc(uid)
          .update({'fcmToken': FieldValue.delete()});

      final userDoc = await _db.collection('users').doc(uid).get();
      final role = (userDoc.data()?['role'] as String?)
              ?.trim()
              .toLowerCase() ?? '';

      if (role == 'craftsman') {
        await _db.collection('craftsmen')
            .doc(uid)
            .update({'fcmToken': FieldValue.delete()});
      }

      if (role == 'customer') {
        await _db.collection('customers')
            .doc(uid)
            .update({'fcmToken': FieldValue.delete()});
      }

      debugPrint('FCM: token vymazaný pre $uid');
    } catch (e) {
      debugPrint('FCM: chyba pri mazaní tokenu: $e');
    }
  }
}