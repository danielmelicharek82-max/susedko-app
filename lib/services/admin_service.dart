// lib/services/admin_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/booking.dart';
import '../models/craftsman.dart';
import '../models/review.dart';
import '../models/app_user.dart';
import '../models/service_request.dart';
import '../models/work_order.dart';

class AdminService {
  static final _db = FirebaseFirestore.instance;

  // ── Helper: načítaj kontakty pre zoznam IDs ───────────────────────────────
  // Vráti mapu uid → {name, email, phone}
  static Future<Map<String, Map<String, String?>>> _fetchContacts(
      Set<String> uids) async {
    final result = <String, Map<String, String?>>{};
    if (uids.isEmpty) return result;

    // Rozdeľ na chunky po 30 (Firestore whereIn limit)
    final list = uids.toList();
    for (var i = 0; i < list.length; i += 30) {
      final chunk = list.sublist(i, i + 30 > list.length ? list.length : i + 30);

      // Zákazníci z 'users'
      final usersSnap = await _db.collection('users')
          .where(FieldPath.documentId, whereIn: chunk).get();
      for (final doc in usersSnap.docs) {
        final d = doc.data();
        result[doc.id] = {
          'name':  d['name'] as String? ?? d['displayName'] as String? ?? '',
          'email': d['email'] as String? ?? '',
          'phone': d['phone'] as String?,
          'role':  d['role'] as String? ?? 'customer',
        };
      }

      // Remeselníci z 'craftsmen'
      final craftsmenSnap = await _db.collection('craftsmen')
          .where(FieldPath.documentId, whereIn: chunk).get();
      for (final doc in craftsmenSnap.docs) {
        final d = doc.data();
        result[doc.id] = {
          'name':  d['name'] as String? ?? '',
          'email': d['email'] as String? ?? '',
          'phone': d['phone'] as String?,
          'role':  'craftsman',
        };
      }
    }
    return result;
  }

  // ── Používatelia ──────────────────────────────────────────────────────────
  static Future<List<AppUser>> getAllUsers() async {
    final snap = await _db.collection('users').get();
    return snap.docs.map(AppUser.fromFirestore).toList();
  }

  static Future<void> toggleUserBlocked(String userId, bool isBlocked) async {
    await _db.collection('users').doc(userId).update({'isBlocked': isBlocked});
  }

  static Future<void> setUserDiscount(String userId, double discount) async {
    await _db.collection('users').doc(userId)
        .update({'discountPercent': discount});
  }

  // ── Remeselníci ───────────────────────────────────────────────────────────
  static Future<List<Craftsman>> getAllCraftsmen() async {
    final snap = await _db
        .collection('craftsmen')
        .where('isVerified', isEqualTo: true)
        .get();
    return snap.docs.map(Craftsman.fromFirestore).toList();
  }

