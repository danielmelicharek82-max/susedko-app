// lib/utils/billing_validators.dart
//
// Validácie fakturačných údajov.
//  • Pre Slovensko (countryCode == 'SK') platia prísne formáty.
//  • Pre ostatné krajiny stačí neprázdna hodnota — formáty identifikátorov
//    sa v EÚ líšia (NIP, adószám, ...), preto ich tu neodhadujeme.
//
// bool metódy (isValid...) používa model BillingProfile.isComplete,
// String? metódy sa dajú priamo použiť ako validator vo formulári.

import 'package:easy_localization/easy_localization.dart';

class BillingValidators {
  BillingValidators._();

  static String _digits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');
  static String _compact(String s) =>
      s.replaceAll(RegExp(r'\s+'), '').toUpperCase();

  // ── bool kontroly ─────────────────────────────────────────────────────────
  static bool isValidPhone(String s) {
    final v = s.trim();
    if (!RegExp(r'^\+?[0-9 ()/\-]+$').hasMatch(v)) return false;
    final d = _digits(v);
    return d.length >= 9 && d.length <= 15;
  }

  static bool isValidZip(String s, String countryCode) {
    final v = s.trim();
    if (countryCode == 'SK') return _digits(v).length == 5 &&
        RegExp(r'^[0-9 ]+$').hasMatch(v);
    return v.length >= 3;
  }

  static bool isValidIco(String s, String countryCode) {
    final v = _compact(s);
    if (countryCode == 'SK') return RegExp(r'^[0-9]{8}$').hasMatch(v);
    return v.length >= 4;
  }

  static bool isValidDic(String s, String countryCode) {
    final v = _compact(s);
    if (countryCode == 'SK') return RegExp(r'^[0-9]{10}$').hasMatch(v);
    return v.length >= 4;
  }

  static bool isValidIcDph(String s, String countryCode) {
    final v = _compact(s);
    if (countryCode == 'SK') return RegExp(r'^SK[0-9]{10}$').hasMatch(v);
    return v.length >= 4;
  }

  /// IBAN s kontrolným súčtom (mod 97).
  static bool isValidIban(String s) {
    final iban = _compact(s);
    if (!RegExp(r'^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$').hasMatch(iban)) {
      return false;
    }
    final rearranged = iban.substring(4) + iban.substring(0, 4);
    var remainder = 0;
    for (final ch in rearranged.split('')) {
      final code = ch.codeUnitAt(0);
      final value = (code >= 65 && code <= 90) ? (code - 55).toString() : ch;
      for (final d in value.split('')) {
        remainder = (remainder * 10 + int.parse(d)) % 97;
      }
    }
    return remainder == 1;
  }

  // ── validátory pre formulár (String? = text chyby, null = v poriadku) ─────
  static String? notEmpty(String? v) =>
      (v == null || v.trim().isEmpty) ? 'billing_err_required'.tr() : null;

  static String? phone(String? v) {
    final e = notEmpty(v);
    if (e != null) return e;
    return isValidPhone(v!) ? null : 'billing_err_phone'.tr();
  }

  static String? zip(String? v, {required String countryCode}) {
    final e = notEmpty(v);
    if (e != null) return e;
    return isValidZip(v!, countryCode) ? null : 'billing_err_zip'.tr();
  }

  static String? ico(String? v, {required String countryCode}) {
    final e = notEmpty(v);
    if (e != null) return e;
    return isValidIco(v!, countryCode) ? null : 'billing_err_ico'.tr();
  }

  static String? dic(String? v, {required String countryCode}) {
    final e = notEmpty(v);
    if (e != null) return e;
    return isValidDic(v!, countryCode) ? null : 'billing_err_dic'.tr();
  }

  static String? icDph(String? v, {required String countryCode}) {
    final e = notEmpty(v);
    if (e != null) return e;
    return isValidIcDph(v!, countryCode) ? null : 'billing_err_ic_dph'.tr();
  }

  static String? iban(String? v) {
    final e = notEmpty(v);
    if (e != null) return e;
    return isValidIban(v!) ? null : 'billing_err_iban'.tr();
  }
}
