// lib/providers/admin_provider.dart

import 'package:flutter/foundation.dart';
import '../models/app_user.dart';
import '../models/booking.dart';
import '../models/craftsman.dart';
import '../models/review.dart';
import '../models/service_request.dart';
import '../models/work_order.dart';
import '../services/admin_service.dart';

class AdminProvider extends ChangeNotifier {
  List<AppUser>       users             = [];
  List<Review>        reviews           = [];
  List<Booking>       bookings          = [];
  List<Craftsman>     craftsmen         = [];
  List<Craftsman>     pendingCraftsmen  = [];
  List<ServiceRequest> serviceRequests  = [];
  List<WorkOrder>     workOrders        = [];
  List<WorkOrder>     disputedWorkOrders = [];

  bool isLoading = false;

  // ── Fetch všetkého ────────────────────────────────────────────────────────
  Future<void> fetchAllData() async {
    isLoading = true;
    notifyListeners();

    final results = await Future.wait([
      AdminService.getAllUsers(),
      AdminService.getAllReviews(),
      AdminService.getAllBookings(),
      AdminService.getAllCraftsmen(),
      AdminService.getPendingCraftsmen(),
      AdminService.getAllServiceRequests(),
      AdminService.getAllWorkOrders(),
      AdminService.getDisputedWorkOrders(),
    ]);

    users              = results[0] as List<AppUser>;
    reviews            = results[1] as List<Review>;
    bookings           = results[2] as List<Booking>;
    craftsmen          = results[3] as List<Craftsman>;
    pendingCraftsmen   = results[4] as List<Craftsman>;
    serviceRequests    = results[5] as List<ServiceRequest>;
    workOrders         = results[6] as List<WorkOrder>;
    disputedWorkOrders = results[7] as List<WorkOrder>;

    isLoading = false;
    notifyListeners();
  }

  // ── Používatelia ──────────────────────────────────────────────────────────
  Future<void> setUserDiscount(String userId, double discount) async {
    await AdminService.setUserDiscount(userId, discount);
    final i = users.indexWhere((u) => u.id == userId);
    if (i != -1) {
      users[i] = users[i].copyWith(discountPercent: discount);
      notifyListeners();
    }
  }

  Future<void> toggleUserBlocked(String userId, bool isBlocked) async {
    await AdminService.toggleUserBlocked(userId, isBlocked);
    final i = users.indexWhere((u) => u.id == userId);
    if (i != -1) {
      users[i] = users[i].copyWith(isBlocked: isBlocked);
      notifyListeners();
    }
  }

  // ── Remeselníci ───────────────────────────────────────────────────────────
  Future<void> verifyCraftsman(String craftsmanId) async {
    await AdminService.verifyCraftsman(craftsmanId);
    final i = pendingCraftsmen.indexWhere((c) => c.id == craftsmanId);
    if (i != -1) {
      final verified = pendingCraftsmen[i].copyWith(isVerified: true);
      pendingCraftsmen.removeAt(i);
      craftsmen.add(verified);
      notifyListeners();
    }
    await logAdminAction('verifyCraftsman', 'Craftsman $craftsmanId verified');
  }

  Future<void> rejectCraftsman(String craftsmanId, {String? reason}) async {
    await AdminService.rejectCraftsman(craftsmanId, reason: reason);
    pendingCraftsmen.removeWhere((c) => c.id == craftsmanId);
    notifyListeners();
    await logAdminAction('rejectCraftsman', 'Craftsman $craftsmanId rejected');
  }

  Future<void> toggleCraftsmanStatus(String craftsmanId, bool isActive) async {
    await AdminService.toggleCraftsmanStatus(craftsmanId, isActive);
    final i = craftsmen.indexWhere((c) => c.id == craftsmanId);
    if (i != -1) {
      craftsmen[i] = craftsmen[i].copyWith(isActive: isActive);
      notifyListeners();
    }
    await logAdminAction('toggleCraftsmanStatus', '$craftsmanId → $isActive');
  }

