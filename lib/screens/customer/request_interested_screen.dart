// lib/screens/customer/request_interested_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../models/service_request.dart';
import '../../models/craftsman.dart';
import '../../services/service_request_service.dart';
import '../auth/craftsman_register_form.dart'; // kProfessionIcons
import 'create_work_order_screen.dart';

const _kPrimary = Color(0xFF2563EB);
const _kDeep    = Color(0xFF1E40AF);
const _kAccent  = Color(0xFF60A5FA);
const _kBg      = Color(0xFFF0F4FF);

class RequestInterestedScreen extends StatefulWidget {
  final ServiceRequest request;
  const RequestInterestedScreen({super.key, required this.request});

  @override
  State<RequestInterestedScreen> createState() =>
      _RequestInterestedScreenState();
}

class _RequestInterestedScreenState
    extends State<RequestInterestedScreen> {
  List<_CraftsmanInterest> _interested = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInterested();
  }

  Future<void> _loadInterested() async {
    final r = widget.request;
    if (r.interestedCraftsmanIds.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final result = <_CraftsmanInterest>[];
    for (final uid in r.interestedCraftsmanIds) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('craftsmen').doc(uid).get();
        if (!doc.exists) continue;
        final craftsman = Craftsman.fromFirestore(doc);
        final interestData =
            r.toMap()['interest_$uid'] as Map<String, dynamic>?;
        final message = interestData?['message'] as String?;
        result.add(
            _CraftsmanInterest(craftsman: craftsman, message: message));
      } catch (e) {
        debugPrint('Error loading craftsman $uid: $e');
      }
    }
    if (mounted) {
      setState(() { _interested = result; _loading = false; });
    }
  }

  Future<void> _selectCraftsman(_CraftsmanInterest interest) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.08),
                shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_outline,
                  color: _kPrimary, size: 32)),
            const SizedBox(height: 16),
            Text('selectCraftsmanTitle'.tr(),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'selectCraftsmanDesc'.tr(namedArgs: {
                'name': interest.craftsman.name,
              }),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13,
                  color: Colors.grey.shade600, height: 1.5)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(ctx, false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text('cancel'.tr(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black54)))))),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(ctx, true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kDeep, _kPrimary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                        color: _kPrimary.withOpacity(0.3),
                        blurRadius: 8, offset: const Offset(0, 3))]),
                  child: Center(child: Text('confirm'.tr(),
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold)))))),
            ]),
          ]))));

    if (confirmed != true || !mounted) return;

    try {
      await ServiceRequestService.selectCraftsman(
        requestId:     widget.request.id,
        craftsmanId:   interest.craftsman.id,
        craftsmanName: interest.craftsman.name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('craftsmanSelectedSnack'.tr(namedArgs: {
            'name': interest.craftsman.name,
          })),
          backgroundColor: Colors.green));
      Navigator.pop(context, true);
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => CreateWorkOrderScreen(
              craftsman: interest.craftsman,
              initialProfession: widget.request.profession)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'error'.tr()}: $e'),
              backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final profLabel = r.profession.startsWith('prof_')
        ? r.profession.tr() : r.profession;

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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 52, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('interestedTitle'.tr(),
                          style: const TextStyle(
                            color: Colors.white, fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5)),
                        const SizedBox(height: 2),
                        Text('interestedSubtitle'.tr(),
                          style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                      ])),
                ])),
            ),
          ),
        ],
        body: Column(children: [
          // ── Request summary ──────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kPrimary.withOpacity(0.1)),
              boxShadow: [BoxShadow(
                  color: _kPrimary.withOpacity(0.06),
                  blurRadius: 12, offset: const Offset(0, 3))]),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.list_alt_outlined,
                      size: 14, color: _kPrimary)),
                const SizedBox(width: 8),
                Text('requestSummary'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold,
                        fontSize: 13, color: Color(0xFF1E293B))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _kPrimary.withOpacity(0.25))),
                  child: Text(profLabel, style: const TextStyle(
                      color: _kPrimary, fontSize: 12,
                      fontWeight: FontWeight.bold))),
                const SizedBox(width: 8),
                Text(r.category,
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 12)),
              ]),
              const SizedBox(height: 8),
              Text(r.description,
                  style: TextStyle(fontSize: 13,
                      color: Colors.grey.shade700, height: 1.4),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.people_outline,
                      size: 14, color: _kPrimary),
                  const SizedBox(width: 6),
                  Text(
                    'openRequests_interested_count'.tr(namedArgs: {
                      'count': r.interestedCraftsmanIds.length.toString(),
                    }),
                    style: const TextStyle(color: _kPrimary,
                        fontSize: 12, fontWeight: FontWeight.w600)),
                ])),
            ])),

          // ── List ──────────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _kPrimary))
                : _interested.isEmpty
                    ? _buildEmpty()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: _interested.length,
                        itemBuilder: (ctx, i) =>
                            _buildCraftsmanCard(_interested[i]))),
        ]),
      ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _kPrimary.withOpacity(0.07), shape: BoxShape.circle),
          child: Icon(Icons.people_outline, size: 52,
              color: _kPrimary.withOpacity(0.4))),
        const SizedBox(height: 20),
        Text('noInterested'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold,
                fontSize: 16, color: Color(0xFF1E293B))),
      ])));

  Widget _buildCraftsmanCard(_CraftsmanInterest interest) {
    final c = interest.craftsman;
    final profLabel = c.profession.startsWith('prof_')
        ? c.profession.tr() : c.profession;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kPrimary.withOpacity(0.08)),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 14, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              _kDeep.withOpacity(0.06), _kAccent.withOpacity(0.04)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20))),
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
              child: ClipOval(child: c.profileImage != null
                  ? Image.network(c.profileImage!, fit: BoxFit.cover)
                  : Container(
                      color: _kPrimary.withOpacity(0.1),
                      child: const Icon(Icons.handyman,
                          size: 24, color: _kPrimary)))),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(c.name, style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B)))),
                if (c.isVerified)
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: _kPrimary.withOpacity(0.08),
                      shape: BoxShape.circle),
                    child: const Icon(Icons.verified,
                        size: 14, color: _kPrimary)),
              ]),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    _kPrimary.withOpacity(0.12),
                    _kAccent.withOpacity(0.08)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _kPrimary.withOpacity(0.2))),
                child: Text(profLabel, style: const TextStyle(
                    fontSize: 11, color: _kPrimary,
                    fontWeight: FontWeight.w600))),
              if (c.cityName != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.location_on,
                      size: 12, color: Colors.grey.shade400),
                  const SizedBox(width: 3),
                  Text(c.cityName!, style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 12)),
                ]),
              ],
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.star_rounded,
                      size: 13, color: Colors.amber),
                  const SizedBox(width: 3),
                  Text(c.rating.toStringAsFixed(1),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                ])),
              if (c.displayRate != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kDeep, _kPrimary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    '${c.displayRate!.toStringAsFixed(0)} €/h',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 12))),
              ],
            ]),
          ])),

        // Body
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Message
            if (interest.message != null &&
                interest.message!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200)),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 8),
                  Expanded(child: Text(interest.message!,
                      style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13, height: 1.4))),
                ])),
              const SizedBox(height: 10),
            ],

            // Skills
            if (c.skills.isNotEmpty) ...[
              Wrap(spacing: 6, runSpacing: 6,
                children: c.skills.take(4).map((s) {
                  final label = s.startsWith('prof_') ? s.tr() : s;
                  final icon =
                      kProfessionIcons[s] ?? Icons.handyman_outlined;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, size: 11,
                          color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(label, style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600)),
                    ]));
                }).toList()),
              const SizedBox(height: 12),
            ],

            // Select button
            GestureDetector(
              onTap: () => _selectCraftsman(interest),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kDeep, _kPrimary],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(
                    color: _kPrimary.withOpacity(0.3),
                    blurRadius: 10, offset: const Offset(0, 4))]),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  const Icon(Icons.check_circle_outline,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text('selectAndOrder'.tr(),
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ]))),
            const SizedBox(height: 16),
          ])),
      ]));
  }
}

class _CraftsmanInterest {
  final Craftsman craftsman;
  final String? message;
  _CraftsmanInterest({required this.craftsman, this.message});
}