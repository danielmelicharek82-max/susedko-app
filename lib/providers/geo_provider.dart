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
  bool _locationDeniedForever = false;
  String? _error;

  Position? get currentPosition => _currentPosition;
  List<CraftsmanWithDistance> get nearbyCraftsmen => _nearbyCraftsmen;
  List<String> get selectedProfessions => _selectedProfessions;
  double get radiusKm => _radiusKm;
  bool get isLoading => _isLoading;
  bool get locationDenied => _locationDenied;
  bool get locationDeniedForever => _locationDeniedForever;
  String? get error => _error;
  bool get hasLocation => _currentPosition != null;

  Future<void> init() async {
    _isLoading = true;
    _locationDenied = false;
    _locationDeniedForever = false;
    _error = null;
    notifyListeners();

    // Skontroluj permission stav pred pokusom o polohu
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      _locationDenied = true;
      _locationDeniedForever = true;
      _isLoading = false;
      notifyListeners();
      return;
    }

    final position = await GeoService.getCurrentPosition();
    if (position == null) {
      // Znova skontroluj – možno používateľ zamietol počas init()
      final permAfter = await Geolocator.checkPermission();
      _locationDeniedForever = permAfter == LocationPermission.deniedForever;
      _locationDenied = true;
      _isLoading = false;
      notifyListeners();
      return;
    }

    _locationDenied = false;
    _locationDeniedForever = false;
    _currentPosition = position;
    await _loadCraftsmen();
  }

  /// Otvorí systémové nastavenia ak je permission permanentne zamietnuté,
  /// inak sa pokúsi znova získať polohu.
  Future<void> requestLocationOrOpenSettings() async {
    if (_locationDeniedForever) {
      await Geolocator.openAppSettings();
    } else {
      await init();
    }
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