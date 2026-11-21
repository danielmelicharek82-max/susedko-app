// lib/screens/craftsman/open_requests_screen.dart
// Remeselník vidí broadcast požiadavky vo svojich profesiách a môže prejaviť záujem

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/service_request.dart';
import '../../models/quote.dart';
import '../../utils/pricing.dart';
import '../../services/service_request_service.dart';
import '../auth/billing_profile_screen.dart';
import 'craftsman_calendar_screen.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/inspection.dart';
import '../../services/inspection_service.dart';

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

    // Do dopytu sa môže zapojiť len remeselník s kompletnými fakturačnými
    // údajmi (inak by zákazku nemohol prijať ani vyfakturovať).
    if (!await BillingProfileScreen.ensureReady(context, 'craftsman')) return;
    if (!mounted) return;

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
      await _maybeAskToSetCalendar();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'error'.tr()}: $e'),
              backgroundColor: Colors.red));
    }
  }

  // ── Odhlásenie zo záujmu (dopyt bez cenovej ponuky) ────────────────────────
  Future<void> _withdrawInterest(ServiceRequest r) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('interestWithdraw_title'.tr()),
        content: Text('interestWithdraw_confirm'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('cancel'.tr())),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text('interestWithdraw_btn'.tr(),
                  style: const TextStyle(color: Colors.red))),
        ]));
    if (ok != true) return;
    try {
      await ServiceRequestService.withdrawInterest(
          requestId: r.id, craftsmanId: uid);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('interestWithdraw_snack'.tr()),
          backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${'error'.tr()}: $e'),
          backgroundColor: Colors.red));
    }
  }

  // ── Pripomenutie kalendára ─────────────────────────────────────────────────
  // Zákazku (aj z cenovej ponuky) možno vytvoriť len na voľný termín, takže
  // remeselník bez kalendára nemôže byť objednaný. Po prejavení záujmu/ponuke
  // ho na to upozorníme — ale len ak nemá žiadne voľné termíny v budúcnosti.
  Future<bool> _hasFutureSlots(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('craftsmen').doc(uid)
          .collection('availability').doc('slots').get();
      if (!doc.exists) return false;
      final now = DateTime.now();
      final today = '${now.year}-${now.month.toString().padLeft(2, '0')}'
          '-${now.day.toString().padLeft(2, '0')}';
      final re = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      for (final e in (doc.data() ?? {}).entries) {
        if (!re.hasMatch(e.key) || e.key.compareTo(today) < 0) continue;
        if (e.value is List && (e.value as List).isNotEmpty) return true;
      }
      return false;
    } catch (_) {
      return true; // pri chybe radšej nič nezobrazuj
    }
  }

  Future<void> _maybeAskToSetCalendar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !mounted) return;
    if (await _hasFutureSlots(uid) || !mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('interestCal_title'.tr()),
        content: Text('interestCal_desc'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('interestCal_later'.tr())),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text('interestCal_btn'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold))),
        ]));
    if (go == true && mounted) {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => const CraftsmanCalendarScreen()));
    }
  }

  // ── Cenová ponuka ──────────────────────────────────────────────────────────
  Future<void> _openQuoteSheet(ServiceRequest r, Quote? existing) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (!await BillingProfileScreen.ensureReady(context, 'craftsman')) return;
    if (!mounted) return;

    final craftsmanDoc = await FirebaseFirestore.instance
        .collection('craftsmen').doc(user.uid).get();
    final name = (craftsmanDoc.data()?['name'] as String?) ?? user.email ?? '';
    if (!mounted) return;

    final quote = await showModalBottomSheet<Quote>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QuoteSheet(
          request: r, existing: existing,
          craftsmanId: user.uid, craftsmanName: name),
    );
    if (quote == null || !mounted) return;

    try {
      await ServiceRequestService.submitQuote(requestId: r.id, quote: quote);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('quote_sent_snack'.tr()),
          backgroundColor: Colors.green));
      await _maybeAskToSetCalendar();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${'error'.tr()}: $e'),
          backgroundColor: Colors.red));
    }
  }

  Future<void> _withdrawQuote(ServiceRequest r) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text('quote_withdraw_confirm'.tr()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('cancel'.tr())),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('quote_withdraw'.tr())),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ServiceRequestService.withdrawQuote(
          requestId: r.id, craftsmanId: uid);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('quote_withdrawn_snack'.tr()),
          backgroundColor: Colors.orange));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${'error'.tr()}: $e'),
          backgroundColor: Colors.red));
    }
  }

  // ── Obhliadka (dopyt s quoteBasis == 'inspection') ─────────────────────────
  Future<void> _expressInspectionInterest(ServiceRequest r) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (!await BillingProfileScreen.ensureReady(context, 'craftsman')) return;
    if (!mounted) return;
    final fee = await InspectionService.fee();
    if (!mounted) return;
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('inspection_interest_title'.tr()),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('inspection_interest_body'.tr(
              namedArgs: {'fee': fee.toStringAsFixed(0)}),
              style: const TextStyle(fontSize: 13, height: 1.4)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl, maxLines: 2, maxLength: 200,
            decoration: InputDecoration(
                labelText: 'inspection_proposed_dates'.tr(),
                hintText: 'inspection_proposed_dates_hint'.tr())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('cancel'.tr())),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text('inspection_interest_send'.tr())),
        ]));
    if (ok != true || !mounted) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('craftsmen').doc(user.uid).get();
      final name = (doc.data()?['name'] as String?) ?? user.email ?? '';
      await InspectionService.expressInspectionInterest(
          requestId: r.id, craftsmanId: user.uid,
          craftsmanName: name, proposedDates: ctrl.text);
      await ServiceRequestService.expressInterest(
          requestId: r.id, craftsmanId: user.uid, craftsmanName: name,
          message: ctrl.text.trim().isEmpty ? null : ctrl.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('inspection_interest_sent'.tr()),
          backgroundColor: Colors.green));
      await _maybeAskToSetCalendar();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${'error'.tr()}: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _withdrawInspectionInterest(ServiceRequest r) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await InspectionService.withdrawInspectionInterest(r.id, uid);
      await ServiceRequestService.withdrawInterest(
          requestId: r.id, craftsmanId: uid);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${'error'.tr()}: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _scheduleInspection(Inspection ins) async {
    final now = DateTime.now();
    final d = await showDatePicker(
        context: context, initialDate: now.add(const Duration(days: 1)),
        firstDate: now, lastDate: now.add(const Duration(days: 60)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(
        context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
    if (t == null) return;
    try {
      await InspectionService.schedule(
          ins.id, DateTime(d.year, d.month, d.day, t.hour, t.minute));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${'error'.tr()}: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _callInspection(Future<dynamic> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${'error'.tr()}: $e'), backgroundColor: Colors.red));
    }
  }

  Widget _insBox(Color c, IconData icon, String text, List<Widget> actions) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: c.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.withOpacity(0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 16, color: c),
            const SizedBox(width: 8),
            Expanded(child: Text(text,
                style: const TextStyle(fontSize: 12.5, height: 1.4))),
          ]),
          if (actions.isNotEmpty) ...[const SizedBox(height: 8), ...actions],
        ]));

  Widget _buildInspectionAction(ServiceRequest r, String? customerReply) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    final fmt = DateFormat('d.M.y HH:mm');
    return StreamBuilder<InspectionOffer?>(
      stream: InspectionService.watchMyOffer(r.id, uid),
      builder: (ctx, offerSnap) => StreamBuilder<Inspection?>(
        stream: InspectionService.watch(InspectionService.idOf(r.id, uid)),
        builder: (ctx2, insSnap) {
          final offer = offerSnap.data;
          final ins = insSnap.data;
          final active = ins != null && ins.status != 'awaiting_payment' &&
              ins.status != 'refunded';

          if (!active) {
            if (offer == null) {
              return GestureDetector(
                onTap: () => _expressInspectionInterest(r),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_kDeep, _kPrimary]),
                    borderRadius: BorderRadius.circular(12)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.home_repair_service_outlined,
                        size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Flexible(child: Text('inspection_interest_btn'.tr(),
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold, fontSize: 13))),
                  ])));
            }
            return _insBox(Colors.green, Icons.check_circle_outline,
                ins?.status == 'refunded'
                    ? 'inspection_craftsman_refunded'.tr()
                    : 'inspection_interest_waiting'.tr(),
                [OutlinedButton(
                    onPressed: () => _withdrawInspectionInterest(r),
                    child: Text('inspection_interest_withdraw'.tr()))]);
          }

          final i = ins!;
          switch (i.status) {
            case 'paid':
              return _insBox(_kPrimary, Icons.event_available_outlined,
                  i.visitAt == null
                      ? 'inspection_craftsman_paid'.tr()
                      : '${'inspection_visit_at'.tr()}: ${fmt.format(i.visitAt!)}',
                  [
                    OutlinedButton.icon(
                        onPressed: () => _scheduleInspection(i),
                        icon: const Icon(Icons.event, size: 16),
                        label: Text('inspection_set_date'.tr())),
                    const SizedBox(height: 6),
                    ElevatedButton.icon(
                        onPressed: () => _callInspection(
                            () => InspectionService.markDone(i.id)),
                        icon: const Icon(Icons.done_all, size: 16),
                        label: Text('inspection_mark_done'.tr())),
                    TextButton(
                        onPressed: () => _callInspection(
                            () => InspectionService.cancel(i.id)),
                        child: Text('inspection_craftsman_cancel'.tr())),
                  ]);
            case 'visited':
              return _insBox(Colors.orange, Icons.hourglass_top,
                  'inspection_craftsman_visited'.tr(), const []);
            case 'confirmed':
              if (i.lateCancelled) {
                return _insBox(Colors.grey, Icons.info_outline,
                    'inspection_craftsman_late_cancel'.tr(), const []);
              }
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _insBox(Colors.green, Icons.check_circle_outline,
                    '${'inspection_craftsman_confirmed'.tr()}${i.quoteDueAt != null ? ' (${DateFormat('d.M.y').format(i.quoteDueAt!)})' : ''}',
                    const []),
                const SizedBox(height: 8),
                StreamBuilder<Quote?>(
                  stream: ServiceRequestService.watchMyQuote(r.id, uid),
                  builder: (c3, qs) =>
                      _buildQuoteAction(r, qs.data != null, customerReply)),
              ]);
            case 'quote_accepted':
              return _insBox(Colors.green, Icons.check_circle_outline,
                  'inspection_craftsman_accepted'.tr(), const []);
          }
          return const SizedBox.shrink();
        }));
  }

  String _eur(double v) => '${v.toStringAsFixed(2)} €';

  Widget _buildQuoteAction(
      ServiceRequest r, bool sent, String? customerReply) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    // Termín uplynul a ponuka nebola odoslaná.
    if (!sent && r.quoteExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12)),
        child: Center(child: Text('quote_deadline_passed'.tr(),
            style: TextStyle(fontSize: 12.5,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600))));
    }

    if (!sent) {
      return GestureDetector(
        onTap: () => _openQuoteSheet(r, null),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kDeep, _kPrimary],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(
              color: _kPrimary.withOpacity(0.3),
              blurRadius: 6, offset: const Offset(0, 3))]),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.request_quote_outlined,
                size: 15, color: Colors.white),
            const SizedBox(width: 8),
            Text('quote_send'.tr(),
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 13)),
          ])));
    }

    return StreamBuilder<Quote?>(
      stream: ServiceRequestService.watchMyQuote(r.id, uid),
      builder: (ctx, snap) {
        final q = snap.data;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.check_circle_rounded,
                    size: 15, color: Colors.green.shade700),
                const SizedBox(width: 6),
                Text('quote_sent'.tr(),
                    style: TextStyle(fontSize: 12.5,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w700)),
              ]),
              if (q != null) ...[
                const SizedBox(height: 6),
                Text(
                  '${'quote_labor_short'.tr()} ${_eur(q.labor)}'
                  '${q.material > 0 ? ' + ${'quote_material_short'.tr()} ${_eur(q.material)}' : ''}'
                  ' = ${_eur(q.craftsmanNet)} ${'quote_without_vat'.tr()}',
                  style: TextStyle(fontSize: 12.5,
                      color: Colors.green.shade800, height: 1.4)),
              ],
            ])),
          const SizedBox(height: 8),
          Row(children: [
            if (!r.quoteExpired && q != null)
              Expanded(child: OutlinedButton.icon(
                onPressed: () => _openQuoteSheet(r, q),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: Text('quote_edit'.tr()))),
            if (!r.quoteExpired && q != null) const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(
              onPressed: () => _withdrawQuote(r),
              icon: const Icon(Icons.undo, size: 16),
              label: Text('quote_withdraw'.tr()))),
          ]),
          if (customerReply != null && customerReply.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kPrimary.withOpacity(0.2))),
              child: Text('${'customerReplyLabel'.tr()}: $customerReply',
                  style: const TextStyle(fontSize: 12.5,
                      color: _kPrimary, height: 1.4))),
          ],
        ]);
      },
    );
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
    final myInterestData = user != null
        ? r.rawData['interest_${user.uid}'] as Map<String, dynamic>?
        : null;
    final customerReply = myInterestData?['customerReply'] as String?;

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
            Expanded(child: Text(r.category.tr(),
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
            if (r.quoteRequired)
              _row(r.quoteByInspection
                      ? Icons.home_repair_service_outlined
                      : Icons.attach_file,
                  r.quoteByInspection
                      ? 'inspection_chip_visit'.tr()
                      : 'inspection_chip_docs'.tr()),
            if (!r.quoteRequired)
              _row(Icons.schedule_outlined,
                  r.estimatedScope == null
                      ? 'inspection_chip_hourly'.tr()
                      : '${'inspection_chip_hourly'.tr()} · ${'scope_${r.estimatedScope}'.tr()}'),
            if (r.documentUrls.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final d in r.documentUrls)
                    ActionChip(
                      avatar: const Icon(Icons.description_outlined, size: 16),
                      label: Text(d['name'] ?? 'document',
                          overflow: TextOverflow.ellipsis),
                      onPressed: () => launchUrl(Uri.parse(d['url'] ?? ''),
                          mode: LaunchMode.externalApplication)),
                ])),
            if (r.quoteRequired)
              _row(Icons.request_quote_outlined,
                  r.quoteDeadline == null
                      ? 'quote_required_chip'.tr()
                      : '${'quote_required_chip'.tr()} · ${'quote_deadline_until'.tr(namedArgs: {'date': formatQuoteDate(r.quoteDeadline!)})}'),

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
              r.quoteByInspection
                  ? _buildInspectionAction(r, customerReply)
                  : r.quoteRequired
                  ? _buildQuoteAction(r, alreadyInterested, customerReply)
                  : alreadyInterested
                  ? Column(children: [
                      Container(
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
                        ])),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _withdrawInterest(r),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200)),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.close_rounded, size: 15, color: Colors.red.shade400),
                            const SizedBox(width: 6),
                            Text('interestWithdraw_btn'.tr(),
                                style: TextStyle(fontSize: 12,
                                    color: Colors.red.shade400,
                                    fontWeight: FontWeight.w600)),
                          ]))),
                      if (customerReply != null && customerReply.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _kPrimary.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _kPrimary.withOpacity(0.2))),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Icon(Icons.reply_outlined,
                                size: 14, color: _kPrimary),
                            const SizedBox(width: 8),
                            Expanded(child: RichText(
                                text: TextSpan(
                                    style: TextStyle(fontSize: 12.5,
                                        color: _kPrimary, height: 1.4),
                                    children: [
                                  TextSpan(
                                      text: '${'customerReplyLabel'.tr()}: ',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  TextSpan(text: customerReply),
                                ]))),
                          ])),
                      ],
                    ])
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
      '3_6_months': 'timeframe_3_6_months',
      'over_6_months': 'timeframe_over_6_months',
      'no_rush':    'timeframe_no_rush',
    };
    final key = map[tf];
    return key != null ? key.tr() : tf;
  }
}


