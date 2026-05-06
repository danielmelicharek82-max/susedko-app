// lib/providers/wishlist_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/wishlist_item.dart';

class WishlistProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;

  List<WishlistItem> _items = [];
  bool _loading = false;

  List<WishlistItem> get items => _items;
  bool get isLoading => _loading;

  void listenToWishlist() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _loading = true;
    notifyListeners();

    _db
        .collection('wishlists')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      _items = snap.docs.map((d) => WishlistItem.fromFirestore(d)).toList();
      _loading = false;
      notifyListeners();
    });
  }

  bool isInWishlist(String craftsmanId) =>
      _items.any((i) => i.craftsmanId == craftsmanId);

  Future<void> add({
    required String craftsmanId,
    required String craftsmanName,
    String? craftsmanPhoto,
    String? profession,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (isInWishlist(craftsmanId)) return;

    final item = WishlistItem(
      id: '',
      userId: uid,
      craftsmanId: craftsmanId,
      craftsmanName: craftsmanName,
      craftsmanPhoto: craftsmanPhoto,
      profession: profession,
      createdAt: DateTime.now(),
    );

    await _db.collection('wishlists').add(item.toMap());
  }

  Future<void> remove(String craftsmanId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await _db
        .collection('wishlists')
        .where('userId', isEqualTo: uid)
        .where('craftsmanId', isEqualTo: craftsmanId)
        .get();

    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> toggle({
    required String craftsmanId,
    required String craftsmanName,
    String? craftsmanPhoto,
    String? profession,
  }) async {
    if (isInWishlist(craftsmanId)) {
      await remove(craftsmanId);
    } else {
      await add(
        craftsmanId: craftsmanId,
        craftsmanName: craftsmanName,
        craftsmanPhoto: craftsmanPhoto,
        profession: profession,
      );
    }
  }

  void clear() {
    _items = [];
    notifyListeners();
  }
}
