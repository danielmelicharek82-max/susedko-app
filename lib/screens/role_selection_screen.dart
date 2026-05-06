// lib/screens/role_selection_screen.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'customer/customer_home.dart';
import 'craftsman/craftsman_home.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class RoleSelectionScreen extends StatefulWidget {
  final String uid;
  const RoleSelectionScreen({super.key, required this.uid});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with TickerProviderStateMixin {
  static const _kPrimary = Color(0xFF2563EB);
  static const _kGreen = Color(0xFF059669);

  bool _loading = false;
  String? _selected;

  late AnimationController _fadeCtrl;
  late AnimationController _floatCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _floatAnim = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectRole(String role) async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _selected = role;
    });

    try {
      final db = FirebaseFirestore.instance;

      await db.collection('users').doc(widget.uid).set({
        'role': role,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (role == 'craftsman') {
        await db.collection('craftsmen').doc(widget.uid).set({
          'uid': widget.uid,
          'rating': 0,
          'jobsCompleted': 0,
          'reviewCount': 0,
          'isActive': true,
          'isVerified': true,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (role == 'customer') {
        await db.collection('customers').doc(widget.uid).set({
          'uid': widget.uid,
          'name': '',
          'city': '',
          'preferredProfessions': [],
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      final token = await FirebaseMessaging.instance.getToken();

      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .set({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => role == 'customer'
              ? const CustomerHomeScreen()
              : const CraftsmanHome(),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // BACKGROUND
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E3A5F),
                  Color(0xFF0F172A),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // GLOW CIRCLES
          Positioned(
            top: -80,
            left: -60,
            child: _GlowCircle(size: 280, color: _kPrimary.withOpacity(0.15)),
          ),
          Positioned(
            bottom: -60,
            right: -40,
            child: _GlowCircle(size: 240, color: _kGreen.withOpacity(0.12)),
          ),
          Positioned(
            top: size.height * 0.4,
            left: size.width * 0.6,
            child: _GlowCircle(size: 140, color: _kPrimary.withOpacity(0.08)),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER
                    AnimatedBuilder(
                      animation: _floatAnim,
                      builder: (_, child) {
                        return Transform.translate(
                          offset: Offset(0, -_floatAnim.value),
                          child: child,
                        );
                      },
                      child: Center(
                        child: Column(
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF3B82F6),
                                    Color(0xFF1D4ED8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Center(
                                child: Image.asset(
                                  'assets/logo.png',
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Susedko',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'roleSelection_tagline'.tr(),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.55),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    Text(
                      'roleSelection_title'.tr(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'roleSelection_subtitle'.tr(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 32),

                    _RoleCard(
                      role: 'craftsman',
                      selected: _selected,
                      loading: _loading,
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1D4ED8),
                          Color(0xFF2563EB),
                          Color(0xFF3B82F6),
                        ],
                      ),
                      glowColor: _kPrimary,
                      icon: '🔧',
                      badge: 'roleSelection_craftsman_badge'.tr(),
                      title: 'roleSelection_craftsman_title'.tr(),
                      subtitle: 'roleSelection_craftsman_subtitle'.tr(),
                      steps: [
                        ('📅', 'roleSelection_craftsman_step1_title'.tr(), 'roleSelection_craftsman_step1_desc'.tr()),
                        ('👤', 'roleSelection_craftsman_step2_title'.tr(), 'roleSelection_craftsman_step2_desc'.tr()),
                        ('📲', 'roleSelection_craftsman_step3_title'.tr(), 'roleSelection_craftsman_step3_desc'.tr()),
                      ],
                      tip: 'roleSelection_craftsman_tip'.tr(),
                      onTap: () => _selectRole('craftsman'),
                    ),

                    const SizedBox(height: 16),

                    _RoleCard(
                      role: 'customer',
                      selected: _selected,
                      loading: _loading,
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF065F46),
                          Color(0xFF059669),
                          Color(0xFF10B981),
                        ],
                      ),
                      glowColor: _kGreen,
                      icon: '🏠',
                      badge: 'roleSelection_customer_badge'.tr(),
                      title: 'roleSelection_customer_title'.tr(),
                      subtitle: 'roleSelection_customer_subtitle'.tr(),
                      steps: [
                        ('🔍', 'roleSelection_customer_step1_title'.tr(), 'roleSelection_customer_step1_desc'.tr()),
                        ('📆', 'roleSelection_customer_step2_title'.tr(), 'roleSelection_customer_step2_desc'.tr()),
                        ('✅', 'roleSelection_customer_step3_title'.tr(), 'roleSelection_customer_step3_desc'.tr()),
                      ],
                      tip: 'roleSelection_customer_tip'.tr(),
                      onTap: () => _selectRole('customer'),
                    ),

                    const SizedBox(height: 32),

                    Center(
                      child: Text(
                        'roleSelection_terms'.tr(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.25),
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────
// ROLE CARD
// ────────────────────────────────

class _RoleCard extends StatelessWidget {
  final String role;
  final String? selected;
  final bool loading;
  final LinearGradient gradient;
  final Color glowColor;
  final String icon;
  final String badge;
  final String title;
  final String subtitle;
  final List<(String, String, String)> steps;
  final String tip;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.selected,
    required this.loading,
    required this.gradient,
    required this.glowColor,
    required this.icon,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.steps,
    required this.tip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == role;
    final isLoading = loading && isSelected;

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 10),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.7), fontSize: 13)),
            const SizedBox(height: 12),
            Text(tip,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6), fontSize: 12)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                child: isLoading
                    ? const CircularProgressIndicator()
                    : Text('roleSelection_cta'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────
// GLOW CIRCLE
// ────────────────────────────────

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}