// ── Formulár cenovej ponuky (bottom sheet) ──────────────────────────────────
class _QuoteSheet extends StatefulWidget {
  final ServiceRequest request;
  final Quote? existing;
  final String craftsmanId;
  final String craftsmanName;
  const _QuoteSheet({
    required this.request,
    required this.existing,
    required this.craftsmanId,
    required this.craftsmanName,
  });

  @override
  State<_QuoteSheet> createState() => _QuoteSheetState();
}

class _QuoteSheetState extends State<_QuoteSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _labor;
  late final TextEditingController _material;
  late final TextEditingController _materialNote;
  late final TextEditingController _duration;
  late final TextEditingController _note;

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _labor        = TextEditingController(text: e != null ? _fmt(e.labor) : '');
    _material     = TextEditingController(
        text: e != null && e.material > 0 ? _fmt(e.material) : '');
    _materialNote = TextEditingController(text: e?.materialNote ?? '');
    _duration     = TextEditingController(text: e?.duration ?? '');
    _note         = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    _labor.dispose();
    _material.dispose();
    _materialNote.dispose();
    _duration.dispose();
    _note.dispose();
    super.dispose();
  }

  double _num(String s) =>
      double.tryParse(s.trim().replaceAll(',', '.')) ?? 0;

  String? _opt(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  String? _numValidator(String? v, {bool required = false}) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return required ? 'quote_error_labor'.tr() : null;
    final n = double.tryParse(t.replaceAll(',', '.'));
    if (n == null || n < 0 || n > 1000000) return 'quote_error_number'.tr();
    if (required && n <= 0) return 'quote_error_labor'.tr();
    return null;
  }

  Quote _current() => Quote(
        craftsmanId: widget.craftsmanId,
        craftsmanName: widget.craftsmanName,
        labor: _num(_labor.text),
        material: _num(_material.text),
        materialNote: _opt(_materialNote),
        duration: _opt(_duration),
        note: _opt(_note),
      );

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, _current());
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
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
            borderSide: const BorderSide(color: _kPrimary, width: 2)),
      );

  @override
  Widget build(BuildContext context) {
    final q = _current();
    final numKb =
        const TextInputType.numberWithOptions(decimal: true);
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
            Text('quote_sheet_title'.tr(),
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('quote_sheet_subtitle'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13,
                    color: Colors.grey.shade500, height: 1.5)),
            const SizedBox(height: 16),

            TextFormField(
              controller: _labor,
              keyboardType: numKb,
              onChanged: (_) => setState(() {}),
              validator: (v) => _numValidator(v, required: true),
              decoration: _dec('quote_labor'.tr())),
            const SizedBox(height: 12),
            TextFormField(
              controller: _material,
              keyboardType: numKb,
              onChanged: (_) => setState(() {}),
              validator: _numValidator,
              decoration: _dec('quote_material'.tr())),
            const SizedBox(height: 12),
            TextFormField(
              controller: _materialNote,
              maxLength: 200, maxLines: 2,
              decoration: _dec('quote_material_note'.tr())),
            const SizedBox(height: 4),
            TextFormField(
              controller: _duration,
              maxLength: 100,
              decoration: _dec('quote_duration'.tr())),
            const SizedBox(height: 4),
            TextFormField(
              controller: _note,
              maxLength: 300, maxLines: 3,
              decoration: _dec('quote_note'.tr())),
            const SizedBox(height: 12),

            // Súhrn: čo bude vidieť zákazník
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: _kBg, borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('quote_total_net'.tr(),
                      style: TextStyle(color: Colors.grey.shade700)),
                  Text('${q.craftsmanNet.toStringAsFixed(2)} €',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('${'quote_customer_sees'.tr()}${Pricing.vatSuffix}',
                      style: TextStyle(color: Colors.grey.shade700)),
                  Text('${q.customerGross.toStringAsFixed(2)} €',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: _kPrimary)),
                ]),
              ])),
            const SizedBox(height: 16),

            Row(children: [
              Expanded(child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('cancel'.tr()))),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: GestureDetector(
                onTap: _submit,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kDeep, _kPrimary],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text('quote_submit'.tr(),
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 15)))))),
            ]),
          ]),
        ),
      ),
    );
  }
}