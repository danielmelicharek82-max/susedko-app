// lib/providers/review_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/review.dart';

class ReviewProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<Review> _reviews = [];
  List<Review> get reviews => _reviews;

  double get averageRating {
    if (_reviews.isEmpty) return 0.0;
    final sum = _reviews.fold(0.0, (acc, r) => acc + r.rating);
    return double.parse((sum / _reviews.length).toStringAsFixed(1));
  }

  Map<int, int> get ratingDistribution {
    final dist = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final r in _reviews) {
      final key = r.rating.toInt().clamp(1, 5);
      dist[key] = (dist[key] ?? 0) + 1;
    }
    return dist;
  }

  Future<bool> submitReview({
    required String customerId,
    required String customerName,
    required String craftsmanId,
    required String bookingId,
    required double rating,
    String? comment,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final existing = await _firestore
          .collection('reviews')
          .where('bookingId', isEqualTo: bookingId)
          .where('customerId', isEqualTo: customerId)
          .get();

      if (existing.docs.isNotEmpty) {
        _errorMessage = 'Tento booking ste už ohodnotili.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final docRef = _firestore.collection('reviews').doc();

      final review = Review(
        id: docRef.id,
        craftsmanId: craftsmanId,
        customerId: customerId,
        customerName: customerName,
        rating: rating,
        comment: comment,
        createdAt: DateTime.now(),
        bookingId: bookingId,
      );

      await docRef.set(review.toMap());
      await _updateCraftsmanRating(craftsmanId, rating);
      await _firestore
          .collection('bookings')
          .doc(bookingId)
          .update({'isReviewed': true});

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Chyba pri odosielaní hodnotenia: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _updateCraftsmanRating(String craftsmanId, double newRating) async {
    final ref = _firestore.collection('craftsmen').doc(craftsmanId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final currentCount = (snapshot.data()?['reviewCount'] ?? 0) as int;
      final currentAvg = (snapshot.data()?['rating'] ?? 0.0) as double;
      final newCount = currentCount + 1;
      final newAvg = ((currentAvg * currentCount) + newRating) / newCount;
      transaction.update(ref, {
        'reviewCount': newCount,
        'rating': double.parse(newAvg.toStringAsFixed(1)),
      });
    });
  }

  Future<void> fetchReviewsForCraftsman(String craftsmanId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final snap = await _firestore
          .collection('reviews')
          .where('craftsmanId', isEqualTo: craftsmanId)
          .orderBy('createdAt', descending: true)
          .get();
      _reviews = snap.docs.map((doc) => Review.fromFirestore(doc)).toList();
    } catch (e) {
      _errorMessage = 'Chyba pri načítaní hodnotení: $e';
    }
    _isLoading = false;
    notifyListeners();
  }

  Stream<List<Review>> streamReviewsForCraftsman(String craftsmanId) {
    return _firestore
        .collection('reviews')
        .where('craftsmanId', isEqualTo: craftsmanId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => Review.fromFirestore(doc)).toList());
  }

  Future<void> fetchAllReviewsAdmin() async {
    _isLoading = true;
    notifyListeners();
    try {
      final snap = await _firestore
          .collection('reviews')
          .orderBy('createdAt', descending: true)
          .get();
      _reviews = snap.docs.map((doc) => Review.fromFirestore(doc)).toList();
    } catch (e) {
      _errorMessage = 'Chyba pri načítaní hodnotení: $e';
    }
    _isLoading = false;
    notifyListeners();
  }

  void clearReviews() {
    _reviews = [];
    notifyListeners();
  }
}
