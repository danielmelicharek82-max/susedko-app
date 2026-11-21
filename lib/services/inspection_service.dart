// lib/services/inspection_service.dart
// Platená obhliadka pri hromadnom dopyte s cenovou ponukou.
// Všetky zápisy robí server (functions/inspections.js) — appka len volá
// callable funkcie a číta kolekciu `inspections`.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/inspection.dart';

class InspectionService {
  static final _db = FirebaseFirestore.instance;
  static final _fn = FirebaseFunctions.instanceFor(region: 'europe-west1');

  static const double defaultFee = 40;

  /// Cena obhliadky z config/pricing.inspectionFee (zmeníš ju bez novej verzie
  /// appky). Pri chybe/absencii 40 €.
  static Future<double> fee() async {
    try {
      final s = await _db.collection('config').doc('pricing').get();
      final f = (s.data() ?? {})['inspectionFee'];
      if (f is num && f > 0) return f.toDouble();
    } catch (_) {}
    return defaultFee;
  }

  static String idOf(String requestId, String craftsmanId) =>
      '${requestId}_$craftsmanId';

  // ── Záujem remeselníka o obhliadku (bez ceny) ──────────────────────────
  static Future<void> expressInspectionInterest({
    required String requestId,
    required String craftsmanId,
    required String craftsmanName,
    String? proposedDates,
  }) async {
    final ref = _db.collection('service_requests').doc(requestId);
    await ref.collection('inspection_offers').doc(craftsmanId).set({
      'craftsmanId': craftsmanId,
      'craftsmanName': craftsmanName,
      'proposedDates': (proposedDates ?? '').trim().isEmpty
          ? null : proposedDates!.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> withdrawInspectionInterest(
      String requestId, String craftsmanId) async {
    await _db.collection('service_requests').doc(requestId)
        .collection('inspection_offers').doc(craftsmanId).delete();
  }

  static Stream<InspectionOffer?> watchMyOffer(
      String requestId, String craftsmanId) {
    return _db.collection('service_requests').doc(requestId)
        .collection('inspection_offers').doc(craftsmanId)
        .snapshots()
        .map((s) => s.exists ? InspectionOffer.fromMap(s.data()!) : null);
  }

  /// Zákazník: všetci remeselníci, ktorí chcú obhliadku.
  static Stream<List<InspectionOffer>> watchOffers(String requestId) {
    return _db.collection('service_requests').doc(requestId)
        .collection('inspection_offers')
        .snapshots()
        .map((q) => q.docs.map((d) => InspectionOffer.fromMap(d.data())).toList());
  }

  // ── Obhliadky (iba čítanie) ────────────────────────────────────────────
  static Stream<Inspection?> watch(String inspectionId) {
    return _db.collection('inspections').doc(inspectionId).snapshots()
        .map((s) => s.exists ? Inspection.fromFirestore(s) : null);
  }

  static Stream<List<Inspection>> watchForRequest(
      String requestId, String customerId) {
    return _db.collection('inspections')
        .where('customerId', isEqualTo: customerId)
        .where('requestId', isEqualTo: requestId)
        .snapshots()
        .map((q) => q.docs.map(Inspection.fromFirestore).toList());
  }

  static Stream<List<Inspection>> watchForCraftsman(String craftsmanId) {
    return _db.collection('inspections')
        .where('craftsmanId', isEqualTo: craftsmanId)
        .snapshots()
        .map((q) => q.docs.map(Inspection.fromFirestore).toList());
  }

  // ── Callable funkcie ───────────────────────────────────────────────────
  /// Zákazník vyberie remeselníka → server vytvorí obhliadku a PaymentIntent.
  /// Vracia {inspectionId, clientSecret}.
  static Future<Map<String, dynamic>> createPayment({
    required String requestId,
    required String craftsmanId,
  }) async {
    final r = await _fn.httpsCallable('createInspectionPayment').call({
      'requestId': requestId,
      'craftsmanId': craftsmanId,
      'currency': 'eur',
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  /// Po úspešnej platbe v PaymentSheet — overí stav u Stripe.
  static Future<String> syncPayment(String inspectionId) async {
    final r = await _fn.httpsCallable('syncInspectionPayment')
        .call({'inspectionId': inspectionId});
    return (r.data as Map)['status']?.toString() ?? '';
  }

  static Future<void> schedule(String inspectionId, DateTime visitAt) =>
      _fn.httpsCallable('scheduleInspection').call({
        'inspectionId': inspectionId,
        'visitAt': visitAt.toUtc().toIso8601String(),
      });

  static Future<void> markDone(String inspectionId) =>
      _fn.httpsCallable('markInspectionDone').call({'inspectionId': inspectionId});

  static Future<void> confirmDone(String inspectionId) =>
      _fn.httpsCallable('confirmInspectionDone').call({'inspectionId': inspectionId});

  /// Vracia true, ak sa platba vrátila zákazníkovi.
  static Future<bool> cancel(String inspectionId) async {
    final r = await _fn.httpsCallable('cancelInspection')
        .call({'inspectionId': inspectionId});
    return (r.data as Map)['refunded'] == true;
  }
}
