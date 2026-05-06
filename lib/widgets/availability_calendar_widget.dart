// lib/widgets/availability_calendar_widget.dart
// 🆕 NOVÉ pre Homie — kalendár dostupnosti remeselníka
// Používa sa v craftsman_calendar_screen.dart a booking_screen.dart

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const _kPrimary = Color(0xFF2563EB);

// ─── Read-only kalendár (pre zákazníka — booking_screen) ─────────────────────
class AvailabilityCalendarReadOnly extends StatelessWidget {
  final Map<String, List<String>> availability; // {'2025-01-15': ['09:00','11:00']}
  final DateTime? selectedDay;
  final DateTime focusedDay;
  final void Function(DateTime selected, DateTime focused) onDaySelected;

  const AvailabilityCalendarReadOnly({
    super.key,
    required this.availability,
    required this.selectedDay,
    required this.focusedDay,
    required this.onDaySelected,
  });

  String _dateKey(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  bool _hasSlots(DateTime day) => (availability[_dateKey(day)] ?? []).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return TableCalendar(
      firstDay: DateTime.now(),
      lastDay: DateTime.now().add(const Duration(days: 180)),
      focusedDay: focusedDay,
      selectedDayPredicate: (day) => isSameDay(selectedDay, day),
      onDaySelected: onDaySelected,
      enabledDayPredicate: (day) => _hasSlots(day),
      calendarStyle: CalendarStyle(
        selectedDecoration: const BoxDecoration(color: _kPrimary, shape: BoxShape.circle),
        todayDecoration: BoxDecoration(color: _kPrimary.withOpacity(0.3), shape: BoxShape.circle),
        disabledTextStyle: TextStyle(color: Colors.grey.shade300)),
      headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true,
          titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      eventLoader: (day) => _hasSlots(day) ? ['free'] : [],
      calendarBuilders: CalendarBuilders(markerBuilder: (context, day, events) {
        if (events.isEmpty) return null;
        return Positioned(bottom: 4, child: Container(width: 6, height: 6,
            decoration: const BoxDecoration(color: _kPrimary, shape: BoxShape.circle)));
      }));
  }
}

// ─── Editable kalendár (pre remeselníka — craftsman_calendar_screen) ─────────
class AvailabilityCalendarEditor extends StatefulWidget {
  final String craftsmanId;
  const AvailabilityCalendarEditor({super.key, required this.craftsmanId});

  @override
  State<AvailabilityCalendarEditor> createState() => _AvailabilityCalendarEditorState();
}

class _AvailabilityCalendarEditorState extends State<AvailabilityCalendarEditor> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<String, List<String>> _availability = {};
  bool _loading = true;
  bool _saving = false;

  // Predvolené časové sloty
  final List<String> _allSlots = [
    '08:00','09:00','10:00','11:00','12:00',
    '13:00','14:00','15:00','16:00','17:00','18:00',
  ];

  @override
  void initState() { super.initState(); _loadAvailability(); }

  String _dateKey(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  Future<void> _loadAvailability() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('craftsmen').doc(widget.craftsmanId)
          .collection('availability').doc('slots').get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        final map = <String, List<String>>{};
        data.forEach((k, v) => map[k] = List<String>.from(v ?? []));
        setState(() => _availability = map);
      }
    } catch (e) { debugPrint('Availability load error: $e'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _saveAvailability() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('craftsmen').doc(widget.craftsmanId)
          .collection('availability').doc('slots').set(_availability);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dostupnosť uložená'), backgroundColor: _kPrimary));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba: $e'), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  void _toggleSlot(String slot) {
    if (_selectedDay == null) return;
    final key = _dateKey(_selectedDay!);
    final slots = List<String>.from(_availability[key] ?? []);
    slots.contains(slot) ? slots.remove(slot) : slots.add(slot);
    slots.sort();
    setState(() => _availability[key] = slots);
  }

  bool _hasSlots(DateTime day) => (_availability[_dateKey(day)] ?? []).isNotEmpty;

  List<String> get _selectedSlots =>
      _selectedDay != null ? (_availability[_dateKey(_selectedDay!)] ?? []) : [];

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(children: [
      // Kalendár
      TableCalendar(
        firstDay: DateTime.now().subtract(const Duration(days: 1)),
        lastDay: DateTime.now().add(const Duration(days: 365)),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selected, focused) =>
            setState(() { _selectedDay = selected; _focusedDay = focused; }),
        calendarStyle: CalendarStyle(
          selectedDecoration: const BoxDecoration(color: _kPrimary, shape: BoxShape.circle),
          todayDecoration: BoxDecoration(color: _kPrimary.withOpacity(0.3), shape: BoxShape.circle)),
        headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true,
            titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        eventLoader: (day) => _hasSlots(day) ? ['busy'] : [],
        calendarBuilders: CalendarBuilders(markerBuilder: (context, day, events) {
          if (events.isEmpty) return null;
          return Positioned(bottom: 4, child: Container(width: 6, height: 6,
              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)));
        })),

      // Sloty pre vybraný deň
      if (_selectedDay != null) ...[
        const Divider(),
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(children: [
            Text('Sloty pre ${_selectedDay!.day}.${_selectedDay!.month}.${_selectedDay!.year}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            if (_saving)
              const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimary))
            else
              TextButton.icon(
                onPressed: _saveAvailability,
                icon: const Icon(Icons.save_outlined, size: 16),
                label: const Text('Uložiť'),
                style: TextButton.styleFrom(foregroundColor: _kPrimary)),
          ])),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(spacing: 8, runSpacing: 8, children: _allSlots.map((slot) {
            final active = _selectedSlots.contains(slot);
            return GestureDetector(
              onTap: () => _toggleSlot(slot),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? _kPrimary : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: active ? _kPrimary : Colors.grey.shade300,
                      width: active ? 2 : 1)),
                child: Text(slot, style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: active ? Colors.white : Colors.grey.shade700))));
          }).toList())),
        const SizedBox(height: 16),
      ],
    ]);
  }
}

// ─── Slot picker (pre booking_screen) ────────────────────────────────────────
class TimeSlotPicker extends StatelessWidget {
  final List<String> slots;
  final String? selectedSlot;
  final void Function(String) onSelected;

  const TimeSlotPicker({
    super.key,
    required this.slots,
    required this.selectedSlot,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('Pre tento deň nie sú dostupné termíny',
            style: TextStyle(color: Colors.grey.shade500)));
    }
    return Wrap(spacing: 10, runSpacing: 10, children: slots.map((slot) {
      final selected = selectedSlot == slot;
      return GestureDetector(
        onTap: () => onSelected(slot),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _kPrimary : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? _kPrimary : Colors.grey.shade300,
                width: selected ? 2 : 1)),
          child: Text(slot, style: TextStyle(
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : Colors.grey.shade700))));
    }).toList());
  }
}
