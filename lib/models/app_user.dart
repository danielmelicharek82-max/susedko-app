// lib/models/app_user.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? profileImage;
  final String? phone;
  final String? fcmToken;
  final String language;
  final DateTime? createdAt;
  final double discountPercent;
  final bool isBlocked;
  final String? country;
  final String? city;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.profileImage,
    this.phone,
    this.fcmToken,
    this.language = 'sk',
    this.createdAt,
    this.discountPercent = 0,
    this.isBlocked = false,
    this.country,
    this.city,
  });

  String get displayName => name.isNotEmpty ? name : email;

  Map<String, dynamic> toMap() => {
    'name': name,
    'email': email,
    'role': role,
    'profileImage': profileImage,
    'phone': phone,
    'fcmToken': fcmToken,
    'language': language,
    'discountPercent': discountPercent,
    'isBlocked': isBlocked,
    'country': country,
    'city': city,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
  };

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return AppUser(
      id: doc.id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'customer',
      profileImage: map['profileImage'],
      phone: map['phone'],
      fcmToken: map['fcmToken'],
      language: map['language'] ?? 'sk',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      discountPercent: (map['discountPercent'] as num?)?.toDouble() ?? 0,
      isBlocked: map['isBlocked'] ?? false,
      country: map['country'],
      city: map['city'],
    );
  }

  AppUser copyWith({
    String? name,
    String? email,
    String? role,
    String? profileImage,
    String? phone,
    String? fcmToken,
    String? language,
    double? discountPercent,
    bool? isBlocked,
    String? country,
    String? city,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      profileImage: profileImage ?? this.profileImage,
      phone: phone ?? this.phone,
      fcmToken: fcmToken ?? this.fcmToken,
      language: language ?? this.language,
      createdAt: createdAt,
      discountPercent: discountPercent ?? this.discountPercent,
      isBlocked: isBlocked ?? this.isBlocked,
      country: country ?? this.country,
      city: city ?? this.city,
    );
  }
}
