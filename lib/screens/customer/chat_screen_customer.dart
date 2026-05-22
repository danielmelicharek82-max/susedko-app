// lib/screens/customer/chat_screen.dart
// ♻️  RECYCLE z chat_screen.dart (Inkmaker)
// Zmeny: farba teal → #2563EB (ostatná logika identická)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../models/message.dart';
import '../../services/chat_service.dart';

const _kPrimary = Color(0xFF2563EB);

class CustomerChatScreen extends StatefulWidget {
  final String conversationId;
  final String receiverId;
  final String? receiverName;

  const CustomerChatScreen({
    super.key,
    required this.conversationId,
    required this.receiverId,
    this.receiverName,
  });

  @override
  State<CustomerChatScreen> createState() => _CustomerChatScreenState();
}

class _CustomerChatScreenState extends State<CustomerChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _chatService = ChatService();
  final _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentUser == null) return;
    _messageController.clear();
    await _chatService.sendMessage(
      conversationId: widget.conversationId,
      senderId: _currentUser!.uid,
      receiverId: widget.receiverId,
      text: text,
    );
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.receiverName ?? 'chat'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _kPrimary, foregroundColor: Colors.white, elevation: 0),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<List<Message>>(
            stream: _chatService.watchMessages(widget.conversationId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final messages = snapshot.data!;
              if (messages.isEmpty) return Center(child: Text('noMessages'.tr(),
                  style: TextStyle(color: Colors.grey.shade400)));
              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, i) => _buildBubble(messages[i]));
            }),
        ),

        // Input
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SafeArea(child: Row(children: [
            Expanded(child: TextField(
              controller: _messageController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'typeMessage'.tr(),
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true, fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)),
              onSubmitted: (_) => _sendMessage())),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(width: 44, height: 44,
                decoration: const BoxDecoration(color: _kPrimary, shape: BoxShape.circle),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20))),
          ])),
        ),
      ]),
    );
  }

  Widget _buildBubble(Message message) {
    final isMe = message.senderId == _currentUser?.uid;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? _kPrimary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]),
        child: Text(message.text,
            style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 14)),
      ),
    );
  }
}