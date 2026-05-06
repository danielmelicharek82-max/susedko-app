// lib/providers/chat_provider.dart
// ♻️  RECYCLE — rovnaká logika ako v nožovom projekte
// Zmeny: žiadne — chat funguje identicky pre tatér app

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  int _unreadCount = 0;
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = false;

  StreamSubscription<int>? _unreadSub;
  StreamSubscription<List<Map<String, dynamic>>>? _convSub;

  // Gettery
  int get unreadCount => _unreadCount;
  List<Map<String, dynamic>> get conversations => _conversations;
  bool get isLoading => _isLoading;
  bool get hasUnread => _unreadCount > 0;

  final ChatService _chatService = ChatService();

  // ─────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────

  void init() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _listenUnread(user.uid);
    _listenConversations(user.uid);
  }

  void _listenUnread(String userId) {
    _unreadSub?.cancel();
    _unreadSub =
        _chatService.getUnreadChatsCount(userId).listen((count) {
      _unreadCount = count;
      notifyListeners();
    });
  }

  void _listenConversations(String userId) {
    _convSub?.cancel();
    _isLoading = true;
    notifyListeners();

    _convSub =
        _chatService.getConversationsForUser(userId).listen((convs) {
      _conversations = convs;
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      debugPrint('>>> ChatProvider._listenConversations error: $e');
      _isLoading = false;
      notifyListeners();
    });
  }

  // ─────────────────────────────────────────
  // AKCIE
  // ─────────────────────────────────────────

  Future<void> markAllAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    for (final conv in _conversations) {
      await ChatService.markAsRead(
        conversationId: conv['id'],
        userId: user.uid,
      );
    }
  }

  Future<String> getOrCreateConversation({
    required String otherUserId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not logged in');
    return _chatService.getOrCreateConversation(
      userId1: user.uid,
      userId2: otherUserId,
    );
  }

  // ─────────────────────────────────────────
  // CLEANUP
  // ─────────────────────────────────────────

  @override
  void dispose() {
    _unreadSub?.cancel();
    _convSub?.cancel();
    super.dispose();
  }
}