// lib/models/service_request.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum ServiceRequestStatus { pending, accepted, declined, expired, open }
enum ServiceRequestType { direct, broadcast }

class ServiceRequest {
  final String id;
  final String customerId;
  final String? craftsmanId;
  final String? craftsmanName;
  final String customerName;
  final String customerEmail;

  final String profession;
  final String category;
  final String description;
  final String? estimatedDuration;
  final List<String> photoUrls;
  final double? budget;
  final String? note;
  final String timeframe;
  final String? address;
  final GeoPoint? location;

  final ServiceRequestStatus status;
  final ServiceRequestType type;
  final List<String> interestedCraftsmanIds;
  final DateTime createdAt;
  final String? craftsmanReply;

  // ── Admin-only transient fields (not stored in Firestore) ─────────────────
  final String? adminCustomerEmail;
  final String? adminCustomerPhone;
  final String? adminCraftsmanEmail;
  final String? adminCraftsmanPhone;

  ServiceRequest({
    required this.id,
    required this.customerId,
    this.craftsmanId,
    this.craftsmanName,
    required this.customerName,
    required this.customerEmail,
    required this.profession,
    required this.category,
    required this.description,
    this.estimatedDuration,
    this.photoUrls = const [],
    this.budget,
    this.note,
    required this.timeframe,
    this.address,
    this.location,
    required this.status,
    this.type = ServiceRequestType.direct,
    this.interestedCraftsmanIds = const [],
    required this.createdAt,
    this.craftsmanReply,
    this.adminCustomerEmail,
    this.adminCustomerPhone,
    this.adminCraftsmanEmail,
    this.adminCraftsmanPhone,
  });

  bool get isBroadcast => type == ServiceRequestType.broadcast;

  Map<String, dynamic> toMap() => {
    'customerId':             customerId,
    'craftsmanId':            craftsmanId,
    'craftsmanName':          craftsmanName,
    'customerName':           customerName,
    'customerEmail':          customerEmail,
    'profession':             profession,
    'category':               category,
    'description':            description,
    'estimatedDuration':      estimatedDuration,
    'photoUrls':              photoUrls,
    'budget':                 budget,
    'note':                   note,
    'timeframe':              timeframe,
    'address':                address,
    'location':               location,
    'status':                 status.name,
    'type':                   type.name,
    'interestedCraftsmanIds': interestedCraftsmanIds,
    'createdAt':              Timestamp.fromDate(createdAt),
    'craftsmanReply':         craftsmanReply,
    // adminContacts sú transient — neukladáme ich do Firestore
  };

  factory ServiceRequest.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return ServiceRequest(
      id:            doc.id,
      customerId:    map['customerId'] ?? '',
      craftsmanId:   map['craftsmanId'],
      craftsmanName: map['craftsmanName'],
      customerName:  map['customerName'] ?? '',
      customerEmail: map['customerEmail'] ?? '',
      profession:    map['profession'] ?? '',
      category:      map['category'] ?? '',
      description:   map['description'] ?? '',
      estimatedDuration: map['estimatedDuration'],
      photoUrls:     List<String>.from(map['photoUrls'] ?? []),
      budget:        map['budget'] != null ? (map['budget'] as num).toDouble() : null,
      note:          map['note'],
      timeframe:     map['timeframe'] ?? 'flexible',
      address:       map['address'],
      location:      map['location'] as GeoPoint?,
      status: ServiceRequestStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ServiceRequestStatus.pending),
      type: ServiceRequestType.values.firstWhere(
        (e) => e.name == (map['type'] ?? 'direct'),
        orElse: () => ServiceRequestType.direct),
      interestedCraftsmanIds:
          List<String>.from(map['interestedCraftsmanIds'] ?? []),
      createdAt:     (map['createdAt'] as Timestamp).toDate(),
      craftsmanReply: map['craftsmanReply'],
    );
  }

  ServiceRequest copyWith({
    String? profession,
    String? category,
    String? description,
    String? estimatedDuration,
    List<String>? photoUrls,
    double? budget,
    String? note,
    String? timeframe,
    String? address,
    GeoPoint? location,
    ServiceRequestStatus? status,
    String? craftsmanReply,
    List<String>? interestedCraftsmanIds,
  }) {
    return ServiceRequest(
      id:            id,
      customerId:    customerId,
      craftsmanId:   craftsmanId,
      craftsmanName: craftsmanName,
      customerName:  customerName,
      customerEmail: customerEmail,
      profession:    profession ?? this.profession,
      category:      category ?? this.category,
      description:   description ?? this.description,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      photoUrls:     photoUrls ?? this.photoUrls,
      budget:        budget ?? this.budget,
      note:          note ?? this.note,
      timeframe:     timeframe ?? this.timeframe,
      address:       address ?? this.address,
      location:      location ?? this.location,
      status:        status ?? this.status,
      type:          type,
      interestedCraftsmanIds:
          interestedCraftsmanIds ?? this.interestedCraftsmanIds,
      createdAt:     createdAt,
      craftsmanReply: craftsmanReply ?? this.craftsmanReply,
      // zachovaj admin kontakty
      adminCustomerEmail:  adminCustomerEmail,
      adminCustomerPhone:  adminCustomerPhone,
      adminCraftsmanEmail: adminCraftsmanEmail,
      adminCraftsmanPhone: adminCraftsmanPhone,
    );
  }

  // ── Admin helper: obohať o kontaktné info bez uloženia do Firestore ────────
  ServiceRequest copyWithAdminContacts({
    String? customerEmail,
    String? customerPhone,
    String? craftsmanEmail,
    String? craftsmanPhone,
  }) {
    return ServiceRequest(
      id:            id,
      customerId:    customerId,
      craftsmanId:   craftsmanId,
      craftsmanName: craftsmanName,
      customerName:  customerName,
      customerEmail: this.customerEmail,
      profession:    profession,
      category:      category,
      description:   description,
      estimatedDuration: estimatedDuration,
      photoUrls:     photoUrls,
      budget:        budget,
      note:          note,
      timeframe:     timeframe,
      address:       address,
      location:      location,
      status:        status,
      type:          type,
      interestedCraftsmanIds: interestedCraftsmanIds,
      createdAt:     createdAt,
      craftsmanReply: craftsmanReply,
      adminCustomerEmail:  customerEmail ?? adminCustomerEmail,
      adminCustomerPhone:  customerPhone ?? adminCustomerPhone,
      adminCraftsmanEmail: craftsmanEmail ?? adminCraftsmanEmail,
      adminCraftsmanPhone: craftsmanPhone ?? adminCraftsmanPhone,
    );
  }
}