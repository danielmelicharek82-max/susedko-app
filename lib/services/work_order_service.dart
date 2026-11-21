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

  // Verejný wrapper — UI obrazovky potrebujú vedieť skonštruovať ten
  // istý "yyyy-MM-dd" kľúč, aký sa používa v dailyLogs mape (napr. pri
  // vyhľadaní existujúceho DailyLog záznamu pre konkrétny deň).
  static String dateKeyFor(DateTime d) => _dateKey(d);

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
  static Future<String> create(WorkOrder order,
      {bool fromQuote = false, double? expectedNet}) async {
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
        // Pevná cena z cenovej ponuky: sumu berie server z ponuky; expectedNet
        // je suma, ktorú zákazník videl a schválil (ochrana pred zmenou ponuky).
        if (fromQuote) 'fromQuote': true,
        if (fromQuote && expectedNet != null) 'expectedNet': expectedNet,
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
        if (e.message == 'QUOTE_CHANGED') throw Exception('QUOTE_CHANGED');
        if (e.message == 'QUOTE_NOT_FOUND') throw Exception('QUOTE_NOT_FOUND');
        if (e.message == 'REQUEST_CLOSED') throw Exception('REQUEST_CLOSED');
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

  // ── PEVNÁ CENA ────────────────────────────────────────────────────────────
  // Remeselník ohlási dokončenie práce. Zákazník ju schváli (alebo žiada
  // úpravu) rovnakou cestou ako pri hodinách; cena sa nemení.
  static Future<void> completeFixed(String id) async {
    await _db.collection(_col).doc(id).update({
      'status': WorkOrderStatus.hoursLogged.name,
      'reworkNote': null,
      'craftsmanInsistNote': null,
    });
  }

  // Zákazník schválil dokončenú prácu → ide rovno na doplatok (bez týždennej
  // faktúry a bez výberu spôsobu platby).
  static Future<void> approveFixedAndPay(String id) async {
    await _db.collection(_col).doc(id).update({
      'status': WorkOrderStatus.paymentDue.name,
      'paymentMode': PaymentMode.immediate.name,
      'paymentStatus': WorkOrderPaymentStatus.approved.name,
      'hoursApprovedAt': FieldValue.serverTimestamp(),
    });
  }

  // Remeselník rozhodne o zálohe po zrušení zákazníkom.
  static Future<void> decideDepositRefund(String id, {required bool refund}) async {
    try {
      await _functions.httpsCallable('decideDepositRefund')
          .call(<String, dynamic>{'orderId': id, 'refund': refund});
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Nepodarilo sa spracovať rozhodnutie');
    }
  }

  // ── DOKLAD O NÁKUPE MATERIÁLU (pevná cena) ───────────────────────────────
  // Remeselník nahrá fotku/PDF dokladu do Storage a zapíše ho cez callable
  // (suma sa pri zrušení zákazníkom ponechá remeselníkovi, max. výška zálohy).
  static Future<void> submitMaterialProof({
    required String orderId,
    required double amount,
    required String receiptUrl,
  }) async {
    try {
      await _functions.httpsCallable('submitMaterialProof').call(<String, dynamic>{
        'orderId': orderId,
        'amount': amount,
        'receiptUrl': receiptUrl,
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Nepodarilo sa uložiť doklad');
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

  // ── VIACDŇOVÉ ZÁKAZKY: per-deň zadávanie/schvaľovanie hodín ───────────────
  // Priamy zápis do dailyLogs.{dateKey}.* — presne rovnaký vzor priameho
  // klientskeho zápisu ako logHours()/approveHours() vyššie pre jednodňové
  // zákazky. Cloud Function `onWorkOrderDailyLogsChanged` (index.js) po
  // každej zmene skontroluje, či sú už schválené úplne všetky dni, a ak
  // áno, sama posunie celú objednávku do hoursApproved (výber platby) —
  // klient sem nič ďalšie posielať nemusí.
  //
  // Sadzba (hourlyRate) je vždy rovnaká pre celú objednávku — ukladá sa
  // pri každom dni len ako pohodlná kópia pre prepočet, nemení sa deň
  // od dňa.

  static Future<void> logDailyHours({
    required String orderId,
    required DateTime day,
    required double hours,
    required double hourlyRate,
    String? note,
  }) async {
    final key = _dateKey(day);
    await _db.collection(_col).doc(orderId).update({
      'dailyLogs.$key.status': DailyLogStatus.logged.name,
      'dailyLogs.$key.hours': hours,
      'dailyLogs.$key.rate': hourlyRate,
      'dailyLogs.$key.craftsmanNote': note,
      'dailyLogs.$key.reworkNote': null,
      'dailyLogs.$key.craftsmanInsistNote': null,
      'dailyLogs.$key.disputeNote': null,
      'dailyLogs.$key.loggedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> approveDailyHours({
    required String orderId,
    required DateTime day,
  }) async {
    final key = _dateKey(day);
    await _db.collection(_col).doc(orderId).update({
      'dailyLogs.$key.status': DailyLogStatus.approved.name,
      'dailyLogs.$key.approvedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> requestDailyRework({
    required String orderId,
    required DateTime day,
    required String customerNote,
  }) async {
    final key = _dateKey(day);
    await _db.collection(_col).doc(orderId).update({
      'dailyLogs.$key.status': DailyLogStatus.reworkRequested.name,
      'dailyLogs.$key.reworkNote': customerNote,
    });
  }

  static Future<void> insistOnDailyHours({
    required String orderId,
    required DateTime day,
    required String reason,
  }) async {
    final key = _dateKey(day);
    await _db.collection(_col).doc(orderId).update({
      'dailyLogs.$key.status': DailyLogStatus.craftsmanInsisting.name,
      'dailyLogs.$key.craftsmanInsistNote': reason,
    });
  }

  // Zákazník napokon akceptuje remeselníkom trvané hodiny (bez sporu).
  static Future<void> acceptDailyDespiteInsistence({
    required String orderId,
    required DateTime day,
  }) async {
    final key = _dateKey(day);
    await _db.collection(_col).doc(orderId).update({
      'dailyLogs.$key.status': DailyLogStatus.approved.name,
      'dailyLogs.$key.approvedAt': FieldValue.serverTimestamp(),
    });
  }

  // Eskalácia sporu na admina — blokuje len TENTO deň, ostatné dni v
  // rozsahu môžu naďalej pokračovať svojou vlastnou cestou (zadanie,
  // schválenie...) nezávisle. Pozri rozhodnutie v návrhu: jeden sporný
  // deň nesmie zablokovať celú viacdňovú zákazku.
  static Future<void> escalateDailyToAdmin({
    required String orderId,
    required DateTime day,
    String? finalNote,
  }) async {
    final key = _dateKey(day);
    await _db.collection(_col).doc(orderId).update({
      'dailyLogs.$key.status': DailyLogStatus.disputed.name,
      if (finalNote != null && finalNote.isNotEmpty)
        'dailyLogs.$key.disputeNote': finalNote,
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