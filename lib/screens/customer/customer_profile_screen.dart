// lib/screens/customer/customer_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:io';

import '../login_screen.dart';
import 'about_app_screen.dart';
import '../auth/craftsman_register_form.dart';

const _kPrimary = Color(0xFF2563EB);
const _kDeep    = Color(0xFF1E40AF);
const _kAccent  = Color(0xFF60A5FA);
const _kBg      = Color(0xFFF0F4FF);

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final _nameController = TextEditingController();

  String? _profileImageUrl;
  File? _newImage;
  List<String> _preferredProfessions = [];

  bool _loading = true;
  bool _saving  = false;

  int _bookingsCount = 0;
  int _reviewsCount  = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadStats();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data() ?? {};
      _nameController.text = data['name'] ?? user.displayName ?? '';
      setState(() {
        _profileImageUrl = data['profileImage'] ?? user.photoURL;
        _preferredProfessions =
            List<String>.from(data['preferredProfessions'] ?? []);
      });
    }
    setState(() => _loading = false);
  }

  Future<void> _loadStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final bookSnap = await FirebaseFirestore.instance
        .collection('bookings')
        .where('customerId', isEqualTo: user.uid)
        .get();
    final revSnap = await FirebaseFirestore.instance
        .collection('reviews')
        .where('customerId', isEqualTo: user.uid)
        .get();
    if (!mounted) return;
    setState(() {
      _bookingsCount = bookSnap.docs.length;
      _reviewsCount  = revSnap.docs.length;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _newImage = File(picked.path));
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      String? imageUrl = _profileImageUrl;
      if (_newImage != null) {
        final ref = FirebaseStorage.instance
            .ref().child('users/${user.uid}/profile.jpg');
        await ref.putFile(_newImage!);
        imageUrl = await ref.getDownloadURL();
      }
      await FirebaseFirestore.instance
          .collection('users').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'profileImage': imageUrl,
        'preferredProfessions': _preferredProfessions,
        'email': user.email,
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('profileSaved'.tr()),
        backgroundColor: Colors.green));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false);
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to permanently delete your account? This action cannot be undone and all your data will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Account')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final uid = user.uid;

      // Vymazanie Firestore dát
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();

      // Vymazanie Firebase Auth účtu
      await user.delete();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            'For security, please log out and log in again before deleting your account.'),
          backgroundColor: Colors.orange));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.message}'),
          backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          backgroundColor: _kBg,
          body: Center(child: CircularProgressIndicator(color: _kPrimary)));
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            expandedHeight: 200,
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
                  Positioned(right: -40, top: -40,
                    child: Container(width: 180, height: 180,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle))),
                  Positioned(left: -30, bottom: -30,
                    child: Container(width: 130, height: 130,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        shape: BoxShape.circle))),
                  Positioned.fill(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 30),
                        GestureDetector(
                          onTap: _pickImage,
                          child: Stack(children: [
                            Container(
                              width: 84, height: 84,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 12)]),
                              child: ClipOval(child: _newImage != null
                                  ? Image.file(_newImage!, fit: BoxFit.cover)
                                  : _profileImageUrl != null
                                      ? Image.network(_profileImageUrl!, fit: BoxFit.cover)
                                      : Container(
                                          color: _kPrimary.withOpacity(0.2),
                                          child: const Icon(Icons.person, size: 40, color: Colors.white)))),
                            Positioned(bottom: 2, right: 2,
                              child: Container(
                                width: 24, height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.white, shape: BoxShape.circle,
                                  border: Border.all(color: _kPrimary, width: 2)),
                                child: const Icon(Icons.camera_alt, size: 12, color: _kPrimary))),
                          ])),
                        const SizedBox(height: 10),
                        Text(_nameController.text.isNotEmpty
                            ? _nameController.text : 'name'.tr(),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(FirebaseAuth.instance.currentUser?.email ?? '',
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                      ])),
                ])),
            ),
            actions: [
              if (_saving)
                const Padding(padding: EdgeInsets.all(16),
                  child: SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
              else
                IconButton(
                  icon: const Icon(Icons.save_outlined, color: Colors.white),
                  onPressed: _save,
                  tooltip: 'save'.tr()),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: _logout,
                tooltip: 'logout'.tr()),
            ],
          ),
        ],
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 60),
          child: Column(children: [

            // Stats
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(
                    color: _kPrimary.withOpacity(0.07),
                    blurRadius: 16, offset: const Offset(0, 4))]),
              child: Row(children: [
                Expanded(child: _statBox(Icons.work_outline, '$_bookingsCount',
                    'bookingsCount'.tr(), _kPrimary)),
                Container(width: 1, height: 50, color: Colors.grey.shade200),
                Expanded(child: _statBox(Icons.star_outline, '$_reviewsCount',
                    'reviewsCount'.tr(), Colors.amber)),
              ])),
            const SizedBox(height: 16),

            // Name
            _sectionCard(
              title: 'name'.tr(),
              icon: Icons.person_outline_rounded,
              child: TextField(
                controller: _nameController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'namePlaceholder'.tr(),
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.edit_outlined,
                      color: Colors.grey.shade400, size: 18)),
              )),
            const SizedBox(height: 16),

            // Preferred professions
            _sectionCard(
              title: 'preferredServices'.tr(),
              icon: Icons.handyman_outlined,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('preferredProfessionsDesc'.tr(),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500, height: 1.4)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8,
                  children: kAllProfessionKeys.map((key) {
                    final selected = _preferredProfessions.contains(key);
                    final icon = kProfessionIcons[key] ?? Icons.handyman_outlined;
                    return GestureDetector(
                      onTap: () => setState(() {
                        selected ? _preferredProfessions.remove(key)
                            : _preferredProfessions.add(key);
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: selected ? _kPrimary : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: selected ? _kPrimary : Colors.grey.shade300,
                              width: selected ? 2 : 1),
                          boxShadow: selected ? [BoxShadow(
                              color: _kPrimary.withOpacity(0.2),
                              blurRadius: 6, offset: const Offset(0, 2))] : []),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(icon, size: 13,
                              color: selected ? Colors.white : Colors.grey.shade600),
                          const SizedBox(width: 5),
                          Text(key.tr(), style: TextStyle(fontSize: 12,
                              color: selected ? Colors.white : Colors.grey.shade700,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                        ])));
                  }).toList()),
                if (_preferredProfessions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kPrimary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      'selectedCount'.tr(namedArgs: {
                        'count': _preferredProfessions.length.toString(),
                      }),
                      style: const TextStyle(fontSize: 12,
                          color: _kPrimary, fontWeight: FontWeight.w500))),
                ],
              ])),
            const SizedBox(height: 16),

            // Save button
            _saving
                ? const Center(child: CircularProgressIndicator(color: _kPrimary))
                : GestureDetector(
                    onTap: _save,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_kDeep, _kPrimary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(
                          color: _kPrimary.withOpacity(0.3),
                          blurRadius: 10, offset: const Offset(0, 4))]),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.save_outlined, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text('save'.tr(), style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ]))),
            const SizedBox(height: 12),

            // About app
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AboutAppScreen())),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200)),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _kPrimary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.info_outline, size: 18, color: _kPrimary)),
                  const SizedBox(width: 12),
                  Expanded(child: Text('terms'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w500,
                          color: Color(0xFF1E293B)))),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 18),
                ])),
            ),
            const SizedBox(height: 12),

            // Logout
            GestureDetector(
              onTap: _logout,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.withOpacity(0.3))),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.logout, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Text('logout'.tr(), style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15)),
                ]))),
            const SizedBox(height: 12),

            // Delete Account
            GestureDetector(
              onTap: _deleteAccount,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.withOpacity(0.5))),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.delete_forever, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  const Text('Delete Account', style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15)),
                ]))),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  Widget _statBox(IconData icon, String value, String label, Color color) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 20)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ]);

  Widget _sectionCard({required String title, required IconData icon, required Widget child}) =>
      Container(
        width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: _kPrimary.withOpacity(0.05),
              blurRadius: 12, offset: const Offset(0, 3))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 15, color: _kPrimary)),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold,
                fontSize: 14, color: Color(0xFF1E293B))),
          ]),
          const SizedBox(height: 12),
          child,
        ]));
}
