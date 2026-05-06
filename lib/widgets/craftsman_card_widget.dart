// lib/widgets/craftsman_card_widget.dart
// 🆕 NOVÉ pre Homie — nahrádza artist_card_widget.dart
// Univerzálna karta remeselníka použiteľná v zoznamoch, vyhľadávaní

import 'package:flutter/material.dart';
import '../models/craftsman.dart';

const _kPrimary = Color(0xFF2563EB);

class CraftsmanCard extends StatelessWidget {
  final Craftsman craftsman;
  final String? distance;       // napr. "2.3 km"
  final VoidCallback? onTap;
  final bool showDistance;

  const CraftsmanCard({
    super.key,
    required this.craftsman,
    this.distance,
    this.onTap,
    this.showDistance = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.only(bottom: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
          // Avatar
          Stack(children: [
            CircleAvatar(radius: 32,
              backgroundImage: craftsman.profileImage != null
                  ? NetworkImage(craftsman.profileImage!) : null,
              backgroundColor: _kPrimary.withOpacity(0.1),
              child: craftsman.profileImage == null
                  ? const Icon(Icons.person, color: _kPrimary, size: 32) : null),
            if (craftsman.isVerified)
              Positioned(bottom: 0, right: 0,
                child: Container(width: 18, height: 18,
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5)),
                  child: const Icon(Icons.verified, size: 14, color: _kPrimary))),
          ]),
          const SizedBox(width: 14),

          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Meno
            Text(craftsman.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 3),

            // Profesia badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Text(craftsman.profession,
                  style: const TextStyle(fontSize: 11, color: _kPrimary, fontWeight: FontWeight.w600))),
            const SizedBox(height: 4),

            // Lokalita + vzdialenosť
            if (craftsman.cityName != null)
              Row(children: [
                Icon(Icons.location_on, size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 2),
                Expanded(child: Text(craftsman.fullAddress ?? craftsman.cityName!,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
                if (showDistance && distance != null) ...[
                  const SizedBox(width: 6),
                  Text('· $distance',
                      style: TextStyle(fontSize: 12, color: _kPrimary, fontWeight: FontWeight.bold)),
                ],
              ]),
            const SizedBox(height: 6),

            // Skills chips
            if (craftsman.skills.isNotEmpty)
              Wrap(spacing: 4, runSpacing: 4,
                children: craftsman.skills.take(3).map((s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
                  child: Text(s, style: TextStyle(fontSize: 10, color: _kPrimary)))).toList()),
            const SizedBox(height: 6),

            // Rating + cena
            Row(children: [
              const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
              const SizedBox(width: 2),
              Text(craftsman.rating.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              Text('(${craftsman.reviewCount})',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              if (craftsman.hourlyRate != null) ...[
                const Spacer(),
                Text('${craftsman.hourlyRate!.toStringAsFixed(0)} €/h',
                    style: const TextStyle(fontSize: 13, color: _kPrimary, fontWeight: FontWeight.bold)),
              ],
            ]),
          ])),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ])),
      ),
    );
  }
}
