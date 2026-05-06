// lib/models/work_order.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum WorkOrderStatus {
  pending,           // zákazník vytvoril, čaká na potvrdenie remeselníka
  confirmed,         // remeselník potvrdil
  inProgress,        // práca prebieha
  hoursLogged,       // remeselník zadal hodiny, čaká na potvrdenie zákazníka
  reworkRequested,   // zákazník žiada prepracovanie / úpravu hodín
  craftsmanInsisting,// remeselník trvá na pôvodných hodinách → potenciálny spor
  disputed,          // zákazník potvrdil spor → admin rieši
  paymentDue,        // zákazník potvrdil hodiny, čaká na platbu
  paid,              // zaplatené
  completed,         // dokončené + zaplatené
  cancelled,         // zrušené
}

enum WorkOrderPaymentStatus {
  unpaid,
  paid,
  refunded,
}

class WorkOrder {
  final String id;
  final String customerId;
  final String craftsmanId;

  final Map<String, dynamic>? customerSnapshot;
  final Map<String, dynamic>? craftsmanSnapshot;

  final String? profession;
  final String? category;
  final String? description;
  final String? address;
  final String? note;
  final List<String> photoUrls;

  final DateTime scheduledAt;
  final int estimatedHours;

  final String? serviceRequestId;

  final double? loggedHours;
  final double? hourlyRate;
  final double? totalAmount;
  final String? craftsmanNote;
  final String? disputeNote;
  final String? reworkNote;
  final String? craftsmanInsistNote;

  final WorkOrderPaymentStatus paymentStatus;
  final String? paymentIntentId;

  final WorkOrderStatus status;
  final bool isReviewed;
  final DateTime createdAt;
  final DateTime? completedAt;

  WorkOrder({
    required this.id,
    required this.customerId,
    required this.craftsmanId,
    this.customerSnapshot,
    this.craftsmanSnapshot,
    this.profession,
    this.category,
    this.description,
    this.address,
    this.note,
    this.photoUrls = const [],
    required this.scheduledAt,
    this.estimatedHours = 2,
    this.serviceRequestId,
    this.loggedHours,
    this.hourlyRate,
    this.totalAmount,
    this.craftsmanNote,
    this.disputeNote,
    this.reworkNote,
    this.craftsmanInsistNote,
    this.paymentStatus = WorkOrderPaymentStatus.unpaid,
    this.paymentIntentId,
    this.status = WorkOrderStatus.pending,
    this.isReviewed = false,
    required this.createdAt,
    this.completedAt,
  });

  double? get calculatedTotal {
    if (totalAmount != null) return totalAmount;
    if (loggedHours != null && hourlyRate != null) {
      return loggedHours! * hourlyRate!;
    }
    return null;
  }

  bool get isPaid => paymentStatus == WorkOrderPaymentStatus.paid;
  bool get needsPayment => status == WorkOrderStatus.paymentDue && !isPaid;

  Map<String, dynamic> toMap() => {
    'customerId':          customerId,
    'craftsmanId':         craftsmanId,
    'customerSnapshot':    customerSnapshot,
    'craftsmanSnapshot':   craftsmanSnapshot,
    'profession':          profession,
    'category':            category,
    'description':         description,
    'address':             address,
    'note':                note,
    'photoUrls':           photoUrls,
    'scheduledAt':         Timestamp.fromDate(scheduledAt),
    'estimatedHours':      estimatedHours,
    'serviceRequestId':    serviceRequestId,
    'loggedHours':         loggedHours,
    'hourlyRate':          hourlyRate,
    'totalAmount':         totalAmount,
    'craftsmanNote':       craftsmanNote,
    'disputeNote':         disputeNote,
    'reworkNote':          reworkNote,
    'craftsmanInsistNote': craftsmanInsistNote,
    'paymentStatus':       paymentStatus.name,
    'paymentIntentId':     paymentIntentId,
    'status':              status.name,
    'isReviewed':          isReviewed,
    'createdAt':           Timestamp.fromDate(createdAt),
    'completedAt':         completedAt != null
        ? Timestamp.fromDate(completedAt!) : null,
  };

