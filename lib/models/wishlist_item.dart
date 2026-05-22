// lib/models/wishlist_item.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class WishlistItem {
  final String id;
  final String userId;
  final String craftsmanId;   // ← zmenené z artistId
  final String craftsmanName;
  final String? craftsmanPhoto;
  final String? profession;
  final DateTime createdAt;

  WishlistItem({
    required this.id,
    required this.userId,
    required this.craftsmanId,
    required this.craftsmanName,
    this.craftsmanPhoto,
    this.profession,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'craftsmanId': craftsmanId,
        'craftsmanName': craftsmanName,
        'craftsmanPhoto': craftsmanPhoto,
        'profession': profession,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory WishlistItem.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return WishlistItem(
      id: doc.id,
      userId: map['userId'] ?? '',
      craftsmanId: map['craftsmanId'] ?? '',
      craftsmanName: map['craftsmanName'] ?? '',
      craftsmanPhoto: map['craftsmanPhoto'],
      profession: map['profession'],
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}