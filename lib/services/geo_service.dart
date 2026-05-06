// lib/services/geo_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/craftsman.dart';

class GeoService {
  static final _db = FirebaseFirestore.instance;

  static Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
    } catch (e) { debugPrint('GeoService.getCurrentPosition error: $e'); return null; }
  }

  static Future<List<CraftsmanWithDistance>> fetchNearbyCraftsmen({
    required double lat,
    required double lng,
    double radiusKm = 50.0,
    List<String>? professions,
  }) async {
    Query query = _db.collection('craftsmen').where('isActive', isEqualTo: true);
    if (professions != null && professions.isNotEmpty) {
      query = query.where('profession', whereIn: professions);
    }
    final snap = await query.get();
    final result = snap.docs
        .map(Craftsman.fromFirestore)
        .where((c) => c.geoPoint != null)
        .map((c) {
          final dist = _haversineKm(lat, lng, c.geoPoint!.latitude, c.geoPoint!.longitude);
          return CraftsmanWithDistance(craftsman: c, distanceKm: dist);
        })
        .where((c) => c.distanceKm <= radiusKm)
        .toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return result;
  }

  static Future<void> updateCraftsmanLocation({
    required String craftsmanId,
    required double lat,
    required double lng,
    required String cityName,
  }) async {
    await _db.collection('craftsmen').doc(craftsmanId).update({
      'geoPoint': GeoPoint(lat, lng),
      'cityName': cityName,
    });
  }

  static double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * pi / 180;

  static String formatDistance(double km) {
    if (km < 1.0) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }
}

class CraftsmanWithDistance {
  final Craftsman craftsman;
  final double distanceKm;
  String get formattedDistance => GeoService.formatDistance(distanceKm);
  CraftsmanWithDistance({required this.craftsman, required this.distanceKm});
}
