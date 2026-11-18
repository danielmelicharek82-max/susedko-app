// lib/utils/pricing.dart
//
// Centrálne pravidlá ceny. ZDROJ PRAVDY pre účtovné sumy je server
// (Cloud Functions); tieto pomocné funkcie slúžia na zobrazenie a odhady
// v appke, aby sa prirážka a DPH nepočítali natvrdo na desiatkach miest.
//
// Hodnoty sa pri štarte appky načítajú z dokumentu Firestore config/pricing
// (Pricing.load() v main.dart), takže zapnutie DPH nevyžaduje novú verziu
// appky:
//
//   config/pricing = {
//     markupPercent: 10,     // prirážka Susedka nad sadzbou remeselníka
//     vatPercent: 23,        // základná sadzba DPH
//     vatEnabled: false,     // true = zákazníkom sa ukazujú ceny s DPH
//   }
//
// Cena pre zákazníka:
//   sadzba remeselníka (bez DPH)            100,00 €
//   + prirážka Susedko 10 %                 110,00 €   ← základ pre zákazníka
//   + DPH 23 %                               25,30 €
//   = cena pre zákazníka s DPH              135,30 €
//
// DÔLEŽITÉ: vatEnabled riadi len ZOBRAZENIE v appke. To, či sa DPH reálne
// účtuje, určuje server (vatPercent na zákazke). Obe musia byť zapnuté
// naraz, inak sa zobrazená cena rozíde so strhnutou sumou.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

class Pricing {
  Pricing._();

  /// Prirážka Susedka nad sadzbou remeselníka (v %).
  static double markupPercent = 10.0;

  /// Základná sadzba DPH v SR (v %).
  static double vatPercent = 23.0;

  /// Zobrazovať zákazníkom ceny s DPH.
  static bool vatEnabled = false;

  /// Načíta pravidlá z config/pricing. Pri chybe alebo chýbajúcom dokumente
  /// ostanú predvolené hodnoty (bez DPH) — štart appky sa tým nezdrží.
  static Future<void> load() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('config')
          .doc('pricing')
          .get()
          .timeout(const Duration(seconds: 4));
      final d = snap.data();
      if (d == null) return;
      markupPercent = (d['markupPercent'] as num?)?.toDouble() ?? markupPercent;
      vatPercent = (d['vatPercent'] as num?)?.toDouble() ?? vatPercent;
      vatEnabled = d['vatEnabled'] == true;
    } catch (e) {
      debugPrint('Pricing.load: použité predvolené hodnoty ($e)');
    }
  }

  /// Dodatok k cene v UI ("s DPH"), ak sa ceny zobrazujú s DPH.
  static String get vatSuffix =>
      vatEnabled ? ' ${'price_incl_vat'.tr()}' : '';

  static double round2(double v) => (v * 100).roundToDouble() / 100;

  /// Sadzba pre zákazníka bez DPH (sadzba remeselníka + prirážka).
  static double customerNetRate(double craftsmanRate) =>
      round2(craftsmanRate * (1 + markupPercent / 100));

  /// Suma cenovej ponuky pre zákazníka bez DPH. Rovnaká prirážka ako pri
  /// hodinovej sadzbe ([markupPercent]) — jedno pravidlo pre všetko, aby
  /// zobrazená cena vždy sedela so zákazkou a faktúrou.
  static double customerQuoteNet(double craftsmanAmount) =>
      round2(craftsmanAmount * (1 + markupPercent / 100));

  /// Opak [customerNetRate]: sadzba remeselníka z ceny pre zákazníka bez DPH.
  static double craftsmanRateFromCustomerNet(double customerNetRate) =>
      round2(customerNetRate / (1 + markupPercent / 100));

  /// Cena s DPH z ceny bez DPH.
  static double withVat(double net, {double? vat}) =>
      round2(net * (1 + (vat ?? vatPercent) / 100));

  /// Suma DPH z ceny bez DPH.
  static double vatAmount(double net, {double? vat}) =>
      round2(net * (vat ?? vatPercent) / 100);
}