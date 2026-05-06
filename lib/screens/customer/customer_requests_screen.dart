// lib/screens/customer/customer_requests_screen.dart

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/service_request.dart';
import '../../models/craftsman.dart';
import '../../services/service_request_service.dart';
import 'create_work_order_screen.dart';
import 'request_interested_screen.dart';

const _kPrimary = Color(0xFF2563EB);
const _kDeep    = Color(0xFF1E40AF);
const _kAccent  = Color(0xFF60A5FA);
const _kBg      = Color(0xFFF0F4FF);

class CustomerRequestsScreen extends StatefulWidget {
  const CustomerRequestsScreen({super.key});
  @override
  State<CustomerRequestsScreen> createState() =>
      _CustomerRequestsScreenState();
}

class _CustomerRequestsScreenState extends State<CustomerRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

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
                        Text('myRequests'.tr(),
                          style: const TextStyle(
                            color: Colors.white, fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5)),
                        const SizedBox(height: 2),
                        Text('requestsSubtitle'.tr(),
                          style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                      ])),
                ])),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13),
              tabs: [
                Tab(text: 'directRequests'.tr()),
                Tab(text: 'broadcastRequests'.tr()),
              ]),
          ),
        ],
        body: StreamBuilder<List<ServiceRequest>>(
          stream: ServiceRequestService.watchCustomerRequests(uid),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: _kPrimary));
            }
            final all = snap.data ?? [];
            final direct = all
                .where((r) => r.type == ServiceRequestType.direct).toList();
            final broadcast = all
                .where((r) => r.type == ServiceRequestType.broadcast).toList();

            return TabBarView(controller: _tabController, children: [
              _buildDirectList(direct),
              _buildBroadcastList(broadcast),
            ]);
          }),
      ),
    );
  }

  // ── DIRECT REQUESTS ────────────────────────────────────────────────────────
  Widget _buildDirectList(List<ServiceRequest> requests) {
    if (requests.isEmpty) return _empty('noDirectRequests'.tr());
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: requests.length,
      itemBuilder: (ctx, i) => _buildDirectCard(requests[i]));
  }

  Widget _buildDirectCard(ServiceRequest r) {
    final dateStr = DateFormat('d. MMM yyyy').format(r.createdAt);
    final profLabel = r.profession.startsWith('prof_')
        ? r.profession.tr() : r.profession;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kPrimary.withOpacity(0.08)),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 16, offset: const Offset(0, 4))]),
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
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.1), shape: BoxShape.circle,
                border: Border.all(color: _kPrimary.withOpacity(0.2))),
              child: const Icon(Icons.handyman, size: 18, color: _kPrimary)),
            const SizedBox(width: 10),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.craftsmanName ?? 'craftsman'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 14, color: Color(0xFF1E293B))),
              Row(children: [
                Icon(Icons.calendar_today_outlined,
                    size: 11, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(dateStr, style: TextStyle(
                    color: Colors.grey.shade500, fontSize: 12)),
              ]),
            ])),
            _statusBadge(r.status),
          ])),

        // Body
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            _infoChip(Icons.handyman_outlined,
                '$profLabel — ${r.category}',
                _kPrimary.withOpacity(0.08), _kPrimary),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200)),
              child: Text(r.description,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13,
                      color: Colors.grey.shade700, height: 1.4))),
            if (r.address != null) ...[
              const SizedBox(height: 6),
              _row(Icons.location_on_outlined, r.address!),
            ],

            // Craftsman reply
            if (r.craftsmanReply != null &&
                r.craftsmanReply!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kPrimary.withOpacity(0.15))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Icon(Icons.reply_rounded,
                      size: 14, color: _kPrimary.withOpacity(0.6)),
                  const SizedBox(width: 8),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('requestReply'.tr(),
                        style: TextStyle(fontSize: 11,
                            color: _kPrimary.withOpacity(0.7),
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(r.craftsmanReply!,
                        style: TextStyle(fontSize: 13,
                            color: Colors.grey.shade700)),
                  ])),
                ])),
            ],

            // Accepted
            if (r.status == ServiceRequestStatus.accepted) ...[
              const SizedBox(height: 10),
              _alertBox(color: Colors.green,
                  icon: Icons.check_circle_outline,
                  text: 'craftsmanAccepted'.tr()),
              const SizedBox(height: 10),
              _gradientBtn(
                label: 'createOrder'.tr(),
                icon: Icons.work_outline,
                onTap: () => _openWorkOrder(r)),
            ],

            // Declined
            if (r.status == ServiceRequestStatus.declined) ...[
              const SizedBox(height: 10),
              _alertBox(color: Colors.red,
                  icon: Icons.cancel_outlined,
                  text: 'requestDeclinedInfo'.tr()),
            ],

            const SizedBox(height: 16),
          ])),
      ]));
  }

  // ── BROADCAST REQUESTS ─────────────────────────────────────────────────────
  Widget _buildBroadcastList(List<ServiceRequest> requests) {
    if (requests.isEmpty) return _empty('noBroadcastRequests'.tr());
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: requests.length,
      itemBuilder: (ctx, i) => _buildBroadcastCard(requests[i]));
  }

  Widget _buildBroadcastCard(ServiceRequest r) {
    final dateStr = DateFormat('d. MMM yyyy').format(r.createdAt);
    final interestedCount = r.interestedCraftsmanIds.length;
    final isOpen     = r.status == ServiceRequestStatus.open;
    final isPending  = r.status == ServiceRequestStatus.pending;
    final isAccepted = r.status == ServiceRequestStatus.accepted;
    final profLabel  = r.profession.startsWith('prof_')
        ? r.profession.tr() : r.profession;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isOpen && interestedCount > 0
            ? Border.all(color: _kPrimary, width: 1.5)
            : Border.all(color: _kPrimary.withOpacity(0.08)),
        boxShadow: [BoxShadow(
          color: isOpen && interestedCount > 0
              ? _kPrimary.withOpacity(0.1)
              : Colors.black.withOpacity(0.05),
          blurRadius: 16, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header ✅ FIX: Expanded na kategórii, overflow ellipsis ──────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              _kDeep.withOpacity(0.06), _kAccent.withOpacity(0.04)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20))),
          child: Row(children: [
            // Profesia chip — fixná šírka
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kPrimary.withOpacity(0.25))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.handyman_outlined,
                    size: 12, color: _kPrimary),
                const SizedBox(width: 5),
                Text(profLabel, style: const TextStyle(
                    color: _kPrimary, fontSize: 12,
                    fontWeight: FontWeight.bold)),
              ])),
            const SizedBox(width: 8),
            // Kategória — Expanded aby nepretiekla
            Expanded(child: Text(r.category,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12))),
            const SizedBox(width: 8),
            // Status badge — fixný
            _statusBadge(r.status),
          ])),

        // Body
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [

            Row(children: [
              Icon(Icons.calendar_today_outlined,
                  size: 12, color: Colors.grey.shade400),
              const SizedBox(width: 5),
              Text(dateStr, style: TextStyle(
                  color: Colors.grey.shade500, fontSize: 12)),
            ]),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200)),
              child: Text(r.description,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13,
                      color: Colors.grey.shade700, height: 1.4))),
            if (r.address != null) ...[
              const SizedBox(height: 6),
              _row(Icons.location_on_outlined, r.address!),
            ],

            // Open — interested count
            if (isOpen) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: interestedCount > 0
                      ? _kPrimary.withOpacity(0.06)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: interestedCount > 0
                          ? _kPrimary.withOpacity(0.2)
                          : Colors.grey.shade200)),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: interestedCount > 0
                          ? _kPrimary.withOpacity(0.1)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.people_outline,
                        size: 15,
                        color: interestedCount > 0
                            ? _kPrimary : Colors.grey.shade400)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    interestedCount > 0
                        ? 'interestedCount'.tr(namedArgs: {
                            'count': interestedCount.toString(),
                          })
                        : 'waitingForInterested'.tr(),
                    style: TextStyle(fontSize: 13,
                        color: interestedCount > 0
                            ? _kPrimary : Colors.grey.shade500,
                        fontWeight: interestedCount > 0
                            ? FontWeight.w600 : FontWeight.normal))),
                ])),
              if (interestedCount > 0) ...[
                const SizedBox(height: 10),
                _gradientBtn(
                  label: 'showInterested'.tr(namedArgs: {
                    'count': interestedCount.toString(),
                  }),
                  icon: Icons.people_alt_outlined,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) =>
                          RequestInterestedScreen(request: r)))),
              ],
            ],

            // Pending
            if (isPending && r.craftsmanName != null) ...[
              const SizedBox(height: 10),
              _alertBox(color: Colors.orange,
                  icon: Icons.hourglass_empty_outlined,
                  text: 'waitingForCraftsman'.tr(namedArgs: {
                    'name': r.craftsmanName!,
                  })),
            ],

            // Accepted
            if (isAccepted) ...[
              const SizedBox(height: 10),
              _alertBox(color: Colors.green,
                  icon: Icons.check_circle_outline,
                  text: 'craftsmanAcceptedBroadcast'.tr(namedArgs: {
                    'name': r.craftsmanName ?? 'craftsman'.tr(),
                  })),
              const SizedBox(height: 10),
              _gradientBtn(
                label: 'createOrder'.tr(),
                icon: Icons.work_outline,
                onTap: () => _openWorkOrder(r)),
            ],

            // Declined
            if (r.status == ServiceRequestStatus.declined) ...[
              const SizedBox(height: 10),
              _alertBox(color: Colors.red,
                  icon: Icons.cancel_outlined,
                  text: 'requestDeclinedInfo'.tr()),
            ],

            const SizedBox(height: 16),
          ])),
      ]));
  }

  // ── Open work order ────────────────────────────────────────────────────────
  Future<void> _openWorkOrder(ServiceRequest r) async {
    if (r.craftsmanId == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('craftsmen').doc(r.craftsmanId).get();
      if (!doc.exists || !mounted) return;
      final craftsman = Craftsman.fromFirestore(doc);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => CreateWorkOrderScreen(
              craftsman: craftsman,
              initialProfession: r.profession)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'error'.tr()}: $e'),
              backgroundColor: Colors.red));
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _empty(String text) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _kPrimary.withOpacity(0.07), shape: BoxShape.circle),
        child: Icon(Icons.inbox_outlined, size: 48,
            color: _kPrimary.withOpacity(0.4))),
      const SizedBox(height: 16),
      Text(text, style: const TextStyle(fontWeight: FontWeight.bold,
          fontSize: 16, color: Color(0xFF1E293B))),
    ]));

  Widget _gradientBtn({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: color != null
                  ? [color, color.withOpacity(0.8)]
                  : [_kDeep, _kPrimary],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(
              color: (color ?? _kPrimary).withOpacity(0.3),
              blurRadius: 8, offset: const Offset(0, 3))]),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold, fontSize: 14)),
          ])));

  Widget _alertBox({
    required Color color,
    required IconData icon,
    required String text,
  }) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25))),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 14, color: color)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(
              fontSize: 13, color: Colors.grey.shade700, height: 1.4))),
        ]));

  Widget _infoChip(IconData icon, String text, Color bg, Color fg) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 6),
          Flexible(child: Text(text, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13, color: fg, fontWeight: FontWeight.w600))),
        ]));

  Widget _row(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Icon(icon, size: 13, color: Colors.grey.shade400),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: TextStyle(
          fontSize: 13, color: Colors.grey.shade600))),
    ]));

  Widget _statusBadge(ServiceRequestStatus status) {
    final cfg = {
      ServiceRequestStatus.pending:  (Colors.orange, 'statusPending'),
      ServiceRequestStatus.open:     (_kPrimary,     'requestOpen'),
      ServiceRequestStatus.accepted: (Colors.green,  'requestAcceptedStatus'),
      ServiceRequestStatus.declined: (Colors.red,    'requestDeclinedStatus'),
      ServiceRequestStatus.expired:  (Colors.grey,   'requestExpiredStatus'),
    };
    final entry = cfg[status];
    final color = entry?.$1 ?? Colors.grey;
    final label = entry != null ? entry.$2.tr() : '?';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35))),
      child: Text(label, style: TextStyle(
          color: color, fontSize: 11, fontWeight: FontWeight.bold)));
  }
}