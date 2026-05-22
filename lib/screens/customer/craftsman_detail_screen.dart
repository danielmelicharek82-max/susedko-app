// lib/screens/customer/craftsman_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/craftsman.dart';
import '../../models/portfolio_item.dart' as model;
import '../chat_screen.dart';
import '../../services/chat_service.dart';
import '../auth/craftsman_register_form.dart'; // kProfessionIcons
import 'create_work_order_screen.dart';
import 'service_request_screen.dart';

const _kPrimary = Color(0xFF2563EB);
const _kDeep    = Color(0xFF1E40AF);
const _kAccent  = Color(0xFF60A5FA);
const _kBg      = Color(0xFFF0F4FF);

class CraftsmanDetailScreen extends StatefulWidget {
  final Craftsman craftsman;
  const CraftsmanDetailScreen({super.key, required this.craftsman});
  @override
  State<CraftsmanDetailScreen> createState() =>
      _CraftsmanDetailScreenState();
}

class _CraftsmanDetailScreenState
    extends State<CraftsmanDetailScreen> {
  List<model.PortfolioItem> _portfolio = [];
  bool _loadingPortfolio = true;

  @override
  void initState() { super.initState(); _loadPortfolio(); }

  Future<void> _loadPortfolio() async {
    final snap = await FirebaseFirestore.instance
        .collection('craftsmen').doc(widget.craftsman.id)
        .collection('portfolio')
        .orderBy('createdAt', descending: true)
        .limit(12).get();
    setState(() {
      _portfolio =
          snap.docs.map(model.PortfolioItem.fromFirestore).toList();
      _loadingPortfolio = false;
    });
  }

  Future<void> _openChat() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final conversationId = await ChatService().getOrCreateConversation(
        userId1: user.uid, userId2: widget.craftsman.id);
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatScreen(
            conversationId: conversationId,
            receiverId: widget.craftsman.id)));
  }

  Future<void> _shareProfile() async {
    final c = widget.craftsman;
    final professions = c.skills.isNotEmpty
        ? c.skills.map((s) => s.startsWith('prof_') ? s.tr() : s).join(', ')
        : (c.profession.startsWith('prof_') ? c.profession.tr() : c.profession);
    final rate = c.displayRate != null
        ? '\n💶 ${c.displayRate!.toStringAsFixed(0)} €/h' : '';
    final city = c.cityName != null ? '\n📍 ${c.cityName}' : '';
    final text = '🔧 ${c.name} — Susedko\n\n$professions$city$rate\n\n'
        '⭐ ${c.rating.toStringAsFixed(1)}/5.0\n\n📲 Susedko';
    await Share.share(text, subject: '${c.name} na Susedko');
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.craftsman;
    final displayRate = c.displayRate;
    final profLabel = c.profession.startsWith('prof_')
        ? c.profession.tr() : c.profession;

    return Scaffold(
      backgroundColor: _kBg,
      body: CustomScrollView(slivers: [

        // ── AppBar ──────────────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 260,
          pinned: true,
          backgroundColor: _kPrimary,
          foregroundColor: Colors.white,
          flexibleSpace: FlexibleSpaceBar(
            background: c.profileImage != null
                ? Stack(fit: StackFit.expand, children: [
                    Image.network(c.profileImage!, fit: BoxFit.cover),
                    Container(decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.55)]))),
                    // Name overlay at bottom
                    Positioned(
                      bottom: 20, left: 20, right: 80,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(c.name, style: const TextStyle(
                            color: Colors.white, fontSize: 24,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(blurRadius: 8,
                                color: Colors.black45)])),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.4))),
                          child: Text(profLabel,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600))),
                      ])),
                  ])
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_kDeep, _kPrimary, Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight)),
                    child: Stack(children: [
                      Positioned(right: -40, top: -40,
                        child: Container(width: 180, height: 180,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            shape: BoxShape.circle))),
                      Center(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        const Icon(Icons.handyman,
                            size: 64, color: Colors.white38),
                        const SizedBox(height: 10),
                        Text(c.name, style: const TextStyle(
                            color: Colors.white, fontSize: 22,
                            fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(profLabel, style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14)),
                      ])),
                    ])),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'craftsmanDetail_share_title'.tr(),
              onPressed: _shareProfile),
          ],
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Stats row ────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(
                      color: _kPrimary.withOpacity(0.07),
                      blurRadius: 16, offset: const Offset(0, 4))]),
                child: Row(children: [
                  // Rating
                  Expanded(child: _statBox(
                    icon: Icons.star_rounded,
                    iconColor: Colors.amber,
                    value: c.rating.toStringAsFixed(1),
                    label: '${c.reviewCount} ${'reviews'.tr()}')),
                  Container(width: 1, height: 50,
                      color: Colors.grey.shade200),
                  // Price
                  if (displayRate != null)
                    Expanded(child: _statBox(
                      icon: Icons.euro_rounded,
                      iconColor: _kPrimary,
                      value: '${displayRate.toStringAsFixed(0)} €',
                      label: 'craftsmanDetail_per_hour'.tr())),
                  if (c.isVerified) ...[
                    Container(width: 1, height: 50,
                        color: Colors.grey.shade200),
                    Expanded(child: _statBox(
                      icon: Icons.verified_rounded,
                      iconColor: Colors.green,
                      value: 'verified'.tr(),
                      label: '')),
                  ],
                ])),
              const SizedBox(height: 14),

              // ── Location ─────────────────────────────────────────────
              if (c.cityName != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200)),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _kPrimary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.location_on_outlined,
                          size: 15, color: _kPrimary)),
                    const SizedBox(width: 10),
                    Text(c.cityName!,
                        style: TextStyle(
                            color: Colors.grey.shade700, fontSize: 14)),
                  ])),
              const SizedBox(height: 14),

              // ── Payment info banner ───────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.green.shade50, Colors.green.shade50],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade200)),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(9)),
                    child: Icon(Icons.verified_user_outlined,
                        color: Colors.green.shade700, size: 16)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(
                    'paymentInfoBanner'.tr(),
                    style: TextStyle(fontSize: 12,
                        color: Colors.green.shade800, height: 1.4))),
                ])),
              const SizedBox(height: 14),

              // ── Bio ───────────────────────────────────────────────────
              if (c.bio != null && c.bio!.isNotEmpty)
                _sectionCard(
                  title: 'about'.tr(),
                  icon: Icons.person_outline_rounded,
                  child: Text(c.bio!,
                      style: TextStyle(color: Colors.grey.shade700,
                          fontSize: 14, height: 1.6))),
              if (c.bio != null && c.bio!.isNotEmpty)
                const SizedBox(height: 14),

              // ── Skills ────────────────────────────────────────────────
              if (c.skills.isNotEmpty)
                _sectionCard(
                  title: 'skills'.tr(),
                  icon: Icons.handyman_outlined,
                  child: Wrap(spacing: 8, runSpacing: 8,
                    children: c.skills.map((s) {
                      final label = s.startsWith('prof_') ? s.tr() : s;
                      final icon =
                          kProfessionIcons[s] ?? Icons.handyman_outlined;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            _kPrimary.withOpacity(0.12),
                            _kAccent.withOpacity(0.08)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _kPrimary.withOpacity(0.25))),
                        child: Row(mainAxisSize: MainAxisSize.min,
                            children: [
                          Icon(icon, size: 13, color: _kPrimary),
                          const SizedBox(width: 6),
                          Text(label, style: const TextStyle(
                              color: _kPrimary, fontSize: 13,
                              fontWeight: FontWeight.w600)),
                        ]));
                    }).toList())),
              if (c.skills.isNotEmpty) const SizedBox(height: 14),

              // ── Portfolio title ───────────────────────────────────────
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.photo_library_outlined,
                      size: 15, color: _kPrimary)),
                const SizedBox(width: 8),
                Text('portfolio'.tr(), style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15,
                    color: Color(0xFF1E293B))),
              ]),
              const SizedBox(height: 10),
            ]))),

        // ── Portfolio grid ───────────────────────────────────────────────
        _loadingPortfolio
            ? const SliverToBoxAdapter(
                child: Center(child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: _kPrimary))))
            : _portfolio.isEmpty
                ? SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.grey.shade200)),
                      child: Row(children: [
                        Icon(Icons.photo_library_outlined,
                            size: 24,
                            color: Colors.grey.shade300),
                        const SizedBox(width: 12),
                        Text('noPortfolio'.tr(),
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 14)),
                      ]))))
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final item = _portfolio[i];
                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 8)]),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Stack(fit: StackFit.expand, children: [
                                Image.network(item.imageUrl,
                                    fit: BoxFit.cover),
                                if (item.title != null &&
                                    item.title!.isNotEmpty)
                                  Positioned(
                                    bottom: 0, left: 0, right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            Colors.black.withOpacity(0.6),
                                            Colors.transparent])),
                                      child: Text(item.title!,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight:
                                                  FontWeight.bold)))),
                              ])));
                        },
                        childCount: _portfolio.length),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8),
                    )),

        // ── Action buttons ───────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            child: Column(children: [

              // Book job — primary
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) =>
                        CreateWorkOrderScreen(
                            craftsman: widget.craftsman,
                            initialProfession:
                                widget.craftsman.profession))),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kDeep, _kPrimary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(
                      color: _kPrimary.withOpacity(0.35),
                      blurRadius: 12, offset: const Offset(0, 5))]),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    const Icon(Icons.work_outline,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text('craftsmanDetail_book'.tr(),
                        style: const TextStyle(color: Colors.white,
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ]))),
              const SizedBox(height: 12),

              // Send request — secondary
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) =>
                        ServiceRequestScreen(
                            craftsmanId: widget.craftsman.id,
                            craftsmanName: widget.craftsman.name,
                            initialProfession:
                                widget.craftsman.profession))),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kPrimary, width: 1.5),
                    boxShadow: [BoxShadow(
                        color: _kPrimary.withOpacity(0.08),
                        blurRadius: 8)]),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    const Icon(Icons.handyman_outlined,
                        color: _kPrimary, size: 18),
                    const SizedBox(width: 10),
                    Text('craftsmanDetail_request'.tr(),
                        style: const TextStyle(color: _kPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ]))),
              const SizedBox(height: 16),

              // Share profile card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12)]),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _kPrimary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.share_outlined,
                          size: 15, color: _kPrimary)),
                    const SizedBox(width: 8),
                    Text('craftsmanDetail_share_title'.tr(),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14,
                            color: Color(0xFF1E293B))),
                  ]),
                  const SizedBox(height: 6),
                  Text('craftsmanDetail_share_desc'.tr(),
                      style: TextStyle(fontSize: 12,
                          color: Colors.grey.shade500, height: 1.4)),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: GestureDetector(
                      onTap: _shareProfile,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1877F2),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(
                              color: const Color(0xFF1877F2)
                                  .withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3))]),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                          const Icon(Icons.facebook,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          const Text('Facebook',
                              style: TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ])))),
                    const SizedBox(width: 10),
                    Expanded(child: GestureDetector(
                      onTap: _shareProfile,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE1306C),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(
                              color: const Color(0xFFE1306C)
                                  .withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3))]),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                          const Icon(Icons.camera_alt_outlined,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          const Text('Instagram',
                              style: TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ])))),
                  ]),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _shareProfile,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _kPrimary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _kPrimary.withOpacity(0.25))),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        const Icon(Icons.ios_share_outlined,
                            color: _kPrimary, size: 16),
                        const SizedBox(width: 8),
                        Text('share'.tr(),
                            style: const TextStyle(color: _kPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ]))),
                ])),
            ])),
        ),
      ]),
    );
  }

  Widget _statBox({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: iconColor, size: 18)),
        const SizedBox(height: 5),
        Text(value, style: TextStyle(fontSize: 14,
            fontWeight: FontWeight.bold, color: iconColor)),
        if (label.isNotEmpty)
          Text(label, style: TextStyle(
              fontSize: 11, color: Colors.grey.shade500)),
      ]);

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) =>
      Container(
        width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: _kPrimary.withOpacity(0.05),
              blurRadius: 12, offset: const Offset(0, 3))]),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 15, color: _kPrimary)),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14,
                color: Color(0xFF1E293B))),
          ]),
          const SizedBox(height: 12),
          child,
        ]));
}