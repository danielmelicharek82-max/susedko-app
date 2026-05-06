// lib/models/review.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String craftsmanId;
  final String customerId;
  final String customerName;
  final String? customerPhoto;
  final double rating;
  final String? comment;
  final DateTime createdAt;
  final String? bookingId;
  final bool isApproved;

  Review({
    required this.id,
    required this.craftsmanId,
    required this.customerId,
    required this.customerName,
    this.customerPhoto,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.bookingId,
    this.isApproved = false,
  });

  Map<String, dynamic> toMap() => {
    'craftsmanId': craftsmanId,
    'customerId': customerId,
    'customerName': customerName,
    'customerPhoto': customerPhoto,
    'rating': rating,
    'comment': comment,
    'createdAt': Timestamp.fromDate(createdAt),
    'bookingId': bookingId,
    'isApproved': isApproved,
  };

  factory Review.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return Review(
      id: doc.id,
      craftsmanId: map['craftsmanId'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerPhoto: map['customerPhoto'],
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      comment: map['comment'],
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      bookingId: map['bookingId'],
      isApproved: map['isApproved'] ?? false,
    );
  }

  // ✅ pridaný fromMap pre admin_service
  factory Review.fromMap(Map<String, dynamic> map, String id) {
    return Review(
      id: id,
      craftsmanId: map['craftsmanId'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerPhoto: map['customerPhoto'],
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      comment: map['comment'],
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      bookingId: map['bookingId'],
      isApproved: map['isApproved'] ?? false,
    );
  }

  // ✅ pridaný copyWith pre admin_provider
  Review copyWith({
    String? craftsmanId,
    String? customerId,
    String? customerName,
    String? customerPhoto,
    double? rating,
    String? comment,
    DateTime? createdAt,
    String? bookingId,
    bool? isApproved,
  }) {
    return Review(
      id: id,
      craftsmanId: craftsmanId ?? this.craftsmanId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhoto: customerPhoto ?? this.customerPhoto,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      bookingId: bookingId ?? this.bookingId,
      isApproved: isApproved ?? this.isApproved,
    );
  }
}
