// lib/models/inspection.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class InspectionOffer {
  final String craftsmanId;
  final String craftsmanName;
  final String? proposedDates;
  InspectionOffer({
    required this.craftsmanId,
    required this.craftsmanName,
    this.proposedDates,
  });
  factory InspectionOffer.fromMap(Map<String, dynamic> m) => InspectionOffer(
        craftsmanId: (m['craftsmanId'] ?? '').toString(),
        craftsmanName: (m['craftsmanName'] ?? '').toString(),
        proposedDates: m['proposedDates']?.toString(),
      );
}

/// Stavy: awaiting_payment, paid, visited, confirmed, quote_accepted,
/// refunded. (Neskoré zrušenie zákazníkom = confirmed + lateCancelled.)
class Inspection {
  final String id;
  final String requestId;
  final String customerId;
  final String craftsmanId;
  final String status;
  final double fee;
  final double craftsmanPayout;
  final DateTime? visitAt;
  final DateTime? autoConfirmAt;
  final DateTime? quoteDueAt;
  final bool lateCancelled;
  final String? refundReason;

  Inspection({
    required this.id,
    required this.requestId,
    required this.customerId,
    required this.craftsmanId,
    required this.status,
    required this.fee,
    required this.craftsmanPayout,
    this.visitAt,
    this.autoConfirmAt,
    this.quoteDueAt,
    this.lateCancelled = false,
    this.refundReason,
  });

  bool get isPaid => const ['paid', 'visited', 'confirmed', 'quote_accepted']
      .contains(status);
  bool get canCancel => status == 'paid';
  bool get awaitingVisit => status == 'paid';
  bool get awaitingConfirm => status == 'visited';
  /// Remeselník môže poslať ponuku (potvrdená, nie neskoro zrušená).
  bool get canSendQuote => status == 'confirmed' && !lateCancelled;

  static DateTime? _d(dynamic v) => v is Timestamp ? v.toDate() : null;

  factory Inspection.fromFirestore(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return Inspection(
      id: doc.id,
      requestId: (m['requestId'] ?? '').toString(),
      customerId: (m['customerId'] ?? '').toString(),
      craftsmanId: (m['craftsmanId'] ?? '').toString(),
      status: (m['status'] ?? '').toString(),
      fee: (m['fee'] as num?)?.toDouble() ?? 0,
      craftsmanPayout: (m['craftsmanPayout'] as num?)?.toDouble() ?? 0,
      visitAt: _d(m['visitAt']),
      autoConfirmAt: _d(m['autoConfirmAt']),
      quoteDueAt: _d(m['quoteDueAt']),
      lateCancelled: m['lateCancelled'] == true,
      refundReason: m['refundReason']?.toString(),
    );
  }
}
