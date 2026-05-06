// lib/providers/craftsman_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/craftsman.dart';

class CraftsmanProvider extends ChangeNotifier {
  List<Craftsman> _craftsmen = [];
  List<Craftsman> _filtered = [];
  bool _isLoading = false;
  String? _error;

  // Aktívne filtre
  List<String> _professionFilter = [];
  String? _categoryFilter;
  String? _cityFilter;
  String _searchQuery = '';

  // Gettery
  List<Craftsman> get craftsmen => _filtered;
  List<Craftsman> get allCraftsmen => _craftsmen;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<String> get professionFilter => _professionFilter;
  String? get categoryFilter => _categoryFilter;
  String? get cityFilter => _cityFilter;

  Future<void> loadCraftsmen() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snap = await FirebaseFirestore.instance
          .collection('craftsmen')
          .where('isActive', isEqualTo: true)
          .where('isVerified', isEqualTo: true)
          .orderBy('rating', descending: true)
          .get();

      _craftsmen = snap.docs.map(Craftsman.fromFirestore).toList();
      _applyFilters();
    } catch (e) {
      _error = e.toString();
      debugPrint('>>> CraftsmanProvider.loadCraftsmen error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void listenCraftsmen() {
    FirebaseFirestore.instance
        .collection('craftsmen')
        .where('isActive', isEqualTo: true)
        .where('isVerified', isEqualTo: true)
        .orderBy('rating', descending: true)
        .snapshots()
        .listen((snap) {
      _craftsmen = snap.docs.map(Craftsman.fromFirestore).toList();
      _applyFilters();
      notifyListeners();
    }, onError: (e) {
      _error = e.toString();
      notifyListeners();
    });
  }

  Future<List<Craftsman>> fetchPendingVerification() async {
    final snap = await FirebaseFirestore.instance
        .collection('craftsmen')
        .where('isVerified', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map(Craftsman.fromFirestore).toList();
  }

  Future<Craftsman?> fetchCraftsman(String craftsmanId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('craftsmen')
          .doc(craftsmanId)
          .get();
      if (!doc.exists) return null;
      return Craftsman.fromFirestore(doc);
    } catch (e) {
      debugPrint('>>> CraftsmanProvider.fetchCraftsman error: $e');
      return null;
    }
  }

  void setProfessionFilter(List<String> professions) {
    _professionFilter = professions;
    _applyFilters();
    notifyListeners();
  }

  void setCategoryFilter(String? category) {
    _categoryFilter = category;
    _applyFilters();
    notifyListeners();
  }

  void setCityFilter(String? city) {
    _cityFilter = city;
    _applyFilters();
    notifyListeners();
  }

  void setSearch(String query) {
    _searchQuery = query.toLowerCase();
    _applyFilters();
    notifyListeners();
  }

  void clearFilters() {
    _professionFilter = [];
    _categoryFilter = null;
    _cityFilter = null;
    _searchQuery = '';
    _filtered = List.from(_craftsmen);
    notifyListeners();
  }

  void _applyFilters() {
    _filtered = _craftsmen.where((craftsman) {
      if (_professionFilter.isNotEmpty) {
        if (!_professionFilter.contains(craftsman.profession)) return false;
      }
      if (_categoryFilter != null && _categoryFilter!.isNotEmpty) {
        if (craftsman.category != _categoryFilter) return false;
      }
      if (_cityFilter != null && _cityFilter!.isNotEmpty) {
        if (craftsman.cityName?.toLowerCase() != _cityFilter!.toLowerCase()) return false;
      }
      if (_searchQuery.isNotEmpty) {
        if (!craftsman.name.toLowerCase().contains(_searchQuery)) return false;
      }
      return true;
    }).toList();
  }

  Future<void> verifyCraftsman(String craftsmanId) async {
    await FirebaseFirestore.instance
        .collection('craftsmen')
        .doc(craftsmanId)
        .update({'isVerified': true});
    await loadCraftsmen();
  }

  Future<void> deactivateCraftsman(String craftsmanId) async {
    await FirebaseFirestore.instance
        .collection('craftsmen')
        .doc(craftsmanId)
        .update({'isActive': false});
    _craftsmen.removeWhere((c) => c.id == craftsmanId);
    _applyFilters();
    notifyListeners();
  }

  void updateLocal(Craftsman updated) {
    final index = _craftsmen.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      _craftsmen[index] = updated;
      _applyFilters();
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
