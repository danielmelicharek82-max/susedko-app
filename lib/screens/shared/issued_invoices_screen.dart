// lib/screens/shared/issued_invoices_screen.dart
//
// Moje doklady: zákazník vidí svoje faktúry, remeselník svoje samofaktúry.
// Tlačidlá "Stiahnuť PDF" / "XML (eFaktúra)" otvoria krátkodobý odkaz.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/issued_invoice.dart';
import '../../services/issued_invoice_service.dart';

const _kPrimary = Color(0xFF2563EB);
const _kBg = Color(0xFFF0F4FF);

class IssuedInvoicesScreen extends StatelessWidget {
  const IssuedInvoicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text('invoices_title'.tr()),
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: uid.isEmpty
          ? const SizedBox.shrink()
          : StreamBuilder<List<IssuedInvoice>>(
              stream: IssuedInvoiceService.watchMine(uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: _kPrimary));
                }
                final list = snap.data ?? const <IssuedInvoice>[];
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.description_outlined,
                              size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('invoices_empty'.tr(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.grey.shade600, height: 1.5)),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _InvoiceCard(invoice: list[i]),
                );
              },
            ),
    );
  }
}

class _InvoiceCard extends StatefulWidget {
  final IssuedInvoice invoice;
  const _InvoiceCard({required this.invoice});

  @override
  State<_InvoiceCard> createState() => _InvoiceCardState();
}

class _InvoiceCardState extends State<_InvoiceCard> {
  bool _busyPdf = false;
  bool _busyXml = false;

  Future<void> _download({required bool xml}) async {
    setState(() => xml ? _busyXml = true : _busyPdf = true);
    try {
      final url =
          await IssuedInvoiceService.downloadUrl(widget.invoice.id, xml: xml);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('invoices_error_download'.tr()),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => xml ? _busyXml = false : _busyPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;
    final badgeColor = inv.paid ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kPrimary.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    inv.isSelfBilled
                        ? 'invoices_type_self'.tr()
                        : 'invoices_type_customer'.tr(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 2),
                  Text(inv.number,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                inv.paid ? 'invoices_paid'.tr() : 'invoices_unpaid'.tr(),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: inv.paid
                        ? Colors.green.shade700
                        : Colors.orange.shade800),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Text('${'invoices_issued'.tr()}: ${inv.issueDateLabel}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const Spacer(),
            Text('${inv.gross.toStringAsFixed(2)} €',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _kPrimary)),
          ]),
          if (inv.vat > 0)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${'invoices_net'.tr()} ${inv.net.toStringAsFixed(2)} € · '
                '${'invoices_vat'.tr()} ${inv.vat.toStringAsFixed(2)} €',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _busyPdf ? null : () => _download(xml: false),
                icon: _busyPdf
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: Text('invoices_download_pdf'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            if (inv.hasXml) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _busyXml ? null : () => _download(xml: true),
                icon: _busyXml
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.code, size: 18),
                label: const Text('XML'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ]),
        ],
      ),
    );
  }
}

/// Dlaždica do profilových obrazoviek: otvorí zoznam dokladov.
class IssuedInvoicesTile extends StatelessWidget {
  const IssuedInvoicesTile({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const IssuedInvoicesScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kPrimary.withOpacity(0.15)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _kPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.description_outlined,
                size: 18, color: _kPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('invoices_title'.tr(),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text('invoices_tile_subtitle'.tr(),
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey.shade400),
        ]),
      ),
    );
  }
}
