// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

import 'customer/customer_home.dart';
import 'craftsman/craftsman_home.dart';
import 'auth/customer_register_form.dart';
import 'auth/craftsman_register_form.dart';
import 'admin/admin_home_screen.dart';
import 'role_selection_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  static const _kPrimary = Color(0xFF2563EB);
  static const _kDeep    = Color(0xFF1E40AF);
  static const _kGreen   = Color(0xFF059669);

  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _googleSignIn       = GoogleSignIn();

  bool _isLoading       = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading  = false;
  bool _passwordVisible = false;

  late AnimationController _fadeCtrl;
  late AnimationController _floatCtrl;
  late AnimationController _shimmerCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _floatAnim;
  late Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
      value: 1.0,
    );

    _floatCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3200))
      ..repeat(reverse: true);

    _shimmerCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _floatAnim = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    _shimmerAnim = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut));

    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _floatCtrl.dispose();
    _shimmerCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _navigateByRole(String role) {
    if (role == 'customer') {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const CustomerHomeScreen()));
    } else if (role == 'craftsman') {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const CraftsmanHome()));
    } else if (role == 'admin') {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const AdminHomeScreen()));
    }
  }

  Future<void> _navigateByRoleFromFirestore(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users').doc(uid).get();
    if (!mounted || !doc.exists) return;
    final role =
        (doc.data()?['role'] as String?)?.trim().toLowerCase() ?? '';
    _navigateByRole(role);
  }

  Future<void> _submit() async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final credential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim());
      await _navigateByRoleFromFirestore(credential.user!.uid);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()),
              backgroundColor: Colors.red.shade700));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      await _googleSignIn.signOut();
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken);
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final uid = userCredential.user!.uid;
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(uid).get();
      if (!mounted) return;
      if (doc.exists) {
        final role =
            (doc.data()?['role'] as String?)?.trim().toLowerCase() ??
                'customer';
        _navigateByRole(role);
      } else {
        Navigator.pushReplacement(context,
            MaterialPageRoute(
                builder: (_) => RoleSelectionScreen(uid: uid)));
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _signInWithApple() async {
    setState(() => _isAppleLoading = true);
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      if (appleCredential.identityToken == null) {
        throw Exception('Apple identity token is null');
      }

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      final uid = userCredential.user!.uid;

      final doc = await FirebaseFirestore.instance
          .collection('users').doc(uid).get();
      if (!mounted) return;

      if (doc.exists) {
        final role =
            (doc.data()?['role'] as String?)?.trim().toLowerCase() ??
                'customer';
        _navigateByRole(role);
      } else {
        final displayName = [
          appleCredential.givenName,
          appleCredential.familyName,
        ].where((n) => n != null).join(' ');

        if (displayName.isNotEmpty) {
          await userCredential.user?.updateDisplayName(displayName);
        }

        Navigator.pushReplacement(context,
            MaterialPageRoute(
                builder: (_) => RoleSelectionScreen(uid: uid)));
      }
    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains('canceled')) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Apple Sign In Error'),
          content: SingleChildScrollView(
            child: Text(e.toString()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isAppleLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('passwordResetSent'.tr()),
            backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(children: [

        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF0A0F1E),
                Color(0xFF0F1E3A),
                Color(0xFF0D2550),
                Color(0xFF0A0F1E),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight)),
        ),

        Positioned(top: -100, left: -80,
          child: _GlowOrb(size: 320, color: _kPrimary.withOpacity(0.18))),
        Positioned(bottom: -80, right: -60,
          child: _GlowOrb(size: 280, color: _kGreen.withOpacity(0.14))),
        Positioned(top: size.height * 0.35, right: -40,
          child: _GlowOrb(size: 180, color: _kPrimary.withOpacity(0.1))),
        Positioned(top: size.height * 0.55, left: -20,
          child: _GlowOrb(size: 140, color: _kGreen.withOpacity(0.08))),

        ...List.generate(12, (i) {
          final positions = [
            [0.1, 0.08], [0.85, 0.12], [0.45, 0.05],
            [0.7, 0.22], [0.2, 0.3],  [0.9, 0.38],
            [0.05, 0.55],[0.75, 0.6], [0.35, 0.72],
            [0.9, 0.78], [0.15, 0.88],[0.6, 0.92],
          ];
          final pos = positions[i];
          final s = (i % 3 == 0) ? 3.0 : (i % 3 == 1) ? 2.0 : 1.5;
          return Positioned(
            left: size.width * pos[0],
            top: size.height * pos[1],
            child: Container(
              width: s, height: s,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.4 + (i % 3) * 0.15),
                shape: BoxShape.circle)));
        }),

        SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Column(children: [
                const SizedBox(height: 20),

                AnimatedBuilder(
                  animation: _floatAnim,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, -_floatAnim.value),
                    child: child),
                  child: Column(children: [
                    Stack(alignment: Alignment.center, children: [
                      Container(
                        width: 110, height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: _kPrimary.withOpacity(0.4),
                                blurRadius: 40, spreadRadius: 10),
                            BoxShadow(color: _kPrimary.withOpacity(0.2),
                                blurRadius: 80, spreadRadius: 20),
                          ])),
                      Container(
                        width: 90, height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.15),
                              Colors.white.withOpacity(0.05)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2), width: 1.5)),
                        child: ClipOval(
                          child: Image.asset('assets/logo.png',
                              width: 90, height: 90, fit: BoxFit.contain))),
                    ]),
                    const SizedBox(height: 16),

                    AnimatedBuilder(
                      animation: _shimmerAnim,
                      builder: (_, __) => ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: const [
                            Colors.white, Color(0xFF93C5FD), Colors.white],
                          stops: const [0.0, 0.5, 1.0],
                          begin: Alignment(_shimmerAnim.value - 1, 0),
                          end: Alignment(_shimmerAnim.value + 1, 0),
                        ).createShader(bounds),
                        child: const Text('Susedko',
                            style: TextStyle(
                              color: Colors.white, fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5)))),
                    const SizedBox(height: 6),
                    Text('signInToAccount'.tr(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55), fontSize: 14)),
                  ])),
                const SizedBox(height: 36),

                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.12), width: 1),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.3),
                          blurRadius: 30, offset: const Offset(0, 10)),
                    ]),
                  child: Column(children: [
                    _GlassField(
                      controller: _emailController,
                      label: 'email'.tr(),
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 14),

                    _GlassField(
                      controller: _passwordController,
                      label: 'password'.tr(),
                      icon: Icons.lock_outline_rounded,
                      obscureText: !_passwordVisible,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _passwordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.white54, size: 20),
                        onPressed: () => setState(
                            () => _passwordVisible = !_passwordVisible))),
                    const SizedBox(height: 8),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _resetPassword,
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.zero, minimumSize: Size.zero),
                        child: Text('forgotPassword'.tr(),
                            style: TextStyle(
                              color: Colors.blue.shade300, fontSize: 13)))),
                    const SizedBox(height: 20),

                    _GradientButton(
                      onTap: _isLoading ? null : _submit,
                      loading: _isLoading,
                      text: 'signInBtn'.tr(),
                      colors: const [Color(0xFF2563EB), Color(0xFF1D4ED8)]),
                    const SizedBox(height: 12),

                    _GoogleButton(
                      onTap: _isGoogleLoading ? null : _signInWithGoogle,
                      loading: _isGoogleLoading,
                      text: 'signInWithGoogle'.tr()),
                    const SizedBox(height: 12),

                    _AppleButton(
                      onTap: _isAppleLoading ? null : _signInWithApple,
                      loading: _isAppleLoading),
                  ])),
                const SizedBox(height: 28),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.08))),
                  child: Column(children: [
                    Text('noAccount'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5), fontSize: 13)),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: _RegisterBtn(
                        label: 'customer'.tr(),
                        icon: Icons.person_outline,
                        color: _kGreen,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) =>
                                const CustomerRegisterForm())))),
                      const SizedBox(width: 12),
                      Expanded(child: _RegisterBtn(
                        label: 'craftsman'.tr(),
                        icon: Icons.handyman_outlined,
                        color: _kPrimary,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) =>
                                const CraftsmanRegisterForm())))),
                    ]),
                  ])),
                const SizedBox(height: 20),
              ])),
          )),
      ]),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: color, blurRadius: size / 2,
          spreadRadius: size / 4)],
      color: color));
}

