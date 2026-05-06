// lib/screens/craftsman/craftsman_requests_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import '../../models/service_request.dart';
import '../../services/service_request_service.dart';

const _kPrimary = Color(0xFF2563EB);
const _kDeep    = Color(0xFF1E40AF);
const _kAccent  = Color(0xFF60A5FA);
const _kBg      = Color(0xFFF0F4FF);

class CraftsmanRequestsScreen extends StatefulWidget {
  const CraftsmanRequestsScreen({super.key});
  @override
  State<CraftsmanRequestsScreen> createState() =>
      _CraftsmanRequestsScreenState();
}

class _CraftsmanRequestsScreenState extends State<CraftsmanRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  Future<void> _respond(
      ServiceRequest request, ServiceRequestStatus status) async {
    final replyController = TextEditingController();
    final isAccept = status == ServiceRequestStatus.accepted;

    final confirm = await showModalBottomSheet<bool>(
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
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 20),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isAccept ? Colors.green : Colors.red)
                    .withOpacity(0.08),
                shape: BoxShape.circle),
              child: Icon(
                isAccept
                    ? Icons.check_circle_outline
                    : Icons.cancel_outlined,
                color: isAccept ? Colors.green : Colors.red,
                size: 32)),
            const SizedBox(height: 12),
            Text(
              isAccept
                  ? 'acceptRequest'.tr()
                  : 'declineRequest'.tr(),
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              isAccept
                  ? 'acceptRequestDesc'.tr()
                  : 'declineRequestDesc'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade500, height: 1.5)),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.1),
                    shape: BoxShape.circle),
                  child: Center(child: Text(
                    request.customerName.isNotEmpty
                        ? request.customerName[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: _kPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)))),
                const SizedBox(width: 12),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(request.customerName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('${request.profession.tr()} — ${request.category}',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12)),
                ])),
              ])),
            const SizedBox(height: 16),

            TextField(
              controller: replyController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: isAccept
                    ? 'replyHintAccept'.tr()
                    : 'replyHintDecline'.tr(),
                filled: true,
                fillColor: Colors.grey.shade50,
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
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black54)))))),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(ctx, true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isAccept
                          ? [Colors.green.shade600, Colors.green.shade500]
                          : [Colors.red.shade600, Colors.red.shade500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                      color: (isAccept ? Colors.green : Colors.red)
                          .withOpacity(0.3),
                      blurRadius: 8, offset: const Offset(0, 3))]),
                  child: Center(child: Text(
                    isAccept ? 'requestAccept'.tr() : 'requestDecline'.tr(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)))))),
            ]),
          ]))));

    if (confirm == true && mounted) {
      await ServiceRequestService.updateStatus(
        request.id, status,
        reply: replyController.text.trim().isEmpty
            ? null : replyController.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isAccept
            ? 'requestAcceptedSnack'.tr()
            : 'requestDeclinedSnack'.tr()),
        backgroundColor: isAccept ? Colors.green : Colors.orange));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const SizedBox();

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
                        Text('requestsTitle'.tr(),
                          style: const TextStyle(
                            color: Colors.white, fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5)),
                        const SizedBox(height: 2),
                        Text('requestsSubtitle'.tr(),
                          style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                      ]),
                  ),
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
                Tab(text: 'requestsPending'.tr()),
                Tab(text: 'requestsHandled'.tr()),
              ]),
          ),
        ],
        body: StreamBuilder<List<ServiceRequest>>(
          stream: ServiceRequestService.watchCraftsmanRequests(user!.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: _kPrimary));
            }
            final all = snapshot.data ?? [];
            final pending = all
                .where((r) => r.status == ServiceRequestStatus.pending)
                .toList();
            final handled = all
                .where((r) => r.status != ServiceRequestStatus.pending)
                .toList();
            return TabBarView(
              controller: _tabController,
              children: [
                _buildList(pending, showActions: true),
                _buildList(handled, showActions: false),
              ]);
          }),
      ),
    );
  }

  Widget _buildList(List<ServiceRequest> requests,
      {required bool showActions}) {
    if (requests.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _kPrimary.withOpacity(0.07),
            shape: BoxShape.circle),
          child: Icon(
            showActions
                ? Icons.inbox_outlined : Icons.check_circle_outline,
            size: 48, color: _kPrimary.withOpacity(0.4))),
        const SizedBox(height: 16),
        Text(
          showActions
              ? 'noPendingRequests'.tr()
              : 'noHandledRequests'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold,
              fontSize: 16, color: Color(0xFF1E293B))),
        const SizedBox(height: 6),
        Text(
          showActions
              ? 'noPendingRequestsDesc'.tr()
              : 'noHandledRequestsDesc'.tr(),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13,
              color: Colors.grey.shade500, height: 1.5)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
      itemCount: requests.length,
      itemBuilder: (ctx, i) =>
          _buildCard(requests[i], showActions: showActions));
  }

  Widget _buildCard(ServiceRequest r, {required bool showActions}) {
    final statusCfg = _statusConfig(r.status);
    final dateStr = DateFormat('d. MMM yyyy').format(r.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: statusCfg.color.withOpacity(0.15), width: 1),
        boxShadow: [BoxShadow(
          color: statusCfg.color.withOpacity(0.06),
          blurRadius: 16, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            color: statusCfg.color.withOpacity(0.05),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20))),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    statusCfg.color.withOpacity(0.2),
                    statusCfg.color.withOpacity(0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
                shape: BoxShape.circle),
              child: Center(child: Text(
                r.customerName.isNotEmpty
                    ? r.customerName[0].toUpperCase() : '?',
                style: TextStyle(
                    color: statusCfg.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)))),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.customerName, style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15,
                  color: Color(0xFF1E293B))),
              const SizedBox(height: 2),
              Row(children: [
                Icon(Icons.calendar_today_outlined,
                    size: 11, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(dateStr, style: TextStyle(
                    color: Colors.grey.shade500, fontSize: 12)),
              ]),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusCfg.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: statusCfg.color.withOpacity(0.3))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(statusCfg.icon, size: 11, color: statusCfg.color),
                const SizedBox(width: 4),
                Text(statusCfg.label, style: TextStyle(
                    color: statusCfg.color, fontSize: 11,
                    fontWeight: FontWeight.bold)),
              ])),
          ])),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [

            _infoChip(Icons.handyman_rounded,
                '${r.profession.tr()} — ${r.category}',
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
                  style: TextStyle(fontSize: 13,
                      color: Colors.grey.shade700, height: 1.4),
                  maxLines: 3, overflow: TextOverflow.ellipsis)),
            const SizedBox(height: 8),

            if (r.address != null)
              _row(Icons.location_on_outlined, r.address!),
            if (r.budget != null)
              _row(Icons.euro_outlined,
                  'budget'.tr(namedArgs: {
                    'amount': r.budget!.toStringAsFixed(0),
                  })),
            _row(Icons.schedule_outlined, _timeframeLabel(r.timeframe)),

            if (r.photoUrls.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: r.photoUrls.length,
                  itemBuilder: (ctx, i) => Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      image: DecorationImage(
                          image: NetworkImage(r.photoUrls[i]),
                          fit: BoxFit.cover))))),
            ],

            if (r.craftsmanReply != null &&
                r.craftsmanReply!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _kPrimary.withOpacity(0.15))),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Icon(Icons.reply_rounded,
                      size: 14, color: _kPrimary.withOpacity(0.6)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(r.craftsmanReply!,
                      style: TextStyle(fontSize: 13,
                          color: Colors.grey.shade700,
                          fontStyle: FontStyle.italic))),
                ])),
            ],

            const SizedBox(height: 12),
            if (showActions)
              _buildActions(r)
            else
              _buildHandledInfo(r),
            const SizedBox(height: 16),
          ])),
      ]));
  }

  Widget _buildActions(ServiceRequest r) => Column(children: [
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.2))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.12),
            borderRadius: BorderRadius.circular(7)),
          child: const Icon(Icons.info_outline,
              size: 14, color: Colors.orange)),
        const SizedBox(width: 8),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('customerWaiting'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold,
                  fontSize: 12, color: Colors.orange)),
          const SizedBox(height: 3),
          Text('customerWaitingDesc'.tr(),
              style: TextStyle(fontSize: 11,
                  color: Colors.grey.shade600, height: 1.4)),
        ])),
      ])),
    const SizedBox(height: 10),
    Row(children: [
      Expanded(child: GestureDetector(
        onTap: () => _respond(r, ServiceRequestStatus.declined),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red, width: 1.5)),
          child: Center(child: Text('requestDecline'.tr(),
              style: const TextStyle(color: Colors.red,
                  fontWeight: FontWeight.bold, fontSize: 14)))))),
      const SizedBox(width: 10),
      Expanded(child: GestureDetector(
        onTap: () => _respond(r, ServiceRequestStatus.accepted),
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
              blurRadius: 8, offset: const Offset(0, 3))]),
          child: Center(child: Text('requestAccept'.tr(),
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 14)))))),
    ]),
  ]);

  Widget _buildHandledInfo(ServiceRequest r) {
    final isAccepted = r.status == ServiceRequestStatus.accepted;
    final color = isAccepted ? Colors.green : Colors.red;
    final icon = isAccepted
        ? Icons.check_circle_outline : Icons.cancel_outlined;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(7)),
          child: Icon(icon, size: 14, color: color)),
        const SizedBox(width: 8),
        Expanded(child: Text(
            isAccepted
                ? 'requestAcceptedInfo'.tr()
                : 'requestDeclinedInfo'.tr(),
            style: TextStyle(fontSize: 12,
                color: Colors.grey.shade600, height: 1.4))),
      ]));
  }

  Widget _infoChip(IconData icon, String text, Color bg, Color fg) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(
              fontSize: 13, color: fg, fontWeight: FontWeight.w600)),
        ]));

  Widget _row(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Icon(icon, size: 14, color: Colors.grey.shade400),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: TextStyle(
          fontSize: 13, color: Colors.grey.shade600))),
    ]));

  String _timeframeLabel(String value) {
    const map = {
      'asap':       'timeframe_asap',
      '1_3_days':   'timeframe_1_3_days',
      '1_2_weeks':  'timeframe_1_2_weeks',
      '1_3_months': 'timeframe_1_3_months',
      'no_rush':    'timeframe_no_rush',
    };
    final key = map[value];
    return key != null ? key.tr() : value;
  }

  _StatusCfg _statusConfig(ServiceRequestStatus status) {
    return switch (status) {
      ServiceRequestStatus.pending =>
        _StatusCfg(Colors.orange, Icons.schedule_rounded,
            'statusPending'.tr()),
      ServiceRequestStatus.accepted =>
        _StatusCfg(_kPrimary, Icons.check_rounded,
            'statusAccepted'.tr()),
      ServiceRequestStatus.declined =>
        _StatusCfg(Colors.red, Icons.close_rounded,
            'statusDeclined'.tr()),
      ServiceRequestStatus.expired =>
        _StatusCfg(Colors.grey, Icons.timer_off_outlined,
            'statusExpired'.tr()),
      _ => _StatusCfg(Colors.grey, Icons.help_outline, '?'),
    };
  }
}

class _StatusCfg {
  final Color color;
  final IconData icon;
  final String label;
  const _StatusCfg(this.color, this.icon, this.label);
}