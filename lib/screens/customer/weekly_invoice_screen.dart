// lib/screens/customer/weekly_invoice_screen.dart
//
// Zobrazuje súhrnnú faktúru zákazníkovi a umožňuje platbu cez Stripe.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import '../../models/weekly_invoice.dart';
import '../../services/weekly_invoice_service.dart';
import 'weekly_invoice_qr_payment_screen.dart';

const _kPrimary = Color(0xFF2563EB);
const _kDeep    = Color(0xFF1E40AF);
const _kAccent  = Color(0xFF60A5FA);
const _kBg      = Color(0xFFF0F4FF);
const _kGooglePayTestEnv = false;
const _kMerchantName = 'Susedko s.r.o.';

class WeeklyInvoiceScreen extends StatefulWidget {
  final WeeklyInvoice invoice;
  const WeeklyInvoiceScreen({super.key, required this.invoice});

  @override
  State<WeeklyInvoiceScreen> createState() => _WeeklyInvoiceScreenState();
}

class _WeeklyInvoiceScreenState extends State<WeeklyInvoiceScreen> {
  bool _paying = false;
  bool _googlePayAvailable = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkGooglePay();
  }

  Future<void> _checkGooglePay() async {
    try {
      final ok = await Stripe.instance.isGooglePaySupported(
          IsGooglePaySupportedParams(testEnv: _kGooglePayTestEnv));
      if (mounted) setState(() => _googlePayAvailable = ok);
    } catch (_) {}
  }

  Future<void> _pay({bool useGooglePay = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() { _paying = true; _error = null; });

    try {
      await user.getIdToken(true);

      final result = await FirebaseFunctions.instance
          .httpsCallable('createPaymentIntent')
          .call({
        'amount':   (widget.invoice.totalAmount * 100).round(),
        'currency': 'eur',
        'metadata': {
          'type':            'weekly_invoice_payment',
          'weeklyInvoiceId': widget.invoice.id,
          'craftsmanId':     widget.invoice.craftsmanId,
          'customerId':      user.uid,
          'orderIds':        widget.invoice.orderIds.join(','),
        },
      });

      final clientSecret    = result.data['clientSecret'] as String;
      final paymentIntentId = result.data['paymentIntentId'] as String;

      if (useGooglePay && _googlePayAvailable) {
        await Stripe.instance.initGooglePay(GooglePayInitParams(
          testEnv: _kGooglePayTestEnv,
          merchantName: _kMerchantName,
          countryCode: 'SK',
        ));
        await Stripe.instance.presentGooglePay(
            PresentGooglePayParams(clientSecret: clientSecret));
      } else {
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: clientSecret,
            merchantDisplayName: _kMerchantName,
            style: ThemeMode.system,
            googlePay: PaymentSheetGooglePay(
              merchantCountryCode: 'SK',
              currencyCode: 'eur',
              testEnv: _kGooglePayTestEnv),
          ));
        await Stripe.instance.presentPaymentSheet();
      }

      await WeeklyInvoiceService.markPaid(
          widget.invoice.id, paymentIntentId);

      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('invoice_paid_success'.tr()),
            backgroundColor: Colors.green));
      }
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = e.message ?? e.toString());
    } on StripeException catch (e) {
      if (e.error.code != FailureCode.Canceled) {
        setState(() => _error =
            e.error.localizedMessage ?? 'paymentFailed'.tr());
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;
    final craftsmanName =
        inv.craftsmanSnapshot?['name'] ?? 'Remeselník';
    final craftsmanImage =
        inv.craftsmanSnapshot?['profileImage'] as String?;
    final isOverdue = inv.isOverdue;
    final dueStr = DateFormat('d. MMMM yyyy').format(inv.dueDate);

    return Scaffold(
      backgroundColor: _kBg,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            expandedHeight: 130,
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
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 52, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        inv.period == InvoicePeriod.weekly
                            ? 'weeklyInvoice_title'.tr()
                            : 'biweeklyInvoice_title'.tr(),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 22,
                            fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(inv.periodLabel,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ])),
              )),
          ),
        ],
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 60),
          child: Column(children: [

            // ── Remeselník ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: _kPrimary.withOpacity(0.08)),
                boxShadow: [BoxShadow(
                    color: _kPrimary.withOpacity(0.06),
                    blurRadius: 14, offset: const Offset(0, 4))]),
              child: Row(children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: _kPrimary.withOpacity(0.2), width: 2)),
                  child: ClipOval(child: craftsmanImage != null
                      ? Image.network(craftsmanImage, fit: BoxFit.cover)
                      : Container(
                          color: _kPrimary.withOpacity(0.1),
                          child: const Icon(Icons.handyman,
                              size: 22, color: _kPrimary)))),
                const SizedBox(width: 12),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(craftsmanName, style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16,
                      color: Color(0xFF1E293B))),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kPrimary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        'invoice_order_count'.tr(namedArgs: {'count': '${inv.orderIds.length}'}),
                        style: const TextStyle(color: _kPrimary,
                            fontSize: 11, fontWeight: FontWeight.w600))),
                    const SizedBox(width: 8),
                    Text(inv.periodLabel,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                  ]),
                ])),
              ])),
            const SizedBox(height: 14),

            // ── Splatnosť ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isOverdue
                    ? Colors.red.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: isOverdue
                        ? Colors.red.shade200
                        : Colors.orange.shade200)),
              child: Row(children: [
                Icon(
                  isOverdue
                      ? Icons.warning_amber_rounded
                      : Icons.calendar_today_outlined,
                  color: isOverdue
                      ? Colors.red.shade700
                      : Colors.orange.shade700,
                  size: 16),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  isOverdue
                      ? 'invoice_overdue'.tr()
                      : 'invoice_due_date'.tr(namedArgs: {'date': dueStr}),
                  style: TextStyle(
                    fontSize: 13,
                    color: isOverdue
                        ? Colors.red.shade700
                        : Colors.orange.shade800,
                    fontWeight: FontWeight.w600))),
              ])),
            const SizedBox(height: 14),

            // ── Rozpis platieb ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  _kPrimary.withOpacity(0.06),
                  _kAccent.withOpacity(0.04)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: _kPrimary.withOpacity(0.15))),
              child: Column(children: [
                _priceRow(Icons.work_outline,
                    'invoice_label_orders'.tr(),
                    '${inv.orderIds.length}'),
                const SizedBox(height: 6),
                _priceRow(Icons.timelapse_outlined,
                    'invoice_label_total_hours'.tr(),
                    '${inv.totalHours.toStringAsFixed(1)} h'),
                const SizedBox(height: 6),
                _priceRow(Icons.handyman_outlined,
                    'invoice_label_craftsman_reward'.tr(),
                    '${inv.craftsmanAmount.toStringAsFixed(2)} €'),
                _priceRow(Icons.percent_outlined,
                    'invoice_label_platform_fee'.tr(),
                    '${(inv.totalAmount - inv.craftsmanAmount).toStringAsFixed(2)} €'),
                const Divider(height: 20),
                _priceRow(Icons.payments_outlined,
                    'invoice_label_total'.tr(),
                    '${inv.totalAmount.toStringAsFixed(2)} €',
                    bold: true, large: true, color: _kPrimary),
              ])),
            const SizedBox(height: 14),

            // ── Bezpečnosť ─────────────────────────────────────────────
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
                  child: Icon(Icons.security_outlined,
                      color: Colors.green.shade700, size: 16)),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  'invoice_security_banner'.tr(),
                  style: TextStyle(fontSize: 12,
                      color: Colors.green.shade800, height: 1.4))),
              ])),

            // ── Chyba ──────────────────────────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.shade200)),
                child: Row(children: [
                  Icon(Icons.error_outline,
                      color: Colors.red.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!,
                      style: TextStyle(
                          color: Colors.red.shade700, fontSize: 13))),
                ])),
            ],
            const SizedBox(height: 28),

            // ── Google Pay ─────────────────────────────────────────────
            if (_googlePayAvailable) ...[
              GestureDetector(
                onTap: _paying ? null : () => _pay(useGooglePay: true),
                child: Container(
                  width: double.infinity, height: 50,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8)),
                  child: _paying
                      ? const Center(child: SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('G', style: TextStyle(
                                color: Colors.white, fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'serif')),
                            const SizedBox(width: 2),
                            const Text('Pay', style: TextStyle(
                                color: Colors.white, fontSize: 16,
                                fontWeight: FontWeight.w500)),
                            const SizedBox(width: 8),
                            Text(
                              '${inv.totalAmount.toStringAsFixed(2)} €',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 14)),
                          ]))),
              const SizedBox(height: 12),
              Row(children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or_divider'.tr(),
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12))),
                const Expanded(child: Divider()),
              ]),
              const SizedBox(height: 12),
            ],

            // ── Platba kartou ──────────────────────────────────────────
            GestureDetector(
              onTap: _paying ? null : () => _pay(useGooglePay: false),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: _paying
                      ? LinearGradient(colors: [
                          Colors.grey.shade400,
                          Colors.grey.shade300])
                      : const LinearGradient(
                          colors: [_kDeep, _kPrimary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _paying ? [] : [BoxShadow(
                    color: _kPrimary.withOpacity(0.35),
                    blurRadius: 12, offset: const Offset(0, 5))]),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  if (_paying)
                    const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  else
                    const Icon(Icons.credit_card_outlined,
                        color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    _paying
                        ? 'loading'.tr()
                        : 'invoice_pay_btn'.tr(namedArgs: {'total': inv.totalAmount.toStringAsFixed(2)}),
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 16)),
                ]))),

            const SizedBox(height: 12),

            // ── QR platba ──────────────────────────────────────────────
            GestureDetector(
              onTap: _paying ? null : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => WeeklyInvoiceQrPaymentScreen(
                          invoice: widget.invoice))),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kPrimary.withOpacity(0.3))),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  const Icon(Icons.qr_code_rounded,
                      color: _kPrimary, size: 20),
                  const SizedBox(width: 10),
                  Text('payWithQr'.tr(),
                      style: const TextStyle(
                          color: _kPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ]))),

            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.credit_card,
                  size: 16, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text('paymentMethods_cards'.tr(),
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500)),
              const SizedBox(width: 12),
              Icon(Icons.lock_outline,
                  size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text('securePayment'.tr(),
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500)),
            ]),
          ])),
      ),
    );
  }

  Widget _priceRow(IconData icon, String label, String value,
      {bool bold = false, bool large = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Icon(icon, size: 15,
              color: color?.withOpacity(0.7) ?? Colors.grey.shade400),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(
              fontSize: 13, color: _kPrimary.withOpacity(0.8))),
          const Spacer(),
          Text(value, style: TextStyle(
              fontSize: large ? 20 : 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color ?? Colors.grey.shade700)),
        ]));
}