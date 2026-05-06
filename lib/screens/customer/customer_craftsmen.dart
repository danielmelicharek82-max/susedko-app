// lib/screens/customer/customer_craftsmen.dart
// KEY FIX: interested count + action button changed from Row to Column
// to prevent RIGHT OVERFLOW on narrow screens

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/craftsman.dart';
import '../../models/service_request.dart';
import '../../providers/geo_provider.dart';
import '../../services/service_request_service.dart';
import '../auth/craftsman_register_form.dart';
import 'craftsman_detail_screen.dart';
import 'broadcast_request_screen.dart';
import 'request_interested_screen.dart';

const _kPrimary = Color(0xFF2563EB);
const _kDeep    = Color(0xFF1E40AF);
const _kAccent  = Color(0xFF60A5FA);
const _kBg      = Color(0xFFF0F4FF);

const List<double> _radiusOptions = [0.5, 1, 2, 5, 10, 20, 50, 100, 200];

String _formatRadius(double km) {
  if (km < 1.0) return '${(km * 1000).round()} m';
  return '${km.toStringAsFixed(0)} km';
}

class CustomerCraftsmenScreen extends StatefulWidget {
  const CustomerCraftsmenScreen({super.key});
  @override
  State<CustomerCraftsmenScreen> createState() => _CustomerCraftsmenScreenState();
}

class _CustomerCraftsmenScreenState extends State<CustomerCraftsmenScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final geo = Provider.of<GeoProvider>(context, listen: false);
      if (!geo.hasLocation) geo.init();
    });
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

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
                    begin: Alignment.topLeft, end: Alignment.bottomRight)),
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
                        Text('craftsmen'.tr(),
                          style: const TextStyle(color: Colors.white,
                            fontSize: 22, fontWeight: FontWeight.bold,
                            letterSpacing: -0.5)),
                        const SizedBox(height: 2),
                        Text('findYourArtist'.tr(),
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
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: [
                Tab(icon: const Icon(Icons.search, size: 18), text: 'search'.tr()),
                Tab(icon: const Icon(Icons.campaign_outlined, size: 18),
                    text: 'myRequests'.tr()),
              ]),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [_CraftsmenTab(), _MyBroadcastsTab()]),
      ),
    );
  }
}

// ── TAB 1 ─────────────────────────────────────────────────────────────────────
class _CraftsmenTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<GeoProvider>(builder: (context, geo, _) {
      if (geo.locationDenied) {
        return Center(child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.07), shape: BoxShape.circle),
              child: Icon(Icons.location_off_outlined,
                  size: 48, color: Colors.red.withOpacity(0.5))),
            const SizedBox(height: 16),
            Text('locationDenied'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 16, color: Color(0xFF1E293B))),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: geo.init,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_kDeep, _kPrimary],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: _kPrimary.withOpacity(0.3),
                    blurRadius: 10, offset: const Offset(0, 4))]),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.my_location_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text('enableLocation'.tr(), style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ]))),
          ])));
      }

      return Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(7)),
                child: Icon(Icons.radar, size: 14, color: _kPrimary)),
              const SizedBox(width: 8),
              Text('${'radius'.tr()}: ${_formatRadius(geo.radiusKm)}',
                  style: TextStyle(fontSize: 13, color: _kPrimary,
                      fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: _radiusOptions.map((r) {
                final sel = geo.radiusKm == r;
                return GestureDetector(
                  onTap: () => geo.setRadius(r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel ? _kPrimary : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? _kPrimary : Colors.grey.shade300)),
                    child: Text(_formatRadius(r), style: TextStyle(fontSize: 12,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        color: sel ? Colors.white : Colors.grey.shade700))));
              }).toList())),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: kAllProfessionKeys.map((key) {
                final sel = geo.selectedProfessions.contains(key);
                final icon = kProfessionIcons[key] ?? Icons.handyman_outlined;
                return GestureDetector(
                  onTap: () {
                    final current = List<String>.from(geo.selectedProfessions);
                    sel ? current.remove(key) : current.add(key);
                    geo.setProfessionFilter(current);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel ? _kPrimary : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? _kPrimary : Colors.grey.shade300)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, size: 13,
                          color: sel ? Colors.white : Colors.grey.shade600),
                      const SizedBox(width: 5),
                      Text(key.tr(), style: TextStyle(fontSize: 12,
                          color: sel ? Colors.white : Colors.grey.shade700,
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                    ])));
              }).toList())),
          ])),
        Expanded(
          child: geo.isLoading
              ? const Center(child: CircularProgressIndicator(color: _kPrimary))
              : geo.nearbyCraftsmen.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _kPrimary.withOpacity(0.07), shape: BoxShape.circle),
                        child: Icon(Icons.search_off, size: 48,
                            color: _kPrimary.withOpacity(0.4))),
                      const SizedBox(height: 16),
                      Text('noCraftsmenFound'.tr(),
                          style: const TextStyle(fontWeight: FontWeight.bold,
                              fontSize: 16, color: Color(0xFF1E293B))),
                    ]))
                  : RefreshIndicator(
                      onRefresh: geo.refresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: geo.nearbyCraftsmen.length,
                        itemBuilder: (ctx, i) {
                          final item = geo.nearbyCraftsmen[i];
                          return _CraftsmanCard(
                            craftsman: item.craftsman,
                            distance: item.formattedDistance,
                            onTap: () => Navigator.push(ctx,
                                MaterialPageRoute(builder: (_) =>
                                    CraftsmanDetailScreen(craftsman: item.craftsman))));
                        }))),
      ]);
    });
  }
}

