// lib/screens/craftsman/craftsman_work_orders_screen.dart

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/work_order.dart';
import '../../services/work_order_service.dart';


// ── Helper: čistá sadzba remeselníka (bez 10% poplatku platformy) ──────────
extension WorkOrderNetExtension on WorkOrder {
  double? get netHourlyRate =>
      hourlyRate != null ? hourlyRate! / 1.1 : null;
  double? get netTotal =>
      loggedHours != null && netHourlyRate != null
          ? double.parse((loggedHours! * netHourlyRate!).toStringAsFixed(2))
          : null;
}

const _kPrimary   = Color(0xFF2563EB);
const _kDeep      = Color(0xFF1E40AF);
const _kAccent    = Color(0xFF60A5FA);
const _kBg        = Color(0xFFF0F4FF);
const _kCard      = Colors.white;

const _kSupportEmail = 'info@susedko.sk';
const _kSupportPhone = '+421 902 744 743';

class CraftsmanWorkOrdersScreen extends StatefulWidget {
  const CraftsmanWorkOrdersScreen({super.key});
  @override
  State<CraftsmanWorkOrdersScreen> createState() =>
      _CraftsmanWorkOrdersScreenState();
}

class _CraftsmanWorkOrdersScreenState extends State<CraftsmanWorkOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _craftsmanId;
  double? _myHourlyRate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRate();
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  Future<void> _loadRate() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _craftsmanId = uid);
    final doc = await FirebaseFirestore.instance
        .collection('craftsmen').doc(uid).get();
    if (doc.exists) {
      setState(() {
        // BASE sadzba remeselníka (bez 10% poplatku)
        _myHourlyRate = (doc.data()?['hourlyRate'] as num?)?.toDouble();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_craftsmanId == null) {
      return const Scaffold(
          backgroundColor: _kBg,
          body: Center(child: CircularProgressIndicator(color: _kPrimary)));
    }

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
                    padding: EdgeInsets.fromLTRB(20, 52, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('workOrders_title'.tr(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5)),
                        SizedBox(height: 2),
                        Text('workOrders_subtitle'.tr(),
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13)),
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
                Tab(text: 'workOrders_tab_active'.tr()),
                Tab(text: 'workOrders_tab_hours'.tr()),
                Tab(text: 'workOrders_tab_done'.tr()),
              ]),
          ),
        ],
        body: StreamBuilder<List<WorkOrder>>(
          stream: WorkOrderService.watchCraftsman(_craftsmanId!),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: _kPrimary));
            }
            final all = snap.data ?? [];

            final active = all.where((o) => [
              WorkOrderStatus.pending,
              WorkOrderStatus.confirmed,
              WorkOrderStatus.inProgress,
            ].contains(o.status)).toList();

            final hours = all.where((o) => [
              WorkOrderStatus.hoursLogged,
              WorkOrderStatus.hoursApproved,
              WorkOrderStatus.reworkRequested,
              WorkOrderStatus.craftsmanInsisting,
              WorkOrderStatus.disputed,
              WorkOrderStatus.paymentDue,
            ].contains(o.status)).toList();

            final done = all.where((o) => [
              WorkOrderStatus.paid,
              WorkOrderStatus.completed,
              WorkOrderStatus.cancelled,
            ].contains(o.status)).toList();

            return TabBarView(controller: _tabController, children: [
              _buildList(active, tab: 'active'),
              _buildList(hours, tab: 'hours'),
              _buildList(done, tab: 'done'),
            ]);
          }),
      ),
    );
  }

  // ── Zoznam ─────────────────────────────────────────────────────────────────
  Widget _buildList(List<WorkOrder> orders, {required String tab}) {
    if (orders.isEmpty) {
      final cfg = {
        'active': (Icons.work_outline, 'workOrders_empty_active_title'.tr(),
            'workOrders_empty_active_desc'.tr()),
        'hours':  (Icons.timer_outlined, 'workOrders_empty_hours_title'.tr(),
            'workOrders_empty_hours_desc'.tr()),
        'done':   (Icons.check_circle_outline, 'workOrders_empty_done_title'.tr(),
            'workOrders_empty_done_desc'.tr()),
      };
      final (icon, title, subtitle) = cfg[tab]!;
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _kPrimary.withOpacity(0.07),
            shape: BoxShape.circle),
          child: Icon(icon, size: 48, color: _kPrimary.withOpacity(0.4))),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 16,
            color: Color(0xFF1E293B))),
        const SizedBox(height: 6),
        Text(subtitle, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500,
                height: 1.5)),
      ]));
    }
    return ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
        itemCount: orders.length,
        itemBuilder: (ctx, i) => _buildCard(orders[i]));
  }

  // ── Karta objednávky ───────────────────────────────────────────────────────
  Widget _buildCard(WorkOrder o) {
    final dateStr = DateFormat('EEE d. MMM, HH:mm').format(o.scheduledAt);
    final customer = o.customerSnapshot;
    final customerName = customer?['name'] ?? customer?['email'] ?? 'customer'.tr();
    final statusCfg = _statusConfig(o.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: o.status == WorkOrderStatus.reworkRequested
              ? Colors.orange.withOpacity(0.4)
              : statusCfg.color.withOpacity(0.12),
          width: o.status == WorkOrderStatus.reworkRequested ? 1.5 : 1),
        boxShadow: [BoxShadow(
          color: statusCfg.color.withOpacity(0.06),
          blurRadius: 16, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Farebný header ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            color: statusCfg.color.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20))),
          child: Row(children: [
            // Avatar
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
                customerName.isNotEmpty
                    ? customerName[0].toUpperCase() : '?',
                style: TextStyle(
                    color: statusCfg.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)))),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(customerName, style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15,
                  color: Color(0xFF1E293B))),
              const SizedBox(height: 2),
              Row(children: [
                Icon(Icons.access_time_rounded,
                    size: 12, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(dateStr, style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12, fontWeight: FontWeight.w500)),
              ]),
            ])),
            // Status badge
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

        // ── Obsah ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Info riadky
            if (o.profession != null)
              _infoChip(Icons.handyman_rounded, o.profession!,
                  _kPrimary.withOpacity(0.08), _kPrimary),
            if (o.description != null) ...[
              const SizedBox(height: 6),
              _row(Icons.description_outlined, o.description!, maxLines: 2),
            ],
            if (o.address != null) ...[
              const SizedBox(height: 4),
              _row(Icons.location_on_outlined, o.address!),
            ],
            const SizedBox(height: 4),
            _row(Icons.timer_outlined,
                'workOrders_estimated_hours'.tr(namedArgs: {'hours': o.estimatedHours.toString()})),

            // Hodiny box
            if (o.loggedHours != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade50, Colors.teal.shade50],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200)),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.check_rounded,
                        color: Colors.green.shade700, size: 16)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('workOrders_logged_hours_label'.tr(),
                        style: TextStyle(fontSize: 11,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600)),
                    Text(
                      'workOrders_logged_hours_detail'.tr(namedArgs: {'hours': o.loggedHours!.toStringAsFixed(1), 'rate': o.netHourlyRate?.toStringAsFixed(0) ?? '?', 'total': o.netTotal?.toStringAsFixed(2) ?? '?'}),
                      style: TextStyle(fontSize: 13,
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold)),
                  ])),
                ])),
            ],

            // Akcie
            const SizedBox(height: 14),
            _buildActions(o),
            const SizedBox(height: 16),
          ])),
      ]));
  }

  // ── Akcie ──────────────────────────────────────────────────────────────────
  Widget _buildActions(WorkOrder o) {
    switch (o.status) {

      case WorkOrderStatus.pending:
        return Column(children: [
          _infoBanner(
            icon: Icons.info_outline,
            color: Colors.orange,
            title: 'workOrders_new_order_title'.tr(),
            text: 'workOrders_new_order_desc'.tr()),
          const SizedBox(height: 12),
          Column(children: [
            _primaryBtn(
              label: 'workOrders_confirm_order'.tr(),
              icon: Icons.check_rounded,
              color: _kPrimary,
              fullWidth: true,
              onTap: () => WorkOrderService.confirm(o.id)),
            const SizedBox(height: 8),
            _outlineBtn(
              label: 'workOrders_pending_reject'.tr(),
              color: Colors.red,
              fullWidth: true,
              onTap: () => WorkOrderService.cancel(o.id)),
          ]),
        ]);

      case WorkOrderStatus.confirmed:
        return Column(children: [
          _infoBanner(
            icon: Icons.handyman_outlined,
            color: _kPrimary,
            title: 'workOrders_confirmed_title'.tr(),
            text: 'workOrders_confirmed_desc'.tr()),
          const SizedBox(height: 12),
          _primaryBtn(
            label: 'workOrders_start'.tr(),
            icon: Icons.play_arrow_rounded,
            color: Colors.purple,
            onTap: () => WorkOrderService.startWork(o.id),
            fullWidth: true),
        ]);

      case WorkOrderStatus.inProgress:
        return Column(children: [
          _infoBanner(
            icon: Icons.construction_outlined,
            color: Colors.green,
            title: 'workOrders_in_progress_title'.tr(),
            text: 'workOrders_in_progress_desc'.tr()),
          const SizedBox(height: 12),
          _primaryBtn(
            label: 'workOrders_log_hours'.tr(),
            icon: Icons.timer_outlined,
            color: Colors.green,
            onTap: () => _showLogHoursDialog(o),
            fullWidth: true),
        ]);

      case WorkOrderStatus.hoursLogged:
        return _statusBox(
          icon: Icons.hourglass_top_rounded,
          color: Colors.orange,
          title: 'workOrders_hours_sent_title'.tr(),
          text: 'workOrders_hours_sent_desc'.tr(),
          showSupport: false);

      // ── NOVÉ: hodiny schválené, čaká na výber platby zákazníkom ─────────
      case WorkOrderStatus.hoursApproved:
        return _statusBox(
          icon: Icons.check_circle_outline,
          color: Colors.teal,
          title: 'hoursApproved_title'.tr(),
          text: o.paymentMode == PaymentMode.weekly
              ? 'craftsman_hoursApproved_weekly'.tr()
              : o.paymentMode == PaymentMode.biweekly
                  ? 'craftsman_hoursApproved_biweekly'.tr()
                  : 'craftsman_hoursApproved_pending'.tr(),
          showSupport: false);

      case WorkOrderStatus.reworkRequested:
        return Column(children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange.shade300)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.refresh_rounded,
                      color: Colors.orange.shade700, size: 16)),
                const SizedBox(width: 10),
                Expanded(child: Text('workOrders_rework_title'.tr(),
                    style: TextStyle(fontWeight: FontWeight.bold,
                        fontSize: 14, color: Colors.orange.shade800))),
              ]),
              if (o.reworkNote != null && o.reworkNote!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.orange.shade100)),
                  child: Row(children: [
                    Icon(Icons.format_quote_rounded,
                        size: 16, color: Colors.orange.shade300),
                    const SizedBox(width: 8),
                    Expanded(child: Text(o.reworkNote!,
                        style: TextStyle(fontSize: 13,
                            color: Colors.grey.shade700,
                            fontStyle: FontStyle.italic))),
                  ])),
              ],
              const SizedBox(height: 12),
              Text('workOrders_rework_options'.tr(),
                  style: TextStyle(fontSize: 12,
                      color: Colors.orange.shade700, height: 1.4)),
            ])),
          const SizedBox(height: 10),
          Column(children: [
            _primaryBtn(
              label: 'workOrders_rework_btn'.tr(),
              icon: Icons.edit_rounded,
              color: _kPrimary,
              fullWidth: true,
              onTap: () => _showLogHoursDialog(o, isRework: true)),
            const SizedBox(height: 8),
            _outlineBtn(
              label: 'workOrders_insist_btn'.tr(),
              color: Colors.red,
              fullWidth: true,
              onTap: () => _showInsistDialog(o)),
          ]),
        ]);

      case WorkOrderStatus.craftsmanInsisting:
        return _statusBox(
          icon: Icons.hourglass_empty_rounded,
          color: Colors.red,
          title: 'workOrders_insisting_waiting'.tr(),
          text: 'workOrders_insisting_desc2'.tr(),
          showSupport: true);

      case WorkOrderStatus.disputed:
        return _statusBox(
          icon: Icons.admin_panel_settings_outlined,
          color: Colors.red.shade700,
          title: 'workOrders_disputed'.tr(),
          text: o.disputeNote != null
              ? 'Zákazník uviedol: „${o.disputeNote}"\n\n'
                'Administrátor vás bude kontaktovať.'
              : 'Administrátor preskúma situáciu a kontaktuje obe strany.',
          showSupport: true);

      case WorkOrderStatus.paymentDue:
        return _statusBox(
          icon: Icons.payment_outlined,
          color: _kPrimary,
          title: o.weeklyInvoiceId != null
              ? 'invoiceIncluded_title'.tr()
              : 'workOrders_payment_processing_title'.tr(),
          text: o.weeklyInvoiceId != null
              ? 'craftsman_invoice_included_text'.tr()
              : 'workOrders_payment_processing_desc'.tr(),
          showSupport: false);

      case WorkOrderStatus.paid:
      case WorkOrderStatus.completed:
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade50, Colors.teal.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.green.shade200)),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle),
              child: Icon(Icons.check_circle_rounded,
                  color: Colors.green.shade700, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('workOrders_paid_title'.tr(),
                  style: TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 14, color: Colors.green.shade800)),
              Text(
                'vaša odmena: ${o.netTotal?.toStringAsFixed(2) ?? '?'} € '
                'bolo úspešne uhradených.',
                style: TextStyle(fontSize: 12,
                    color: Colors.green.shade700)),
            ])),
          ]));

      default:
        return const SizedBox.shrink();
    }
  }

  // ── Info banner ────────────────────────────────────────────────────────────
  Widget _infoBanner({
    required IconData icon,
    required Color color,
    required String title,
    required String text,
  }) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color)),
          const SizedBox(width: 10),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold,
                fontSize: 13, color: color)),
            const SizedBox(height: 4),
            Text(text, style: TextStyle(fontSize: 12,
                color: Colors.grey.shade600, height: 1.5)),
          ])),
        ]));

  // ── Status box ─────────────────────────────────────────────────────────────
  Widget _statusBox({
    required IconData icon,
    required Color color,
    required String title,
    required String text,
    required bool showSupport,
  }) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 16, color: color)),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13, color: color))),
          ]),
          const SizedBox(height: 8),
          Text(text, style: TextStyle(fontSize: 12,
              color: Colors.grey.shade600, height: 1.5)),
          if (showSupport) ...[
            const SizedBox(height: 12),
            _supportContactBox(),
          ],
        ]));

  // ── Tlačidlá ───────────────────────────────────────────────────────────────
  Widget _primaryBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool fullWidth = false,
  }) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8, offset: const Offset(0, 3))]),
        child: Row(mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold,
              fontSize: 14)),
        ])));
    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }

  Widget _outlineBtn({
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool fullWidth = false,
  }) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 1.5)),
        child: Center(child: Text(label, style: TextStyle(
            color: color, fontWeight: FontWeight.bold, fontSize: 14)))));
    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }

  // ── Info chip ──────────────────────────────────────────────────────────────
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

  // ── Dialog: zadaj hodiny ───────────────────────────────────────────────────
  Future<void> _showLogHoursDialog(WorkOrder o,
      {bool isRework = false}) async {
    double hours = o.loggedHours ?? o.estimatedHours.toDouble();
    final noteController = TextEditingController(
        text: isRework ? o.craftsmanNote ?? '' : '');
    // NET sadzba remeselníka (bez 10% poplatku)
    final rate = o.netHourlyRate ?? _myHourlyRate ?? 0;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Container(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Handle
                Container(margin: const EdgeInsets.only(top: 8, bottom: 20),
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2))),

                Text(isRework ? 'workOrders_rework_btn'.tr() : 'workOrders_log_hours_dialog_title'.tr(),
                    style: const TextStyle(fontSize: 20,
                        fontWeight: FontWeight.bold)),

                if (isRework && o.reworkNote != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200)),
                    child: Row(children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 14, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(child: Text('„${o.reworkNote}"',
                          style: TextStyle(fontSize: 12,
                              color: Colors.orange.shade800,
                              fontStyle: FontStyle.italic))),
                    ])),
                ],
                const SizedBox(height: 24),

                // Suma display
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kDeep, _kPrimary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16)),
                  child: Column(children: [
                    Text('workOrders_hours_label'.tr(namedArgs: {'hours': hours.toStringAsFixed(1)}),
                        style: const TextStyle(color: Colors.white70,
                            fontSize: 14)),
                    Text('${(hours * rate).toStringAsFixed(2)} €',
                        style: const TextStyle(color: Colors.white,
                            fontSize: 32, fontWeight: FontWeight.bold)),
                    Text('${rate.toStringAsFixed(0)} €/hod',
                        style: const TextStyle(color: Colors.white54,
                            fontSize: 12)),
                  ])),
                const SizedBox(height: 20),

                // Stepper
                Row(children: [
                  _stepperBtn(Icons.remove_rounded,
                      hours > 0.5
                          ? () => setBS(() =>
                              hours = (hours - 0.5).clamp(0.5, 24))
                          : null),
                  Expanded(child: Slider(
                      value: hours, min: 0.5, max: 24, divisions: 47,
                      activeColor: _kPrimary,
                      onChanged: (v) => setBS(() => hours = v))),
                  _stepperBtn(Icons.add_rounded,
                      hours < 24
                          ? () => setBS(() =>
                              hours = (hours + 0.5).clamp(0.5, 24))
                          : null),
                ]),
                const SizedBox(height: 12),

                TextField(
                  controller: noteController,
                  decoration: InputDecoration(
                    hintText: isRework ? 'workOrders_rework_note_hint'.tr() : 'workOrders_hours_note_hint'.tr(),
                    filled: true, fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.grey.shade200)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: _kPrimary, width: 2)))),
                const SizedBox(height: 16),

                SizedBox(width: double.infinity, child: _primaryBtn(
                  label: isRework ? 'workOrders_hours_send_rework'.tr() : 'workOrders_confirm_hours_btn'.tr(),
                  icon: Icons.send_rounded,
                  color: _kPrimary,
                  fullWidth: true,
                  onTap: () async {
                    Navigator.pop(ctx);
                    await WorkOrderService.logHours(
                      id: o.id, hours: hours, hourlyRate: rate * 1.1,
                      note: noteController.text.trim().isEmpty
                          ? null : noteController.text.trim());
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(isRework ? 'workOrders_hours_rework_snack'.tr() : 'workOrders_hours_snack2'.tr()),
                            backgroundColor: Colors.green));
                  })),
              ]),
            ),
          ))));
  }

  // ── Dialog: trvám na hodinách ──────────────────────────────────────────────
  Future<void> _showInsistDialog(WorkOrder o) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.gavel_outlined,
                      color: Colors.red.shade600, size: 22)),
                const SizedBox(width: 12),
                Expanded(child: Text('workOrders_insist_title'.tr(),
                    style: TextStyle(fontSize: 18,
                        fontWeight: FontWeight.bold))),
              ]),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kBg,
                  borderRadius: BorderRadius.circular(12)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('workOrders_insist_hours_label'.tr(),
                      style: TextStyle(fontSize: 12,
                          color: Colors.grey.shade500)),
                  Text(
                    '${o.loggedHours?.toStringAsFixed(1)} hod'
                    ' = ${o.netTotal?.toStringAsFixed(2)} € (vaša odmena)',
                    style: const TextStyle(fontSize: 18,
                        fontWeight: FontWeight.bold, color: _kPrimary)),
                ])),
              const SizedBox(height: 12),
              Text('workOrders_insist_escalate_desc'.tr(),
                style: TextStyle(fontSize: 13,
                    color: Colors.grey.shade600, height: 1.5)),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl, maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'workOrders_insist_reason_hint'.tr(),
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
              const SizedBox(height: 12),
              _supportContactBox(),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('cancel'.tr()))),
                const SizedBox(width: 8),
                Expanded(child: _primaryBtn(
                  label: 'workOrders_pending_confirm'.tr(),
                  icon: Icons.gavel_outlined,
                  color: Colors.red,
                  onTap: () => Navigator.pop(ctx, true))),
              ]),
            ]),
          ),
        )));

    if (confirmed == true && mounted) {
      if (ctrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('workOrders_insist_reason_required'.tr()),
                backgroundColor: Colors.orange));
        return;
      }
      await WorkOrderService.insistOnHours(o.id, ctrl.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'workOrders_insist_snack'.tr()),
              backgroundColor: Colors.orange));
    }
  }

  // ── Pomocné widgety ────────────────────────────────────────────────────────
  Widget _stepperBtn(IconData icon, VoidCallback? onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: onTap != null
                ? _kPrimary.withOpacity(0.1) : Colors.grey.shade100,
            shape: BoxShape.circle),
          child: Icon(icon, size: 18,
              color: onTap != null
                  ? _kPrimary : Colors.grey.shade300)));

  Widget _supportContactBox() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('workOrders_support'.tr(),
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Row(children: [
        Icon(Icons.email_outlined, size: 14, color: _kPrimary),
        const SizedBox(width: 6),
        Text(_kSupportEmail, style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: _kPrimary)),
      ]),
      const SizedBox(height: 4),
      Row(children: [
        Icon(Icons.phone_outlined, size: 14, color: _kPrimary),
        const SizedBox(width: 6),
        Text(_kSupportPhone, style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: _kPrimary)),
      ]),
    ]));

  Widget _row(IconData icon, String text, {int maxLines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Icon(icon, size: 14, color: Colors.grey.shade400),
      const SizedBox(width: 6),
      Expanded(child: Text(text, maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600))),
    ]));

  // ── Status konfigurácia ────────────────────────────────────────────────────
  _StatusCfg _statusConfig(WorkOrderStatus status) {
    return switch (status) {
      WorkOrderStatus.pending =>
        _StatusCfg(Colors.orange, Icons.schedule_rounded, 'status_pending'.tr()),
      WorkOrderStatus.confirmed =>
        _StatusCfg(_kPrimary, Icons.check_rounded, 'calendar_confirmed_label'.tr()),
      WorkOrderStatus.inProgress =>
        _StatusCfg(Colors.purple, Icons.construction_rounded, 'status_in_progress'.tr()),
      WorkOrderStatus.hoursLogged =>
        _StatusCfg(Colors.teal, Icons.timer_rounded, 'workOrders_tab_hours'.tr()),
      WorkOrderStatus.hoursApproved =>
        _StatusCfg(Colors.teal, Icons.check_circle_rounded, 'workOrders_hours_approved_badge'.tr()),
      WorkOrderStatus.reworkRequested =>
        _StatusCfg(Colors.orange, Icons.refresh_rounded, 'status_rework'.tr()),
      WorkOrderStatus.craftsmanInsisting =>
        _StatusCfg(Colors.red, Icons.gavel_rounded, 'status_insisting'.tr()),
      WorkOrderStatus.disputed =>
        _StatusCfg(Colors.red.shade700, Icons.admin_panel_settings_outlined, 'status_disputed'.tr()),
      WorkOrderStatus.paymentDue =>
        _StatusCfg(Colors.indigo, Icons.payment_outlined, 'status_payment_due'.tr()),
      WorkOrderStatus.paid =>
        _StatusCfg(Colors.green, Icons.check_circle_rounded, 'status_paid'.tr()),
      WorkOrderStatus.completed =>
        _StatusCfg(Colors.green, Icons.verified_rounded, 'status_completed'.tr()),
      WorkOrderStatus.cancelled =>
        _StatusCfg(Colors.grey, Icons.cancel_outlined, 'status_cancelled'.tr()),
    };
  }
}

class _StatusCfg {
  final Color color;
  final IconData icon;
  final String label;
  const _StatusCfg(this.color, this.icon, this.label);
}