  factory WorkOrder.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return WorkOrder(
      id:            doc.id,
      customerId:    map['customerId'] ?? '',
      craftsmanId:   map['craftsmanId'] ?? '',
      customerSnapshot: map['customerSnapshot'] != null
          ? Map<String, dynamic>.from(map['customerSnapshot']) : null,
      craftsmanSnapshot: map['craftsmanSnapshot'] != null
          ? Map<String, dynamic>.from(map['craftsmanSnapshot']) : null,
      profession:    map['profession'],
      category:      map['category'],
      description:   map['description'],
      address:       map['address'],
      note:          map['note'],
      photoUrls:     List<String>.from(map['photoUrls'] ?? []),
      scheduledAt:   (map['scheduledAt'] as Timestamp).toDate(),
      estimatedHours: map['estimatedHours'] ?? 2,
      serviceRequestId: map['serviceRequestId'],
      loggedHours:   map['loggedHours'] != null
          ? (map['loggedHours'] as num).toDouble() : null,
      hourlyRate:    map['hourlyRate'] != null
          ? (map['hourlyRate'] as num).toDouble() : null,
      totalAmount:   map['totalAmount'] != null
          ? (map['totalAmount'] as num).toDouble() : null,
      craftsmanNote:       map['craftsmanNote'],
      disputeNote:         map['disputeNote'],
      reworkNote:          map['reworkNote'],
      craftsmanInsistNote: map['craftsmanInsistNote'],
      paymentStatus: WorkOrderPaymentStatus.values.firstWhere(
          (e) => e.name == map['paymentStatus'],
          orElse: () => WorkOrderPaymentStatus.unpaid),
      paymentIntentId: map['paymentIntentId'],
      status: WorkOrderStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => WorkOrderStatus.pending),
      isReviewed:    map['isReviewed'] ?? false,
      createdAt:     (map['createdAt'] as Timestamp).toDate(),
      completedAt:   map['completedAt'] != null
          ? (map['completedAt'] as Timestamp).toDate() : null,
    );
  }

  // ✅ FIX: pridané customerSnapshot + craftsmanSnapshot
  WorkOrder copyWith({
    WorkOrderStatus? status,
    WorkOrderPaymentStatus? paymentStatus,
    Map<String, dynamic>? customerSnapshot,
    Map<String, dynamic>? craftsmanSnapshot,
    double? loggedHours,
    double? hourlyRate,
    double? totalAmount,
    String? craftsmanNote,
    String? disputeNote,
    String? reworkNote,
    String? craftsmanInsistNote,
    String? paymentIntentId,
    bool? isReviewed,
    DateTime? completedAt,
  }) {
    return WorkOrder(
      id: id, customerId: customerId, craftsmanId: craftsmanId,
      customerSnapshot:  customerSnapshot  ?? this.customerSnapshot,
      craftsmanSnapshot: craftsmanSnapshot ?? this.craftsmanSnapshot,
      profession: profession, category: category, description: description,
      address: address, note: note, photoUrls: photoUrls,
      scheduledAt: scheduledAt, estimatedHours: estimatedHours,
      serviceRequestId: serviceRequestId,
      loggedHours:         loggedHours         ?? this.loggedHours,
      hourlyRate:          hourlyRate           ?? this.hourlyRate,
      totalAmount:         totalAmount          ?? this.totalAmount,
      craftsmanNote:       craftsmanNote        ?? this.craftsmanNote,
      disputeNote:         disputeNote          ?? this.disputeNote,
      reworkNote:          reworkNote           ?? this.reworkNote,
      craftsmanInsistNote: craftsmanInsistNote  ?? this.craftsmanInsistNote,
      paymentStatus:       paymentStatus        ?? this.paymentStatus,
      paymentIntentId:     paymentIntentId      ?? this.paymentIntentId,
      status:              status               ?? this.status,
      isReviewed:          isReviewed           ?? this.isReviewed,
      createdAt:           createdAt,
      completedAt:         completedAt          ?? this.completedAt,
    );
  }
}