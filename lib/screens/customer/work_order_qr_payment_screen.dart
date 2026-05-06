// lib/screens/customer/work_order_qr_payment_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/work_order.dart';
import '../../services/work_order_service.dart';

const _kPrimary = Color(0xFF2563EB);
const _kDeep    = Color(0xFF1E40AF);
const _kAccent  = Color(0xFF60A5FA);
const _kBg      = Color(0xFFF0F4FF);

class WorkOrderQrPaymentScreen extends StatefulWidget {
  final WorkOrder order;
  const WorkOrderQrPaymentScreen({super.key, required this.order});

  @override
  State<WorkOrderQrPaymentScreen> createState() =>
      _WorkOrderQrPaymentScreenState();
}

class _WorkOrderQrPaymentScreenState
    extends State<WorkOrderQrPaymentScreen> {

  bool _loading = true;
  bool _paid = false;
  String? _checkoutUrl;
  String? _paymentIntentId;
  String? _error;

  StreamSubscription? _orderSub;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _createCheckoutLink();
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _createCheckoutLink() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final total = widget.order.calculatedTotal;
    if (total == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await user.getIdToken(true);

      final result = await FirebaseFunctions.instance
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

      setState(() {
        _checkoutUrl = result.data['url'];
        _paymentIntentId = result.data['paymentIntentId'];
        _loading = false;
      });

      _listenForPayment();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _listenForPayment() {
    _orderSub = FirebaseFirestore.instance
        .collection('work_orders')
        .doc(widget.order.id)
        .snapshots()
        .listen((snap) {
      if (!snap.exists || !mounted) return;

      final status = snap.data()?['status'];
      if (status == 'paid' || status == 'completed') {
        _onPaymentSuccess();
      }
    });

    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_paid) return;

      final snap = await FirebaseFirestore.instance
          .collection('work_orders')
          .doc(widget.order.id)
          .get();

      final status = snap.data()?['status'];
      if (status == 'paid' || status == 'completed') {
        _onPaymentSuccess();
      }
    });
  }

  void _onPaymentSuccess() {
    _orderSub?.cancel();
    _pollTimer?.cancel();

    if (!mounted) return;

    setState(() => _paid = true);

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;

      Navigator.popUntil(context, (route) => route.isFirst);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('orderSuccess'.tr()),
          backgroundColor: Colors.green,
        ),
      );
    });
  }

  Future<void> _openInBrowser() async {
    if (_checkoutUrl == null) return;

    final uri = Uri.parse(_checkoutUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.order.calculatedTotal ?? 0;
    final craftsmanName =
        widget.order.craftsmanSnapshot?['name'] ?? 'craftsman'.tr();

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('QR platba',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
      ),
      body: _paid
          ? _buildSuccess()
          : _loading
              ? _buildLoading()
              : _error != null
                  ? _buildError()
                  : _buildQr(total, craftsmanName),
    );
  }

  Widget _buildLoading() => const Center(
        child: CircularProgressIndicator(color: _kPrimary),
      );

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'Chyba'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _createCheckoutLink,
                child: const Text('Skúsiť znova'),
              )
            ],
          ),
        ),
      );

  Widget _buildSuccess() => const Center(
        child: Icon(Icons.check_circle, size: 80, color: Colors.green),
      );

  Widget _buildQr(double total, String craftsmanName) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 60),
      child: Column(
        children: [

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_kDeep, _kPrimary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              Text('Suma na zaplatenie',
                  style: TextStyle(color: Colors.white.withOpacity(0.8),
                      fontSize: 13)),
              const SizedBox(height: 4),
              Text('${total.toStringAsFixed(2)} €',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 36, fontWeight: FontWeight.bold)),
              Text(craftsmanName,
                  style: TextStyle(color: Colors.white.withOpacity(0.7),
                      fontSize: 13)),
            ])),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                QrImageView(
                  data: _checkoutUrl ?? '',
                  size: 220,
                ),

                const SizedBox(height: 16),

                // 🔥 FIX OVERFLOW (len toto upravené)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.qr_code_scanner, size: 14),
                      const SizedBox(width: 6),

                      Flexible(
                        child: Text(
                          'Naskenuj QR kód bankou alebo Google Lens',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _openInBrowser,
                  child: const Text('Otvoriť v prehliadači'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}