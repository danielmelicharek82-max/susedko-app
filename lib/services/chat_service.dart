// lib/services/chat_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  static final _firestore = FirebaseFirestore.instance;

  // ─────────────────────────────────────────
  // KONVERZÁCIA — tatér ↔ zákazník
  // ─────────────────────────────────────────

  // Instance metóda
  Future<String> getOrCreateConversation({
    required String userId1,
    required String userId2,
  }) async {
    return ChatService.createOrGetConversation(
      userId1: userId1,
      userId2: userId2,
    );
  }

  // ✅ OPRAVENÉ: positional args → named args (chat_screen.dart volá named)
  static Future<String> createOrGetConversation({
    required String userId1,
    required String userId2,
  }) async {
    final ids = [userId1, userId2]..sort();
    final conversationId = '${ids[0]}_${ids[1]}';
    final docRef =
        _firestore.collection('conversations').doc(conversationId);
    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({
        'participants': [userId1, userId2],
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return conversationId;
  }

  // Pre booking kontext
  static Future<String> createOrGetBookingConversation({
    required String bookingId,
    required String customerId,
    required String artistId,
  }) async {
    final conversationId = 'booking_$bookingId';
    final docRef =
        _firestore.collection('conversations').doc(conversationId);
    final doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({
        'bookingId': bookingId,
        'participants': [customerId, artistId],
        'customerId': customerId,
        'artistId': artistId,
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return conversationId;
  }

  // ─────────────────────────────────────────
  // SPRÁVY
  // ─────────────────────────────────────────

  static Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;

    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add({
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });

    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .update({
      'lastMessage': text.trim(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': senderId,
    });

    await _sendChatNotification(
      receiverId: receiverId,
      senderId: senderId,
      text: text.trim(),
      conversationId: conversationId,
    );
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getMessages(
      String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots();
  }

  static Future<void> markAsRead({
    required String conversationId,
    required String userId,
  }) async {
    final unread = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('receiverId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  // ─────────────────────────────────────────
  // UNREAD COUNT
  // ─────────────────────────────────────────

  Stream<int> getUnreadChatsCount(String userId) =>
      ChatService.getUnreadCount(userId);

  static Stream<int> getUnreadCount(String userId) {
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .snapshots()
        .asyncMap((snapshot) async {
      int count = 0;
      for (final doc in snapshot.docs) {
        final unread = await doc.reference
            .collection('messages')
            .where('receiverId', isEqualTo: userId)
            .where('read', isEqualTo: false)
            .get();
        if (unread.docs.isNotEmpty) count++;
      }
      return count;
    });
  }

  // ─────────────────────────────────────────
  // KONVERZÁCIE ZOZNAM
  // ─────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> getConversationsForUser(String userId) =>
      ChatService._conversationsStream(userId);

  static Stream<List<Map<String, dynamic>>> _conversationsStream(
      String userId) {
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  // ─────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────

  static Future<String> getUserName(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['name'] ?? 'Používateľ';
      }
    } catch (_) {}
    return 'Používateľ';
  }

  static Future<void> _sendChatNotification({
    required String receiverId,
    required String senderId,
    required String text,
    required String conversationId,
  }) async {
    try {
      final senderDoc =
          await _firestore.collection('users').doc(senderId).get();
      final senderName = senderDoc.data()?['name'] ?? 'Nová správa';
      final fcmToken =
          (await _firestore.collection('users').doc(receiverId).get())
              .data()?['fcmToken'];

      if (fcmToken == null) return;

      await _firestore.collection('notification_queue').add({
        'token': fcmToken,
        'title': senderName,
        'body': text.length > 60 ? '${text.substring(0, 60)}...' : text,
        'data': {
          'type': 'new_message',
          'conversationId': conversationId,
          'screen': 'chat',
        },
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      });
    } catch (e) {
      // Notifikácia nie je kritická
    }
  }
}