// lib/services/work_order_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/work_order.dart';
import '../models/weekly_invoice.dart'; // InvoicePeriod

class WorkOrderService {
  static final _db = FirebaseFirestore.instance;
  static const _col = 'work_orders';
  static final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

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
  // Vytvorenie objednávky ide cez Cloud Function (createWorkOrder),
  // pretože zákazník (auth.uid != craftsmanId) nemá podľa Firestore
  // Security Rules právo zapisovať do craftsmen/{id}/availability/slots
  // priamo z klienta. Function beží s admin právami a:
  //   1. overí že slot je voľný (transakčne, bez race condition)
  //   2. vytvorí work_order dokument
  //   3. odoberie slot z dostupnosti remeselníka
  //   4. pošle remeselníkovi push notifikáciu
  static Future<String> create(WorkOrder order) async {
    if (FirebaseAuth.instance.currentUser == null) {
      throw Exception('NOT_AUTHENTICATED');
    }

    try {
      final callable = _functions.httpsCallable('createWorkOrder');
      final result = await callable.call(<String, dynamic>{
        'craftsmanId': order.craftsmanId,
        'customerSnapshot': order.customerSnapshot,
        'craftsmanSnapshot': order.craftsmanSnapshot,
        'profession': order.profession,
        'category': order.category,
        'description': order.description,
        'address': order.address,
        'note': order.note,
        'photoUrls': order.photoUrls,
        'scheduledAt': order.scheduledAt.toIso8601String(),
        'scheduledEndAt': order.scheduledEndAt?.toIso8601String(),
        'estimatedHours': order.estimatedHours,
        'serviceRequestId': order.serviceRequestId,
      });

      final orderId = result.data['orderId'] as String?;
      if (orderId == null) {
        throw Exception('Server nevrátil ID objednávky');
      }
      return orderId;

    } on FirebaseFunctionsException catch (e) {
      // Premapuj na čitateľné chyby pre UI. Server posiela v message
      // buď 'SLOT_TAKEN' (vybraný čas v deň 1 už nie je voľný) alebo,
      // pri viacdňovej zákazke, 'DAY_UNAVAILABLE' (niektorý z ďalších
      // dní rozsahu nemá žiadny slot — remeselník v ten deň vôbec
      // nepracuje), aby to UI vedelo rozlíšiť a ukázať vhodnú hlášku.
      if (e.code == 'failed-precondition') {
        if (e.message == 'DAY_UNAVAILABLE') {
          throw Exception('DAY_UNAVAILABLE');
        }
        throw Exception('SLOT_TAKEN');
      }
      if (e.code == 'unauthenticated') {
        throw Exception('NOT_AUTHENTICATED');
      }
      throw Exception(e.message ?? 'Nepodarilo sa vytvoriť objednávku');
    }
  }

  // ── CONFIRM ───────────────────────────────────────────────────────────────
  static Future<void> confirm(String id) async {
    await _db.collection(_col).doc(id).update({
      'status': WorkOrderStatus.confirmed.name,
    });
  }

  // ── CANCEL ────────────────────────────────────────────────────────────────
  // Cez Cloud Function (cancelWorkOrder) — zo segrovacieho dôvodu ako create():
  // vrátenie slotu do dostupnosti remeselníka je zápis do cudzej kolekcie,
  // ktorý klient (zákazník ani remeselník v opačnom garde) nemá podľa rules
  // dovolené urobiť priamo v rámci jednej transakcie.
  static Future<void> cancel(String id, {String? reason}) async {
    if (FirebaseAuth.instance.currentUser == null) {
      throw Exception('NOT_AUTHENTICATED');
    }
    try {
      final callable = _functions.httpsCallable('cancelWorkOrder');
      await callable.call(<String, dynamic>{
        'orderId': id,
        if (reason != null) 'reason': reason,
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Nepodarilo sa zrušiť objednávku');
    }
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

  // ── APPROVE HOURS (nové) ──────────────────────────────────────────────────
  // Zákazník schváli hodiny — zákazka čaká na výber spôsobu platby.
  // Na rozdiel od confirmHours() NEPRESUNIE zákazku do paymentDue okamžite.
  static Future<void> approveHours(String id) async {
    await _db.collection(_col).doc(id).update({
      'status': WorkOrderStatus.hoursApproved.name,
      'paymentStatus': WorkOrderPaymentStatus.approved.name,
      'hoursApprovedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── CONFIRM HOURS → okamžitá platba ───────────────────────────────────────
  // Zachované pre spätnú kompatibilitu + okamžitú platbu
  static Future<void> confirmHours(String id) async {
    await _db.collection(_col).doc(id).update({
      'status': WorkOrderStatus.paymentDue.name,
      'paymentMode': PaymentMode.immediate.name,
      'hoursApprovedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── SCHVÁLIŤ A NASTAVIŤ OKAMŽITÚ PLATBU ──────────────────────────────────
  static Future<void> approveAndPayNow(String id) async {
    await _db.collection(_col).doc(id).update({
      'status': WorkOrderStatus.paymentDue.name,
      'paymentMode': PaymentMode.immediate.name,
      'hoursApprovedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── SCHVÁLIŤ A PRIDAŤ DO SÚHRNNEJ FAKTÚRY ────────────────────────────────
  static Future<void> approveAndAddToInvoice(
      String id, InvoicePeriod period) async {
    await _db.collection(_col).doc(id).update({
      'status': WorkOrderStatus.hoursApproved.name,
      'paymentMode': period == InvoicePeriod.weekly
          ? PaymentMode.weekly.name
          : PaymentMode.biweekly.name,
      'paymentStatus': WorkOrderPaymentStatus.approved.name,
      'hoursApprovedAt': FieldValue.serverTimestamp(),
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
      'status': WorkOrderStatus.hoursApproved.name,
      'paymentStatus': WorkOrderPaymentStatus.approved.name,
      'hoursApprovedAt': FieldValue.serverTimestamp(),
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
        .where('status', whereIn: [
          WorkOrderStatus.paymentDue.name,
          WorkOrderStatus.hoursApproved.name,
        ])
        .snapshots()
        .map((s) => s.docs.length);
  }

  // Zákazky schválené ale ešte bez priradenia k faktúre
  static Stream<List<WorkOrder>> watchApprovedWithoutInvoice(
      String customerId, String craftsmanId) {
    return _db
        .collection(_col)
        .where('customerId', isEqualTo: customerId)
        .where('craftsmanId', isEqualTo: craftsmanId)
        .where('status', isEqualTo: WorkOrderStatus.hoursApproved.name)
        .where('weeklyInvoiceId', isNull: true)
        .snapshots()
        .map((s) => s.docs.map(WorkOrder.fromFirestore).toList());
  }
}