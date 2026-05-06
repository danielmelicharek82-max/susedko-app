// lib/widgets/maker_rating_widget.dart
// ♻️  RECYCLE z maker_rating_widget.dart (Inkmaker)
// Zmeny: artistId → craftsmanId, kolekcia 'artists' → 'craftsmen', teal → #2563EB

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review.dart';

const _kPrimary = Color(0xFF2563EB);

// ─── 1. KOMPAKTNÝ BADGE ──────────────────────────────────────────────────────
class MakerRatingBadge extends StatelessWidget {
  final double averageRating;
  final int reviewCount;
  final double iconSize;
  final double fontSize;

  const MakerRatingBadge({
    super.key,
    required this.averageRating,
    required this.reviewCount,
    this.iconSize = 14,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    if (reviewCount == 0) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.star_rounded, color: Colors.amber, size: iconSize),
      const SizedBox(width: 3),
      Text(averageRating.toStringAsFixed(1),
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A))),
      const SizedBox(width: 3),
      Text('($reviewCount)', style: TextStyle(fontSize: fontSize - 1, color: Colors.grey[600])),
    ]);
  }
}

// ─── 2. STREDNÝ SÚHRN ────────────────────────────────────────────────────────
class MakerRatingSummary extends StatelessWidget {
  final String craftsmanId;
  const MakerRatingSummary({super.key, required this.craftsmanId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('craftsmen').doc(craftsmanId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final avg = ((data?['rating'] ?? data?['averageRating'] ?? 0.0) as num).toDouble();
        final count = (data?['reviewCount'] ?? 0) as int;

        if (count == 0) {
          return Padding(padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Zatiaľ žiadne hodnotenia',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13)));
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kPrimary.withOpacity(0.05), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kPrimary.withOpacity(0.15))),
          child: Row(children: [
            Column(children: [
              Text(avg.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A), height: 1)),
              const SizedBox(height: 4),
              _StarRow(rating: avg, size: 16),
              const SizedBox(height: 4),
              Text('$count hodnotení', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ]),
            const SizedBox(width: 20),
            const VerticalDivider(width: 1, color: Color(0xFFE0DDD8)),
            const SizedBox(width: 20),
            Expanded(child: _RatingBarsFromCraftsmanId(craftsmanId: craftsmanId, total: count)),
          ]),
        );
      },
    );
  }
}

// ─── 3. PLNÝ ZOZNAM RECENZIÍ ─────────────────────────────────────────────────
class MakerReviewsList extends StatelessWidget {
  final String craftsmanId;
  final int limit;
  const MakerReviewsList({super.key, required this.craftsmanId, this.limit = 20});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('reviews')
          .where('craftsmanId', isEqualTo: craftsmanId)
          .orderBy('createdAt', descending: true).limit(limit).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(24),
              child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Padding(padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Column(children: [
              Icon(Icons.rate_review_outlined, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text('Zatiaľ žiadne recenzie', style: TextStyle(color: Colors.grey[500])),
            ])));
        }
        final reviews = snapshot.data!.docs
            .map((doc) => Review.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
        return ListView.separated(
          physics: const NeverScrollableScrollPhysics(), shrinkWrap: true,
          itemCount: reviews.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEDE9E0)),
          itemBuilder: (context, i) => _ReviewTile(review: reviews[i]));
      },
    );
  }
}

// ─── 4. RATING DISTRIBUTION BAR ──────────────────────────────────────────────
class RatingDistributionBar extends StatelessWidget {
  final Map<int, int> distribution;
  final int total;
  const RatingDistributionBar({super.key, required this.distribution, required this.total});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min,
      children: [5, 4, 3, 2, 1].map((star) {
        final count = distribution[star] ?? 0;
        final fraction = total > 0 ? count / total : 0.0;
        return Padding(padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Text('$star', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            const SizedBox(width: 4),
            const Icon(Icons.star_rounded, size: 11, color: Colors.amber),
            const SizedBox(width: 6),
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: fraction,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                  minHeight: 6))),
            const SizedBox(width: 6),
            SizedBox(width: 20, child: Text('$count',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]), textAlign: TextAlign.end)),
          ]));
      }).toList());
  }
}

// ─── PRIVATE HELPERS ─────────────────────────────────────────────────────────
class _StarRow extends StatelessWidget {
  final double rating;
  final double size;
  const _StarRow({required this.rating, required this.size});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = rating >= i + 1;
        final half = !filled && rating >= i + 0.5;
        return Icon(
          half ? Icons.star_half_rounded : filled ? Icons.star_rounded : Icons.star_outline_rounded,
          color: Colors.amber, size: size);
      }));
  }
}

class _ReviewTile extends StatelessWidget {
  final Review review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 18, backgroundColor: _kPrimary.withOpacity(0.1),
            child: Text(review.customerName.isNotEmpty ? review.customerName[0].toUpperCase() : '?',
                style: TextStyle(fontWeight: FontWeight.w700, color: _kPrimary))),
          const SizedBox(width: 10),
          Expanded(child: Text(review.customerName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _StarRow(rating: review.rating, size: 14),
            const SizedBox(height: 2),
            Text('${review.createdAt.day}.${review.createdAt.month}.${review.createdAt.year}',
                style: TextStyle(fontSize: 11, color: Colors.grey[400])),
          ]),
        ]),
        if (review.comment != null && review.comment!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(review.comment!,
              style: const TextStyle(fontSize: 14, color: Color(0xFF3D3D3D), height: 1.5)),
        ],
      ]));
  }
}

class _RatingBarsFromCraftsmanId extends StatelessWidget {
  final String craftsmanId;
  final int total;
  const _RatingBarsFromCraftsmanId({required this.craftsmanId, required this.total});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('reviews')
          .where('craftsmanId', isEqualTo: craftsmanId).snapshots(),
      builder: (context, snapshot) {
        final dist = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final r = (((doc.data() as Map)['rating'] ?? 0) as num).toInt().clamp(1, 5);
            dist[r] = (dist[r] ?? 0) + 1;
          }
        }
        return RatingDistributionBar(distribution: dist, total: total);
      });
  }
}
