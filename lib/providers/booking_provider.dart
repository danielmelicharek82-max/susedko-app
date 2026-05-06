// lib/providers/booking_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/booking.dart';
import '../services/booking_service.dart';

class BookingProvider extends ChangeNotifier {
  List<Booking> _customerBookings = [];
  List<Booking> _craftsmanBookings = [];

  bool _isLoading = false;
  String? _error;

  StreamSubscription<List<Booking>>? _customerSub;
  StreamSubscription<List<Booking>>? _craftsmanSub;

  List<Booking> get customerBookings => _customerBookings;
  List<Booking> get craftsmanBookings => _craftsmanBookings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Filtrované — zákazník
  List<Booking> get upcomingCustomer => _customerBookings
      .where((b) =>
          b.scheduledAt.isAfter(DateTime.now()) &&
          (b.status == BookingStatus.pending ||
              b.status == BookingStatus.confirmed))
      .toList()
    ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

  List<Booking> get pastCustomer => _customerBookings
      .where((b) =>
          b.status == BookingStatus.completed ||
          b.status == BookingStatus.cancelled)
      .toList()
    ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

  // Filtrované — remeselník
  List<Booking> get pendingCraftsman => _craftsmanBookings
      .where((b) => b.status == BookingStatus.pending)
      .toList()
    ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

  List<Booking> get confirmedCraftsman => _craftsmanBookings
      .where((b) =>
          b.status == BookingStatus.confirmed ||
          b.status == BookingStatus.inProgress)
      .toList()
    ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

  List<Booking> get completedCraftsman => _craftsmanBookings
      .where((b) =>
          b.status == BookingStatus.completed ||
          b.status == BookingStatus.cancelled ||
          b.status == BookingStatus.noShow)
      .toList()
    ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

  int get pendingCount => pendingCraftsman.length;
  int get upcomingCustomerCount => upcomingCustomer.length;

  void listenCustomerBookings(String customerId) {
    _customerSub?.cancel();
    _isLoading = true;
    notifyListeners();

    _customerSub = BookingService.watchCustomerBookings(customerId)
        .listen((bookings) {
      _customerBookings = bookings;
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    });
  }

  void listenCraftsmanBookings(String craftsmanId) {
    _craftsmanSub?.cancel();
    _isLoading = true;
    notifyListeners();

    _craftsmanSub = BookingService.watchCraftsmanBookings(craftsmanId)
        .listen((bookings) {
      _craftsmanBookings = bookings;
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> updateStatus(String bookingId, BookingStatus status) async {
    try {
      await BookingService.updateStatus(bookingId, status);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> cancelBooking(Booking booking) async {
    try {
      await BookingService.cancelBooking(booking);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> createBooking(Booking booking) async {
    try {
      _isLoading = true;
      notifyListeners();
      await BookingService.createBooking(booking);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void initForCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    listenCustomerBookings(user.uid);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _customerSub?.cancel();
    _craftsmanSub?.cancel();
    super.dispose();
  }
}
