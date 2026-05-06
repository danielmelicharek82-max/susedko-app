// lib/services/calendar_service.dart
// ♻️  RECYCLE z calendar_service.dart (Inkmaker)
// Zmeny: artistId → craftsmanId, kolekcia 'artists' → 'craftsmen'

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/availability_slot.dart';

class CalendarService {
  static final _db = FirebaseFirestore.instance;

  static DocumentReference _availRef(String craftsmanId) => _db
      .collection('craftsmen').doc(craftsmanId)
      .collection('availability').doc('slots');

  static Future<Map<String, List<String>>> fetchAvailability(String craftsmanId) async {
    try {
      final doc = await _availRef(craftsmanId).get();
      if (!doc.exists) return {};
      final data = doc.data() as Map<String, dynamic>? ?? {};
      return data.map((k, v) => MapEntry(k, List<String>.from(v ?? [])));
    } catch (e) { debugPrint('CalendarService.fetchAvailability error: $e'); return {}; }
  }

  static Stream<Map<String, List<String>>> watchAvailability(String craftsmanId) {
    return _availRef(craftsmanId).snapshots().map((doc) {
      if (!doc.exists) return {};
      final data = doc.data() as Map<String, dynamic>? ?? {};
      return data.map((k, v) => MapEntry(k, List<String>.from(v ?? [])));
    });
  }

  static Future<List<String>> fetchSlotsForDate({required String craftsmanId, required DateTime date}) async {
    final availability = await fetchAvailability(craftsmanId);
    return AvailabilitySlot.timesForDate(availability as Map<String, dynamic>, date);
  }

  static Future<Set<DateTime>> fetchAvailableDays(String craftsmanId) async {
    final availability = await fetchAvailability(craftsmanId);
    final days = <DateTime>{};
    availability.forEach((dateStr, slots) {
      if (slots.isNotEmpty) {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          days.add(DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])));
        }
      }
    });
    return days;
  }

  static Future<void> saveAvailability({required String craftsmanId, required Map<String, List<String>> availability}) async {
    final data = <String, dynamic>{};
    availability.forEach((key, slots) => data[key] = slots);
    await _availRef(craftsmanId).set(data);
  }

  static Future<void> addSlot({required String craftsmanId, required DateTime date, required String time}) async {
    final key = AvailabilitySlot.dateKey(date);
    await _availRef(craftsmanId).update({key: FieldValue.arrayUnion([time])});
  }

  static Future<void> removeSlot({required String craftsmanId, required DateTime date, required String time}) async {
    final key = AvailabilitySlot.dateKey(date);
    await _availRef(craftsmanId).update({key: FieldValue.arrayRemove([time])});
  }

  static Future<void> clearDay({required String craftsmanId, required DateTime date}) async {
    await _availRef(craftsmanId).update({AvailabilitySlot.dateKey(date): FieldValue.delete()});
  }

  static Future<void> setFullDay({required String craftsmanId, required DateTime date, List<String>? customSlots}) async {
    final slots = customSlots ?? ['08:00','09:00','10:00','11:00','12:00','13:00','14:00','15:00','16:00','17:00','18:00'];
    await _availRef(craftsmanId).update({AvailabilitySlot.dateKey(date): slots});
  }

  static Future<void> cleanPastSlots(String craftsmanId) async {
    try {
      final doc = await _availRef(craftsmanId).get();
      if (!doc.exists) return;
      final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>? ?? {});
      final today = AvailabilitySlot.dateKey(DateTime.now());
      data.removeWhere((key, _) => key.compareTo(today) < 0);
      await _availRef(craftsmanId).set(data);
    } catch (e) { debugPrint('CalendarService.cleanPastSlots error: $e'); }
  }
}
