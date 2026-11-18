// lib/models/quote.dart
//
// Cenová ponuka remeselníka k broadcast dopytu.
// Uložená v subkolekcii service_requests/{requestId}/quotes/{craftsmanId}
// (jedna ponuka na remeselníka; úprava prepíše tú istú). Subkolekcia je
// zámerná: samotný dopyt je verejne čitateľný (web), ponuky nie.
//
// Remeselník zadáva sumy BEZ DPH. Zákazník vidí sumu navýšenú o prirážku
// Susedka (Pricing.markupPercent, 10 %) a (ak je zapnutá) DPH. Server je zdrojom pravdy pre platby;
// tu ide len o zobrazenie.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/pricing.dart';

String formatQuoteDate(DateTime d) => '${d.day}.${d.month}.${d.year}';

class Quote {
  final String craftsmanId;
  final String craftsmanName;
  final double labor;      // práca, bez DPH, cena remeselníka
  final double material;   // materiál, bez DPH, cena remeselníka
  final String? materialNote;
  final String? duration;  // voľný text: termín nástupu / trvanie
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Quote({
    required this.craftsmanId,
    required this.craftsmanName,
    required this.labor,
    this.material = 0,
    this.materialNote,
    this.duration,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  // ── Pohľad remeselníka (bez DPH, bez prirážky) ───────────────────────────
  double get craftsmanNet => Pricing.round2(labor + material);

  // ── Pohľad zákazníka ─────────────────────────────────────────────────────
  // Remeselník zadá sumy; zákazník vidí o prirážku Susedka (Pricing.
  // markupPercent, 10 %) viac. Prirážku počítame z CELKU a časť
  // "materiál" je dopočítaná z rozdielu, aby sa súčet vždy zhodoval.
  double get customerNet => Pricing.customerQuoteNet(craftsmanNet);
  double get customerLabor => Pricing.customerQuoteNet(labor);
  double get customerMaterial => Pricing.round2(customerNet - customerLabor);
  double get customerVat =>
      Pricing.vatEnabled ? Pricing.vatAmount(customerNet) : 0;
  double get customerGross => Pricing.round2(customerNet + customerVat);

  Map<String, dynamic> toMap() => {
        'craftsmanId': craftsmanId,
        'craftsmanName': craftsmanName,
        'labor': labor,
        'material': material,
        'materialNote': materialNote,
        'duration': duration,
        'note': note,
        'craftsmanNet': craftsmanNet,
      };

  factory Quote.fromMap(String id, Map<String, dynamic> d) {
    DateTime? ts(dynamic v) => v is Timestamp ? v.toDate() : null;
    return Quote(
      craftsmanId: (d['craftsmanId'] as String?) ?? id,
      craftsmanName: (d['craftsmanName'] as String?) ?? '',
      labor: (d['labor'] as num?)?.toDouble() ?? 0,
      material: (d['material'] as num?)?.toDouble() ?? 0,
      materialNote: d['materialNote'] as String?,
      duration: d['duration'] as String?,
      note: d['note'] as String?,
      createdAt: ts(d['createdAt']),
      updatedAt: ts(d['updatedAt']),
    );
  }
}