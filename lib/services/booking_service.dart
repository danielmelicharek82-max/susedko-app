// lib/services/booking_service.dart
// ♻️  RECYCLE z booking_service.dart (Inkmaker)
// Zmeny:
//   - artistId → craftsmanId
//   - kolekcia 'artists' → 'craftsmen' (pre availability)
//   - watchArtistBookings → watchCraftsmanBookings

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/booking.dart';
import '../models/availability_slot.dart';

class BookingService {
  static final _db = FirebaseFirestore.instance;
  static const _col = 'bookings';

  // ── Vytvorenie ────────────────────────────────────────────────────────────
  static Future<String> createBooking(Booking booking) async {
    final batch = _db.batch();
    final bookingRef = _db.collection(_col).doc();
    batch.set(bookingRef, booking.toMap());

    // Zablokuj slot v dostupnosti remeselníka
    final slotKey = AvailabilitySlot.dateKey(booking.scheduledAt);
    final timeStr =
        '${booking.scheduledAt.hour.toString().padLeft(2, '0')}:${booking.scheduledAt.minute.toString().padLeft(2, '0')}';

    final availRef = _db.collection('craftsmen').doc(booking.craftsmanId)
        .collection('availability').doc('slots');

    final availDoc = await availRef.get();
    if (availDoc.exists) {
      final data = Map<String, dynamic>.from(availDoc.data() ?? {});
      final slots = List<String>.from(data[slotKey] ?? []);
      slots.remove(timeStr);
      if (slots.isEmpty) { data.remove(slotKey); } else { data[slotKey] = slots; }
      batch.set(availRef, data);
    }

    await batch.commit();
    return bookingRef.id;
  }

  // ── Čítanie — Remeselník ──────────────────────────────────────────────────
  static Stream<List<Booking>> watchCraftsmanBookings(String craftsmanId) {
    return _db.collection(_col)
        .where('craftsmanId', isEqualTo: craftsmanId)
        .orderBy('scheduledAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map(Booking.fromFirestore).toList());
  }

  static Stream<List<Booking>> watchUpcomingCraftsmanBookings(String craftsmanId) {
    return _db.collection(_col)
        .where('craftsmanId', isEqualTo: craftsmanId)
        .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now()))
        .orderBy('scheduledAt')
        .snapshots()
        .map((s) => s.docs.map(Booking.fromFirestore).toList());
  }

  static Stream<int> watchUpcomingCount(String craftsmanId) {
    return _db.collection(_col)
        .where('craftsmanId', isEqualTo: craftsmanId)
        .where('status', whereIn: ['pending', 'confirmed'])
        .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now()))
        .snapshots()
        .map((s) => s.docs.length);
  }

  // ── Čítanie — Zákazník ────────────────────────────────────────────────────
  static Stream<List<Booking>> watchCustomerBookings(String customerId) {
    return _db.collection(_col)
        .where('customerId', isEqualTo: customerId)
        .orderBy('scheduledAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Booking.fromFirestore).toList());
  }

  static Future<Booking?> fetchBooking(String bookingId) async {
    final doc = await _db.collection(_col).doc(bookingId).get();
    if (!doc.exists) return null;
    return Booking.fromFirestore(doc);
  }

  // ── Aktualizácia statusu ──────────────────────────────────────────────────
  static Future<void> updateStatus(String bookingId, BookingStatus status) async {
    final data = <String, dynamic>{'status': status.name};
    if (status == BookingStatus.completed) data['completedAt'] = FieldValue.serverTimestamp();
    await _db.collection(_col).doc(bookingId).update(data);
  }

  static Future<void> markDepositPaid({required String bookingId, required String paymentIntentId}) async {
    await _db.collection(_col).doc(bookingId).update({
      'paymentStatus': PaymentStatus.depositPaid.name,
      'depositPaymentIntentId': paymentIntentId,
      'status': BookingStatus.pending.name,
    });
  }

  static Future<void> markFullyPaid({required String bookingId, required String paymentIntentId}) async {
    await _db.collection(_col).doc(bookingId).update({
      'paymentStatus': PaymentStatus.fullyPaid.name,
      'finalPaymentIntentId': paymentIntentId,
    });
  }

  static Future<void> markReviewed(String bookingId) async {
    await _db.collection(_col).doc(bookingId).update({'isReviewed': true});
  }

  // ── Zrušenie ──────────────────────────────────────────────────────────────
  static Future<void> cancelBooking(Booking booking) async {
    final batch = _db.batch();
    final bookingRef = _db.collection(_col).doc(booking.id);
    batch.update(bookingRef, {'status': BookingStatus.cancelled.name});

    // Vráť slot do dostupnosti
    final slotKey = AvailabilitySlot.dateKey(booking.scheduledAt);
    final timeStr =
        '${booking.scheduledAt.hour.toString().padLeft(2, '0')}:${booking.scheduledAt.minute.toString().padLeft(2, '0')}';
    final availRef = _db.collection('craftsmen').doc(booking.craftsmanId)
        .collection('availability').doc('slots');

    try {
      final availDoc = await availRef.get();
      final data = Map<String, dynamic>.from(availDoc.data() ?? {});
      final slots = List<String>.from(data[slotKey] ?? []);
      if (!slots.contains(timeStr)) {
        slots.add(timeStr);
        slots.sort();
        data[slotKey] = slots;
        batch.set(availRef, data);
      }
    } catch (e) { debugPrint('cancelBooking restore slot error: $e'); }

    await batch.commit();
  }

  // ── Conflict check ────────────────────────────────────────────────────────
  static Future<bool> hasConflict({required String craftsmanId, required DateTime scheduledAt}) async {
    final startWindow = scheduledAt.subtract(const Duration(minutes: 30));
    final endWindow   = scheduledAt.add(const Duration(minutes: 30));
    final q = await _db.collection(_col)
        .where('craftsmanId', isEqualTo: craftsmanId)
        .where('status', whereIn: ['pending', 'confirmed', 'inProgress'])
        .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startWindow))
        .where('scheduledAt', isLessThanOrEqualTo: Timestamp.fromDate(endWindow))
        .limit(1).get();
    return q.docs.isNotEmpty;
  }
}