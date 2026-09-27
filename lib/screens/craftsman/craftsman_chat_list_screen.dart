// lib/screens/craftsman/craftsman_chat_list_screen.dart
//
// Zoznam všetkých konverzácií remeselníka — doteraz jediný spôsob, ako sa
// remeselník dozvedel o novej správe od zákazníka, bola push notifikácia;
// v appke pre ne neexistovalo žiadne miesto, kde by si ich vôbec našiel.
// Táto obrazovka to rieši a je dostupná z profilu (AppBar ikonka + banner).

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/chat_service.dart';
import '../chat_screen.dart';

const _kPrimary = Color(0xFF2563EB);
const _kBg      = Color(0xFFF0F4FF);

class CraftsmanChatListScreen extends StatefulWidget {
  const CraftsmanChatListScreen({super.key});

  @override
  State<CraftsmanChatListScreen> createState() =>
      _CraftsmanChatListScreenState();
}

class _CraftsmanChatListScreenState extends State<CraftsmanChatListScreen> {
  final _chatService = ChatService();
  final Map<String, String> _nameCache = {};

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<String> _nameFor(String uid) async {
    final cached = _nameCache[uid];
    if (cached != null) return cached;
    final name = await ChatService.getUserName(uid);
    _nameCache[uid] = name;
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text('myMessages'.tr(),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _kPrimary,
        elevation: 0,
      ),
      body: uid.isEmpty
          ? Center(child: Text('error'.tr()))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _chatService.getConversationsForUser(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: _kPrimary));
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('${'error'.tr()}: ${snapshot.error}',
                          style: TextStyle(color: Colors.red.shade400)));
                }
                final convs = snapshot.data ?? [];
                if (convs.isEmpty) {
                  return Center(
                      child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 14),
                      Text('noMessages'.tr(),
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 14)),
                    ]),
                  ));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: convs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _convTile(convs[i], uid),
                );
              },
            ),
    );
  }

  Widget _convTile(Map<String, dynamic> conv, String uid) {
    final participants = List<String>.from(conv['participants'] ?? []);
    final otherUid =
        participants.firstWhere((p) => p != uid, orElse: () => '');
    if (otherUid.isEmpty) return const SizedBox.shrink();

    final lastMessage = (conv['lastMessage'] ?? '') as String;
    final lastMessageAt = conv['lastMessageAt'] as Timestamp?;
    final convId = conv['id'] as String;

    return FutureBuilder<String>(
      future: _nameFor(otherUid),
      builder: (context, nameSnap) {
        final name = nameSnap.data ?? '…';
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('conversations')
              .doc(convId)
              .collection('messages')
              .where('receiverId', isEqualTo: uid)
              .where('read', isEqualTo: false)
              .snapshots(),
          builder: (context, unreadSnap) {
            final unread = unreadSnap.data?.docs.length ?? 0;
            return GestureDetector(
              onTap: () async {
                await ChatService.markAsRead(
                    conversationId: convId, userId: uid);
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                        conversationId: convId, receiverId: otherUid),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: _kPrimary.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: Row(children: [
                  CircleAvatar(
                      radius: 22,
                      backgroundColor: _kPrimary.withOpacity(0.1),
                      child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: _kPrimary,
                              fontWeight: FontWeight.bold))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(name,
                          style: TextStyle(
                              fontWeight: unread > 0
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              fontSize: 14,
                              color: const Color(0xFF1E293B))),
                      const SizedBox(height: 3),
                      Text(
                          lastMessage.isEmpty
                              ? 'startConversation'.tr()
                              : lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.5,
                              color: unread > 0
                                  ? const Color(0xFF1E293B)
                                  : Colors.grey.shade500,
                              fontWeight: unread > 0
                                  ? FontWeight.w600
                                  : FontWeight.normal)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (lastMessageAt != null)
                          Text(_formatTime(lastMessageAt.toDate()),
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade400)),
                        if (unread > 0) ...[
                          const SizedBox(height: 6),
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text('$unread',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold))),
                        ],
                      ]),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  String _formatTime(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}';
  }
}
