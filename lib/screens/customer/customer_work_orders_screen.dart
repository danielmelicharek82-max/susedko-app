// lib/screens/customer/customer_work_orders_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import '../../models/work_order.dart';
import '../../services/work_order_service.dart';
import 'work_order_payment_screen.dart';
import '../review_screen.dart';

const _kPrimary = Color(0xFF2563EB);
const _kDeep    = Color(0xFF1E40AF);
const _kAccent  = Color(0xFF60A5FA);
const _kBg      = Color(0xFFF0F4FF);

const _kSupportEmail = 'info@susedko.sk';
const _kSupportPhone = '+421 902 744 743';

class CustomerWorkOrdersScreen extends StatefulWidget {
  const CustomerWorkOrdersScreen({super.key});
  @override
  State<CustomerWorkOrdersScreen> createState() =>
      _CustomerWorkOrdersScreenState();
}

class _CustomerWorkOrdersScreenState extends State<CustomerWorkOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
            expandedHeight: 130,
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
                    child: Container(width: 160, height: 160,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle))),
                  Positioned(left: -20, bottom: -20,
                    child: Container(width: 110, height: 110,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        shape: BoxShape.circle))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 52, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('customerOrders_title'.tr(),
                          style: const TextStyle(
                            color: Colors.white, fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5)),
                        const SizedBox(height: 2),
                        Text('customerOrders_subtitle'.tr(),
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
                Tab(text: 'customerOrders_tab_active'.tr()),
                Tab(text: 'customerOrders_tab_hours'.tr()),
                Tab(text: 'customerOrders_tab_done'.tr()),
              ]),
          ),
        ],
        body: StreamBuilder<List<WorkOrder>>(
          stream: WorkOrderService.watchCustomer(uid),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: _kPrimary));
            }
            final all = snap.data ?? [];

            final active = all.where((o) => [
              WorkOrderStatus.pending, WorkOrderStatus.confirmed,
              WorkOrderStatus.inProgress, WorkOrderStatus.hoursLogged,
              WorkOrderStatus.reworkRequested,
              WorkOrderStatus.craftsmanInsisting,
              WorkOrderStatus.disputed,
            ].contains(o.status)).toList();

            final paymentDue = all
                .where((o) => o.status == WorkOrderStatus.paymentDue)
                .toList();

            final history = all.where((o) => [
              WorkOrderStatus.paid, WorkOrderStatus.completed,
              WorkOrderStatus.cancelled,
            ].contains(o.status)).toList();

            return TabBarView(controller: _tabController, children: [
              _buildList(active, tab: 'active'),
              _buildList(paymentDue, tab: 'payment', highlight: true),
              _buildList(history, tab: 'history'),
            ]);
          }),
      ),
    );
  }

  // ── List ───────────────────────────────────────────────────────────────────
  Widget _buildList(List<WorkOrder> orders,
      {required String tab, bool highlight = false}) {
    if (orders.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _kPrimary.withOpacity(0.07), shape: BoxShape.circle),
          child: Icon(Icons.inbox_outlined, size: 48,
              color: _kPrimary.withOpacity(0.4))),
        const SizedBox(height: 16),
        Text(
          tab == 'payment' ? 'customerOrders_empty_payment'.tr()
              : tab == 'active' ? 'customerOrders_empty_active'.tr()
              : 'customerOrders_empty_history'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold,
              fontSize: 16, color: Color(0xFF1E293B))),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: orders.length,
      itemBuilder: (ctx, i) =>
          _buildCard(orders[i], tab: tab, highlight: highlight));
  }

  // ── Card ───────────────────────────────────────────────────────────────────
  Widget _buildCard(WorkOrder o,
      {required String tab, bool highlight = false}) {
    final dateStr =
        DateFormat('EEE d. MMM yyyy, HH:mm').format(o.scheduledAt);
    final craftsmanName =
        o.craftsmanSnapshot?['name'] ?? 'craftsman'.tr();
    final craftsmanImage =
        o.craftsmanSnapshot?['profileImage'] as String?;
    // Safely translate profession key
    final profLabel = o.profession != null
        ? (o.profession!.startsWith('prof_')
            ? o.profession!.tr()
            : o.profession!)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: highlight
            ? Border.all(color: _kPrimary, width: 2)
            : Border.all(color: _kPrimary.withOpacity(0.08)),
        boxShadow: [BoxShadow(
          color: highlight
              ? _kPrimary.withOpacity(0.12)
              : Colors.black.withOpacity(0.05),
          blurRadius: 16, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [

        // ── Header ────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              _kDeep.withOpacity(0.06), _kAccent.withOpacity(0.04)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20))),
          child: Row(children: [
            // Avatar
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: _kPrimary.withOpacity(0.2), width: 2)),
              child: ClipOval(child: craftsmanImage != null
                  ? Image.network(craftsmanImage, fit: BoxFit.cover)
                  : Container(
                      color: _kPrimary.withOpacity(0.1),
                      child: const Icon(Icons.handyman,
                          size: 18, color: _kPrimary)))),
            const SizedBox(width: 10),
            // Name + date — Expanded to prevent overflow
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(craftsmanName,
                  style: const TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 14, color: Color(0xFF1E293B)),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(children: [
                Icon(Icons.calendar_today_outlined,
                    size: 10, color: Colors.grey.shade400),
                const SizedBox(width: 3),
                Expanded(child: Text(dateStr,
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 11),
                    overflow: TextOverflow.ellipsis)),
              ]),
            ])),
            const SizedBox(width: 8),
            // Status badge — fixed width to prevent overflow
            _statusBadge(o.status),
          ])),

        // ── Body ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Profession chip
            if (profLabel != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kPrimary.withOpacity(0.2))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.handyman_outlined,
                      size: 12, color: _kPrimary),
                  const SizedBox(width: 5),
                  Text(profLabel, style: const TextStyle(
                      color: _kPrimary, fontSize: 12,
                      fontWeight: FontWeight.w600)),
                ])),

            // Description
            if (o.description != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200)),
                child: Text(o.description!,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12,
                        color: Colors.grey.shade700, height: 1.4))),
            ],

            // Address
            if (o.address != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.location_on_outlined,
                    size: 12, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Expanded(child: Text(o.address!,
                    style: TextStyle(fontSize: 12,
                        color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis)),
              ]),
            ],

            // ── HOURS TO CONFIRM ──────────────────────────────────────
            if (o.status == WorkOrderStatus.hoursLogged) ...[
              const SizedBox(height: 12),
              _hoursCard(o),
              const SizedBox(height: 10),
              _gradientBtn(label: 'approveHours'.tr(),
                  icon: Icons.check_circle_outline,
                  onTap: () => _confirmHours(o)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _outlineBtn(
                    label: 'requestAdjustment'.tr(),
                    icon: Icons.refresh, color: Colors.orange,
                    onTap: () => _showReworkDialog(o))),
                const SizedBox(width: 8),
                Expanded(child: _outlineBtn(
                    label: 'reject'.tr(),
                    icon: Icons.flag_outlined, color: Colors.red,
                    onTap: () => _showRejectInfoDialog(o))),
              ]),
            ],

            // ── REWORK REQUESTED ──────────────────────────────────────
            if (o.status == WorkOrderStatus.reworkRequested) ...[
              const SizedBox(height: 12),
              _hoursCard(o),
              const SizedBox(height: 8),
              _alertBox(color: Colors.orange, icon: Icons.refresh,
                  title: 'reworkRequested_title'.tr(),
                  text: o.reworkNote != null && o.reworkNote!.isNotEmpty
                      ? 'reworkRequested_comment'.tr(
                          namedArgs: {'note': o.reworkNote!})
                      : 'reworkRequested_waiting'.tr()),
            ],

            // ── CRAFTSMAN INSISTING ───────────────────────────────────
            if (o.status == WorkOrderStatus.craftsmanInsisting) ...[
              const SizedBox(height: 12),
              _hoursCard(o),
              const SizedBox(height: 8),
              _alertBox(color: Colors.red,
                  icon: Icons.warning_amber_rounded,
                  title: 'craftsmanInsisting_title'.tr(),
                  text: o.craftsmanInsistNote != null &&
                          o.craftsmanInsistNote!.isNotEmpty
                      ? '„${o.craftsmanInsistNote}"' : ''),
              const SizedBox(height: 10),
              _supportContactBox(),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _gradientBtn(
                    label: 'acceptAndPay'.tr(), icon: Icons.check,
                    color: Colors.green,
                    onTap: () => _acceptDespiteInsistence(o))),
                const SizedBox(width: 8),
                Expanded(child: _outlineBtn(
                    label: 'resolveWithAdmin'.tr(),
                    icon: Icons.admin_panel_settings_outlined,
                    color: Colors.red,
                    onTap: () => _showEscalateDialog(o))),
              ]),
            ],

            // ── PAYMENT DUE ───────────────────────────────────────────
            if (o.status == WorkOrderStatus.paymentDue) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    _kPrimary.withOpacity(0.06),
                    _kAccent.withOpacity(0.04)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: _kPrimary.withOpacity(0.15))),
                child: Column(children: [
                  _priceRow(Icons.timelapse_outlined,
                      'paymentDue_worked'.tr(),
                      '${o.loggedHours?.toStringAsFixed(1)} h'),
                  _priceRow(Icons.euro_outlined,
                      'paymentDue_rate'.tr(),
                      '${(o.loggedHours != null && o.loggedHours! > 0 && o.calculatedTotal != null ? o.calculatedTotal! / o.loggedHours! : o.hourlyRate ?? 0).toStringAsFixed(0)} €/h'),
                  const Divider(height: 16),
                  _priceRow(Icons.payments_outlined,
                      'paymentDue_total'.tr(),
                      '${o.calculatedTotal?.toStringAsFixed(2)} €',
                      bold: true, color: _kPrimary),
                ])),
              const SizedBox(height: 10),
              _gradientBtn(
                label: 'payBtn'.tr(namedArgs: {
                  'total': o.calculatedTotal?.toStringAsFixed(2) ?? '?',
                }),
                icon: Icons.payment_outlined,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) =>
                        WorkOrderPaymentScreen(order: o)))),
            ],

            // ── DISPUTED ──────────────────────────────────────────────
            if (o.status == WorkOrderStatus.disputed) ...[
              const SizedBox(height: 12),
              _alertBox(color: Colors.red,
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'disputed_title'.tr(),
                  text: 'disputed_desc'.tr()),
              const SizedBox(height: 8),
              _supportContactBox(),
            ],

            // ── PAID + REVIEW ─────────────────────────────────────────
            if (o.status == WorkOrderStatus.completed ||
                o.status == WorkOrderStatus.paid) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.shade200)),
                child: Row(children: [
                  Icon(Icons.check_circle_rounded,
                      color: Colors.green.shade700, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'paid_label'.tr(namedArgs: {
                      'total': o.calculatedTotal?.toStringAsFixed(2) ?? '?',
                    }),
                    style: TextStyle(fontSize: 13,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold)),
                ])),
              if (!o.isReviewed) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ReviewScreen(
                        craftsmanId: o.craftsmanId,
                        craftsmanName:
                            o.craftsmanSnapshot?['name'] ?? '',
                        bookingId: o.id))),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.amber.withOpacity(0.4))),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      const Icon(Icons.star_rounded,
                          color: Colors.amber, size: 16),
                      const SizedBox(width: 8),
                      Text('rateBtn'.tr(),
                          style: const TextStyle(color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ]))),
              ],
            ],

            const SizedBox(height: 14),
          ])),
      ]));
  }

  // ── Hours card ─────────────────────────────────────────────────────────────
  Widget _hoursCard(WorkOrder o) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [
        Colors.orange.withOpacity(0.08),
        Colors.orange.withOpacity(0.04)],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.orange.withOpacity(0.3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.timer,
              color: Colors.orange.shade700, size: 15)),
        const SizedBox(width: 8),
        Text('hoursLogged_title'.tr(),
            style: TextStyle(fontWeight: FontWeight.bold,
                fontSize: 13, color: Colors.orange.shade800)),
      ]),
      const SizedBox(height: 10),
      _priceRow(Icons.timelapse_outlined, 'hoursLogged_worked'.tr(),
          '${o.loggedHours?.toStringAsFixed(1)} h'),
      _priceRow(Icons.euro_outlined, 'hoursLogged_rate'.tr(),
          '${(o.loggedHours != null && o.loggedHours! > 0 && o.calculatedTotal != null ? o.calculatedTotal! / o.loggedHours! : o.hourlyRate ?? 0).toStringAsFixed(0)} €/h'),
      const Divider(height: 14),
      _priceRow(Icons.payments_outlined, 'hoursLogged_total'.tr(),
          '${o.calculatedTotal?.toStringAsFixed(2)} €', bold: true),
      if (o.craftsmanNote != null && o.craftsmanNote!.isNotEmpty) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: Colors.orange.withOpacity(0.2))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Icon(Icons.notes_outlined,
                size: 12, color: Colors.orange.shade400),
            const SizedBox(width: 6),
            Expanded(child: Text(
              'hoursLogged_note'.tr(
                  namedArgs: {'note': o.craftsmanNote!}),
              style: TextStyle(fontSize: 12,
                  color: Colors.orange.shade800,
                  fontStyle: FontStyle.italic))),
          ])),
      ],
    ]));

  // ── Support box ────────────────────────────────────────────────────────────
  Widget _supportContactBox() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _kPrimary.withOpacity(0.04),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _kPrimary.withOpacity(0.15))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: _kPrimary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(7)),
          child: const Icon(Icons.support_agent_outlined,
              size: 13, color: _kPrimary)),
        const SizedBox(width: 8),
        Text('supportContact'.tr(),
            style: TextStyle(fontSize: 12,
                fontWeight: FontWeight.bold, color: _kPrimary)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Icon(Icons.email_outlined,
            size: 12, color: Colors.grey.shade400),
        const SizedBox(width: 6),
        const Text(_kSupportEmail,
            style: TextStyle(fontSize: 12,
                fontWeight: FontWeight.w600, color: _kPrimary)),
      ]),
      const SizedBox(height: 4),
      Row(children: [
        Icon(Icons.phone_outlined,
            size: 12, color: Colors.grey.shade400),
        const SizedBox(width: 6),
        const Text(_kSupportPhone,
            style: TextStyle(fontSize: 12,
                fontWeight: FontWeight.w600, color: _kPrimary)),
      ]),
    ]));

  // ── Actions ────────────────────────────────────────────────────────────────
  Future<void> _confirmHours(WorkOrder o) async {
    await WorkOrderService.confirmHours(o.id);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('hoursConfirmed'.tr()),
        backgroundColor: Colors.green));
  }

  Future<void> _showReworkDialog(WorkOrder o) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.refresh,
                    color: Colors.orange.shade600, size: 20)),
              const SizedBox(width: 10),
              Expanded(child: Text('reworkDialog_title'.tr(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16))),
            ]),
            const SizedBox(height: 14),
            Text('reworkDialog_desc'.tr(),
                style: TextStyle(fontSize: 13,
                    color: Colors.grey.shade600, height: 1.5)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl, maxLines: 3,
              decoration: InputDecoration(
                hintText: 'reworkDialog_hint'.tr(),
                hintStyle: TextStyle(
                    color: Colors.grey.shade400, fontSize: 13),
                filled: true, fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: _kPrimary, width: 2)))),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(ctx, false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
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
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.orange.shade600,
                      Colors.orange.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text('reworkDialog_send'.tr(),
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold)))))),
            ]),
          ]))));

    if (confirmed == true && mounted) {
      if (ctrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('reworkDialog_empty'.tr()),
            backgroundColor: Colors.orange));
        return;
      }
      await WorkOrderService.requestRework(o.id, ctrl.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('reworkDialog_sent'.tr()),
          backgroundColor: Colors.orange));
    }
  }

  Future<void> _showRejectInfoDialog(WorkOrder o) async {
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.info_outline,
                    color: Colors.orange.shade600, size: 20)),
              const SizedBox(width: 10),
              Expanded(child: Text('rejectInfo_title'.tr(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16))),
            ]),
            const SizedBox(height: 14),
            Text('rejectInfo_desc'.tr(),
                style: TextStyle(fontSize: 13,
                    color: Colors.grey.shade600, height: 1.5)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(
                      'rejectInfo_understand'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w600,
                          color: Colors.black54)))))),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _showReworkDialog(o);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.orange.shade600,
                      Colors.orange.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(
                      'requestAdjustment'.tr(),
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)))))),
            ]),
          ]))));
  }

  Future<void> _acceptDespiteInsistence(WorkOrder o) async {
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
                color: Colors.green.withOpacity(0.08),
                shape: BoxShape.circle),
              child: Icon(Icons.check_circle_outline,
                  color: Colors.green.shade600, size: 30)),
            const SizedBox(height: 14),
            Text('acceptInsist_title'.tr(),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'acceptInsist_desc'.tr(namedArgs: {
                'hours': o.loggedHours?.toStringAsFixed(1) ?? '?',
                'total': o.calculatedTotal?.toStringAsFixed(2) ?? '?',
              }),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13,
                  color: Colors.grey.shade600, height: 1.5)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(ctx, false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
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
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.green.shade600, Colors.green.shade500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text('acceptAndPay'.tr(),
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold)))))),
            ]),
          ]))));

    if (confirmed == true && mounted) {
      await WorkOrderService.acceptDespiteInsistence(o.id);
    }
  }

  Future<void> _showEscalateDialog(WorkOrder o) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.admin_panel_settings_outlined,
                    color: Colors.red.shade600, size: 20)),
              const SizedBox(width: 10),
              Expanded(child: Text('escalate_title'.tr(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16))),
            ]),
            const SizedBox(height: 14),
            Text('escalate_desc'.tr(),
                style: TextStyle(fontSize: 13,
                    color: Colors.grey.shade600, height: 1.5)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl, maxLines: 2,
              decoration: InputDecoration(
                hintText: 'escalate_hint'.tr(),
                hintStyle: TextStyle(
                    color: Colors.grey.shade400, fontSize: 13),
                filled: true, fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: _kPrimary, width: 2)))),
            const SizedBox(height: 12),
            _supportContactBox(),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(ctx, false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text('cancel'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w600,
                          color: Colors.black54)))))),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(ctx, true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.red.shade700, Colors.red.shade500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text('escalate_send'.tr(),
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)))))),
            ]),
          ]))));

    if (confirmed == true && mounted) {
      await WorkOrderService.escalateToAdmin(o.id, ctrl.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('escalate_sent'.tr()),
          backgroundColor: Colors.red));
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
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
          padding: const EdgeInsets.symmetric(vertical: 12),
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
          child: Row(mainAxisAlignment: MainAxisAlignment.center,
              children: [
            Icon(icon, color: Colors.white, size: 15),
            const SizedBox(width: 7),
            Flexible(child: Text(label,
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 13),
                overflow: TextOverflow.ellipsis)),
          ])));

  Widget _outlineBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 1.5)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center,
              children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
            Flexible(child: Text(label,
                style: TextStyle(color: color,
                    fontWeight: FontWeight.bold, fontSize: 12),
                overflow: TextOverflow.ellipsis)),
          ])));

  Widget _alertBox({
    required Color color,
    required IconData icon,
    required String title,
    required String text,
  }) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 14, color: color)),
          const SizedBox(width: 8),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold,
                fontSize: 12, color: color)),
            if (text.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(text, style: TextStyle(fontSize: 12,
                  color: Colors.grey.shade600, height: 1.4)),
            ],
          ])),
        ]));

  Widget _priceRow(IconData icon, String label, String value,
      {bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(children: [
          Icon(icon, size: 13, color: Colors.grey.shade400),
          const SizedBox(width: 7),
          Expanded(child: Text(label, style: TextStyle(
              fontSize: 12, color: Colors.grey.shade600))),
          Text(value, style: TextStyle(fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color ?? Colors.grey.shade800)),
        ]));

  Widget _statusBadge(WorkOrderStatus status) {
    final cfg = {
      WorkOrderStatus.pending:            (Colors.orange,      'pending'),
      WorkOrderStatus.confirmed:          (_kPrimary,          'confirmed'),
      WorkOrderStatus.inProgress:         (Colors.purple,      'workOrders_tab_active'),
      WorkOrderStatus.hoursLogged:        (Colors.teal,        'customerOrders_tab_hours'),
      WorkOrderStatus.reworkRequested:    (Colors.orange,      'reworkRequested_title'),
      WorkOrderStatus.craftsmanInsisting: (Colors.red,         'craftsmanInsistingNote'),
      WorkOrderStatus.disputed:           (Colors.red.shade700,'disputed_title'),
      WorkOrderStatus.paymentDue:         (Colors.indigo,      'customerOrders_tab_hours'),
      WorkOrderStatus.paid:               (Colors.green,       'completed'),
      WorkOrderStatus.completed:          (Colors.green,       'completed'),
      WorkOrderStatus.cancelled:          (Colors.grey,        'cancelled'),
    };
    final entry = cfg[status];
    final color = entry?.$1 ?? Colors.grey;
    final label = entry != null ? entry.$2.tr() : '?';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3))),
      child: Text(label, style: TextStyle(
          color: color, fontSize: 10, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis));
  }
}