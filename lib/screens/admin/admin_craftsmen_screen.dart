// lib/screens/admin/admin_craftsmen_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/craftsman.dart';

class AdminCraftsmenScreen extends StatefulWidget {
  const AdminCraftsmenScreen({super.key});
  @override
  State<AdminCraftsmenScreen> createState() => _AdminCraftsmenScreenState();
}

class _AdminCraftsmenScreenState extends State<AdminCraftsmenScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _kPrimary = Color(0xFF2563EB);
  static const _kBg = Color(0xFFF8FAFC);

  @override
  void initState() { super.initState(); _tabController = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  Stream<List<Craftsman>> _streamPending() => FirebaseFirestore.instance.collection('craftsmen').where('isVerified', isEqualTo: false).orderBy('createdAt', descending: true).snapshots().map((s) => s.docs.map(Craftsman.fromFirestore).toList());
  Stream<List<Craftsman>> _streamVerified() => FirebaseFirestore.instance.collection('craftsmen').where('isVerified', isEqualTo: true).orderBy('createdAt', descending: true).snapshots().map((s) => s.docs.map(Craftsman.fromFirestore).toList());

  Future<void> _verify(Craftsman craftsman) async {
    await FirebaseFirestore.instance.collection('craftsmen').doc(craftsman.id).update({'isVerified': true, 'isActive': true});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${craftsman.name} overený'), backgroundColor: _kPrimary));
  }

  Future<void> _reject(Craftsman craftsman) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Odmietnuť remeselníka?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Zrušiť')), TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Odmietnuť'))]));
    if (confirm == true) await FirebaseFirestore.instance.collection('craftsmen').doc(craftsman.id).update({'isActive': false});
  }

  Future<void> _toggleActive(Craftsman craftsman) async {
    await FirebaseFirestore.instance.collection('craftsmen').doc(craftsman.id).update({'isActive': !craftsman.isActive});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('Remeselníci', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _kPrimary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [Tab(text: 'Čakajú na overenie'), Tab(text: 'Overení')],
        ),
      ),
      body: TabBarView(controller: _tabController, children: [
        StreamBuilder<List<Craftsman>>(
          stream: _streamPending(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            final craftsmen = snap.data ?? [];
            if (craftsmen.isEmpty) return const Center(child: Text('Žiadni čakajúci remeselníci'));
            return ListView.builder(padding: const EdgeInsets.all(16), itemCount: craftsmen.length, itemBuilder: (context, i) => _buildPendingCard(craftsmen[i]));
          },
        ),
        StreamBuilder<List<Craftsman>>(
          stream: _streamVerified(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            final craftsmen = snap.data ?? [];
            if (craftsmen.isEmpty) return const Center(child: Text('Žiadni overení remeselníci'));
            return ListView.builder(padding: const EdgeInsets.all(16), itemCount: craftsmen.length, itemBuilder: (context, i) => _buildVerifiedCard(craftsmen[i]));
          },
        ),
      ]),
    );
  }

  Widget _buildPendingCard(Craftsman craftsman) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 28, backgroundImage: craftsman.profileImage != null ? NetworkImage(craftsman.profileImage!) : null, child: craftsman.profileImage == null ? const Icon(Icons.handyman) : null),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(craftsman.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            if (craftsman.profession.isNotEmpty) Text(craftsman.profession, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            if (craftsman.cityName != null) Text(craftsman.cityName!, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange.shade300)), child: Text('Čaká', style: TextStyle(color: Colors.orange.shade700, fontSize: 11, fontWeight: FontWeight.bold))),
        ]),
        if (craftsman.bio != null && craftsman.bio!.isNotEmpty) ...[const SizedBox(height: 8), Text(craftsman.bio!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade700, fontSize: 13))],
        if (craftsman.skills.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: craftsman.skills.map((s) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _kPrimary.withOpacity(0.08), borderRadius: BorderRadius.circular(12)), child: Text(s, style: TextStyle(fontSize: 11, color: _kPrimary)))).toList()),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () => _reject(craftsman), child: const Text('Odmietnuť'))),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () => _verify(craftsman), child: const Text('Overiť'))),
        ]),
      ])),
    );
  }

  Widget _buildVerifiedCard(Craftsman craftsman) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(backgroundImage: craftsman.profileImage != null ? NetworkImage(craftsman.profileImage!) : null, child: craftsman.profileImage == null ? const Icon(Icons.handyman) : null),
        title: Row(children: [Text(craftsman.name, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(width: 6), Icon(Icons.verified, size: 14, color: _kPrimary)]),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(craftsman.profession, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          Row(children: [const Icon(Icons.star, size: 13, color: Colors.amber), const SizedBox(width: 2), Text(craftsman.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 12)), const SizedBox(width: 4), Text('(${craftsman.reviewCount})', style: TextStyle(fontSize: 11, color: Colors.grey.shade500))]),
        ]),
        trailing: PopupMenuButton<String>(
          onSelected: (val) { if (val == 'toggle') _toggleActive(craftsman); },
          itemBuilder: (_) => [PopupMenuItem(value: 'toggle', child: Text(craftsman.isActive ? 'Deaktivovať' : 'Aktivovať', style: const TextStyle(color: Colors.red)))],
        ),
      ),
    );
  }
}