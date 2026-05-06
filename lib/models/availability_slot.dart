// lib/models/availability_slot.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum SlotStatus { available, booked, blocked }

class AvailabilitySlot {
  final String id;
  final String craftsmanId;
  final DateTime startTime;
  final DateTime endTime;
  final SlotStatus status;
  final String? bookingId;

  AvailabilitySlot({
    required this.id,
    required this.craftsmanId,
    required this.startTime,
    required this.endTime,
    this.status = SlotStatus.available,
    this.bookingId,
  });

  bool get isAvailable => status == SlotStatus.available;
  int get durationMinutes => endTime.difference(startTime).inMinutes;

  // ✅ pridané static helper metody pre calendar_service a booking_service
  static String dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static List<String> timesForDate(Map<String, dynamic> availability, DateTime date) {
    final key = dateKey(date);
    return List<String>.from(availability[key] ?? []);
  }

  Map<String, dynamic> toMap() => {
    'craftsmanId': craftsmanId,
    'startTime': Timestamp.fromDate(startTime),
    'endTime': Timestamp.fromDate(endTime),
    'status': status.name,
    'bookingId': bookingId,
  };

  factory AvailabilitySlot.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return AvailabilitySlot(
      id: doc.id,
      craftsmanId: map['craftsmanId'] ?? '',
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: (map['endTime'] as Timestamp).toDate(),
      status: SlotStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => SlotStatus.available),
      bookingId: map['bookingId'],
    );
  }

  AvailabilitySlot copyWith({SlotStatus? status, String? bookingId}) {
    return AvailabilitySlot(
      id: id, craftsmanId: craftsmanId,
      startTime: startTime, endTime: endTime,
      status: status ?? this.status,
      bookingId: bookingId ?? this.bookingId);
  }
}
