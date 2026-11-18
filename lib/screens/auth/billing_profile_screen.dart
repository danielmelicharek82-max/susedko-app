// lib/screens/auth/billing_profile_screen.dart
//
// Samostatná obrazovka na úpravu fakturačných údajov + pomocné prvky:
//  • BillingProfileScreen.ensureReady(context, role) — "brána": ak údaje
//    nie sú kompletné, ponúkne ich doplnenie a vráti, či sú teraz v poriadku,
//  • BillingProfileTile — dlaždica pre profilové obrazovky so stavom údajov.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../models/billing_profile.dart';
import '../../services/billing_profile_service.dart';
import '../../utils/countries.dart';
import 'billing_details_form.dart';

const _kPrimary = Color(0xFF2563EB);
const _kBg = Color(0xFFF5F6FA);

class BillingProfileScreen extends StatefulWidget {
  final String role; // 'customer' | 'craftsman'

  /// true = otvorené z "brány" — zobrazí vysvetľujúci banner.
  final bool requiredMode;

  const BillingProfileScreen({
    super.key,
    required this.role,
    this.requiredMode = false,
  });

  /// Skontroluje, či má prihlásený používateľ kompletné fakturačné údaje.
  /// Ak nie, zobrazí dialóg a ponúkne ich doplnenie. Vráti true, ak sú
  /// údaje (už) kompletné a môže sa pokračovať.
  static Future<bool> ensureReady(BuildContext context, String role) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    if (await BillingProfileService.isReady(uid, role)) return true;
    if (!context.mounted) return false;

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.receipt_long_outlined, color: _kPrimary),
          const SizedBox(width: 8),
          Expanded(child: Text('billing_gate_title'.tr())),
        ]),
        content: Text(role == 'craftsman'
            ? 'billing_gate_craftsman'.tr()
            : 'billing_gate_customer'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('billing_gate_btn'.tr()),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return false;

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BillingProfileScreen(role: role, requiredMode: true),
      ),
    );
    return saved == true;
  }

  @override
  State<BillingProfileScreen> createState() => _BillingProfileScreenState();
}

class _BillingProfileScreenState extends State<BillingProfileScreen> {
  final BillingFormController _c = BillingFormController();
  late final List<String> _countryNames;
  BillingProfile? _previous;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _countryNames = countryMap.keys.toList()..sort();
    _load();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final existing = await BillingProfileService.load(uid);
      if (existing != null) {
        _previous = existing;
        _c.load(existing);
      } else {
        await _prefillFromProfile(uid);
      }
    } catch (e) {
      debugPrint('BillingProfileScreen: načítanie zlyhalo: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Predvyplní polia z už existujúcich údajov používateľa (meno, adresa,
  /// telefón), aby ich nemusel písať znova.
  Future<void> _prefillFromProfile(String uid) async {
    final db = FirebaseFirestore.instance;
    final isCraftsman = widget.role == 'craftsman';
    try {
      final roleDoc = await db
          .collection(isCraftsman ? 'craftsmen' : 'customers')
          .doc(uid)
          .get();
      final d = roleDoc.data() ?? {};
      _c.legalName.text = (d['name'] ?? '').toString();
      _c.street.text =
          ((isCraftsman ? d['streetAddress'] : d['street']) ?? '').toString();
      _c.city.text =
          ((isCraftsman ? d['cityName'] : d['city']) ?? '').toString();
      _c.phone.text = (d['phone'] ?? '').toString();
      final country = (d['country'] ?? '').toString();
      final code = (d['countryCode'] ?? '').toString();
      if (country.isNotEmpty) _c.country = country;
      if (code.isNotEmpty) _c.countryCode = code;
    } catch (e) {
      debugPrint('BillingProfileScreen: predvyplnenie zlyhalo: $e');
    }
    if (_c.phone.text.isEmpty) {
      try {
        final u = await db.collection('users').doc(uid).get();
        _c.phone.text = (u.data()?['phone'] ?? '').toString();
      } catch (_) {}
    }
    if (widget.role == 'craftsman') _c.isCompany = true;
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (!_c.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('fillAllFields'.tr())),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final profile = _c.toProfile(role: widget.role);
      await BillingProfileService.save(uid, profile, previous: _previous);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('billing_saved'.tr()),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text('billing_title'.tr()),
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kPrimary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.requiredMode) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(children: [
                        Icon(Icons.info_outline,
                            size: 18, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'billing_required_banner'.tr(),
                            style: TextStyle(
                                fontSize: 13, color: Colors.orange.shade900),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ],
                  BillingDetailsForm(
                    role: widget.role,
                    controller: _c,
                    showAddress: true,
                    countryNames: _countryNames,
                    countryMap: countryMap,
                  ),
                  const SizedBox(height: 12),
                  _saving
                      ? const Center(
                          child: CircularProgressIndicator(color: _kPrimary))
                      : ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'billing_save'.tr(),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

/// Dlaždica do profilových obrazoviek: ukazuje, či sú fakturačné údaje
/// kompletné, a po ťuknutí otvorí ich úpravu.
class BillingProfileTile extends StatelessWidget {
  final String role; // 'customer' | 'craftsman'
  const BillingProfileTile({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<BillingProfile?>(
      stream: BillingProfileService.watch(uid),
      builder: (context, snap) {
        final complete = snap.data?.isCompleteFor(role) ?? false;
        final color = complete ? Colors.green : Colors.orange;
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BillingProfileScreen(role: role)),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.35)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long_outlined,
                    size: 18, color: _kPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('billing_title'.tr(),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('billing_tile_subtitle'.tr(),
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  complete
                      ? 'billing_badge_complete'.tr()
                      : 'billing_badge_missing'.tr(),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: complete
                          ? Colors.green.shade700
                          : Colors.orange.shade800),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ]),
          ),
        );
      },
    );
  }
}
