// lib/screens/customer/create_work_order_screen.dart

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../models/craftsman.dart';
import '../../models/work_order.dart';
import '../../services/work_order_service.dart';
import '../auth/craftsman_register_form.dart'; // kProfessionIcons
import '../customer/service_request_screen.dart'; // kProfessionCategories

const _kPrimary = Color(0xFF2563EB);
const _kDeep    = Color(0xFF1E40AF);
const _kAccent  = Color(0xFF60A5FA);
const _kBg      = Color(0xFFF0F4FF);

class CreateWorkOrderScreen extends StatefulWidget {
  final Craftsman craftsman;
  final String? serviceRequestId;
  final String? initialProfession;

  const CreateWorkOrderScreen({
    super.key,
    required this.craftsman,
    this.serviceRequestId,
    this.initialProfession,
  });

  @override
  State<CreateWorkOrderScreen> createState() =>
      _CreateWorkOrderScreenState();
}

class _CreateWorkOrderScreenState
    extends State<CreateWorkOrderScreen> {
  final _descController    = TextEditingController();
  final _addressController = TextEditingController();
  final _noteController    = TextEditingController();

  DateTime _focusedDay  = DateTime.now();
  DateTime? _selectedDay;
  String? _selectedSlot;
  Map<String, List<String>> _availability = {};
  bool _loadingSlots = true;

  late String _selectedProfession;
  late String _selectedCategory;
  int _estimatedHours = 2;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedProfession = widget.initialProfession != null &&
            kProfessionCategories.containsKey(widget.initialProfession)
        ? widget.initialProfession!
        : kProfessionCategories.keys.first;
    _selectedCategory =
        kProfessionCategories[_selectedProfession]!.first;
    _loadAvailability();
  }

  @override
  void dispose() {
    _descController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _dateKey(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  Future<void> _loadAvailability() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('craftsmen')
          .doc(widget.craftsman.id)
          .collection('availability')
          .doc('slots')
          .get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        final map = <String, List<String>>{};
        data.forEach((k, v) => map[k] = List<String>.from(v ?? []));
        setState(() => _availability = map);
      }
    } catch (e) { debugPrint('availability error: $e'); }
    finally {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  List<String> _slotsForDay(DateTime? day) =>
      day == null ? [] : _availability[_dateKey(day)] ?? [];

  bool _hasSlots(DateTime day) => _slotsForDay(day).isNotEmpty;

  Future<void> _submit() async {
    if (_selectedDay == null || _selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('createWorkOrder_select_date_time'.tr()),
          backgroundColor: Colors.orange));
      return;
    }
    if (_descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('createWorkOrder_fill_desc'.tr()),
          backgroundColor: Colors.orange));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _submitting = true);
    try {
      final timeParts = _selectedSlot!.split(':');
      final scheduledAt = DateTime(
        _selectedDay!.year, _selectedDay!.month, _selectedDay!.day,
        int.parse(timeParts[0]), int.parse(timeParts[1]));

      final customerDoc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();
      final customerData = customerDoc.data() ?? {};

      final order = WorkOrder(
        id:          '',
        customerId:  user.uid,
        craftsmanId: widget.craftsman.id,
        customerSnapshot: {
          'name':  customerData['name'] ?? user.displayName ?? user.email,
          'email': user.email,
        },
        craftsmanSnapshot: {
          'name':         widget.craftsman.name,
          'profileImage': widget.craftsman.profileImage,
          'cityName':     widget.craftsman.cityName,
          'profession':   widget.craftsman.profession,
        },
        profession:       _selectedProfession,
        category:         _selectedCategory,
        description:      _descController.text.trim(),
        address:          _addressController.text.trim().isEmpty
                              ? null : _addressController.text.trim(),
        note:             _noteController.text.trim().isEmpty
                              ? null : _noteController.text.trim(),
        scheduledAt:      scheduledAt,
        estimatedHours:   _estimatedHours,
        serviceRequestId: widget.serviceRequestId,
        hourlyRate:       widget.craftsman.displayRate,
        createdAt:        DateTime.now(),
      );

      await WorkOrderService.create(order);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('createWorkOrder_success'.tr()),
            backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${'error'.tr()}: $e'),
          backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slots = _slotsForDay(_selectedDay);
    final displayRate = widget.craftsman.displayRate;
    final profLabel = widget.craftsman.profession.startsWith('prof_')
        ? widget.craftsman.profession.tr()
        : widget.craftsman.profession;

    return Scaffold(
      backgroundColor: _kBg,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: _kPrimary,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_kDeep, _kPrimary, Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight)),
                child: Stack(children: [
                  Positioned(right: -30, top: -30,
                    child: Container(width: 150, height: 150,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle))),
                  Positioned(left: -20, bottom: -20,
                    child: Container(width: 100, height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        shape: BoxShape.circle))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 52, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('createWorkOrder_title'.tr(),
                          style: const TextStyle(
                            color: Colors.white, fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5)),
                        const SizedBox(height: 2),
                        Text(widget.craftsman.name,
                          style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                      ])),
                ])),
            ),
          ),
        ],
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 60),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Craftsman header card ──────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kPrimary.withOpacity(0.1)),
                boxShadow: [BoxShadow(
                    color: _kPrimary.withOpacity(0.07),
                    blurRadius: 14, offset: const Offset(0, 4))]),
              child: Row(children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: _kPrimary.withOpacity(0.2), width: 2),
                    boxShadow: [BoxShadow(
                        color: _kPrimary.withOpacity(0.15),
                        blurRadius: 8)]),
                  child: ClipOval(child: widget.craftsman.profileImage != null
                      ? Image.network(widget.craftsman.profileImage!,
                          fit: BoxFit.cover)
                      : Container(
                          color: _kPrimary.withOpacity(0.1),
                          child: const Icon(Icons.handyman,
                              size: 24, color: _kPrimary)))),
                const SizedBox(width: 12),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(widget.craftsman.name, style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15,
                      color: Color(0xFF1E293B))),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kPrimary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                    child: Text(profLabel, style: const TextStyle(
                        color: _kPrimary, fontSize: 11,
                        fontWeight: FontWeight.w600))),
                  if (widget.craftsman.cityName != null) ...[
                    const SizedBox(height: 3),
                    Row(children: [
                      Icon(Icons.location_on,
                          size: 11, color: Colors.grey.shade400),
                      const SizedBox(width: 3),
                      Text(widget.craftsman.cityName!,
                          style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11)),
                    ]),
                  ],
                ])),
                if (displayRate != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_kDeep, _kPrimary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(14)),
                    child: Column(children: [
                      Text('${displayRate.toStringAsFixed(0)} €',
                          style: const TextStyle(color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      Text('createWorkOrder_per_hour'.tr(),
                          style: TextStyle(color: Colors.white.withOpacity(0.8),
                              fontSize: 10)),
                    ])),
              ])),
            const SizedBox(height: 14),

            // ── Info banner ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade200)),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(9)),
                  child: Icon(Icons.verified_user_outlined,
                      color: Colors.green.shade700, size: 16)),
                const SizedBox(width: 12),
                Expanded(child: Text('createOrderInfoBanner'.tr(),
                    style: TextStyle(fontSize: 12,
                        color: Colors.green.shade800, height: 1.4))),
              ])),
            const SizedBox(height: 20),

            // ── Profession ─────────────────────────────────────────────
            _sectionTitle('createWorkOrder_profession'.tr(),
                Icons.handyman_outlined),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8)]),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedProfession,
                  isExpanded: true,
                  items: kProfessionCategories.keys.map((key) =>
                      DropdownMenuItem(
                          value: key,
                          child: Row(children: [
                            Icon(kProfessionIcons[key] ??
                                Icons.handyman_outlined,
                                size: 16, color: _kPrimary),
                            const SizedBox(width: 8),
                            Text(key.tr()),
                          ]))).toList(),
                  onChanged: (v) => setState(() {
                    _selectedProfession = v!;
                    _selectedCategory =
                        kProfessionCategories[v]!.first;
                  })))),
            const SizedBox(height: 16),

            // ── Category ───────────────────────────────────────────────
            _sectionTitle('createWorkOrder_category'.tr(),
                Icons.category_outlined),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: (kProfessionCategories[_selectedProfession] ?? [])
                  .map((cat) {
                final sel = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedCategory = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? _kPrimary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sel ? _kPrimary : Colors.grey.shade300,
                          width: sel ? 2 : 1),
                      boxShadow: sel ? [BoxShadow(
                          color: _kPrimary.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2))] : []),
                    child: Text(cat, style: TextStyle(fontSize: 13,
                        color: sel ? Colors.white : Colors.grey.shade700,
                        fontWeight: sel
                            ? FontWeight.bold : FontWeight.normal))));
              }).toList()),
            const SizedBox(height: 16),

            // ── Description ────────────────────────────────────────────
            _sectionTitle('createWorkOrder_desc'.tr(),
                Icons.description_outlined),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8)]),
              child: TextField(
                controller: _descController,
                maxLines: 3, maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'createWorkOrder_desc_hint'.tr(),
                  hintStyle: TextStyle(
                      color: Colors.grey.shade400, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14)))),
            const SizedBox(height: 16),

            // ── Address ────────────────────────────────────────────────
            _sectionTitle('createWorkOrder_address'.tr(),
                Icons.location_on_outlined),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8)]),
              child: TextField(
                controller: _addressController,
                decoration: InputDecoration(
                  hintText: 'createWorkOrder_address_hint'.tr(),
                  hintStyle: TextStyle(
                      color: Colors.grey.shade400, fontSize: 13),
                  prefixIcon: Icon(Icons.location_on_outlined,
                      color: _kPrimary.withOpacity(0.6), size: 18),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14)))),
            const SizedBox(height: 16),

            // ── Estimated hours ────────────────────────────────────────
            _sectionTitle('createWorkOrder_estimated'.tr(),
                Icons.timer_outlined),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8)]),
              child: Row(children: [
                GestureDetector(
                  onTap: _estimatedHours > 1
                      ? () => setState(() => _estimatedHours--)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _estimatedHours > 1
                          ? _kPrimary.withOpacity(0.1)
                          : Colors.grey.shade100,
                      shape: BoxShape.circle),
                    child: Icon(Icons.remove,
                        color: _estimatedHours > 1
                            ? _kPrimary : Colors.grey.shade400,
                        size: 18))),
                Expanded(child: Column(children: [
                  Text(
                    'createWorkOrder_hours_label'.tr(namedArgs: {
                      'hours': _estimatedHours.toString(),
                    }),
                    style: const TextStyle(fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B)),
                    textAlign: TextAlign.center),
                  if (displayRate != null)
                    Text(
                      'estimatedNote'.tr(namedArgs: {
                        'total': (_estimatedHours * displayRate)
                            .toStringAsFixed(0),
                      }),
                      style: TextStyle(fontSize: 12,
                          color: Colors.grey.shade500),
                      textAlign: TextAlign.center),
                ])),
                GestureDetector(
                  onTap: _estimatedHours < 12
                      ? () => setState(() => _estimatedHours++)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _estimatedHours < 12
                          ? _kPrimary.withOpacity(0.1)
                          : Colors.grey.shade100,
                      shape: BoxShape.circle),
                    child: Icon(Icons.add,
                        color: _estimatedHours < 12
                            ? _kPrimary : Colors.grey.shade400,
                        size: 18))),
              ])),
            const SizedBox(height: 20),

            // ── Calendar ───────────────────────────────────────────────
            _sectionTitle('createWorkOrder_date'.tr(),
                Icons.calendar_today_outlined),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8)]),
              child: TableCalendar(
                firstDay: DateTime.now(),
                lastDay:
                    DateTime.now().add(const Duration(days: 180)),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) =>
                    isSameDay(_selectedDay, day),
                onDaySelected: (sel, foc) => setState(() {
                  _selectedDay = sel;
                  _focusedDay = foc;
                  _selectedSlot = null;
                }),
                enabledDayPredicate: (day) => _hasSlots(day),
                calendarStyle: CalendarStyle(
                  selectedDecoration: const BoxDecoration(
                      color: _kPrimary, shape: BoxShape.circle),
                  todayDecoration: BoxDecoration(
                      color: _kPrimary.withOpacity(0.3),
                      shape: BoxShape.circle),
                  disabledTextStyle: TextStyle(
                      color: Colors.grey.shade300)),
                headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true),
                eventLoader: (day) =>
                    _hasSlots(day) ? ['•'] : [],
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (ctx, day, events) {
                    if (events.isEmpty) return null;
                    return Positioned(
                      bottom: 4,
                      child: Container(
                        width: 6, height: 6,
                        decoration: const BoxDecoration(
                            color: _kPrimary,
                            shape: BoxShape.circle)));
                  }),
              )),
            const SizedBox(height: 16),

            // ── Time slots ─────────────────────────────────────────────
            if (_selectedDay != null) ...[
              _sectionTitle('createWorkOrder_time'.tr(),
                  Icons.access_time_outlined),
              const SizedBox(height: 10),
              _loadingSlots
                  ? const Center(child: CircularProgressIndicator(
                      color: _kPrimary))
                  : slots.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.orange.shade200)),
                          child: Row(children: [
                            Icon(Icons.warning_amber_outlined,
                                color: Colors.orange.shade700,
                                size: 16),
                            const SizedBox(width: 8),
                            Text('createWorkOrder_no_slots'.tr(),
                                style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontSize: 13)),
                          ]))
                      : Wrap(
                          spacing: 10, runSpacing: 10,
                          children: slots.map((slot) {
                            final sel = _selectedSlot == slot;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedSlot = slot),
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 10),
                                decoration: BoxDecoration(
                                  color: sel ? _kPrimary : Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  border: Border.all(
                                      color: sel
                                          ? _kPrimary
                                          : Colors.grey.shade300,
                                      width: sel ? 2 : 1),
                                  boxShadow: sel ? [BoxShadow(
                                      color: _kPrimary.withOpacity(0.2),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2))]
                                      : []),
                                child: Text(slot,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: sel
                                            ? Colors.white
                                            : Colors.grey.shade700))));
                          }).toList()),
              const SizedBox(height: 16),
            ],

            // ── Note ───────────────────────────────────────────────────
            _sectionTitle('noteForCraftsman'.tr(), Icons.note_outlined),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8)]),
              child: TextField(
                controller: _noteController, maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'noteHintCraftsman'.tr(),
                  hintStyle: TextStyle(
                      color: Colors.grey.shade400, fontSize: 13),
                  prefixIcon: Icon(Icons.note_outlined,
                      color: _kPrimary.withOpacity(0.6), size: 18),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14)))),
            const SizedBox(height: 20),

            // ── Order summary ──────────────────────────────────────────
            if (_selectedDay != null && _selectedSlot != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    _kPrimary.withOpacity(0.06),
                    _kAccent.withOpacity(0.04)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: _kPrimary.withOpacity(0.15))),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _kPrimary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.receipt_long_outlined,
                          size: 14, color: _kPrimary)),
                    const SizedBox(width: 8),
                    Text('createWorkOrder_summary'.tr(),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1E293B))),
                  ]),
                  const SizedBox(height: 12),
                  _summaryRow(Icons.calendar_today_outlined,
                      DateFormat('EEE d. MMMM yyyy')
                          .format(_selectedDay!)),
                  _summaryRow(Icons.access_time_outlined,
                      _selectedSlot!),
                  _summaryRow(Icons.timer_outlined,
                      'summaryEstimated'.tr(namedArgs: {
                        'hours': _estimatedHours.toString(),
                      })),
                  if (displayRate != null)
                    _summaryRow(Icons.euro_outlined,
                        'finalPriceNote'.tr(namedArgs: {
                          'total': (_estimatedHours * displayRate)
                              .toStringAsFixed(0),
                        })),
                ])),
              const SizedBox(height: 16),
            ],

            // ── Submit ─────────────────────────────────────────────────
            GestureDetector(
              onTap: _submitting ? null : _submit,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  gradient: _submitting
                      ? LinearGradient(colors: [
                          Colors.grey.shade400,
                          Colors.grey.shade300])
                      : const LinearGradient(
                          colors: [_kDeep, _kPrimary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _submitting ? [] : [BoxShadow(
                    color: _kPrimary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4))]),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  if (_submitting)
                    const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  else
                    const Icon(Icons.send_rounded,
                        color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    _submitting
                        ? 'createWorkOrder_submitting'.tr()
                        : 'createWorkOrder_submit'.tr(),
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 15)),
                ]))),
          ])),
      ),
    );
  }

  Widget _sectionTitle(String text, IconData icon) => Row(children: [
    Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _kPrimary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 15, color: _kPrimary)),
    const SizedBox(width: 8),
    Text(text, style: const TextStyle(fontSize: 15,
        fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
  ]);

  Widget _summaryRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Icon(icon, size: 14, color: Colors.grey.shade400),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: TextStyle(
          fontSize: 13, color: Colors.grey.shade700))),
    ]));
}