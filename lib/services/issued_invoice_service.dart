// lib/services/issued_invoice_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/issued_invoice.dart';

class IssuedInvoiceService {
  IssuedInvoiceService._();

  /// Doklady, ktorých príjemcom je [uid] (zákazník = jeho faktúry,
  /// remeselník = jeho samofaktúry). Zoradené od najnovšieho. Zoradenie sa robí
  /// v pamäti, aby dotaz nevyžadoval zložený index vo Firestore.
  static Stream<List<IssuedInvoice>> watchMine(String uid) {
    return FirebaseFirestore.instance
        .collection('invoices')
        .where('recipientId', isEqualTo: uid)
        .snapshots()
        .map((s) {
      final list = s.docs.map(IssuedInvoice.fromFirestore).toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(2000))
          .compareTo(a.createdAt ?? DateTime(2000)));
      return list;
    });
  }

  /// Krátkodobý odkaz na PDF alebo XML dokladu (server overí, že doklad patrí
  /// prihlásenému používateľovi).
  static Future<String> downloadUrl(String invoiceId, {bool xml = false}) async {
    final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('getInvoiceDownloadUrl');
    final res = await callable.call({
      'invoiceId': invoiceId,
      'kind': xml ? 'xml' : 'pdf',
    });
    return (res.data['url'] as String);
  }
}
