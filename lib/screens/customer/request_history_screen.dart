// lib/screens/customer/request_history_screen.dart
// História dopytov zákazníka — stručné záznamy po automatickom zmazaní dopytu
// (users/{uid}/request_history, zapisuje server).

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

const _kPrimary = Color(0xFF2563EB);
const _kBg      = Color(0xFFF0F4FF);

class RequestHistoryScreen extends StatelessWidget {
  const RequestHistoryScreen({super.key});

  Stream<List<Map<String, dynamic>>> _stream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('users').doc(uid).collection('request_history')
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      list.sort((a, b) {
        final ta = (a['closedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final tb = (b['closedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      });
      return list;
    });
  }

  Color _outcomeColor(String? o) {
    switch (o) {
      case 'cancelled':  return Colors.red;
      case 'unanswered': return Colors.orange;
      default:           return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        title: Text('requestHistoryTitle'.tr()),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _stream(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _kPrimary));
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('requestHistoryEmpty'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600)),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length + 1,
            itemBuilder: (ctx, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('requestHistoryNote'.tr(),
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                );
              }
              return _card(items[i - 1]);
            },
          );
        },
      ),
    );
  }

  Widget _card(Map<String, dynamic> h) {
    final profs = (h['professions'] is List && (h['professions'] as List).isNotEmpty)
        ? (h['professions'] as List).map((e) => e.toString()).toList()
        : [if (h['profession'] != null) h['profession'].toString()];
    final title = profs.map((k) => k.tr()).join(', ');
    final outcome = (h['outcome'] ?? 'cancelled').toString();
    final color = _outcomeColor(outcome);
    final created = (h['createdAt'] as Timestamp?)?.toDate();
    final n = (h['interestedCount'] as num?)?.toInt() ?? 0;
    final snippet = (h['descriptionSnippet'] ?? '').toString();
    final meta = [
      if (created != null) DateFormat.yMd().format(created),
      if (n > 0) 'requestHistoryInterested'.tr(namedArgs: {'n': '$n'}),
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: _kPrimary.withOpacity(0.06),
            blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(title.isEmpty ? '—' : title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14))),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20)),
            child: Text('requestHistory_$outcome'.tr(),
                style: TextStyle(
                    fontSize: 11, color: color, fontWeight: FontWeight.bold)),
          ),
        ]),
        if (snippet.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(snippet,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
        ],
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(meta,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ]),
    );
  }
}