// ── TAB 2 ─────────────────────────────────────────────────────────────────────
class _MyBroadcastsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Center(child: Text('notLoggedIn'.tr()));

    return StreamBuilder<List<ServiceRequest>>(
      stream: ServiceRequestService.watchCustomerBroadcasts(uid),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _kPrimary));
        }
        final requests = snap.data ?? [];

        return Column(children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.campaign_outlined, size: 18, color: _kPrimary)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('broadcastRequest_title'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold,
                        fontSize: 15, color: Color(0xFF1E293B))),
                Text('activeRequests'.tr(namedArgs: {'count': requests.length.toString()}),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ])),
              GestureDetector(
                onTap: () => Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => const BroadcastRequestScreen())),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_kDeep, _kPrimary],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: _kPrimary.withOpacity(0.3),
                      blurRadius: 6, offset: const Offset(0, 2))]),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.add, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text('newRequest'.tr(), style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ]))),
            ])),
          Expanded(
            child: requests.isEmpty
                ? _buildEmpty(ctx)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: requests.length,
                    itemBuilder: (ctx, i) => _BroadcastCard(request: requests[i]))),
        ]);
      });
  }

  Widget _buildEmpty(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              _kPrimary.withOpacity(0.1), _kAccent.withOpacity(0.06)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            shape: BoxShape.circle),
          child: Icon(Icons.campaign_outlined, size: 52,
              color: _kPrimary.withOpacity(0.5))),
        const SizedBox(height: 20),
        Text('requestsEmpty'.tr(), textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B))),
        const SizedBox(height: 8),
        Text('broadcastRequest_info'.tr(), textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.5)),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const BroadcastRequestScreen())),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_kDeep, _kPrimary],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: _kPrimary.withOpacity(0.3),
                blurRadius: 10, offset: const Offset(0, 4))]),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.campaign_outlined, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text('broadcastRequest_submit'.tr(), style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ]))),
      ])));
}

