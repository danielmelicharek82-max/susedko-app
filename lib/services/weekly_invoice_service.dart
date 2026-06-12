// lib/services/weekly_invoice_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/weekly_invoice.dart';
import '../models/work_order.dart';

class WeeklyInvoiceService {
  static final _db = FirebaseFirestore.instance;
  static const _col = 'weekly_invoices';
  static const _orderCol = 'work_orders';

  // ── Vypočítaj obdobie faktúry ─────────────────────────────────────────────
  static (DateTime start, DateTime end) _calcPeriod(
      InvoicePeriod period) {
    final now = DateTime.now();
    // Začneme od pondelka aktuálneho týždňa
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(monday.year, monday.month, monday.day);
    final days = period == InvoicePeriod.weekly ? 6 : 13;
    final end = start.add(Duration(days: days));
    return (start, end);
  }

  // ── Vytvor alebo aktualizuj faktúru ───────────────────────────────────────
  // Ak pre dané obdobie + customerId + craftsmanId faktúra už existuje,
  // pridá zákazky do nej. Inak vytvorí novú.
  static Future<WeeklyInvoice> createOrUpdate({
    required String customerId,
    required String craftsmanId,
    required List<WorkOrder> orders,
    required InvoicePeriod period,
    Map<String, dynamic>? customerSnapshot,
    Map<String, dynamic>? craftsmanSnapshot,
  }) async {
    if (orders.isEmpty) throw Exception('Žiadne zákazky na faktúru');

    final (start, end) = _calcPeriod(period);

    // Hľadáme existujúcu otvorenú faktúru pre rovnaké obdobie
    final existing = await _db
        .collection(_col)
        .where('customerId', isEqualTo: customerId)
        .where('craftsmanId', isEqualTo: craftsmanId)
        .where('status', isEqualTo: WeeklyInvoiceStatus.pending.name)
        .where('period', isEqualTo: period.name)
        .limit(1)
        .get();

    final orderIds = orders.map((o) => o.id).toList();
    final totalHours = orders.fold(
        0.0, (sum, o) => sum + (o.loggedHours ?? 0));
    final totalAmount = orders.fold(
        0.0, (sum, o) => sum + (o.calculatedTotal ?? 0));
    final craftsmanAmount = double.parse(
        (totalAmount / 1.1).toStringAsFixed(2));

    final batch = _db.batch();
    late WeeklyInvoice invoice;

    if (existing.docs.isNotEmpty) {
      // Pridaj do existujúcej faktúry
      final doc = existing.docs.first;
      final current = WeeklyInvoice.fromFirestore(doc);
      final mergedIds = [...current.orderIds, ...orderIds].toSet().toList();
      final newTotalH = current.totalHours + totalHours;
      final newTotalA = double.parse(
          (current.totalAmount + totalAmount).toStringAsFixed(2));
      final newCraftA = double.parse((newTotalA / 1.1).toStringAsFixed(2));

      batch.update(doc.reference, {
        'orderIds': mergedIds,
        'totalHours': newTotalH,
        'totalAmount': newTotalA,
        'craftsmanAmount': newCraftA,
      });

      // Priraď weeklyInvoiceId k zákazkám
      for (final id in orderIds) {
        batch.update(_db.collection(_orderCol).doc(id), {
          'weeklyInvoiceId': doc.id,
          'status': WorkOrderStatus.paymentDue.name,
        });
      }

      invoice = current.copyWith(
        orderIds: mergedIds,
        totalHours: newTotalH,
        totalAmount: newTotalA,
        craftsmanAmount: newCraftA,
      );
    } else {
      // Vytvor novú faktúru
      final ref = _db.collection(_col).doc();
      final dueDate = end.add(const Duration(days: 3));

      invoice = WeeklyInvoice(
        id:              ref.id,
        customerId:      customerId,
        craftsmanId:     craftsmanId,
        customerSnapshot: customerSnapshot,
        craftsmanSnapshot: craftsmanSnapshot,
        orderIds:        orderIds,
        totalHours:      totalHours,
        totalAmount:     totalAmount,
        craftsmanAmount: craftsmanAmount,
        period:          period,
        periodStart:     start,
        periodEnd:       end,
        dueDate:         dueDate,
        status:          WeeklyInvoiceStatus.pending,
        createdAt:       DateTime.now(),
      );

      batch.set(ref, invoice.toMap());

      // Priraď weeklyInvoiceId k zákazkám
      for (final id in orderIds) {
        batch.update(_db.collection(_orderCol).doc(id), {
          'weeklyInvoiceId': ref.id,
          'status': WorkOrderStatus.paymentDue.name,
        });
      }
    }

    await batch.commit();
    return invoice;
  }

  // ── Označ faktúru ako zaplatenú ───────────────────────────────────────────
  static Future<void> markPaid(
      String invoiceId, String paymentIntentId) async {
    // Najprv načítaj faktúru aby sme mali orderIds
    final doc = await _db.collection(_col).doc(invoiceId).get();
    if (!doc.exists) throw Exception('Faktúra nenájdená');

    final invoice = WeeklyInvoice.fromFirestore(doc);
    final batch = _db.batch();

    // Aktualizuj faktúru
    batch.update(_db.collection(_col).doc(invoiceId), {
      'status': WeeklyInvoiceStatus.paid.name,
      'paymentIntentId': paymentIntentId,
      'paidAt': FieldValue.serverTimestamp(),
    });

    // Označ všetky zákazky ako zaplatené
    for (final orderId in invoice.orderIds) {
      batch.update(_db.collection(_orderCol).doc(orderId), {
        'status': WorkOrderStatus.completed.name,
        'paymentStatus': WorkOrderPaymentStatus.paid.name,
        'paymentIntentId': paymentIntentId,
        'completedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // ── Aktualizuj premlčané faktúry ──────────────────────────────────────────
  static Future<void> checkOverdue() async {
    final now = Timestamp.now();
    final snap = await _db
        .collection(_col)
        .where('status', isEqualTo: WeeklyInvoiceStatus.pending.name)
        .where('dueDate', isLessThan: now)
        .get();

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {
        'status': WeeklyInvoiceStatus.overdue.name,
      });
    }
    await batch.commit();
  }

  // ── STREAMS ───────────────────────────────────────────────────────────────
  static Stream<List<WeeklyInvoice>> watchCustomerInvoices(
      String customerId) {
    return _db
        .collection(_col)
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(WeeklyInvoice.fromFirestore).toList());
  }

  static Stream<List<WeeklyInvoice>> watchCraftsmanInvoices(
      String craftsmanId) {
    return _db
        .collection(_col)
        .where('craftsmanId', isEqualTo: craftsmanId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(WeeklyInvoice.fromFirestore).toList());
  }

  static Stream<int> watchPendingInvoiceCount(String customerId) {
    return _db
        .collection(_col)
        .where('customerId', isEqualTo: customerId)
        .where('status', isEqualTo: WeeklyInvoiceStatus.pending.name)
        .snapshots()
        .map((s) => s.docs.length);
  }
}
