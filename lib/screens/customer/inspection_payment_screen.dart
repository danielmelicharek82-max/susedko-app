// lib/screens/customer/inspection_payment_screen.dart
//
// Zákazník vybral remeselníka na obhliadku → zhrnutie + platba cez Stripe
// PaymentSheet. Výber je platný až po úspešnej platbe (stav obhliadky
// nastavuje server). Nič sa neúčtuje pri zadaní dopytu.

import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/inspection_service.dart';

const _kPrimary = Color(0xFF2563EB);
const _kBg      = Color(0xFFF0F4FF);
const _kMerchantName = 'Susedko s.r.o.';
const _kGooglePayTestEnv = false;

class InspectionPaymentScreen extends StatefulWidget {
  final String requestId;
  final String craftsmanId;
  final String craftsmanName;
  final String? proposedDates;
  const InspectionPaymentScreen({
    super.key,
    required this.requestId,
    required this.craftsmanId,
    required this.craftsmanName,
    this.proposedDates,
  });

  @override
  State<InspectionPaymentScreen> createState() => _InspectionPaymentScreenState();
}

class _InspectionPaymentScreenState extends State<InspectionPaymentScreen> {
  bool _paying = false;
  String? _error;
  double _fee = InspectionService.defaultFee;

  @override
  void initState() {
    super.initState();
    InspectionService.fee().then((f) {
      if (mounted) setState(() => _fee = f);
    });
  }

  String _mapError(FirebaseFunctionsException e) {
    final m = e.message ?? '';
    if (m.contains('MAX_INSPECTIONS')) return 'inspection_err_max'.tr();
    if (m.contains('REQUEST_CLOSED')) return 'inspection_err_closed'.tr();
    if (m.contains('ALREADY_PAID')) return 'inspection_err_already'.tr();
    return m.isEmpty ? e.toString() : m;
  }

  Future<void> _pay() async {
    setState(() { _paying = true; _error = null; });
    try {
      final r = await InspectionService.createPayment(
          requestId: widget.requestId, craftsmanId: widget.craftsmanId);
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: r['clientSecret'] as String,
          merchantDisplayName: _kMerchantName,
          style: ThemeMode.system,
          googlePay: PaymentSheetGooglePay(
              merchantCountryCode: 'SK',
              currencyCode: 'eur',
              testEnv: _kGooglePayTestEnv),
          billingDetailsCollectionConfiguration:
              const BillingDetailsCollectionConfiguration(
                  name: CollectionMode.automatic,
                  email: CollectionMode.automatic),
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      // Stav nastaví server (webhook); sync ho len dorovná, ak je webhook pomalší.
      await InspectionService.syncPayment(r['inspectionId'] as String);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('inspection_paid_snack'.tr()),
          backgroundColor: Colors.green));
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = _mapError(e));
    } on StripeException catch (e) {
      if (e.error.code != FailureCode.Canceled) {
        setState(() => _error = e.error.localizedMessage ?? 'error'.tr());
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text('inspection_pay_title'.tr()),
        backgroundColor: _kPrimary, foregroundColor: Colors.white),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.home_repair_service_outlined, color: _kPrimary),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.craftsmanName,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold))),
            ]),
            if ((widget.proposedDates ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('${'inspection_proposed_dates'.tr()}: ${widget.proposedDates}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            ],
            const Divider(height: 28),
            Row(children: [
              Expanded(child: Text('inspection_fee_label'.tr(),
                  style: const TextStyle(fontSize: 15))),
              Text('${_fee.toStringAsFixed(2)} €',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: _kPrimary)),
            ]),
          ])),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final k in const [
              'inspection_rule_deduct', 'inspection_rule_refund_noshow',
              'inspection_rule_refund_noquote', 'inspection_rule_cancel',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.check_circle_outline, size: 16, color: _kPrimary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(k.tr(namedArgs: {'fee': _fee.toStringAsFixed(0)}),
                      style: const TextStyle(fontSize: 12.5, height: 1.4))),
                ])),
          ])),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 18),
        SizedBox(height: 52, child: ElevatedButton(
          onPressed: _paying ? null : _pay,
          style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: _paying
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('inspection_pay_btn'.tr(
                  namedArgs: {'fee': _fee.toStringAsFixed(0)}),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        )),
      ])),
    );
  }
}
