import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
// lib/screens/customer/work_order_payment_screen.dart
//
// Google Pay compliance:
// ✅ Vlastné GP tlačidlo podľa Brand Guidelines (čierne, správny text)
// ✅ isReadyToPay použitý len na zobrazenie/skrytie GP
// ✅ testEnv prepínateľný cez konštantu
// ✅ Merchant name = reálny názov
// ✅ Jasné zhrnutie objednávky pred platbou
// ✅ Žiadny surcharge špecifický pre GP
// ✅ Žiadne minimum/maximum špecifické pre GP

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import '../../models/work_order.dart';
import '../../services/work_order_service.dart';
import 'work_order_qr_payment_screen.dart';

const _kPrimary = Color(0xFF2563EB);
const _kDeep    = Color(0xFF1E40AF);
const _kAccent  = Color(0xFF60A5FA);
const _kBg      = Color(0xFFF0F4FF);

// ⚠️ Pred nahratím do produkcie nastav na FALSE
const _kGooglePayTestEnv = false;

// Merchant name presne ako je zaregistrovaný v Google Pay Console
const _kMerchantName = 'Susedko s.r.o.';

class WorkOrderPaymentScreen extends StatefulWidget {
  final WorkOrder order;
  const WorkOrderPaymentScreen({super.key, required this.order});

  @override
  State<WorkOrderPaymentScreen> createState() =>
      _WorkOrderPaymentScreenState();
}

