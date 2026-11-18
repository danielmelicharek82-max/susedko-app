// lib/models/issued_invoice.dart
//
// Vystavený doklad (faktúra pre zákazníka alebo samofaktúra remeselníka).
// Vytvára ich server (Cloud Functions) po zaplatení — appka ich len číta
// z kolekcie `invoices` a sťahuje cez callable getInvoiceDownloadUrl.

import 'package:cloud_firestore/cloud_firestore.dart';

class IssuedInvoice {
  /// 'customer_invoice' = faktúra Susedko → zákazník,
  /// 'self_billed'      = samofaktúra remeselníka (vystavená v jeho mene).
  final String id;
  final String type;
  final String number;
  final String issueDate; // YYYY-MM-DD
  final String dueDate;   // YYYY-MM-DD
  final double net;
  final double vat;
  final double gross;
  final bool paid;
  final bool hasXml;
  final String status;
  final DateTime? createdAt;

  const IssuedInvoice({
    required this.id,
    required this.type,
    required this.number,
    required this.issueDate,
    required this.dueDate,
    required this.net,
    required this.vat,
    required this.gross,
    required this.paid,
    required this.hasXml,
    required this.status,
    this.createdAt,
  });

  bool get isSelfBilled => type == 'self_billed';

  /// 2026-11-05 → 05.11.2026
  String get issueDateLabel => _label(issueDate);
  String get dueDateLabel => _label(dueDate);

  static String _label(String iso) {
    final p = iso.split('-');
    return p.length == 3 ? '${p[2]}.${p[1]}.${p[0]}' : iso;
  }

  factory IssuedInvoice.fromFirestore(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return IssuedInvoice(
      id: doc.id,
      type: (m['type'] ?? 'customer_invoice').toString(),
      number: (m['number'] ?? '').toString(),
      issueDate: (m['issueDate'] ?? '').toString(),
      dueDate: (m['dueDate'] ?? '').toString(),
      net: (m['net'] as num?)?.toDouble() ?? 0,
      vat: (m['vat'] as num?)?.toDouble() ?? 0,
      gross: (m['gross'] as num?)?.toDouble() ?? 0,
      paid: m['paid'] == true,
      hasXml: (m['xmlPath'] ?? '').toString().isNotEmpty,
      status: (m['status'] ?? '').toString(),
      createdAt: m['createdAt'] is Timestamp
          ? (m['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}
