// lib/models/booking.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingStatus {
  pending,    // zákazník zabookoval, čaká na potvrdenie remeselníka
  confirmed,  // remeselník potvrdil
  inProgress, // prebieha práca
  completed,  // dokončené, zákazník môže hodnotiť
  cancelled,  // zrušené
  noShow,     // zákazník nebol doma
}

enum PaymentStatus {
  unpaid,
  depositPaid,   // záloha zaplatená
  fullyPaid,     // celá suma zaplatená
  refunded,
}

class Booking {
  final String id;
  final String customerId;
  final String craftsmanId;

  // Snapshoty — zachované pre prípad zmeny profilu
  final Map<String, dynamic>? customerSnapshot;
  final Map<String, dynamic>? craftsmanSnapshot;

  // Termín
  final DateTime scheduledAt;
  final int durationMinutes;

  // Prepojenie na service request (voliteľné)
  final String? serviceRequestId;

  // Popis práce
  final String? profession;         // napr. "Inštalatér"
  final String? category;           // napr. "Opravy & údržba"
  final String? description;        // popis práce
  final String? address;            // adresa kde sa práca vykoná
  final String? note;
  final List<String> photoUrls;     // fotky problému

  // Platba
  final double totalPrice;
  final double depositAmount;
  final double? finalAmount;
  final PaymentStatus paymentStatus;
  final String? depositPaymentIntentId;
  final String? finalPaymentIntentId;

  // Status
  final BookingStatus status;
  final bool isReviewed;
  final DateTime createdAt;
  final DateTime? completedAt;

  Booking({
    required this.id,
    required this.customerId,
    required this.craftsmanId,
    this.customerSnapshot,
    this.craftsmanSnapshot,
    required this.scheduledAt,
    this.durationMinutes = 60,
    this.serviceRequestId,
    this.profession,
    this.category,
    this.description,
    this.address,
    this.note,
    this.photoUrls = const [],
    required this.totalPrice,
    required this.depositAmount,
    this.finalAmount,
    this.paymentStatus = PaymentStatus.unpaid,
    this.depositPaymentIntentId,
    this.finalPaymentIntentId,
    this.status = BookingStatus.pending,
    this.isReviewed = false,
    required this.createdAt,
    this.completedAt,
  });

  bool get isDepositPaid =>
      paymentStatus == PaymentStatus.depositPaid ||
      paymentStatus == PaymentStatus.fullyPaid;

  bool get isFullyPaid => paymentStatus == PaymentStatus.fullyPaid;

  double get effectiveTotal => finalAmount ?? totalPrice;

  double get remainingAmount => effectiveTotal - depositAmount;

  Map<String, dynamic> toMap() => {
        'customerId': customerId,
        'craftsmanId': craftsmanId,
        'customerSnapshot': customerSnapshot,
        'craftsmanSnapshot': craftsmanSnapshot,
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        'durationMinutes': durationMinutes,
        'serviceRequestId': serviceRequestId,
        'profession': profession,
        'category': category,
        'description': description,
        'address': address,
        'note': note,
        'photoUrls': photoUrls,
        'totalPrice': totalPrice,
        'depositAmount': depositAmount,
        'finalAmount': finalAmount,
        'paymentStatus': paymentStatus.name,
        'depositPaymentIntentId': depositPaymentIntentId,
        'finalPaymentIntentId': finalPaymentIntentId,
        'status': status.name,
        'isReviewed': isReviewed,
        'createdAt': Timestamp.fromDate(createdAt),
        'completedAt':
            completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      };

  factory Booking.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;

    BookingStatus parseStatus(String? s) =>
        BookingStatus.values.firstWhere((e) => e.name == s,
            orElse: () => BookingStatus.pending);

    PaymentStatus parsePayment(String? s) =>
        PaymentStatus.values.firstWhere((e) => e.name == s,
            orElse: () => PaymentStatus.unpaid);

    return Booking(
      id: doc.id,
      customerId: map['customerId'] ?? '',
      craftsmanId: map['craftsmanId'] ?? '',
      customerSnapshot: map['customerSnapshot'] != null
          ? Map<String, dynamic>.from(map['customerSnapshot'])
          : null,
      craftsmanSnapshot: map['craftsmanSnapshot'] != null
          ? Map<String, dynamic>.from(map['craftsmanSnapshot'])
          : null,
      scheduledAt: (map['scheduledAt'] as Timestamp).toDate(),
      durationMinutes: map['durationMinutes'] ?? 60,
      serviceRequestId: map['serviceRequestId'],
      profession: map['profession'],
      category: map['category'],
      description: map['description'],
      address: map['address'],
      note: map['note'],
      photoUrls: List<String>.from(map['photoUrls'] ?? []),
      totalPrice: (map['totalPrice'] as num?)?.toDouble() ?? 0.0,
      depositAmount: (map['depositAmount'] as num?)?.toDouble() ?? 0.0,
      finalAmount: map['finalAmount'] != null
          ? (map['finalAmount'] as num).toDouble()
          : null,
      paymentStatus: parsePayment(map['paymentStatus']),
      depositPaymentIntentId: map['depositPaymentIntentId'],
      finalPaymentIntentId: map['finalPaymentIntentId'],
      status: parseStatus(map['status']),
      isReviewed: map['isReviewed'] ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      completedAt: map['completedAt'] != null
          ? (map['completedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Booking copyWith({
    BookingStatus? status,
    PaymentStatus? paymentStatus,
    double? finalAmount,
    String? depositPaymentIntentId,
    String? finalPaymentIntentId,
    bool? isReviewed,
    DateTime? completedAt,
    String? address,
    String? description,
  }) {
    return Booking(
      id: id,
      customerId: customerId,
      craftsmanId: craftsmanId,
      customerSnapshot: customerSnapshot,
      craftsmanSnapshot: craftsmanSnapshot,
      scheduledAt: scheduledAt,
      durationMinutes: durationMinutes,
      serviceRequestId: serviceRequestId,
      profession: profession,
      category: category,
      description: description ?? this.description,
      address: address ?? this.address,
      note: note,
      photoUrls: photoUrls,
      totalPrice: totalPrice,
      depositAmount: depositAmount,
      finalAmount: finalAmount ?? this.finalAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      depositPaymentIntentId:
          depositPaymentIntentId ?? this.depositPaymentIntentId,
      finalPaymentIntentId:
          finalPaymentIntentId ?? this.finalPaymentIntentId,
      status: status ?? this.status,
      isReviewed: isReviewed ?? this.isReviewed,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}