// lib/models/conversation.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Conversation {
  final String id;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final Map<String, String?> participantPhotos;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final Map<String, int> unreadCount;
  final DateTime? createdAt;

  Conversation({
    required this.id,
    required this.participantIds,
    required this.participantNames,
    required this.participantPhotos,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = const {},
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'participantIds': participantIds,
        'participantNames': participantNames,
        'participantPhotos': participantPhotos,
        'lastMessage': lastMessage,
        'lastMessageAt': lastMessageAt != null
            ? Timestamp.fromDate(lastMessageAt!)
            : null,
        'unreadCount': unreadCount,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
      };

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return Conversation(
      id: doc.id,
      participantIds: List<String>.from(map['participantIds'] ?? []),
      participantNames: Map<String, String>.from(map['participantNames'] ?? {}),
      participantPhotos:
          Map<String, String?>.from(map['participantPhotos'] ?? {}),
      lastMessage: map['lastMessage'],
      lastMessageAt: map['lastMessageAt'] is Timestamp
          ? (map['lastMessageAt'] as Timestamp).toDate()
          : null,
      unreadCount: Map<String, int>.from(map['unreadCount'] ?? {}),
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}