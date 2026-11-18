// lib/models/billing_profile.dart
//
// Fakturačné údaje používateľa (zákazník aj remeselník).
// Ukladajú sa do súkromnej kolekcie billing_profiles/{uid} — NIE do
// verejného dokumentu craftsmen/{uid}, aby IBAN a IČO nevideli ostatní.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/billing_validators.dart';

class BillingProfile {
  /// Verzia znenia súhlasu so samofakturáciou. Pri zmene textu súhlasu zvýš —
  /// uloží sa spolu s časom súhlasu ako dôkaz, s čím remeselník súhlasil.
  static const String consentVersion = 'v1';

  final String role; // 'customer' | 'craftsman'
  final String phone;
  final String legalName; // zákazník: meno alebo obchodné meno; remeselník: obchodné meno
  final String street;
  final String city;
  final String zip;
  final String country;
  final String countryCode;
  final bool isCompany; // zákazník nakupuje ako firma; remeselník je vždy true
  final String ico;
  final String dic;
  final bool vatPayer;
  final String icDph;
  final String iban; // len remeselník
  final bool selfBillingConsent; // len remeselník
  final DateTime? selfBillingConsentAt;
  final String? selfBillingConsentVersion;

  const BillingProfile({
    required this.role,
    this.phone = '',
    this.legalName = '',
    this.street = '',
    this.city = '',
    this.zip = '',
    this.country = '',
    this.countryCode = 'SK',
    this.isCompany = false,
    this.ico = '',
    this.dic = '',
    this.vatPayer = false,
    this.icDph = '',
    this.iban = '',
    this.selfBillingConsent = false,
    this.selfBillingConsentAt,
    this.selfBillingConsentVersion,
  });

  static bool _ok(String s) => s.trim().isNotEmpty;

  /// Sú údaje kompletné pre danú rolu? ([forRole] je rola, v ktorej ich
  /// práve potrebujeme — remeselník v zákazníckom režime sa posudzuje ako
  /// zákazník.)
  bool isCompleteFor(String forRole) {
    if (!BillingValidators.isValidPhone(phone)) return false;
    if (!_ok(legalName) || !_ok(street) || !_ok(city) || !_ok(country)) {
      return false;
    }
    if (!BillingValidators.isValidZip(zip, countryCode)) return false;

    final needsCompanyData = forRole == 'craftsman' || isCompany;
    if (needsCompanyData) {
      if (!BillingValidators.isValidIco(ico, countryCode)) return false;
      if (!BillingValidators.isValidDic(dic, countryCode)) return false;
      if (vatPayer && !BillingValidators.isValidIcDph(icDph, countryCode)) {
        return false;
      }
    }
    if (forRole == 'craftsman') {
      if (!BillingValidators.isValidIban(iban)) return false;
      if (!selfBillingConsent) return false;
    }
    return true;
  }

  /// Mapa pre Firestore. Čas súhlasu a updatedAt dopĺňa služba.
  Map<String, dynamic> toMap() => {
        'role': role,
        'phone': phone,
        'legalName': legalName,
        'street': street,
        'city': city,
        'zip': zip,
        'country': country,
        'countryCode': countryCode,
        'isCompany': isCompany,
        'ico': ico,
        'dic': dic,
        'vatPayer': vatPayer,
        'icDph': icDph,
        'iban': iban,
        'selfBillingConsent': selfBillingConsent,
      };

  static String _s(Object? v) => (v ?? '').toString();

  factory BillingProfile.fromMap(Map<String, dynamic> m) {
    return BillingProfile(
      role: _s(m['role']).isEmpty ? 'customer' : _s(m['role']),
      phone: _s(m['phone']),
      legalName: _s(m['legalName']),
      street: _s(m['street']),
      city: _s(m['city']),
      zip: _s(m['zip']),
      country: _s(m['country']),
      countryCode: _s(m['countryCode']).isEmpty ? 'SK' : _s(m['countryCode']),
      isCompany: m['isCompany'] == true,
      ico: _s(m['ico']),
      dic: _s(m['dic']),
      vatPayer: m['vatPayer'] == true,
      icDph: _s(m['icDph']),
      iban: _s(m['iban']),
      selfBillingConsent: m['selfBillingConsent'] == true,
      selfBillingConsentAt: m['selfBillingConsentAt'] is Timestamp
          ? (m['selfBillingConsentAt'] as Timestamp).toDate()
          : null,
      selfBillingConsentVersion: m['selfBillingConsentVersion'] as String?,
    );
  }
}