  static Future<List<Craftsman>> getPendingCraftsmen() async {
    final snap = await _db
        .collection('craftsmen')
        .where('isVerified', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map(Craftsman.fromFirestore).toList();
  }

  static Future<void> verifyCraftsman(String craftsmanId) async {
    await _db.collection('craftsmen').doc(craftsmanId).update({
      'isVerified': true,
      'isActive':   true,
    });
  }

  static Future<void> rejectCraftsman(String craftsmanId,
      {String? reason}) async {
    await _db.collection('craftsmen').doc(craftsmanId).update({
      'isActive': false,
      if (reason != null) 'rejectionReason': reason,
    });
  }

  static Future<void> toggleCraftsmanStatus(
      String craftsmanId, bool isActive) async {
    await _db.collection('craftsmen').doc(craftsmanId)
        .update({'isActive': isActive});
  }

  // ── Rezervácie ────────────────────────────────────────────────────────────
  static Future<List<Booking>> getAllBookings() async {
    final snap = await _db
        .collection('bookings')
        .orderBy('scheduledAt', descending: true)
        .get();
    return snap.docs.map(Booking.fromFirestore).toList();
  }

  static Future<void> updateBookingStatus(
      String bookingId, BookingStatus status) async {
    await _db.collection('bookings').doc(bookingId)
        .update({'status': status.name});
  }

  // ── Service Requests ──────────────────────────────────────────────────────
  // ✅ Obohatené o email + telefón zákazníka (a remeselníka ak je priradený)
  static Future<List<ServiceRequest>> getAllServiceRequests() async {
    final snap = await _db
        .collection('service_requests')
        .orderBy('createdAt', descending: true)
        .get();

    final requests = snap.docs.map(ServiceRequest.fromFirestore).toList();

    // Zbieraj všetky relevantné UIDs
    final uids = <String>{};
    for (final r in requests) {
      uids.add(r.customerId);
      if (r.craftsmanId != null) uids.add(r.craftsmanId!);
    }

    final contacts = await _fetchContacts(uids);

    // Vlož kontaktné info do každej požiadavky cez adminContacts pole
    return requests.map((r) {
      final customerContact = contacts[r.customerId];
      final craftsmanContact = r.craftsmanId != null
          ? contacts[r.craftsmanId] : null;
      return r.copyWithAdminContacts(
        customerEmail: customerContact?['email'],
        customerPhone: customerContact?['phone'],
        craftsmanEmail: craftsmanContact?['email'],
        craftsmanPhone: craftsmanContact?['phone'],
      );
    }).toList();
  }

  static Future<List<ServiceRequest>> getOpenBroadcastRequests() async {
    final snap = await _db
        .collection('service_requests')
        .where('type',   isEqualTo: 'broadcast')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map(ServiceRequest.fromFirestore).toList();
  }

  static Future<void> updateServiceRequestStatus(
      String requestId, ServiceRequestStatus status) async {
    await _db.collection('service_requests').doc(requestId)
        .update({'status': status.name});
  }

  static Future<void> deleteServiceRequest(String requestId) async {
    await _db.collection('service_requests').doc(requestId).delete();
  }

  // ── Work Orders ───────────────────────────────────────────────────────────
  // ✅ Obohatené o email + telefón zákazníka aj remeselníka
  static Future<List<WorkOrder>> getAllWorkOrders() async {
    final snap = await _db
        .collection('work_orders')
        .orderBy('createdAt', descending: true)
        .get();

    final orders = snap.docs.map(WorkOrder.fromFirestore).toList();

    // Zbieraj všetky UIDs
    final uids = <String>{};
    for (final w in orders) {
      uids.add(w.customerId);
      uids.add(w.craftsmanId);
    }

    final contacts = await _fetchContacts(uids);

    // Obohať každú objednávku o kontaktné info
    return orders.map((w) {
      final customerContact  = contacts[w.customerId];
      final craftsmanContact = contacts[w.craftsmanId];

      // Pridaj email + phone do existujúcich snapshots
      final enrichedCustomer = {
        ...?w.customerSnapshot,
        if (customerContact?['email'] != null)
          'email': customerContact!['email']!,
        if (customerContact?['phone'] != null)
          'phone': customerContact!['phone']!,
      };
      final enrichedCraftsman = {
        ...?w.craftsmanSnapshot,
        if (craftsmanContact?['email'] != null)
          'email': craftsmanContact!['email']!,
        if (craftsmanContact?['phone'] != null)
          'phone': craftsmanContact!['phone']!,
      };

      return w.copyWith(
        customerSnapshot:  enrichedCustomer,
        craftsmanSnapshot: enrichedCraftsman,
      );
    }).toList();
  }

  static Future<List<WorkOrder>> getDisputedWorkOrders() async {
    final snap = await _db
        .collection('work_orders')
        .where('status', isEqualTo: 'disputed')
        .orderBy('createdAt', descending: true)
        .get();

    final orders = snap.docs.map(WorkOrder.fromFirestore).toList();

    final uids = <String>{};
    for (final w in orders) {
      uids.add(w.customerId);
      uids.add(w.craftsmanId);
    }
    final contacts = await _fetchContacts(uids);

    return orders.map((w) {
      final cc = contacts[w.customerId];
      final cr = contacts[w.craftsmanId];
      return w.copyWith(
        customerSnapshot: {
          ...?w.customerSnapshot,
          if (cc?['email'] != null) 'email': cc!['email']!,
          if (cc?['phone'] != null) 'phone': cc!['phone']!,
        },
        craftsmanSnapshot: {
          ...?w.craftsmanSnapshot,
          if (cr?['email'] != null) 'email': cr!['email']!,
          if (cr?['phone'] != null) 'phone': cr!['phone']!,
        },
      );
    }).toList();
  }

  static Future<void> updateWorkOrderStatus(
      String workOrderId, WorkOrderStatus status) async {
    await _db.collection('work_orders').doc(workOrderId)
        .update({'status': status.name});
  }

  static Future<void> resolveDispute(
    String workOrderId, {
    required WorkOrderStatus resolution,
    String? adminNote,
  }) async {
    await _db.collection('work_orders').doc(workOrderId).update({
      'status':     resolution.name,
      if (adminNote != null) 'adminNote': adminNote,
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
    });
    await logAdminAction(
      action: 'resolveDispute',
      detail: 'WorkOrder $workOrderId → ${resolution.name}'
          '${adminNote != null ? ' | $adminNote' : ''}',
    );
  }

  static Future<void> deleteWorkOrder(String workOrderId) async {
    await _db.collection('work_orders').doc(workOrderId).delete();
  }

  // ── Recenzie ──────────────────────────────────────────────────────────────
  static Future<List<Review>> getAllReviews() async {
    final snap = await _db
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs
        .map((doc) => Review.fromMap(doc.data(), doc.id))
        .toList();
  }

  static Future<void> deleteReview(String reviewId) async {
    await _db.collection('reviews').doc(reviewId).delete();
  }

  static Future<void> approveReview(String reviewId) async {
    await _db.collection('reviews').doc(reviewId)
        .update({'isApproved': true});
  }

  // ── Notifikácie ───────────────────────────────────────────────────────────
  static Future<void> sendBroadcastNotification({
    required String title,
    required String body,
  }) async {
    final usersSnap = await _db.collection('users').get();
    for (final doc in usersSnap.docs) {
      final token = doc.data()['fcmToken'] as String?;
      if (token == null || token.isEmpty) continue;
      await _db.collection('notification_queue').add({
        'token':     token,
        'title':     title,
        'body':      body,
        'data':      {'type': 'broadcast'},
        'createdAt': FieldValue.serverTimestamp(),
        'sent':      false,
      });
    }
    await logAdminAction(action: 'broadcastNotification', detail: title);
  }

  // ── Export CSV ────────────────────────────────────────────────────────────
  static Future<String> exportBookingsCsv(List<Booking> bookings) async {
    final buffer = StringBuffer();
    buffer.writeln('ID,Dátum termínu,Status,Trvanie,Zákazník,Remeselník');
    for (final b in bookings) {
      final date =
          '${b.scheduledAt.day}.${b.scheduledAt.month}.${b.scheduledAt.year}';
      final customer =
          b.customerSnapshot?['name'] ?? b.customerId.substring(0, 6);
      final craftsman =
          b.craftsmanSnapshot?['name'] ?? b.craftsmanId.substring(0, 6);
      final duration = '${b.durationMinutes ~/ 60} hod';
      buffer.writeln(
        '${b.id.substring(0, 6).toUpperCase()},$date,${b.status.name},'
        '$duration,$customer,$craftsman',
      );
    }
    return buffer.toString();
  }

  static Future<String> exportUsersCsv(List<AppUser> users) async {
    final buffer = StringBuffer();
    buffer.writeln('Meno,Email,Rola,Blokovaný');
    for (final u in users) {
      buffer.writeln(
        '${u.displayName.replaceAll(',', ' ')},'
        '${u.email},${u.role},${u.isBlocked}',
      );
    }
    return buffer.toString();
  }

  static Future<String> exportWorkOrdersCsv(
      List<WorkOrder> workOrders) async {
    final buffer = StringBuffer();
    buffer.writeln(
        'ID,Dátum,Status,Platba,Hodiny,Suma,Zákazník,Email zákazníka,Remeselník,Email remeselníka');
    for (final w in workOrders) {
      final date =
          '${w.scheduledAt.day}.${w.scheduledAt.month}.${w.scheduledAt.year}';
      final customer  = w.customerSnapshot?['name']  ?? w.customerId.substring(0, 6);
      final craftsman = w.craftsmanSnapshot?['name'] ?? w.craftsmanId.substring(0, 6);
      final custEmail = w.customerSnapshot?['email']  ?? '';
      final crEmail   = w.craftsmanSnapshot?['email'] ?? '';
      final amount    = w.calculatedTotal?.toStringAsFixed(2) ?? '-';
      buffer.writeln(
        '${w.id.substring(0, 6).toUpperCase()},$date,${w.status.name},'
        '${w.paymentStatus.name},${w.loggedHours ?? '-'},$amount,'
        '$customer,$custEmail,$craftsman,$crEmail',
      );
    }
    return buffer.toString();
  }

  // ── Admin log ─────────────────────────────────────────────────────────────
  static Future<void> logAdminAction({
    required String action,
    required String detail,
  }) async {
    await _db.collection('admin_logs').add({
      'action':    action,
      'detail':    detail,
      'timestamp': FieldValue.serverTimestamp(),
      'adminId':   FirebaseAuth.instance.currentUser?.uid ?? '',
    });
  }
}