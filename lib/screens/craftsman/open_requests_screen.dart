// lib/screens/craftsman/open_requests_screen.dart
// Remeselník vidí broadcast požiadavky vo svojich profesiách a môže prejaviť záujem

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/service_request.dart';
import '../../services/service_request_service.dart';

const _kPrimary = Color(0xFF2563EB);
const _kDeep    = Color(0xFF1E40AF);
const _kAccent  = Color(0xFF60A5FA);
const _kBg      = Color(0xFFF0F4FF);

class OpenRequestsScreen extends StatefulWidget {
  const OpenRequestsScreen({super.key});
  @override
  State<OpenRequestsScreen> createState() => _OpenRequestsScreenState();
}

class _OpenRequestsScreenState extends State<OpenRequestsScreen> {
  List<String> _myProfessions = [];
  bool _loadingProfessions = true;

  @override
  void initState() {
    super.initState();
    _loadProfessions();
  }

  Future<void> _loadProfessions() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { setState(() => _loadingProfessions = false); return; }
    final doc = await FirebaseFirestore.instance
        .collection('craftsmen').doc(uid).get();
    if (!doc.exists || !mounted) {
      setState(() => _loadingProfessions = false);
      return;
    }
    final data = doc.data()!;
    final skills = List<String>.from(data['skills'] ?? []);
    final profession = data['profession'] as String? ?? '';
    setState(() {
      _myProfessions = skills.isNotEmpty
          ? skills : [if (profession.isNotEmpty) profession];
      _loadingProfessions = false;
    });
  }

  Future<void> _expressInterest(ServiceRequest request) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (request.interestedCraftsmanIds.contains(user.uid)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('openRequests_already_snack'.tr()),
          backgroundColor: Colors.orange));
      return;
    }

    final messageController = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 20),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),

            // Icon
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kDeep, _kPrimary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
                shape: BoxShape.circle),
              child: const Icon(Icons.pan_tool_outlined,
                  color: Colors.white, size: 28)),
            const SizedBox(height: 14),

            // ✅ OPRAVA: .tr() pridané
            Text('openRequests_interest_title'.tr(),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('openRequests_interest_subtitle'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13,
                    color: Colors.grey.shade500, height: 1.5)),
            const SizedBox(height: 20),

            // Info box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Icon(Icons.info_outline,
                    size: 16, color: _kPrimary.withOpacity(0.7)),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  'openRequests_interest_info'.tr(),
                  style: TextStyle(fontSize: 12,
                      color: Colors.grey.shade600, height: 1.5))),
              ])),
            const SizedBox(height: 16),

            // Správa
            TextField(
              controller: messageController,
              maxLines: 3, maxLength: 200,
              decoration: InputDecoration(
                hintText: 'openRequests_message_hint'.tr(),
                filled: true, fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: _kPrimary, width: 2)))),
            const SizedBox(height: 16),

            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(ctx, false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text('cancel'.tr(),
                      style: TextStyle(fontWeight: FontWeight.w600,
                          color: Colors.black54)))))),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(ctx, true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kDeep, _kPrimary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                      color: _kPrimary.withOpacity(0.3),
                      blurRadius: 8, offset: const Offset(0, 3))]),
                  child: Center(child: Text('openRequests_interest_confirm'.tr(),
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)))))),
            ]),
          ]))));

    if (confirmed != true || !mounted) return;

    try {
      final craftsmanDoc = await FirebaseFirestore.instance
          .collection('craftsmen').doc(user.uid).get();
      final craftsmanName =
          craftsmanDoc.data()?['name'] ?? user.email ?? '';

      await ServiceRequestService.expressInterest(
        requestId:     request.id,
        craftsmanId:   user.uid,
        craftsmanName: craftsmanName,
        message: messageController.text.trim().isEmpty
            ? null : messageController.text.trim(),
      );

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('openRequests_interest_snack'.tr()),
              backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'error'.tr()}: $e'),
              backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            automaticallyImplyLeading: false,
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
                    child: Container(width: 140, height: 140,
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
                        Text('openRequests_title'.tr(),
                          style: const TextStyle(
                            color: Colors.white, fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5)),
                        const SizedBox(height: 2),
                        Text('openRequests_subtitle'.tr(),
                          style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                      ]),
                  ),
                ])),
            ),
          ),
        ],
        body: _loadingProfessions
            ? const Center(
                child: CircularProgressIndicator(color: _kPrimary))
            : _myProfessions.isEmpty
                ? _buildNoProfessions()
                : StreamBuilder<List<ServiceRequest>>(
                    stream: ServiceRequestService
                        .watchOpenRequests(_myProfessions),
                    builder: (ctx, snap) {
                      if (snap.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: _kPrimary));
                      }
                      final requests = snap.data ?? [];
                      if (requests.isEmpty) return _buildEmpty();
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                            14, 14, 14, 100),
                        itemCount: requests.length,
                        itemBuilder: (ctx, i) =>
                            _buildCard(requests[i]));
                    }),
      ),
    );
  }

  // ── Prázdne stavy ──────────────────────────────────────────────────────────
  Widget _buildNoProfessions() => SingleChildScrollView(
    padding: const EdgeInsets.all(32),
    child: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _kPrimary.withOpacity(0.07),
            shape: BoxShape.circle),
          child: Icon(Icons.handyman_outlined,
              size: 48, color: _kPrimary.withOpacity(0.4))),
        const SizedBox(height: 16),
        Text('openRequests_no_professions'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold,
                fontSize: 16, color: Color(0xFF1E293B))),
        const SizedBox(height: 6),
        Text('openRequests_no_professions_desc'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13,
                color: Colors.grey.shade500, height: 1.5)),
      ])));

  Widget _buildEmpty() => SingleChildScrollView(
    padding: const EdgeInsets.all(32),
    child: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _kPrimary.withOpacity(0.07),
            shape: BoxShape.circle),
          child: Icon(Icons.campaign_outlined,
              size: 48, color: _kPrimary.withOpacity(0.4))),
        const SizedBox(height: 16),
        Text('openRequests_empty'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold,
                fontSize: 16, color: Color(0xFF1E293B))),
        const SizedBox(height: 6),
        Text('openRequests_empty_desc'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13,
                color: Colors.grey.shade500, height: 1.5)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _kPrimary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20)),
          child: Text(
            _myProfessions.map((p) => p.tr()).join(' · '),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12,
                color: _kPrimary, fontWeight: FontWeight.w500))),
      ])));

  // ── Karta zákazky ──────────────────────────────────────────────────────────
  Widget _buildCard(ServiceRequest r) {
    final user = FirebaseAuth.instance.currentUser;
    final alreadyInterested = user != null &&
        r.interestedCraftsmanIds.contains(user.uid);
    final interestCount = r.interestedCraftsmanIds.length;

    // ✅ OPRAVA: profession key preložený cez .tr()
    final profLabel = r.profession.startsWith('prof_')
        ? r.profession.tr() : r.profession;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: alreadyInterested
              ? Colors.green.withOpacity(0.3)
              : _kPrimary.withOpacity(0.1),
          width: alreadyInterested ? 1.5 : 1),
        boxShadow: [BoxShadow(
          color: _kPrimary.withOpacity(0.05),
          blurRadius: 16, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header ───────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            color: _kPrimary.withOpacity(0.04),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20))),
          child: Row(children: [
            // profesia chip
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kDeep, _kPrimary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20)),
              child: Text(profLabel,
                  style: const TextStyle(color: Colors.white,
                      fontSize: 12, fontWeight: FontWeight.bold))),
            const SizedBox(width: 6),
            // kategória — Expanded aby nepretiekla
            Expanded(child: Text(r.category,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 12))),
            const SizedBox(width: 6),
            // čas
            Row(children: [
              Icon(Icons.access_time_rounded,
                  size: 11, color: Colors.grey.shade400),
              const SizedBox(width: 3),
              Text(_formatDate(r.createdAt),
                  style: TextStyle(
                      color: Colors.grey.shade400, fontSize: 11)),
            ]),
          ])),

        // ── Obsah ─────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200)),
              child: Text(r.description,
                  style: TextStyle(fontSize: 13,
                      color: Colors.grey.shade700, height: 1.4),
                  maxLines: 3, overflow: TextOverflow.ellipsis)),
            const SizedBox(height: 10),

            if (r.address != null)
              _row(Icons.location_on_outlined, r.address!),
            if (r.budget != null)
              _row(Icons.euro_outlined,
                  'openRequests_budget'.tr(namedArgs: {
                    'amount': r.budget!.toStringAsFixed(0),
                  })),
            _row(Icons.schedule_outlined, _timeframeLabel(r.timeframe)),

            if (r.photoUrls.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 76,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: r.photoUrls.length,
                  itemBuilder: (ctx, i) => Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 76, height: 76,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      image: DecorationImage(
                          image: NetworkImage(r.photoUrls[i]),
                          fit: BoxFit.cover))))),
            ],

            const SizedBox(height: 14),

            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Záujemci badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: interestCount > 0
                      ? Colors.orange.withOpacity(0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: interestCount > 0
                        ? Colors.orange.withOpacity(0.3)
                        : Colors.grey.shade200)),
                child: Row(children: [
                  Icon(Icons.people_outline,
                      size: 14,
                      color: interestCount > 0
                          ? Colors.orange : Colors.grey.shade400),
                  const SizedBox(width: 6),
                  Flexible(child: Text(
                    interestCount > 0
                        ? 'openRequests_interested_count'.tr(
                            namedArgs: {'count': interestCount.toString()})
                        : 'waitingForCraftsmen'.tr(),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: interestCount > 0
                            ? Colors.orange.shade700
                            : Colors.grey.shade500))),
                ])),
              const SizedBox(height: 8),
              // Tlačidlo záujmu
              alreadyInterested
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200)),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.check_circle_rounded,
                            size: 15, color: Colors.green.shade700),
                        const SizedBox(width: 6),
                        Text('openRequests_already_interested'.tr(),
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600)),
                      ]))
                  : GestureDetector(
                      onTap: () => _expressInterest(r),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_kDeep, _kPrimary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(
                            color: _kPrimary.withOpacity(0.3),
                            blurRadius: 6, offset: const Offset(0, 3))]),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.pan_tool_outlined,
                              size: 14, color: Colors.white),
                          const SizedBox(width: 8),
                          Text('openRequests_interest_confirm'.tr(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        ]))),
            ]),
            const SizedBox(height: 16),
          ])),
      ]));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _row(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Icon(icon, size: 14, color: Colors.grey.shade400),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: TextStyle(
          fontSize: 13, color: Colors.grey.shade600))),
    ]));

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'minutesAgo'.tr(namedArgs: {'min': diff.inMinutes.toString()});
    if (diff.inHours < 24)   return 'hoursAgo'.tr(namedArgs: {'hrs': diff.inHours.toString()});
    return 'daysAgo'.tr(namedArgs: {'days': diff.inDays.toString()});
  }

  String _timeframeLabel(String tf) {
    const map = {
      'asap':       'timeframe_asap',
      '1_3_days':   'timeframe_1_3_days',
      '1_2_weeks':  'timeframe_1_2_weeks',
      '1_3_months': 'timeframe_1_3_months',
      'no_rush':    'timeframe_no_rush',
    };
    final key = map[tf];
    return key != null ? key.tr() : tf;
  }
}