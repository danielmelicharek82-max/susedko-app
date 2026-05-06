// lib/screens/craftsman/craftsman_calendar_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../models/work_order.dart';
import '../../services/work_order_service.dart';

class CraftsmanCalendarScreen extends StatefulWidget {
  const CraftsmanCalendarScreen({super.key});
  @override
  State<CraftsmanCalendarScreen> createState() =>
      _CraftsmanCalendarScreenState();
}

class _CraftsmanCalendarScreenState extends State<CraftsmanCalendarScreen>
    with SingleTickerProviderStateMixin {
  static const _kPrimary  = Color(0xFF2563EB);
  static const _kAccent   = Color(0xFF60A5FA);
  static const _kBg       = Color(0xFFF0F4FF);
  static const _kCard     = Colors.white;

  DateTime _focusedDay  = DateTime.now();
  DateTime? _selectedDay;

  Map<String, List<String>>   _availability = {};
  Map<String, List<WorkOrder>> _ordersByDay  = {};

  bool _loading = true;
  bool _saving  = false;
  bool _infoDismissed = false;
  StreamSubscription? _ordersSub;
  String? _uid;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  final List<String> _allSlots = [
    '08:00', '09:00', '10:00', '11:00', '12:00',
    '13:00', '14:00', '15:00', '16:00', '17:00', '18:00',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadAvailability();
    _subscribeOrders();
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  String _dateKey(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}'
      '-${day.day.toString().padLeft(2, '0')}';

  Future<void> _loadAvailability() async {
    if (_uid == null) return;
    setState(() => _loading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('craftsmen').doc(_uid)
          .collection('availability').doc('slots').get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        final map  = <String, List<String>>{};
        data.forEach((k, v) => map[k] = List<String>.from(v ?? []));
        setState(() => _availability = map);
      }
    } catch (e) { debugPrint('_loadAvailability error: $e'); }
    finally {
      if (mounted) {
        setState(() => _loading = false);
        _fadeCtrl.forward();
      }
    }
  }

  void _subscribeOrders() {
    if (_uid == null) return;
    _ordersSub = WorkOrderService.watchCraftsman(_uid!).listen(
      (orders) {
        final map = <String, List<WorkOrder>>{};
        for (final o in orders) {
          if (o.status == WorkOrderStatus.cancelled) continue;
          if (o.status == WorkOrderStatus.completed) continue;
          final key = _dateKey(o.scheduledAt);
          map.putIfAbsent(key, () => []).add(o);
        }
        if (mounted) setState(() => _ordersByDay = map);
      },
      onError: (e) => debugPrint('_subscribeOrders error: $e'),
    );
  }

  Future<void> _saveAvailability() async {
    if (_uid == null) return;
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{};
      _availability.forEach((k, v) => data[k] = v);
      await FirebaseFirestore.instance
          .collection('craftsmen').doc(_uid)
          .collection('availability').doc('slots').set(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('calendar_saved'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'error'.tr()}: $e'), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  void _toggleSlot(String slot) {
    if (_selectedDay == null) return;
    final key    = _dateKey(_selectedDay!);
    final booked = _bookedTimesForDay(_selectedDay!);

    if (booked.contains(slot)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.lock, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text('calendar_slot_booked'.tr(namedArgs: {'time': slot})),
        ]),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16)));
      return;
    }

    setState(() {
      final current = List<String>.from(_availability[key] ?? []);
      if (current.contains(slot)) {
        current.remove(slot);
      } else {
        current.add(slot);
        current.sort();
      }
      if (current.isEmpty) {
        _availability.remove(key);
      } else {
        _availability[key] = current;
      }
    });
  }

  Set<String> _bookedTimesForDay(DateTime day) {
    final orders = _ordersByDay[_dateKey(day)] ?? [];
    return orders.map((o) =>
      '${o.scheduledAt.hour.toString().padLeft(2, '0')}:'
      '${o.scheduledAt.minute.toString().padLeft(2, '0')}').toSet();
  }

  Color _slotOrderColor(String slot, DateTime day) {
    final orders = _ordersByDay[_dateKey(day)] ?? [];
    final order  = orders.cast<WorkOrder?>().firstWhere(
      (o) {
        final t = '${o!.scheduledAt.hour.toString().padLeft(2, '0')}:'
                  '${o.scheduledAt.minute.toString().padLeft(2, '0')}';
        return t == slot;
      },
      orElse: () => null,
    );
    if (order == null) return _kPrimary;
    switch (order.status) {
      case WorkOrderStatus.pending:   return Colors.orange;
      case WorkOrderStatus.confirmed: return const Color(0xFFDC2626);
      default: return Colors.grey;
    }
  }

  List<String> _slotsForDay(DateTime? day) =>
      day == null ? [] : _availability[_dateKey(day)] ?? [];

  bool _hasActivity(DateTime day) {
    final key = _dateKey(day);
    return (_availability[key]?.isNotEmpty ?? false) ||
        (_ordersByDay[key]?.isNotEmpty ?? false);
  }

  void _selectAll() {
    if (_selectedDay == null) return;
    setState(() =>
        _availability[_dateKey(_selectedDay!)] = List<String>.from(_allSlots));
  }

  void _clearDay() {
    if (_selectedDay == null) return;
    final key    = _dateKey(_selectedDay!);
    final booked = _bookedTimesForDay(_selectedDay!);
    if (booked.isNotEmpty) {
      setState(() => _availability[key] = booked.toList()..sort());
    } else {
      setState(() => _availability.remove(key));
    }
  }

  String _formatDateSk(DateTime day) {
    const months = ['', 'januára', 'februára', 'marca', 'apríla', 'mája',
        'júna', 'júla', 'augusta', 'septembra', 'októbra', 'novembra', 'decembra'];
    const days   = ['', 'Pondelok', 'Utorok', 'Streda', 'Štvrtok',
        'Piatok', 'Sobota', 'Nedeľa'];
    return '${days[day.weekday]}, ${day.day}. ${months[day.month]}';
  }

  Future<void> _confirmOrder(WorkOrder o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.check_circle_outline, color: Colors.green, size: 24),
          SizedBox(width: 10),
          Text('calendar_confirm_title'.tr(),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _dialogRow(Icons.person_outline,
                  o.customerSnapshot?['name'] ?? 'customer'.tr()),
              _dialogRow(Icons.access_time_outlined,
                  DateFormat('EEE d. MMM, HH:mm').format(o.scheduledAt)),
              if (o.profession != null)
                _dialogRow(Icons.handyman_outlined,
                    '${o.profession!.startsWith("prof_") ? o.profession!.tr() : o.profession!} — ${o.estimatedHours} hod'),
            ])),
          const SizedBox(height: 12),
          Text('calendar_notif_confirm'.tr(),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('cancel'.tr())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: Text('workOrders_pending_confirm'.tr(), style: TextStyle(fontWeight: FontWeight.bold))),
        ]));
    if (ok == true && mounted) {
      await WorkOrderService.confirm(o.id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          Icon(Icons.check_circle, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('calendar_confirmed_snack'.tr()),
        ]),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16)));
    }
  }

  Future<void> _cancelOrder(WorkOrder o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.cancel_outlined, color: Colors.red, size: 24),
          SizedBox(width: 10),
          Text('calendar_reject_title'.tr(),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kBg, borderRadius: BorderRadius.circular(12)),
            child: _dialogRow(Icons.person_outline,
                o.customerSnapshot?['name'] ?? 'customer'.tr())),
          const SizedBox(height: 12),
          Text('calendar_reject_desc'.tr(),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('back'.tr())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: Text('workOrders_pending_reject'.tr(), style: TextStyle(fontWeight: FontWeight.bold))),
        ]));
    if (ok == true && mounted) {
      await WorkOrderService.cancel(o.id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          Icon(Icons.info_outline, color: Colors.white, size: 18),
          SizedBox(width: 8), Text('calendar_rejected_snack'.tr()),
        ]),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedSlots = _slotsForDay(_selectedDay);
    final bookedTimes   = _selectedDay != null
        ? _bookedTimesForDay(_selectedDay!) : <String>{};
    final ordersToday   = _selectedDay != null
        ? (_ordersByDay[_dateKey(_selectedDay!)] ?? []) : <WorkOrder>[];

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text('calendar_title'.tr(),
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold,
                fontSize: 18, letterSpacing: -0.3)),
        backgroundColor: _kPrimary,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          if (_saving)
            const Padding(padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)))
          else
            Container(
              margin: const EdgeInsets.only(right: 12),
              child: IconButton(
                icon: const Icon(Icons.save_rounded, color: Colors.white),
                tooltip: 'save'.tr(),
                onPressed: _saveAvailability)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kPrimary))
          : FadeTransition(
              opacity: _fadeAnim,
              child: CustomScrollView(
                slivers: [

                  // ── Info banner ──────────────────────────────────────────
                  if (!_infoDismissed)
                    SliverToBoxAdapter(
                      child: _InfoBanner(
                        onDismiss: () =>
                            setState(() => _infoDismissed = true))),

                  // ── Legenda ──────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          _legendChip(_kPrimary, 'calendar_legend_free'.tr()),
                          const SizedBox(width: 8),
                          _legendChip(Colors.orange, 'calendar_legend_pending'.tr()),
                          const SizedBox(width: 8),
                          _legendChip(Color(0xFFDC2626), 'calendar_legend_confirmed'.tr()),
                          const SizedBox(width: 8),
                          _legendChip(Colors.grey.shade300, 'calendar_legend_unavailable'.tr()),
                        ]))),

                  // ── Kalendár ─────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: _kPrimary.withOpacity(0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 6)),
                        ]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: TableCalendar(
                          locale: 'sk_SK',
                          firstDay: DateTime.now()
                              .subtract(const Duration(days: 1)),
                          lastDay: DateTime.now()
                              .add(const Duration(days: 180)),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (day) =>
                              isSameDay(_selectedDay, day),
                          onDaySelected: (sel, foc) => setState(() {
                            _selectedDay = sel; _focusedDay = foc;
                          }),
                          calendarStyle: CalendarStyle(
                            selectedDecoration: const BoxDecoration(
                                color: _kPrimary, shape: BoxShape.circle),
                            todayDecoration: BoxDecoration(
                                color: _kAccent.withOpacity(0.3),
                                shape: BoxShape.circle),
                            todayTextStyle: const TextStyle(
                                color: _kPrimary, fontWeight: FontWeight.bold),
                            weekendTextStyle: TextStyle(
                                color: Colors.red.shade400),
                            outsideDaysVisible: false,
                            cellMargin: const EdgeInsets.all(4)),
                          headerStyle: HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                            titleTextStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF1E293B)),
                            leftChevronIcon: Icon(
                                Icons.chevron_left_rounded,
                                color: _kPrimary),
                            rightChevronIcon: Icon(
                                Icons.chevron_right_rounded,
                                color: _kPrimary),
                            headerPadding: const EdgeInsets.symmetric(
                                vertical: 12)),
                          daysOfWeekStyle: DaysOfWeekStyle(
                            weekdayStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade500),
                            weekendStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade300)),
                          eventLoader: (day) =>
                              _hasActivity(day) ? ['event'] : [],
                          calendarBuilders: CalendarBuilders(
                            markerBuilder: (ctx, day, events) {
                              if (events.isEmpty) return null;
                              final key      = _dateKey(day);
                              final hasOrder = _ordersByDay[key]?.isNotEmpty ?? false;
                              final hasPending = _ordersByDay[key]
                                  ?.any((o) => o.status == WorkOrderStatus.pending)
                                  ?? false;
                              return Positioned(
                                bottom: 3,
                                child: Container(
                                    width: 5, height: 5,
                                    decoration: BoxDecoration(
                                        color: hasOrder
                                            ? (hasPending
                                                ? Colors.orange
                                                : const Color(0xFFDC2626))
                                            : _kPrimary,
                                        shape: BoxShape.circle)));
                            }),
                        )))),

                  // ── Deň sekcia ───────────────────────────────────────────
                  if (_selectedDay != null) ...[
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _kPrimary,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16))),
                        child: Row(children: [
                          Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(_formatDateSk(_selectedDay!),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            if (ordersToday.isNotEmpty)
                              Text('calendar_order_count'.tr(namedArgs: {'count': ordersToday.length.toString()}),
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 12)),
                          ])),
                          // Quick actions
                          _quickBtn(Icons.select_all_rounded,
                              'calendar_select_all'.tr(), _selectAll),
                          const SizedBox(width: 6),
                          _quickBtn(Icons.clear_rounded,
                              'delete'.tr(), _clearDay, danger: true),
                        ]))),

                    // ── Grid slotov ──────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _kCard,
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(16)),
                          boxShadow: [BoxShadow(
                              color: _kPrimary.withOpacity(0.07),
                              blurRadius: 12,
                              offset: const Offset(0, 4))]),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 2.1),
                          itemCount: _allSlots.length,
                          itemBuilder: (ctx, i) {
                            final slot     = _allSlots[i];
                            final isBooked = bookedTimes.contains(slot);
                            final isFree   = selectedSlots.contains(slot);
                            final color    = isBooked
                                ? _slotOrderColor(slot, _selectedDay!)
                                : (isFree ? _kPrimary : null);

                            return GestureDetector(
                              onTap: () => _toggleSlot(slot),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                                decoration: BoxDecoration(
                                  color: color != null
                                      ? color.withOpacity(
                                          isBooked ? 0.12 : 1.0)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: color != null
                                          ? color.withOpacity(
                                              isBooked ? 0.6 : 0.0)
                                          : Colors.grey.shade200,
                                      width: isBooked ? 1.5 : 0),
                                  boxShadow: isFree ? [
                                    BoxShadow(
                                        color: _kPrimary.withOpacity(0.25),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2))
                                  ] : null),
                                child: Center(child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isBooked) ...[
                                      Icon(
                                        color == Colors.orange
                                            ? Icons.schedule_rounded
                                            : Icons.lock_rounded,
                                        size: 10,
                                        color: color),
                                      const SizedBox(width: 3),
                                    ],
                                    Text(slot,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            color: isBooked
                                                ? color
                                                : (isFree
                                                    ? Colors.white
                                                    : Colors.grey.shade400))),
                                  ]))));
                          }))),
                  ],

                  // ── Objednávky ───────────────────────────────────────────
                  if (ordersToday.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: Row(children: [
                          Container(
                            width: 4, height: 18,
                            decoration: BoxDecoration(
                                color: _kPrimary,
                                borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 10),
                          Text('calendar_orders_today'.tr(),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Color(0xFF1E293B))),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _kPrimary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20)),
                            child: Text('${ordersToday.length}',
                                style: TextStyle(
                                    fontSize: 12, color: _kPrimary,
                                    fontWeight: FontWeight.bold))),
                        ]))),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                          child: _orderCard(ordersToday[i])),
                        childCount: ordersToday.length)),
                  ],

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              )),
    );
  }

  // ── Info Banner ────────────────────────────────────────────────────────────
  Widget _InfoBanner({required VoidCallback onDismiss}) => Container(
    margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          const Color(0xFF1D4ED8),
          _kPrimary,
          _kAccent.withOpacity(0.9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(
          color: _kPrimary.withOpacity(0.3),
          blurRadius: 16,
          offset: const Offset(0, 6))]),
    child: Stack(children: [
      // Dekorácia — kruh na pozadí
      Positioned(
        right: -20, top: -20,
        child: Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              shape: BoxShape.circle))),
      Positioned(
        right: 30, bottom: -30,
        child: Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              shape: BoxShape.circle))),
      // Obsah
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 44, 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.calendar_month_rounded,
                color: Colors.white, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('calendar_info_title'.tr(),
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              'calendar_info_desc'.tr(),
              style: TextStyle(
                  color: Colors.white.withOpacity(0.88),
                  fontSize: 12,
                  height: 1.5)),
          ])),
        ])),
      // Zavrieť
      Positioned(
        right: 8, top: 8,
        child: GestureDetector(
          onTap: onDismiss,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle),
            child: const Icon(Icons.close_rounded,
                color: Colors.white, size: 14)))),
    ]));

  // ── Karta objednávky ───────────────────────────────────────────────────────
  Widget _orderCard(WorkOrder o) {
    final isPending   = o.status == WorkOrderStatus.pending;
    final isConfirmed = o.status == WorkOrderStatus.confirmed;
    final statusColor = isPending ? Colors.orange : const Color(0xFFDC2626);
    final timeStr     = DateFormat('HH:mm').format(o.scheduledAt);
    final customer    = o.customerSnapshot?['name'] ?? 'customer'.tr();

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: statusColor.withOpacity(0.2), width: 1.5),
        boxShadow: [BoxShadow(
            color: statusColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4))]),
      child: Column(children: [
        // Header farebný pruh
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15))),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(isPending
                    ? Icons.schedule_rounded
                    : Icons.check_circle_rounded,
                    size: 13, color: statusColor),
                const SizedBox(width: 5),
                Text(
                  isPending ? 'calendar_pending_label'.tr() : 'calendar_confirmed_label'.tr(),
                  style: TextStyle(
                      fontSize: 11, color: statusColor,
                      fontWeight: FontWeight.bold)),
              ])),
            const Spacer(),
            Text(timeStr,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: statusColor)),
          ])),
        // Telo
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: _kPrimary.withOpacity(0.1),
                child: Text(
                  customer.isNotEmpty ? customer[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: _kPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14))),
              const SizedBox(width: 10),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(customer,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                if (o.profession != null)
                  Text('${o.profession != null && o.profession!.startsWith("prof_") ? o.profession!.tr() : (o.profession ?? "")} · ${o.estimatedHours} hod',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500)),
              ])),
            ]),
            if (o.description != null && o.description!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10)),
                child: Text(
                  o.description!.length > 80
                      ? '${o.description!.substring(0, 80)}...'
                      : o.description!,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600,
                      height: 1.4))),
            ],
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _actionBtn(
                  label: 'workOrders_pending_confirm'.tr(),
                  icon: Icons.check_rounded,
                  color: _kPrimary,
                  filled: true,
                  onTap: () => _confirmOrder(o))),
                const SizedBox(width: 8),
                Expanded(child: _actionBtn(
                  label: 'workOrders_pending_reject'.tr(),
                  icon: Icons.close_rounded,
                  color: Colors.red,
                  filled: false,
                  onTap: () => _cancelOrder(o))),
              ]),
            ],
            if (isConfirmed) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(Icons.check_circle,
                      size: 14, color: Colors.green.shade600),
                  const SizedBox(width: 6),
                  Text('calendar_confirmed_info'.tr(),
                      style: TextStyle(
                          fontSize: 12, color: Colors.green.shade700,
                          fontWeight: FontWeight.w500)),
                ])),
            ],
          ])),
      ]));
  }

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required bool filled,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: filled ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color, width: 1.5)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 15, color: filled ? Colors.white : color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: filled ? Colors.white : color)),
          ])));

  Widget _legendChip(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8, height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600,
              fontWeight: FontWeight.w500)),
    ]);

  Widget _quickBtn(IconData icon, String label, VoidCallback onTap,
      {bool danger = false}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: danger
                ? Colors.red.withOpacity(0.15)
                : Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13,
                color: danger ? Colors.red.shade200 : Colors.white),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: danger ? Colors.red.shade200 : Colors.white,
                    fontWeight: FontWeight.w600)),
          ])));

  Widget _dialogRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Icon(icon, size: 15, color: Colors.grey.shade400),
      const SizedBox(width: 8),
      Expanded(child: Text(text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
    ]));
}