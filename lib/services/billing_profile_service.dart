// lib/services/billing_profile_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/billing_profile.dart';

class BillingProfileService {
  BillingProfileService._();

  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('billing_profiles');

  static Future<BillingProfile?> load(String uid) async {
    final snap = await _col.doc(uid).get();
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return BillingProfile.fromMap(data);
  }

  static Stream<BillingProfile?> watch(String uid) {
    return _col.doc(uid).snapshots().map((s) {
      final data = s.data();
      if (!s.exists || data == null) return null;
      return BillingProfile.fromMap(data);
    });
  }

  /// Uloží fakturačné údaje. [previous] je naposledy načítaný profil — slúži
  /// na zachovanie pôvodného času súhlasu so samofakturáciou (čas sa nemení
  /// pri každom uložení, len keď súhlas pribudne).
  static Future<void> save(String uid, BillingProfile p,
      {BillingProfile? previous}) async {
    final data = p.toMap();
    data['updatedAt'] = FieldValue.serverTimestamp();

    if (p.selfBillingConsent) {
      final alreadyConsented = previous != null &&
          previous.selfBillingConsent &&
          previous.selfBillingConsentAt != null;
      if (alreadyConsented) {
        data['selfBillingConsentAt'] =
            Timestamp.fromDate(previous!.selfBillingConsentAt!);
        data['selfBillingConsentVersion'] =
            previous.selfBillingConsentVersion ??
                BillingProfile.consentVersion;
      } else {
        data['selfBillingConsentAt'] = FieldValue.serverTimestamp();
        data['selfBillingConsentVersion'] = BillingProfile.consentVersion;
      }
    } else {
      data['selfBillingConsentAt'] = null;
      data['selfBillingConsentVersion'] = null;
    }

    await _col.doc(uid).set(data, SetOptions(merge: true));

    // Telefón zrkadlíme aj do users/{uid} (AppUser.phone), nech ho majú aj
    // ostatné časti appky. Zlyhanie tu nesmie zhodiť uloženie profilu.
    try {
      await _db
          .collection('users')
          .doc(uid)
          .set({'phone': p.phone}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('BillingProfileService: zrkadlenie telefónu zlyhalo: $e');
    }
  }

  /// Má používateľ kompletné fakturačné údaje pre danú rolu?
  ///
  /// Pri CHYBE čítania (napr. pravidlá Firestore ešte nenasadené) vracia
  /// true — nechceme zablokovať všetkých používateľov kvôli konfigurácii.
  /// Chýbajúci dokument alebo neúplné údaje vracajú false.
  static Future<bool> isReady(String uid, String role) async {
    try {
      final p = await load(uid);
      return p != null && p.isCompleteFor(role);
    } catch (e) {
      debugPrint('BillingProfileService.isReady: chyba čítania, '
          'pokračujem bez blokovania: $e');
      return true;
    }
  }
}