// ── Broadcast card ────────────────────────────────────────────────────────────
class _BroadcastCard extends StatelessWidget {
  final ServiceRequest request;
  const _BroadcastCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final r               = request;
    final interestedCount = r.interestedCraftsmanIds.length;
    final isOpen          = r.status == ServiceRequestStatus.open;
    final profLabel       = r.profession.startsWith('prof_')
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
              ? _kPrimary.withOpacity(0.1) : Colors.black.withOpacity(0.05),
          blurRadius: 16, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              _kDeep.withOpacity(0.06), _kAccent.withOpacity(0.04)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kPrimary.withOpacity(0.25))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.handyman_outlined, size: 12, color: _kPrimary),
                const SizedBox(width: 5),
                Text(profLabel, style: const TextStyle(color: _kPrimary,
                    fontSize: 12, fontWeight: FontWeight.bold)),
              ])),
            const SizedBox(width: 8),
            Expanded(child: Text(r.category,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                overflow: TextOverflow.ellipsis)),
            _StatusBadge(status: r.status),
          ])),

        // Body
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200)),
              child: Text(r.description,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13,
                      color: Colors.grey.shade700, height: 1.4))),
            const SizedBox(height: 10),

            // Info chips
            Wrap(spacing: 8, runSpacing: 6, children: [
              if (r.budget != null)
                _chip(Icons.euro_outlined,
                    '${r.budget!.toStringAsFixed(0)} €', Colors.green),
              _chip(Icons.schedule_outlined,
                  _timeframeLabel(r.timeframe), Colors.blue),
              _chip(Icons.access_time_outlined,
                  _formatDate(r.createdAt), Colors.grey),
            ]),
            const SizedBox(height: 12),

            // ── FIX: Column instead of Row to prevent overflow ──────────
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

              // Interested badge — full width
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: interestedCount > 0
                      ? Colors.green.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: interestedCount > 0
                          ? Colors.green.shade300 : Colors.grey.shade300)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.people_outline, size: 14,
                      color: interestedCount > 0
                          ? Colors.green.shade700 : Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Flexible(child: Text(
                    interestedCount > 0
                        ? 'openRequests_interested_count'.tr(namedArgs: {
                            'count': interestedCount.toString()})
                        : 'waitingForCraftsmen'.tr(),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                        color: interestedCount > 0
                            ? Colors.green.shade700 : Colors.grey.shade500),
                    overflow: TextOverflow.ellipsis)),
                ])),

              // Action button — only if open & interested
              if (isOpen && interestedCount > 0) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) =>
                          RequestInterestedScreen(request: r))),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_kDeep, _kPrimary],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: _kPrimary.withOpacity(0.3),
                        blurRadius: 6, offset: const Offset(0, 2))]),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.people_alt_outlined,
                          color: Colors.white, size: 15),
                      const SizedBox(width: 6),
                      Text('viewInterested'.tr(), style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold,
                          fontSize: 13)),
                    ]))),
              ] else if (!isOpen) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.check_circle_outline,
                        size: 14, color: Colors.green.shade700),
                    const SizedBox(width: 6),
                    Text('requestAlreadyHandled'.tr(), style: TextStyle(
                        fontSize: 12, color: Colors.green.shade700,
                        fontWeight: FontWeight.w500)),
                  ])),
              ],
            ]),

            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFEFF2F7)),
            const SizedBox(height: 10),

            // Edit / Delete row
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) =>
                        BroadcastRequestScreen(existingRequest: r))),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kPrimary.withOpacity(0.2))),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.edit_outlined, size: 15, color: _kPrimary),
                    const SizedBox(width: 6),
                    Text('edit'.tr(), style: const TextStyle(
                        color: _kPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                  ])))),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => Dialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.08),
                              shape: BoxShape.circle),
                            child: Icon(Icons.delete_outline_rounded,
                                color: Colors.red.shade500, size: 30)),
                          const SizedBox(height: 16),
                          Text('delete'.tr(), style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('$profLabel — ${r.category}',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13,
                                  color: Colors.grey.shade500)),
                          const SizedBox(height: 24),
                          Row(children: [
                            Expanded(child: GestureDetector(
                              onTap: () => Navigator.pop(context, false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12)),
                                child: Center(child: Text('cancel'.tr(),
                                    style: const TextStyle(fontWeight: FontWeight.w600,
                                        color: Colors.black54)))))),
                            const SizedBox(width: 12),
                            Expanded(child: GestureDetector(
                              onTap: () => Navigator.pop(context, true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [BoxShadow(
                                    color: Colors.red.withOpacity(0.3),
                                    blurRadius: 8, offset: const Offset(0, 3))]),
                                child: Center(child: Text('delete'.tr(),
                                    style: const TextStyle(color: Colors.white,
                                        fontWeight: FontWeight.bold)))))),
                          ]),
                        ]))));
                  if (ok == true) {
                    await ServiceRequestService.deleteBroadcastRequest(r.id);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.25))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.delete_outline, size: 15, color: Colors.red),
                    const SizedBox(width: 6),
                    Text('delete'.tr(), style: const TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                  ]))),
            ]),
            const SizedBox(height: 14),
          ])),
      ]));
  }

  Widget _chip(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.2))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color.withOpacity(0.8)),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 12,
          color: color.withOpacity(0.9), fontWeight: FontWeight.w500)),
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

