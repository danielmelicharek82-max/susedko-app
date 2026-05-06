// lib/services/ai_match_service.dart
// ♻️  RECYCLE z ai_match_service.dart (Inkmaker)
// Zmeny:
//   - TattooArtist → Craftsman
//   - styles → profession + skills
//   - kolekcia 'artists' → 'craftsmen'
//   - detectTattooStyles → detectServiceNeeds (popis problému namiesto fotiek)
//   - AiMatchResult používa craftsman namiesto artist

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/craftsman.dart';
import 'geo_service.dart';

class AiMatchResult {
  final Craftsman craftsman;
  final double matchScore;
  final List<String> matchedSkills;
  final String? matchReason;
  final double? distanceKm;

  AiMatchResult({
    required this.craftsman,
    required this.matchScore,
    required this.matchedSkills,
    this.matchReason,
    this.distanceKm,
  });

  String get formattedScore => '${(matchScore * 100).round()}%';
  String? get formattedDistance =>
      distanceKm != null ? GeoService.formatDistance(distanceKm!) : null;
}

class AiMatchService {
  static final _db = FirebaseFirestore.instance;

  // ── Hlavná match funkcia ──────────────────────────────────────────────────
  /// Zanalyzuje popis problému a vráti zoradených remeselníkov podľa zhody
  /// [description] — popis čo zákazník potrebuje
  /// [photoUrls] — voliteľné fotky problému
  static Future<List<AiMatchResult>> matchCraftsmen({
    required String description,
    List<String> photoUrls = const [],
    double? lat,
    double? lng,
    int maxResults = 10,
  }) async {
    try {
      // 1. Detekuj profesiu z popisu cez Cloud Function
      final detectedProfessions = await _detectProfessionFromDescription(
          description: description, photoUrls: photoUrls);

      if (detectedProfessions.isEmpty) {
        return _fallbackMatch(lat: lat, lng: lng, maxResults: maxResults);
      }

      // 2. Načítaj remeselníkov s danou profesiou
      final snap = await _db.collection('craftsmen')
          .where('isActive', isEqualTo: true)
          .where('profession', whereIn: detectedProfessions).get();

      final craftsmen = snap.docs.map(Craftsman.fromFirestore).toList();

      // 3. Vypočítaj match score
      final results = craftsmen.map((craftsman) {
        final professionMatch = detectedProfessions.contains(craftsman.profession) ? 0.6 : 0.0;
        double score = professionMatch;

        // Geo boost
        double? distKm;
        if (lat != null && lng != null && craftsman.geoPoint != null) {
          distKm = _haversineKm(lat, lng, craftsman.geoPoint!.latitude, craftsman.geoPoint!.longitude);
          if (distKm < 5)  score += 0.2;
          else if (distKm < 20) score += 0.1;
          else if (distKm < 50) score += 0.05;
        }

        // Rating boost
        score += craftsman.rating / 50;

        return AiMatchResult(
          craftsman: craftsman,
          matchScore: score.clamp(0.0, 1.0),
          matchedSkills: craftsman.skills,
          matchReason: 'Odborník na ${craftsman.profession}',
          distanceKm: distKm,
        );
      }).toList()
        ..sort((a, b) => b.matchScore.compareTo(a.matchScore));

      return results.take(maxResults).toList();
    } catch (e) {
      debugPrint('AiMatchService.matchCraftsmen error: $e');
      return _fallbackMatch(lat: lat, lng: lng, maxResults: maxResults);
    }
  }

  // ── Detekcia profesie z popisu ────────────────────────────────────────────
  /// Cloud Function analyzuje text + fotky a vráti zoznam vhodných profesií
  static Future<List<String>> _detectProfessionFromDescription({
    required String description,
    List<String> photoUrls = const [],
  }) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('detectServiceProfession')
          .call({'description': description, 'photoUrls': photoUrls});
      return List<String>.from(result.data['professions'] ?? []);
    } catch (e) {
      debugPrint('_detectProfessionFromDescription error: $e');
      return [];
    }
  }

  // ── Match podľa profesie (bez AI) ─────────────────────────────────────────
  static Future<List<AiMatchResult>> matchByProfession({
    required String profession,
    double? lat,
    double? lng,
    int maxResults = 10,
  }) async {
    final snap = await _db.collection('craftsmen')
        .where('isActive', isEqualTo: true)
        .where('profession', isEqualTo: profession).get();

    final results = snap.docs.map(Craftsman.fromFirestore).map((craftsman) {
      double score = 0.6;
      score += craftsman.rating / 50;
      double? distKm;
      if (lat != null && lng != null && craftsman.geoPoint != null) {
        distKm = _haversineKm(lat, lng, craftsman.geoPoint!.latitude, craftsman.geoPoint!.longitude);
        if (distKm < 10) score += 0.1;
      }
      return AiMatchResult(
        craftsman: craftsman,
        matchScore: score.clamp(0.0, 1.0),
        matchedSkills: craftsman.skills,
        matchReason: 'Odborník na $profession',
        distanceKm: distKm,
      );
    }).toList()
      ..sort((a, b) => b.matchScore.compareTo(a.matchScore));

    return results.take(maxResults).toList();
  }

  // ── Fallback ──────────────────────────────────────────────────────────────
  static Future<List<AiMatchResult>> _fallbackMatch({
    double? lat, double? lng, int maxResults = 10}) async {
    final snap = await _db.collection('craftsmen')
        .where('isActive', isEqualTo: true)
        .orderBy('rating', descending: true).limit(maxResults).get();
    return snap.docs.map(Craftsman.fromFirestore).map((craftsman) {
      double? distKm;
      if (lat != null && lng != null && craftsman.geoPoint != null) {
        distKm = _haversineKm(lat, lng, craftsman.geoPoint!.latitude, craftsman.geoPoint!.longitude);
      }
      return AiMatchResult(
        craftsman: craftsman, matchScore: craftsman.rating / 5.0,
        matchedSkills: craftsman.skills, distanceKm: distKm);
    }).toList();
  }

  static double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    double toRad(double d) => d * 3.141592653589793 / 180;
    final dLat = toRad(lat2 - lat1);
    final dLng = toRad(lng2 - lng1);
    final a = (dLat / 2) * (dLat / 2) +
        toRad(lat1).abs() * toRad(lat2).abs() * (dLng / 2) * (dLng / 2);
    final c = 2 * (a < 1 ? a : 1 - a); // uprostenná aproximácia
    return r * c;
  }
}
