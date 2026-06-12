// lib/models/weekly_invoice.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum WeeklyInvoiceStatus {
  pending,   // čaká na platbu
  paid,      // zaplatená
  overdue,   // po splatnosti (3 dni)
  cancelled, // zrušená
}

enum InvoicePeriod {
  weekly,   // 7 dní
  biweekly, // 14 dní
}

class WeeklyInvoice {
  final String id;
  final String customerId;
  final String craftsmanId;

  final Map<String, dynamic>? customerSnapshot;
  final Map<String, dynamic>? craftsmanSnapshot;

  final List<String> orderIds;      // IDs zákaziek v tejto faktúre
  final double totalHours;
  final double totalAmount;         // suma ktorú zákazník zaplatí (s poplatkom)
  final double craftsmanAmount;     // suma ktorú dostane remeselník (bez 10%)

  final InvoicePeriod period;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime dueDate;           // deadline na zaplatenie (periodEnd + 3 dni)

  final WeeklyInvoiceStatus status;
  final String? paymentIntentId;

  final DateTime createdAt;
  final DateTime? paidAt;

  WeeklyInvoice({
    required this.id,
    required this.customerId,
    required this.craftsmanId,
    this.customerSnapshot,
    this.craftsmanSnapshot,
    required this.orderIds,
    required this.totalHours,
    required this.totalAmount,
    required this.craftsmanAmount,
    required this.period,
    required this.periodStart,
    required this.periodEnd,
    required this.dueDate,
    this.status = WeeklyInvoiceStatus.pending,
    this.paymentIntentId,
    required this.createdAt,
    this.paidAt,
  });

  bool get isOverdue =>
      status == WeeklyInvoiceStatus.pending &&
      DateTime.now().isAfter(dueDate);

  String get periodLabel {
    final f = (DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    return '${f(periodStart)} – ${f(periodEnd)}';
  }

  Map<String, dynamic> toMap() => {
    'customerId':       customerId,
    'craftsmanId':      craftsmanId,
    'customerSnapshot': customerSnapshot,
    'craftsmanSnapshot': craftsmanSnapshot,
    'orderIds':         orderIds,
    'totalHours':       totalHours,
    'totalAmount':      totalAmount,
    'craftsmanAmount':  craftsmanAmount,
    'period':           period.name,
    'periodStart':      Timestamp.fromDate(periodStart),
    'periodEnd':        Timestamp.fromDate(periodEnd),
    'dueDate':          Timestamp.fromDate(dueDate),
    'status':           status.name,
    'paymentIntentId':  paymentIntentId,
    'createdAt':        Timestamp.fromDate(createdAt),
    'paidAt':           paidAt != null ? Timestamp.fromDate(paidAt!) : null,
  };

  factory WeeklyInvoice.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return WeeklyInvoice(
      id:           doc.id,
      customerId:   map['customerId'] ?? '',
      craftsmanId:  map['craftsmanId'] ?? '',
      customerSnapshot: map['customerSnapshot'] != null
          ? Map<String, dynamic>.from(map['customerSnapshot']) : null,
      craftsmanSnapshot: map['craftsmanSnapshot'] != null
          ? Map<String, dynamic>.from(map['craftsmanSnapshot']) : null,
      orderIds:     List<String>.from(map['orderIds'] ?? []),
      totalHours:   (map['totalHours'] as num?)?.toDouble() ?? 0,
      totalAmount:  (map['totalAmount'] as num?)?.toDouble() ?? 0,
      craftsmanAmount: (map['craftsmanAmount'] as num?)?.toDouble() ?? 0,
      period: InvoicePeriod.values.firstWhere(
          (e) => e.name == map['period'],
          orElse: () => InvoicePeriod.weekly),
      periodStart:  (map['periodStart'] as Timestamp).toDate(),
      periodEnd:    (map['periodEnd'] as Timestamp).toDate(),
      dueDate:      (map['dueDate'] as Timestamp).toDate(),
      status: WeeklyInvoiceStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => WeeklyInvoiceStatus.pending),
      paymentIntentId: map['paymentIntentId'],
      createdAt:    (map['createdAt'] as Timestamp).toDate(),
      paidAt:       map['paidAt'] != null
          ? (map['paidAt'] as Timestamp).toDate() : null,
    );
  }

  WeeklyInvoice copyWith({
    WeeklyInvoiceStatus? status,
    String? paymentIntentId,
    List<String>? orderIds,
    double? totalHours,
    double? totalAmount,
    double? craftsmanAmount,
    DateTime? paidAt,
  }) => WeeklyInvoice(
    id: id, customerId: customerId, craftsmanId: craftsmanId,
    customerSnapshot: customerSnapshot, craftsmanSnapshot: craftsmanSnapshot,
    orderIds:        orderIds        ?? this.orderIds,
    totalHours:      totalHours      ?? this.totalHours,
    totalAmount:     totalAmount     ?? this.totalAmount,
    craftsmanAmount: craftsmanAmount ?? this.craftsmanAmount,
    period: period, periodStart: periodStart,
    periodEnd: periodEnd, dueDate: dueDate,
    status:          status          ?? this.status,
    paymentIntentId: paymentIntentId ?? this.paymentIntentId,
    createdAt: createdAt,
    paidAt:          paidAt          ?? this.paidAt,
  );
}
