// lib/services/service_request_service.dart
// ♻️  RECYCLE z tattoo_request_service.dart
// Rozšírené o broadcast požiadavky

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/service_request.dart';
import '../models/quote.dart';
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
    required List<String> professions,
    required String category,
    required String description,
    String? address,
    GeoPoint? location,
    double? budget,
    required List<String> photoUrls,
    required String timeframe,
    bool quoteRequired = false,
    DateTime? quoteDeadline,
    String quoteBasis = 'documents',
    List<Map<String, String>> documentUrls = const [],
    String? estimatedScope,
  }) async {
    assert(professions.isNotEmpty && professions.length <= 3,
        'professions must contain between 1 and 3 items');
    await _db.collection(_col).doc(requestId).update({
      // 'profession' (singulár) sa udržuje kvôli starým queries/UI, ktoré
      // ešte filtrujú na jednu profesiu — vždy prvá zo zoznamu.
      'profession':  professions.first,
      'professions': professions,
      'category':    category,
      'description': description,
      'address':     address,
      'location':    location,
      'budget':      budget,
      'photoUrls':   photoUrls,
      'timeframe':   timeframe,
      'quoteRequired': quoteRequired,
      'quoteDeadline': quoteDeadline != null
          ? Timestamp.fromDate(quoteDeadline) : null,
      'quoteBasis': quoteRequired ? quoteBasis : null,
      'documentUrls': documentUrls,
      'estimatedScope': quoteRequired ? null : estimatedScope,
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

  /// Remeselník sa odhlási z prejaveného záujmu (dopyt bez cenovej ponuky).
  /// Odstráni ho zo záujemcov a zmaže jeho záznam (vrátane odpovede zákazníka).
  static Future<void> withdrawInterest({
    required String requestId,
    required String craftsmanId,
  }) async {
    await _db.collection(_col).doc(requestId).update({
      'interestedCraftsmanIds': FieldValue.arrayRemove([craftsmanId]),
      'interest_$craftsmanId': FieldValue.delete(),
    });
  }

  // ── Cenové ponuky ─────────────────────────────────────────────────────────
  // service_requests/{requestId}/quotes/{craftsmanId}  (jedna na remeselníka)

  /// Odošle alebo upraví ponuku. Zároveň remeselníka zapíše medzi záujemcov,
  /// takže funguje ako "prejavenie záujmu" (a zákazník ho vidí v zozname).
  /// Dotované cesty (interest_<uid>.pole) sa MERGUJÚ — neprepíšu customerReply.
  static Future<void> submitQuote({
    required String requestId,
    required Quote quote,
  }) async {
    final id = quote.craftsmanId;
    final reqRef = _db.collection(_col).doc(requestId);
    final qRef = reqRef.collection('quotes').doc(id);
    final existing = await qRef.get();
    final isNew = !existing.exists;

    final batch = _db.batch();
    batch.set(qRef, {
      ...quote.toMap(),
      'createdAt': isNew
          ? FieldValue.serverTimestamp()
          : (existing.data()?['createdAt'] ?? FieldValue.serverTimestamp()),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(reqRef, {
      'interestedCraftsmanIds': FieldValue.arrayUnion([id]),
      'interest_$id.craftsmanId':   id,
      'interest_$id.craftsmanName': quote.craftsmanName,
      'interest_$id.message':       quote.note,
      'interest_$id.hasQuote':      true,
      if (isNew) 'interest_$id.timestamp': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Stiahne ponuku (remeselník sa tým vráti do stavu "bez záujmu").
  static Future<void> withdrawQuote({
    required String requestId,
    required String craftsmanId,
  }) async {
    final reqRef = _db.collection(_col).doc(requestId);
    final batch = _db.batch();
    batch.delete(reqRef.collection('quotes').doc(craftsmanId));
    batch.update(reqRef, {
      'interestedCraftsmanIds': FieldValue.arrayRemove([craftsmanId]),
      'interest_$craftsmanId': FieldValue.delete(),
    });
    await batch.commit();
  }

  /// Zákazník: všetky ponuky k svojmu dopytu.
  static Stream<List<Quote>> watchQuotes(String requestId) {
    return _db
        .collection(_col)
        .doc(requestId)
        .collection('quotes')
        .snapshots()
        .map((s) => s.docs.map((d) => Quote.fromMap(d.id, d.data())).toList());
  }

  /// Remeselník: jeho vlastná ponuka (null, ak ešte neposlal).
  static Stream<Quote?> watchMyQuote(String requestId, String craftsmanId) {
    return _db
        .collection(_col)
        .doc(requestId)
        .collection('quotes')
        .doc(craftsmanId)
        .snapshots()
        .map((d) => d.exists ? Quote.fromMap(d.id, d.data()!) : null);
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
  // ✅ FIX: whereIn / arrayContainsAny majú limit 10 — chunkujeme a zlúčime streamy.
  // Dopyty vytvorené pred zavedením viacnásobných profesií majú len singulárne
  // pole 'profession' (bez 'professions'), preto bežia OBIDVE query varianty
  // súčasne a výsledky sa zlúčia a deduplikujú podľa id.
  static Stream<List<ServiceRequest>> watchOpenRequests(List<String> professions) {
    if (professions.isEmpty) return const Stream.empty();

    final chunks = _chunks(professions, 10);

    final legacyStreams = chunks.map((chunk) => _db
        .collection(_col)
        .where('status', isEqualTo: 'open')
        .where('type', isEqualTo: 'broadcast')
        .where('profession', whereIn: chunk)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ServiceRequest.fromFirestore).toList()));

    final multiStreams = chunks.map((chunk) => _db
        .collection(_col)
        .where('status', isEqualTo: 'open')
        .where('type', isEqualTo: 'broadcast')
        .where('professions', arrayContainsAny: chunk)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ServiceRequest.fromFirestore).toList()));

    // Zlúčime všetky streamy (legacy + nové) do jedného
    return StreamZip([...legacyStreams, ...multiStreams]).map((lists) {
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
  // ✅ Postavené nad watchOpenRequests(), ktorý už rieši dedup naprieč
  // legacy 'profession' aj novým 'professions' poľom — sčítanie surových
  // počtov z oboch query variant by dvojnásobne počítalo dopyty, ktoré
  // zodpovedajú obom (napr. staré dopyty migrované do 'professions').
  static Stream<int> watchOpenRequestsCount(List<String> professions) {
    if (professions.isEmpty) return Stream.value(0);
    return watchOpenRequests(professions).map((list) => list.length);
  }
}