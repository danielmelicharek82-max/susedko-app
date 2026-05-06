// lib/models/message.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime createdAt;
  final bool isRead;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() => {
        'conversationId': conversationId,
        'senderId': senderId,
        'senderName': senderName,
        'text': text,
        'createdAt': Timestamp.fromDate(createdAt),
        'isRead': isRead,
      };

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      conversationId: map['conversationId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      text: map['text'] ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: map['isRead'] ?? false,
    );
  }
}