// ── Status badge ──────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final ServiceRequestStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final cfg = {
      ServiceRequestStatus.open:     (_kPrimary,     'requestOpen'),
      ServiceRequestStatus.pending:  (Colors.orange, 'statusPending'),
      ServiceRequestStatus.accepted: (Colors.green,  'requestAcceptedStatus'),
      ServiceRequestStatus.declined: (Colors.red,    'requestDeclinedStatus'),
      ServiceRequestStatus.expired:  (Colors.grey,   'requestExpiredStatus'),
    };
    final entry = cfg[status];
    final color = entry?.$1 ?? _kPrimary;
    final label = entry != null ? entry.$2.tr() : '';
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

// ── Craftsman card ────────────────────────────────────────────────────────────
class _CraftsmanCard extends StatelessWidget {
  final Craftsman craftsman;
  final String distance;
  final VoidCallback onTap;
  const _CraftsmanCard({required this.craftsman, required this.distance, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final profLabel = craftsman.profession.startsWith('prof_')
        ? craftsman.profession.tr() : craftsman.profession;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kPrimary.withOpacity(0.08)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 16, offset: const Offset(0, 4))]),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _kPrimary.withOpacity(0.2), width: 2)),
              child: ClipOval(child: craftsman.profileImage != null
                  ? Image.network(craftsman.profileImage!, fit: BoxFit.cover)
                  : Container(color: _kPrimary.withOpacity(0.1),
                      child: const Icon(Icons.handyman, size: 28, color: _kPrimary)))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(craftsman.name, style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15,
                    color: Color(0xFF1E293B)),
                    overflow: TextOverflow.ellipsis)),
                if (craftsman.isVerified)
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: _kPrimary.withOpacity(0.08), shape: BoxShape.circle),
                    child: const Icon(Icons.verified, size: 14, color: _kPrimary)),
              ]),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    _kPrimary.withOpacity(0.12), _kAccent.withOpacity(0.08)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kPrimary.withOpacity(0.2))),
                child: Text(profLabel, style: const TextStyle(
                    fontSize: 11, color: _kPrimary, fontWeight: FontWeight.w600))),
              if (craftsman.cityName != null) ...[
                const SizedBox(height: 5),
                Row(children: [
                  Icon(Icons.location_on, size: 12, color: Colors.grey.shade400),
                  const SizedBox(width: 3),
                  Expanded(child: Text(craftsman.fullAddress ?? craftsman.cityName!,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _kPrimary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10)),
                    child: Text('· $distance', style: TextStyle(
                        fontSize: 11, color: _kPrimary, fontWeight: FontWeight.bold))),
                ]),
              ],
              const SizedBox(height: 6),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.star_rounded, size: 13, color: Colors.amber)),
                const SizedBox(width: 4),
                Text(craftsman.rating.toStringAsFixed(1), style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(width: 3),
                Text('(${craftsman.reviewCount})', style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade400)),
                if (craftsman.hourlyRate != null) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_kDeep, _kPrimary],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      '${(craftsman.hourlyRate! * 1.1).toStringAsFixed(0)} €/h',
                      style: const TextStyle(fontSize: 12, color: Colors.white,
                          fontWeight: FontWeight.bold))),
                ],
              ]),
            ])),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.chevron_right, color: _kPrimary, size: 18)),
          ]))));
  }
}