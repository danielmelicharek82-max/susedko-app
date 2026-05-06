// lib/providers/geo_provider.dart
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/craftsman.dart';
import '../services/geo_service.dart';

class GeoProvider extends ChangeNotifier {
  Position? _currentPosition;
  List<CraftsmanWithDistance> _nearbyCraftsmen = [];
  List<String> _selectedProfessions = [];
  double _radiusKm = 50.0;
  bool _isLoading = false;
  bool _locationDenied = false;
  String? _error;

  Position? get currentPosition => _currentPosition;
  List<CraftsmanWithDistance> get nearbyCraftsmen => _nearbyCraftsmen;
  List<String> get selectedProfessions => _selectedProfessions;
  double get radiusKm => _radiusKm;
  bool get isLoading => _isLoading;
  bool get locationDenied => _locationDenied;
  String? get error => _error;
  bool get hasLocation => _currentPosition != null;

  Future<void> init() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final position = await GeoService.getCurrentPosition();
    if (position == null) {
      _locationDenied = true;
      _isLoading = false;
      notifyListeners();
      return;
    }
    _currentPosition = position;
    await _loadCraftsmen();
  }

  Future<void> refresh() async {
    if (_currentPosition == null) { await init(); return; }
    await _loadCraftsmen();
  }

  Future<void> setProfessionFilter(List<String> professions) async {
    _selectedProfessions = professions;
    notifyListeners();
    await _loadCraftsmen();
  }

  Future<void> setRadius(double km) async {
    _radiusKm = km;
    notifyListeners();
    await _loadCraftsmen();
  }

  Future<void> _loadCraftsmen() async {
    if (_currentPosition == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _nearbyCraftsmen = await GeoService.fetchNearbyCraftsmen(
        lat: _currentPosition!.latitude,
        lng: _currentPosition!.longitude,
        radiusKm: _radiusKm,
        professions: _selectedProfessions.isEmpty ? null : _selectedProfessions,
      );
    } catch (e) {
      _error = e.toString();
      debugPrint('GeoProvider._loadCraftsmen error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String? distanceTo(Craftsman craftsman) {
    if (_currentPosition == null || craftsman.geoPoint == null) return null;
    final km = GeoService.formatDistance(0); // placeholder
    return km;
  }

  void clearError() { _error = null; notifyListeners(); }
}