class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;

  const _GlassField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.07),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1), width: 1)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)));
  }
}

class _GradientButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool loading;
  final String text;
  final List<Color> colors;

  const _GradientButton({
    required this.onTap,
    required this.loading,
    required this.text,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors,
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: colors.first.withOpacity(0.4),
                blurRadius: 16, offset: const Offset(0, 6))]),
        child: Center(child: loading
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Text(text, style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold,
                fontSize: 15)))));
  }
}

class _GoogleButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool loading;
  final String text;

  const _GoogleButton({
    required this.onTap,
    required this.loading,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.15))),
        child: Center(child: loading
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 20, height: 20,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Colors.white),
                  child: const Center(child: Text('G',
                      style: TextStyle(
                        color: Color(0xFF4285F4),
                        fontWeight: FontWeight.bold, fontSize: 13)))),
                const SizedBox(width: 10),
                Text(text, style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w500, fontSize: 14)),
              ]))));
  }
}

class _AppleButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool loading;

  const _AppleButton({required this.onTap, required this.loading});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.15))),
        child: Center(child: loading
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(
                    color: Colors.black, strokeWidth: 2))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.apple, color: Colors.black, size: 22),
                const SizedBox(width: 8),
                const Text('Sign in with Apple',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w600, fontSize: 14)),
              ]))));
  }
}

class _RegisterBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RegisterBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.35))),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ])));
  }
}
