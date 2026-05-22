// lib/models/craftsman.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Craftsman {
  final String id;
  final String name;
  final String? bio;
  final String? profileImage;
  final String? email;

  final String profession;
  final String category;
  final List<String> skills;
  final String? cityName;
  final String? streetAddress;
  final GeoPoint? geoPoint;

  final double? hourlyRate;         // sadzba remeselníka (interná)
  final double? hourlyRateCustomer; // sadzba pre zákazníka (+10%)

  final double depositPercent;
  final bool isVerified;
  final double rating;
  final int reviewCount;
  final bool isActive;
  final DateTime? createdAt;

  Craftsman({
    required this.id,
    required this.name,
    this.bio,
    this.profileImage,
    this.email,
    this.profession = '',
    this.category = '',
    this.skills = const [],
    this.cityName,
    this.streetAddress,
    this.geoPoint,
    this.hourlyRate,
    this.hourlyRateCustomer,
    this.depositPercent = 30.0,
    this.isVerified = false,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.isActive = true,
    this.createdAt,
  });

  /// Cena ktorú vidí zákazník — ak nie je uložená, vypočíta sa +10%
  double? get displayRate {
    if (hourlyRateCustomer != null) return hourlyRateCustomer;
    if (hourlyRate != null) return hourlyRate! * 1.10;
    return null;
  }

  String? get fullAddress {
    if (streetAddress != null && cityName != null) return '$streetAddress, $cityName';
    if (streetAddress != null) return streetAddress;
    if (cityName != null) return cityName;
    return null;
  }

  Map<String, dynamic> toMap() => {
    'name':               name,
    'bio':                bio,
    'profileImage':       profileImage,
    'email':              email,
    'profession':         profession,
    'category':           category,
    'skills':             skills,
    'cityName':           cityName,
    'streetAddress':      streetAddress,
    'geoPoint':           geoPoint,
    'hourlyRate':         hourlyRate,
    'hourlyRateCustomer': hourlyRateCustomer,
    'depositPercent':     depositPercent,
    'isVerified':         isVerified,
    'rating':             rating,
    'reviewCount':        reviewCount,
    'isActive':           isActive,
    'createdAt':          createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
  };

  factory Craftsman.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return Craftsman(
      id:               doc.id,
      name:             map['name'] ?? '',
      bio:              map['bio'],
      profileImage:     map['profileImage'],
      email:            map['email'],
      profession:       map['profession'] ?? '',
      category:         map['category'] ?? '',
      skills:           List<String>.from(map['skills'] ?? []),
      cityName:         map['cityName'],
      streetAddress:    map['streetAddress'],
      geoPoint:         map['geoPoint'] as GeoPoint?,
      hourlyRate:       map['hourlyRate'] != null
          ? (map['hourlyRate'] as num).toDouble() : null,
      hourlyRateCustomer: map['hourlyRateCustomer'] != null
          ? (map['hourlyRateCustomer'] as num).toDouble() : null,
      depositPercent:   (map['depositPercent'] as num?)?.toDouble() ?? 30.0,
      isVerified:       map['isVerified'] ?? false,
      rating:           (map['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount:      map['reviewCount'] ?? 0,
      isActive:         map['isActive'] ?? true,
      createdAt:        map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate() : null,
    );
  }

  Craftsman copyWith({
    String? name, String? bio, String? profileImage, String? email,
    String? profession, String? category, List<String>? skills,
    String? cityName, String? streetAddress, GeoPoint? geoPoint,
    double? hourlyRate, double? hourlyRateCustomer,
    double? depositPercent, bool? isVerified,
    double? rating, int? reviewCount, bool? isActive,
  }) {
    return Craftsman(
      id: id,
      name: name ?? this.name,
      bio: bio ?? this.bio,
      profileImage: profileImage ?? this.profileImage,
      email: email ?? this.email,
      profession: profession ?? this.profession,
      category: category ?? this.category,
      skills: skills ?? this.skills,
      cityName: cityName ?? this.cityName,
      streetAddress: streetAddress ?? this.streetAddress,
      geoPoint: geoPoint ?? this.geoPoint,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      hourlyRateCustomer: hourlyRateCustomer ?? this.hourlyRateCustomer,
      depositPercent: depositPercent ?? this.depositPercent,
      isVerified: isVerified ?? this.isVerified,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }
}