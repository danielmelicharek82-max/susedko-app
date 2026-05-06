// lib/screens/craftsman/craftsman_portfolio_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:io';
import '../../models/portfolio_item.dart';

const _kPrimary = Color(0xFF2563EB);
const _kDeep    = Color(0xFF1E40AF);
const _kAccent  = Color(0xFF60A5FA);
const _kBg      = Color(0xFFF0F4FF);

class CraftsmanPortfolioScreen extends StatefulWidget {
  const CraftsmanPortfolioScreen({super.key});
  @override
  State<CraftsmanPortfolioScreen> createState() =>
      _CraftsmanPortfolioScreenState();
}

class _CraftsmanPortfolioScreenState
    extends State<CraftsmanPortfolioScreen> {
  bool _uploading = false;
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  Stream<List<PortfolioItem>> _portfolioStream() {
    if (_userId == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('craftsmen').doc(_userId)
        .collection('portfolio')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(PortfolioItem.fromFirestore).toList());
  }

  Future<void> _addPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || _userId == null) return;

    setState(() => _uploading = true);
    try {
      final file = File(picked.path);
      final ref = FirebaseStorage.instance.ref().child(
          'craftsmen/$_userId/portfolio/'
          '${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('craftsmen').doc(_userId)
          .collection('portfolio').add({
        'imageUrl':    url,
        'craftsmanId': _userId,
        'createdAt':   FieldValue.serverTimestamp(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('photoAdded'.tr()),
              backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'error'.tr()}: $e'),
              backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deletePhoto(PortfolioItem item) async {
    if (_userId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                shape: BoxShape.circle),
              child: Icon(Icons.delete_outline_rounded,
                  color: Colors.red.shade500, size: 30)),
            const SizedBox(height: 16),
            Text('deletePhoto'.tr(),
                style: const TextStyle(fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('deletePhotoDesc'.tr(),
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade500)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(ctx, false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text('cancel'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w600,
                          color: Colors.black54)))))),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(ctx, true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 8, offset: const Offset(0, 3))]),
                  child: Center(child: Text('delete'.tr(),
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold)))))),
            ]),
          ]))));

    if (confirm != true) return;
    try {
      await FirebaseStorage.instance.refFromURL(item.imageUrl).delete();
      await FirebaseFirestore.instance
          .collection('craftsmen').doc(_userId)
          .collection('portfolio').doc(item.id).delete();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('delete'.tr()),
              backgroundColor: Colors.orange));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'error'.tr()}: $e'),
              backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            expandedHeight: 120,
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
                  Positioned(right: -30, top: -30,
                    child: Container(width: 140, height: 140,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle))),
                  Positioned(left: -20, bottom: -20,
                    child: Container(width: 100, height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        shape: BoxShape.circle))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 52, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('portfolioTitle'.tr(),
                          style: const TextStyle(
                            color: Colors.white, fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5)),
                        const SizedBox(height: 2),
                        Text('portfolioSubtitle'.tr(),
                          style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                      ]),
                  ),
                ])),
            ),
            actions: [
              if (_uploading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)))
              else
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: _addPhoto,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3))),
                      child: Row(
                          mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.add_photo_alternate_outlined,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text('addPhoto'.tr(),
                            style: const TextStyle(color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ])))),
            ],
          ),
        ],
        body: StreamBuilder<List<PortfolioItem>>(
          stream: _portfolioStream(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: _kPrimary));
            }
            final items = snap.data ?? [];
            if (items.isEmpty) return _buildEmpty();
            return _buildGrid(items);
          }),
      ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _kPrimary.withOpacity(0.1),
                _kAccent.withOpacity(0.06)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
            shape: BoxShape.circle),
          child: Icon(Icons.photo_library_outlined,
              size: 52, color: _kPrimary.withOpacity(0.5))),
        const SizedBox(height: 20),
        Text('portfolioEmpty'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold,
                fontSize: 18, color: Color(0xFF1E293B))),
        const SizedBox(height: 8),
        Text('portfolioEmptyDesc'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13,
                color: Colors.grey.shade500, height: 1.6)),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _uploading ? null : _addPhoto,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 28, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kDeep, _kPrimary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                color: _kPrimary.withOpacity(0.3),
                blurRadius: 10, offset: const Offset(0, 4))]),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _uploading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.add_photo_alternate_outlined,
                      color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text('addFirstPhoto'.tr(),
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ]))),
      ])));

  Widget _buildGrid(List<PortfolioItem> items) => CustomScrollView(
    slivers: [
      SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _kPrimary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kPrimary.withOpacity(0.15))),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.touch_app_outlined,
                  size: 15, color: _kPrimary)),
            const SizedBox(width: 10),
            Expanded(child: Text(
              'portfolioInfoBanner'.tr(),
              style: TextStyle(fontSize: 12,
                  color: Colors.grey.shade600, height: 1.4))),
          ]))),

      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(children: [
            Container(
              width: 4, height: 18,
              decoration: BoxDecoration(
                color: _kPrimary,
                borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Text('workPhotos'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 15, color: Color(0xFF1E293B))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20)),
              child: Text('${items.length}',
                  style: TextStyle(fontSize: 12, color: _kPrimary,
                      fontWeight: FontWeight.bold))),
          ]))),

      SliverPadding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _buildPhotoCard(items[i]),
            childCount: items.length),
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.85))),
    ]);

  Widget _buildPhotoCard(PortfolioItem item) => GestureDetector(
    onLongPress: () => _deletePhoto(item),
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 10, offset: const Offset(0, 4))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(fit: StackFit.expand, children: [
          Image.network(item.imageUrl, fit: BoxFit.cover,
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return Container(
                color: _kPrimary.withOpacity(0.05),
                child: Center(child: CircularProgressIndicator(
                  color: _kPrimary,
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2)));
            }),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.55),
                    Colors.transparent])))),
          if (item.profession != null && item.profession!.isNotEmpty)
            Positioned(
              bottom: 8, left: 8, right: 8,
              child: Text(item.profession!.tr(),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11,
                      fontWeight: FontWeight.bold),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
          Positioned(
            top: 8, right: 8,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle),
              child: const Icon(Icons.more_vert_rounded,
                  color: Colors.white, size: 14))),
        ]))));
}