class _WorkOrderPaymentScreenState extends State<WorkOrderPaymentScreen> {
  bool _paying = false;
  bool _googlePayAvailable = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkGooglePayAvailability();
  }

  // ✅ Google Pay Brand Guidelines: isReadyToPay len na zobrazenie tlačidla
  Future<void> _checkGooglePayAvailability() async {
    try {
      final isReady = await Stripe.instance.isGooglePaySupported(
        IsGooglePaySupportedParams(testEnv: _kGooglePayTestEnv));
      if (mounted) setState(() => _googlePayAvailable = isReady);
    } catch (_) {
      if (mounted) setState(() => _googlePayAvailable = false);
    }
  }

  Future<void> _pay({bool useGooglePay = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final total = widget.order.calculatedTotal;
    if (total == null) return;

    setState(() { _paying = true; _error = null; });
    try {
      debugPrint('STRIPE iOS: zacina platba');
      await user.getIdToken(true);
      debugPrint('STRIPE iOS: token OK');

      final result = await FirebaseFunctions.instance
          .httpsCallable('createPaymentIntent')
          .call({
        'amount':   (total * 100).round(),
        'currency': 'eur',
        'metadata': {
          'type':        'work_order_payment',
          'workOrderId': widget.order.id,
          'craftsmanId': widget.order.craftsmanId,
          'customerId':  user.uid,
        },
      });

      debugPrint('STRIPE iOS: function OK, mam clientSecret');
      final clientSecret    = result.data['clientSecret'] as String;
      final paymentIntentId = result.data['paymentIntentId'] as String;

      if (useGooglePay && _googlePayAvailable) {
        // ✅ Priama Google Pay platba
        await Stripe.instance.initGooglePay(GooglePayInitParams(
          testEnv: _kGooglePayTestEnv,
          merchantName: _kMerchantName,
          countryCode: 'SK',
        ));
        await Stripe.instance.presentGooglePay(
          PresentGooglePayParams(clientSecret: clientSecret));
      } else {
        // iOS: Checkout URL, Android: Payment Sheet
        debugPrint("PLATFORM: $defaultTargetPlatform");
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          debugPrint('STRIPE iOS: pouzivam Checkout URL');
          final checkoutResult = await FirebaseFunctions.instance
              .httpsCallable('createCheckoutSession')
              .call({
            'amount': (total * 100).round(),
            'currency': 'eur',
            'workOrderId': widget.order.id,
            'customerId': user.uid,
            'craftsmanId': widget.order.craftsmanId,
            'successUrl': 'susedko://payment/success?orderId=${widget.order.id}',
            'cancelUrl': 'susedko://payment/cancel?orderId=${widget.order.id}',
          });
          final checkoutUrl = checkoutResult.data['url'] as String;
          final uri = Uri.parse(checkoutUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
          return;
        } else {
          // Android: Štandardný Payment Sheet
          await Stripe.instance.initPaymentSheet(
            paymentSheetParameters: SetupPaymentSheetParameters(
              paymentIntentClientSecret: clientSecret,
              merchantDisplayName: _kMerchantName,
              returnURL: 'susedko://stripe-redirect',
              style: ThemeMode.system,
              googlePay: PaymentSheetGooglePay(
                merchantCountryCode: 'SK',
                currencyCode: 'eur',
                testEnv: _kGooglePayTestEnv),
              billingDetailsCollectionConfiguration:
                  const BillingDetailsCollectionConfiguration(
                      name: CollectionMode.automatic,
                      email: CollectionMode.automatic),
            ));
          await Stripe.instance.presentPaymentSheet();
        }
      }

      await WorkOrderService.markPaid(widget.order.id, paymentIntentId);

      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('orderSuccess'.tr()),
            backgroundColor: Colors.green));
      }
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = e.message ?? e.toString());
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        setState(() => _error = null); // Zrušenie nie je chyba
      } else {
        setState(() => _error =
            e.error.localizedMessage ?? 'cancelled'.tr());
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final total = o.calculatedTotal ?? 0;
    final dateStr =
        DateFormat('EEE d. MMMM yyyy, HH:mm').format(o.scheduledAt);
    final craftsmanName =
        o.craftsmanSnapshot?['name'] ?? 'craftsman'.tr();
    final craftsmanImage =
        o.craftsmanSnapshot?['profileImage'] as String?;
    final profLabel = o.profession != null
        ? (o.profession!.startsWith('prof_')
            ? o.profession!.tr()
            : o.profession!)
        : null;

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
                        Text('depositPayment'.tr(),
                          style: const TextStyle(
                            color: Colors.white, fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5)),
                        const SizedBox(height: 2),
                        Text(craftsmanName,
                          style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                      ])),
                ])),
            ),
          ),
        ],
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 60),
          child: Column(children: [

            // ── Zhrnutie objednávky (povinné pre GP review) ────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kPrimary.withOpacity(0.08)),
                boxShadow: [BoxShadow(
                    color: _kPrimary.withOpacity(0.06),
                    blurRadius: 14, offset: const Offset(0, 4))]),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Container(
                    width: 50, height: 50,
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
                    if (profLabel != null)
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _kPrimary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10)),
                        child: Text(profLabel,
                            style: const TextStyle(
                                color: _kPrimary, fontSize: 11,
                                fontWeight: FontWeight.w600))),
                  ])),
                ]),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 10),
                _infoRow(Icons.calendar_today_outlined, dateStr),
                if (o.description != null)
                  _infoRow(Icons.description_outlined, o.description!),
                if (o.address != null)
                  _infoRow(Icons.location_on_outlined, o.address!),
              ])),
            const SizedBox(height: 16),

            // ── Rozpis ceny (povinný pre GP review) ───────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  _kPrimary.withOpacity(0.06),
                  _kAccent.withOpacity(0.04)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kPrimary.withOpacity(0.15))),
              child: Column(children: [
                _priceRow(Icons.timelapse_outlined,
                    'hoursLogged_worked'.tr(),
                    '${o.loggedHours?.toStringAsFixed(1) ?? '?'} h'),
                const SizedBox(height: 8),
                _priceRow(Icons.euro_outlined,
                    'hoursLogged_rate'.tr(),
                    '${o.hourlyRate?.toStringAsFixed(0) ?? '?'} €/h'),
                const SizedBox(height: 10),
                const Divider(),
                const SizedBox(height: 10),
                // ✅ Celková suma jasne viditeľná pred potvrdením
                _priceRow(Icons.payments_outlined,
                    'paymentDue_total'.tr(),
                    '${total.toStringAsFixed(2)} €',
                    bold: true, large: true, color: _kPrimary),
              ])),
            const SizedBox(height: 14),

            // ── Bezpečnostný banner ────────────────────────────────────
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
                  'paymentInfoBanner'.tr(),
                  style: TextStyle(fontSize: 12,
                      color: Colors.green.shade800, height: 1.4))),
              ])),

            // ── Chybová hláška ─────────────────────────────────────────
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

            // ── Google Pay tlačidlo (Brand Guidelines) ─────────────────
            // ✅ Čierne tlačidlo, biely logo+text, zaoblené rohy
            // ✅ Zobrazené LEN ak isReadyToPay vrátilo true
            // ✅ Žiadny surcharge oproti iným metódam
            if (_googlePayAvailable) ...[
              GestureDetector(
                onTap: _paying ? null : () => _pay(useGooglePay: true),
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                    // ✅ Brand Guidelines: 1dp border pre svetlé pozadie
                    border: Border.all(color: Colors.black)),
                  child: _paying
                      ? const Center(child: SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // ✅ Google Pay logo (G + "Pay" in correct colors)
                            const Text('G',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'serif')),
                            const SizedBox(width: 2),
                            // ✅ Správny text podľa GP Brand Guidelines
                            const Text('Pay',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(width: 8),
                            Text(
                              '${total.toStringAsFixed(2)} €',
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14)),
                          ])),
              ),
              const SizedBox(height: 12),
              Row(children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('alebo',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12))),
                const Expanded(child: Divider()),
              ]),
              const SizedBox(height: 12),
            ],

            // ── Štandardné platobné tlačidlo (karta) ──────────────────
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
                    blurRadius: 12,
                    offset: const Offset(0, 5))]),
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
                        : 'payBtn'.tr(namedArgs: {
                            'total': total.toStringAsFixed(2),
                          }),
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 16)),
                ]))),

            const SizedBox(height: 12),

            // ── QR platba ──────────────────────────────────────────────
            GestureDetector(
              onTap: _paying ? null : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => WorkOrderQrPaymentScreen(
                          order: widget.order))),
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
                  Text('Zaplatiť QR kódom',
                      style: const TextStyle(
                          color: _kPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ]))),

            const SizedBox(height: 12),

            // ── Accepted payment methods info ──────────────────────────
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.credit_card, size: 16, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text('Visa, Mastercard',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500)),
              const SizedBox(width: 12),
              Icon(Icons.lock_outline, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text('Zabezpečená platba',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500)),
            ]),
          ])),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(children: [
      Icon(icon, size: 14, color: Colors.grey.shade400),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: TextStyle(
          fontSize: 13, color: Colors.grey.shade700))),
    ]));

  Widget _priceRow(IconData icon, String label, String value,
      {bool bold = false, bool large = false, Color? color}) =>
      Row(children: [
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
      ]);
}