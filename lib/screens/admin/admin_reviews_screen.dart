// lib/screens/admin/admin_reviews_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../models/review.dart';

class AdminReviewsScreen extends StatefulWidget {
  const AdminReviewsScreen({super.key});

  @override
  State<AdminReviewsScreen> createState() => _AdminReviewsScreenState();
}

class _AdminReviewsScreenState extends State<AdminReviewsScreen> {
  static const _kPrimary = Color(0xFF2563EB);
  static const _kBg = Color(0xFFF8FAFC);

  String _filter = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();

    final reviews = provider.reviews.where((r) {
      if (_filter == 'approved' && !r.isApproved) return false;
      if (_filter == 'pending' && r.isApproved) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return r.customerName.toLowerCase().contains(q) ||
            (r.comment?.toLowerCase().contains(q) ?? false);
      }
      return true;
    }).toList();

    final totalCount = provider.reviews.length;
    final pendingCount = provider.reviews.where((r) => !r.isApproved).length;
    final avgRating = totalCount > 0
        ? provider.reviews.fold(0.0, (sum, r) => sum + r.rating) / totalCount
        : 0.0;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text('Recenzie (${reviews.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _kPrimary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                _StatBadge(label: 'Celkom', value: '$totalCount', color: _kPrimary),
                const SizedBox(width: 10),
                _StatBadge(label: 'Čakajú', value: '$pendingCount', color: Colors.orange),
                const SizedBox(width: 10),
                _StatBadge(label: 'Priemer', value: avgRating > 0 ? avgRating.toStringAsFixed(1) : '–', color: Colors.amber, icon: Icons.star_rounded),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Hľadať...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); }) : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                _FilterChip(label: 'Všetky', selected: _filter == 'all', color: Colors.grey, onTap: () => setState(() => _filter = 'all')),
                const SizedBox(width: 8),
                _FilterChip(label: 'Čakajúce', selected: _filter == 'pending', color: Colors.orange, onTap: () => setState(() => _filter = 'pending')),
                const SizedBox(width: 8),
                _FilterChip(label: 'Schválené', selected: _filter == 'approved', color: Colors.green, onTap: () => setState(() => _filter = 'approved')),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: reviews.isEmpty
                ? const Center(child: Text('Žiadne recenzie'))
                : ListView.builder(itemCount: reviews.length, itemBuilder: (context, index) => _ReviewTile(review: reviews[index])),
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label; final String value; final Color color; final IconData? icon;
  const _StatBadge({required this.label, required this.value, required this.color, this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
      ]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label; final bool selected; final Color color; final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: selected ? color.withOpacity(0.15) : Colors.grey.shade100, borderRadius: BorderRadius.circular(20), border: Border.all(color: selected ? color : Colors.grey.shade300)),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.bold : FontWeight.normal, color: selected ? color : Colors.grey.shade600)),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final Review review;
  const _ReviewTile({required this.review});
  @override
  Widget build(BuildContext context) {
    final provider = context.read<AdminProvider>();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 16, backgroundColor: Colors.blue.shade100, child: Text(review.customerName.isNotEmpty ? review.customerName[0].toUpperCase() : '?', style: TextStyle(color: Colors.blue.shade700, fontSize: 13))),
            const SizedBox(width: 8),
            Expanded(child: Text(review.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: review.isApproved ? Colors.green.shade50 : Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: review.isApproved ? Colors.green.shade300 : Colors.orange.shade300)),
              child: Text(review.isApproved ? 'Schválená' : 'Čaká', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: review.isApproved ? Colors.green.shade700 : Colors.orange.shade700)),
            ),
          ]),
          const SizedBox(height: 6),
          Row(children: List.generate(5, (i) => Icon(i < review.rating ? Icons.star : Icons.star_border, size: 16, color: Colors.amber))),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(review.comment!, style: const TextStyle(fontSize: 13, color: Colors.black87)),
          ],
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (!review.isApproved)
              TextButton.icon(icon: const Icon(Icons.check_circle_outline, size: 18), label: const Text('Schváliť'), style: TextButton.styleFrom(foregroundColor: Colors.green), onPressed: () => provider.approveReview(review.id)),
            const SizedBox(width: 8),
            TextButton.icon(icon: const Icon(Icons.delete_outline, size: 18), label: const Text('Zmazať'), style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Zmazať recenziu?'), content: const Text('Táto akcia je nevratná.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Zrušiť')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: const Text('Zmazať', style: TextStyle(color: Colors.white)))]));
                if (confirm == true) provider.deleteReview(review.id);
              },
            ),
          ]),
        ]),
      ),
    );
  }
}