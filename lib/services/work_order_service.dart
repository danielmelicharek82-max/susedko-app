// lib/services/work_order_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/work_order.dart';

class WorkOrderService {
  static final _db = FirebaseFirestore.instance;
  static const _col = 'work_orders';

  // ── Helpers ───────────────────────────────────────────────────────────────
  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';

  static String _timeStr(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  static DocumentReference _availRef(String craftsmanId) => _db
      .collection('craftsmen')
      .doc(craftsmanId)
      .collection('availability')
      .doc('slots');

  // ── CREATE ────────────────────────────────────────────────────────────────
  static Future<String> create(WorkOrder order) async {
    final orderRef = _db.collection(_col).doc();
    final availRef = _availRef(order.craftsmanId);
    final slotKey = _dateKey(order.scheduledAt);
    final time = _timeStr(order.scheduledAt);

    await _db.runTransaction((tx) async {
      // ✅ NAJPRV READ (správne)
      final availSnap = await tx.get(availRef);

      final data = Map<String, dynamic>.from(
        (availSnap.data() as Map<String, dynamic>? ?? {}),
      );

      final slots = List<String>.from(data[slotKey] ?? []);

      // ❗ SLOT NEEXISTUJE = OBSADENÝ
      if (!slots.contains(time)) {
        throw Exception('SLOT_TAKEN');
      }

      // ✅ odstráň slot (rezervácia)
      slots.remove(time);

      if (slots.isEmpty) {
        data.remove(slotKey);
      } else {
        data[slotKey] = slots;
      }

      // ✅ WRITE až po read
      tx.set(orderRef, order.toMap());
      tx.set(availRef, data);
    });

    return orderRef.id;
  }

  // ── CONFIRM ───────────────────────────────────────────────────────────────
  static Future<void> confirm(String id) async {
    await _db.collection(_col).doc(id).update({
      'status': WorkOrderStatus.confirmed.name,
    });
  }

  // ── CANCEL ────────────────────────────────────────────────────────────────
  static Future<void> cancel(String id, {String? reason}) async {
    final doc = await _db.collection(_col).doc(id).get();
    if (!doc.exists) return;

    final order = WorkOrder.fromFirestore(doc);
    final availRef = _availRef(order.craftsmanId);
    final slotKey = _dateKey(order.scheduledAt);
    final time = _timeStr(order.scheduledAt);

    await _db.runTransaction((tx) async {
      tx.update(_db.collection(_col).doc(id), {
        'status': WorkOrderStatus.cancelled.name,
        if (reason != null) 'craftsmanNote': reason,
      });

      if (order.scheduledAt.isAfter(DateTime.now())) {
        final availSnap = await tx.get(availRef);

        final data = Map<String, dynamic>.from(
          (availSnap.data() as Map<String, dynamic>? ?? {}),
        );

        final slots = List<String>.from(data[slotKey] ?? []);

        if (!slots.contains(time)) {
          slots..add(time)..sort();
          data[slotKey] = slots;
        }

        tx.set(availRef, data);
      }
    });
  }

  // ── START WORK ────────────────────────────────────────────────────────────
  static Future<void> startWork(String id) async {
    await _db.collection(_col).doc(id).update({
      'status': WorkOrderStatus.inProgress.name,
    });
  }

  // ── LOG HOURS ─────────────────────────────────────────────────────────────
  static Future<void> logHours({
    required String id,
    required double hours,
    required double hourlyRate,
    String? note,
  }) async {
    final total = hours * hourlyRate;

    await _db.collection(_col).doc(id).update({
      'status': WorkOrderStatus.hoursLogged.name,
      'loggedHours': hours,
      'hourlyRate': hourlyRate,
      'totalAmount': double.parse(total.toStringAsFixed(2)),
      if (note != null) 'craftsmanNote': note,
      'reworkNote': null,
      'craftsmanInsistNote': null,
    });
  }

  static Future<void> confirmHours(String id) async {
    await _db.collection(_col).doc(id).update({
      'status': WorkOrderStatus.paymentDue.name,
    });
  }

  static Future<void> requestRework(String id, String customerNote) async {
    await _db.collection(_col).doc(id).update({
      'status': WorkOrderStatus.reworkRequested.name,
      'reworkNote': customerNote,
    });
  }

  static Future<void> adjustHours({
    required String id,
    required double hours,
    required double hourlyRate,
    String? note,
  }) =>
      logHours(id: id, hours: hours, hourlyRate: hourlyRate, note: note);

  static Future<void> insistOnHours(String id, String reason) async {
    await _db.collection(_col).doc(id).update({
      'status': WorkOrderStatus.craftsmanInsisting.name,
      'craftsmanInsistNote': reason,
    });
  }

  static Future<void> escalateToAdmin(String id, String? finalNote) async {
    await _db.collection(_col).doc(id).update({
      'status': WorkOrderStatus.disputed.name,
      if (finalNote != null && finalNote.isNotEmpty)
        'disputeNote': finalNote,
    });
  }

  static Future<void> acceptDespiteInsistence(String id) async {
    await _db.collection(_col).doc(id).update({
      'status': WorkOrderStatus.paymentDue.name,
    });
  }

  static Future<void> markPaid(String id, String paymentIntentId) async {
    await _db.collection(_col).doc(id).update({
      'status': WorkOrderStatus.completed.name,
      'paymentStatus': WorkOrderPaymentStatus.paid.name,
      'paymentIntentId': paymentIntentId,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> markReviewed(String id) async {
    await _db.collection(_col).doc(id).update({'isReviewed': true});
  }

  // ── STREAMS ───────────────────────────────────────────────────────────────
  static Stream<List<WorkOrder>> watchCustomer(String customerId) {
    return _db
        .collection(_col)
        .where('customerId', isEqualTo: customerId)
        .orderBy('scheduledAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(WorkOrder.fromFirestore).toList());
  }

  static Stream<List<WorkOrder>> watchCraftsman(String craftsmanId) {
    return _db
        .collection(_col)
        .where('craftsmanId', isEqualTo: craftsmanId)
        .orderBy('scheduledAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map(WorkOrder.fromFirestore).toList());
  }

  static Stream<int> watchPendingCount(String craftsmanId) {
    return _db
        .collection(_col)
        .where('craftsmanId', isEqualTo: craftsmanId)
        .where('status', isEqualTo: WorkOrderStatus.pending.name)
        .snapshots()
        .map((s) => s.docs.length);
  }

  static Stream<int> watchPaymentDueCount(String customerId) {
    return _db
        .collection(_col)
        .where('customerId', isEqualTo: customerId)
        .where('status', isEqualTo: WorkOrderStatus.paymentDue.name)
        .snapshots()
        .map((s) => s.docs.length);
  }
}