  // ── Rezervácie ────────────────────────────────────────────────────────────
  Future<void> updateBookingStatus(String bookingId, BookingStatus status) async {
    await AdminService.updateBookingStatus(bookingId, status);
    bookings = bookings.map((b) =>
        b.id == bookingId ? b.copyWith(status: status) : b).toList();
    notifyListeners();
    await logAdminAction('updateBookingStatus', 'Booking $bookingId → ${status.name}');
  }

  // ── Service Requests ──────────────────────────────────────────────────────
  Future<void> updateServiceRequestStatus(
    String requestId,
    ServiceRequestStatus status,
  ) async {
    await AdminService.updateServiceRequestStatus(requestId, status);
    serviceRequests = serviceRequests.map((r) =>
        r.id == requestId ? r.copyWith(status: status) : r).toList();
    notifyListeners();
    await logAdminAction(
        'updateServiceRequestStatus', 'Request $requestId → ${status.name}');
  }

  Future<void> deleteServiceRequest(String requestId) async {
    await AdminService.deleteServiceRequest(requestId);
    serviceRequests.removeWhere((r) => r.id == requestId);
    notifyListeners();
    await logAdminAction('deleteServiceRequest', 'Request $requestId deleted');
  }

  // ── Work Orders ───────────────────────────────────────────────────────────
  Future<void> updateWorkOrderStatus(
    String workOrderId,
    WorkOrderStatus status,
  ) async {
    await AdminService.updateWorkOrderStatus(workOrderId, status);
    workOrders = workOrders.map((w) =>
        w.id == workOrderId ? w.copyWith(status: status) : w).toList();
    disputedWorkOrders.removeWhere((w) => w.id == workOrderId);
    notifyListeners();
    await logAdminAction(
        'updateWorkOrderStatus', 'WorkOrder $workOrderId → ${status.name}');
  }

  Future<void> resolveDispute(
    String workOrderId, {
    required WorkOrderStatus resolution,
    String? adminNote,
  }) async {
    await AdminService.resolveDispute(
      workOrderId,
      resolution: resolution,
      adminNote: adminNote,
    );
    workOrders = workOrders.map((w) =>
        w.id == workOrderId ? w.copyWith(status: resolution) : w).toList();
    disputedWorkOrders.removeWhere((w) => w.id == workOrderId);
    notifyListeners();
  }

  Future<void> deleteWorkOrder(String workOrderId) async {
    await AdminService.deleteWorkOrder(workOrderId);
    workOrders.removeWhere((w) => w.id == workOrderId);
    disputedWorkOrders.removeWhere((w) => w.id == workOrderId);
    notifyListeners();
    await logAdminAction('deleteWorkOrder', 'WorkOrder $workOrderId deleted');
  }

  // ── Recenzie ──────────────────────────────────────────────────────────────
  Future<void> deleteReview(String reviewId) async {
    await AdminService.deleteReview(reviewId);
    reviews.removeWhere((r) => r.id == reviewId);
    notifyListeners();
    await logAdminAction('deleteReview', 'Review $reviewId');
  }

  Future<void> approveReview(String reviewId) async {
    await AdminService.approveReview(reviewId);
    final i = reviews.indexWhere((r) => r.id == reviewId);
    if (i != -1) {
      reviews[i] = reviews[i].copyWith(isApproved: true);
      notifyListeners();
    }
    await logAdminAction('approveReview', 'Review $reviewId');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Future<void> logAdminAction(String action, String detail) async {
    await AdminService.logAdminAction(action: action, detail: detail);
  }

  // Shortcuty pre dashboard štatistiky
  int get openBroadcastCount =>
      serviceRequests.where((r) => r.isBroadcast && r.status == ServiceRequestStatus.open).length;

  int get pendingWorkOrderCount =>
      workOrders.where((w) => w.status == WorkOrderStatus.pending).length;

  int get disputedCount => disputedWorkOrders.length;

  double get totalRevenue => workOrders
      .where((w) => w.isPaid)
      .fold(0.0, (sum, w) => sum + (w.calculatedTotal ?? 0));
}