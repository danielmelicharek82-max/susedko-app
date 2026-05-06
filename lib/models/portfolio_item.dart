// lib/models/portfolio_item.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class PortfolioItem {
  final String id;
  final String craftsmanId;   // ← zmenené z artistId
  final String imageUrl;
  final String? title;
  final String? description;
  final String? profession;   // ← nové: napr. "Inštalatér"
  final String? category;     // ← nové: napr. "Opravy & údržba"
  final DateTime createdAt;

  PortfolioItem({
    required this.id,
    required this.craftsmanId,
    required this.imageUrl,
    this.title,
    this.description,
    this.profession,
    this.category,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'craftsmanId': craftsmanId,
        'imageUrl': imageUrl,
        'title': title,
        'description': description,
        'profession': profession,
        'category': category,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory PortfolioItem.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return PortfolioItem(
      id: doc.id,
      craftsmanId: map['craftsmanId'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      title: map['title'],
      description: map['description'],
      profession: map['profession'],
      category: map['category'],
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}