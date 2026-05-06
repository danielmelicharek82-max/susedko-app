// lib/services/service_request_service.dart
// ♻️  RECYCLE z tattoo_request_service.dart
// Rozšírené o broadcast požiadavky

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/service_request.dart';
import 'package:async/async.dart';

class ServiceRequestService {
  static final _db = FirebaseFirestore.instance;
  static const _col = 'service_requests';

  // ── Direct request (konkrétny remeselník) ─────────────────────────────────
  static Future<void> submitRequest(ServiceRequest request) async {
    await _db.collection(_col).add(request.toMap());
  }

  // ── Broadcast request (všetci v kategórii) ────────────────────────────────
  static Future<void> submitBroadcastRequest(ServiceRequest request) async {
    await _db.collection(_col).add({
      ...request.toMap(),
      'type':   'broadcast',
      'status': 'open',
      'craftsmanId':   null,
      'craftsmanName': null,
      'interestedCraftsmanIds': [],
    });
  }

  // ── NOVÉ METÓDY ──────────────────────────────────────────────────────────

  // Editácia broadcast požiadavky
  static Future<void> updateBroadcastRequest({
    required String requestId,
    required String profession,
    required String category,
    required String description,
    String? address,
    GeoPoint? location,
    double? budget,
    required List<String> photoUrls,
    required String timeframe,
  }) async {
    await _db.collection(_col).doc(requestId).update({
      'profession':  profession,
      'category':    category,
      'description': description,
      'address':     address,
      'location':    location,
      'budget':      budget,
      'photoUrls':   photoUrls,
      'timeframe':   timeframe,
    });
  }

  // Zmazanie broadcast požiadavky
  static Future<void> deleteBroadcastRequest(String requestId) async {
    await _db.collection(_col).doc(requestId).delete();
  }

  // Remeselník prejaví záujem o broadcast požiadavku
  static Future<void> expressInterest({
    required String requestId,
    required String craftsmanId,
    required String craftsmanName,
    String? message,
  }) async {
    await _db.collection(_col).doc(requestId).update({
      'interestedCraftsmanIds': FieldValue.arrayUnion([craftsmanId]),
      'interest_$craftsmanId': {
        'craftsmanId':   craftsmanId,
        'craftsmanName': craftsmanName,
        'message':       message,
        'timestamp':     FieldValue.serverTimestamp(),
      },
    });
  }

  // Zákazník vyberie remeselníka z broadcast požiadavky
  static Future<void> selectCraftsman({
    required String requestId,
    required String craftsmanId,
    required String craftsmanName,
  }) async {
    await _db.collection(_col).doc(requestId).update({
      'craftsmanId':   craftsmanId,
      'craftsmanName': craftsmanName,
      'status':        'pending',
      'type':          'direct',
    });
  }

  // ── Helper: rozdeľ list na chunky po N ────────────────────────────────────
  static List<List<T>> _chunks<T>(List<T> list, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      chunks.add(list.sublist(i, i + size > list.length ? list.length : i + size));
    }
    return chunks;
  }

  // ── Streams ───────────────────────────────────────────────────────────────

  // Remeselník — jeho direct požiadavky
  static Stream<List<ServiceRequest>> watchCraftsmanRequests(String craftsmanId) {
    return _db
        .collection(_col)
        .where('craftsmanId', isEqualTo: craftsmanId)
        .where('type', isEqualTo: 'direct')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ServiceRequest.fromFirestore).toList());
  }

  // Remeselník — otvorené broadcast požiadavky pre jeho profesie
  // ✅ FIX: whereIn má limit 10 — rozdelíme profesie na chunky a zlúčime streamy
  static Stream<List<ServiceRequest>> watchOpenRequests(List<String> professions) {
    if (professions.isEmpty) return const Stream.empty();

    final chunks = _chunks(professions, 10);

    // Vytvoríme stream pre každý chunk
    final streams = chunks.map((chunk) => _db
        .collection(_col)
        .where('status', isEqualTo: 'open')
        .where('type', isEqualTo: 'broadcast')
        .where('profession', whereIn: chunk)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ServiceRequest.fromFirestore).toList()));

    // Zlúčime všetky streamy do jedného
    return StreamZip(streams).map((lists) {
      final all = lists.expand((l) => l).toList();
      // Deduplikácia podľa id
      final seen = <String>{};
      final unique = all.where((r) => seen.add(r.id)).toList();
      // Zoradenie podľa createdAt desc
      unique.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return unique;
    });
  }

  // Zákazník — jeho broadcast požiadavky (kde vidí záujemcov)
  static Stream<List<ServiceRequest>> watchCustomerBroadcasts(String customerId) {
    return _db
        .collection(_col)
        .where('customerId', isEqualTo: customerId)
        .where('type', isEqualTo: 'broadcast')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ServiceRequest.fromFirestore).toList());
  }

  // Zákazník — jeho direct požiadavky
  static Stream<List<ServiceRequest>> watchCustomerRequests(String customerId) {
    return _db
        .collection(_col)
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ServiceRequest.fromFirestore).toList());
  }

  // ── Ostatné ───────────────────────────────────────────────────────────────

  static Future<void> updateStatus(
    String requestId,
    ServiceRequestStatus status, {
    String? reply,
  }) async {
    await _db.collection(_col).doc(requestId).update({
      'status': status.name,
      if (reply != null) 'craftsmanReply': reply,
    });
  }

  static Future<bool> hasPendingRequest(
      String customerId, String craftsmanId) async {
    final q = await _db
        .collection(_col)
        .where('customerId', isEqualTo: customerId)
        .where('craftsmanId', isEqualTo: craftsmanId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    return q.docs.isNotEmpty;
  }

  static Stream<int> watchPendingCount(String craftsmanId) {
    return _db
        .collection(_col)
        .where('craftsmanId', isEqualTo: craftsmanId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs.length);
  }

  // Počet otvorených broadcast požiadaviek pre remeselníka
  // ✅ FIX: rovnaký chunking ako watchOpenRequests
  static Stream<int> watchOpenRequestsCount(List<String> professions) {
    if (professions.isEmpty) return Stream.value(0);

    final chunks = _chunks(professions, 10);

    final streams = chunks.map((chunk) => _db
        .collection(_col)
        .where('status', isEqualTo: 'open')
        .where('type', isEqualTo: 'broadcast')
        .where('profession', whereIn: chunk)
        .snapshots()
        .map((s) => s.docs.length));

    return StreamZip(streams).map((counts) =>
        counts.fold(0, (sum, c) => sum + c));
  }
}