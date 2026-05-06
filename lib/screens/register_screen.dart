import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/chat_service.dart';

/// Otvorí chat bottomsheet pre konkrétny pre-order
Future<void> showPreOrderChat(
  BuildContext context, {
  required String preOrderId,
  required String customerId,
  required String manufacturerId,
  required String otherUserName,
}) async {
  // FIX 3: Pridaný try/catch – tiché zlyhanie spôsobovalo bielu obrazovku
  try {
    final conversationId = await ChatService.createOrGetPreOrderConversation(
      preOrderId: preOrderId,
      customerId: customerId,
      manufacturerId: manufacturerId,
    );

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true, // FIX 1: Opravuje problémy s notch/výrez na Androide
      backgroundColor: Colors.transparent,
      builder: (_) => PreOrderChatSheet(
        conversationId: conversationId,
        otherUserName: otherUserName,
        customerId: customerId,
        manufacturerId: manufacturerId,
      ),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chyba pri otváraní chatu: $e')),
      );
    }
  }
}

class PreOrderChatSheet extends StatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String customerId;
  final String manufacturerId;

  const PreOrderChatSheet({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    required this.customerId,
    required this.manufacturerId,
  });

  @override
  State<PreOrderChatSheet> createState() => _PreOrderChatSheetState();
}

class _PreOrderChatSheetState extends State<PreOrderChatSheet> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  String get _currentUserId => FirebaseAuth.instance.currentUser!.uid;

  String get _receiverId =>
      _currentUserId == widget.customerId
          ? widget.manufacturerId
          : widget.customerId;

  @override
  void initState() {
    super.initState();
    ChatService.markAsRead(
      conversationId: widget.conversationId,
      userId: _currentUserId,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _controller.clear();

    try {
      await ChatService.sendMessage(
        conversationId: widget.conversationId,
        senderId: _currentUserId,
        receiverId: _receiverId,
        text: text,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'error'.tr()}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // FIX 2: Reaktívny bottomInset cez Padding widget namiesto manuálneho počítania
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // ── Handle ──
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.teal.shade100,
                    child: Text(
                      widget.otherUserName.isNotEmpty
                          ? widget.otherUserName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: Colors.teal.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.otherUserName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── Správy ──
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: ChatService.getMessages(widget.conversationId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.teal),
                    );
                  }

                  // FIX 4: Explicitné spracovanie chyby streamu
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        '${'error'.tr()}: ${snapshot.error}',
                        style: TextStyle(color: Colors.red.shade400),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 48,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'startConversation'.tr(),
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                    );
                  }

                  ChatService.markAsRead(
                    conversationId: widget.conversationId,
                    userId: _currentUserId,
                  );

                  _scrollToBottom();

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data =
                          docs[index].data() as Map<String, dynamic>;
                      final isMe = data['senderId'] == _currentUserId;
                      final text = data['text'] ?? '';
                      final time = data['createdAt'] as Timestamp?;
                      final timeStr = time != null
                          ? '${time.toDate().hour.toString().padLeft(2, '0')}:${time.toDate().minute.toString().padLeft(2, '0')}'
                          : '';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: isMe
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMe) ...[
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.teal.shade100,
                                child: Text(
                                  widget.otherUserName.isNotEmpty
                                      ? widget.otherUserName[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.teal.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? Colors.teal
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft:
                                        Radius.circular(isMe ? 16 : 4),
                                    bottomRight:
                                        Radius.circular(isMe ? 4 : 16),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      text,
                                      style: TextStyle(
                                        color: isMe
                                            ? Colors.white
                                            : Colors.black87,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      timeStr,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isMe
                                            ? Colors.white70
                                            : Colors.grey.shade400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isMe) const SizedBox(width: 6),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // ── Input ──
            // FIX 2: bottomInset je teraz v Padding wrapperi vyššie, nie tu
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border:
                    Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLines: 3,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'typeMessage'.tr(),
                        hintStyle:
                            TextStyle(color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.teal,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// Starý ChatScreen – používa sa v knife_detail_screen.dart
// a customer_home / producer_home
// ═══════════════════════════════════════════════════════
class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String receiverId;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.receiverId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  String get _currentUserId => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    ChatService.markAsRead(
      conversationId: widget.conversationId,
      userId: _currentUserId,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();
    try {
      await ChatService.sendMessage(
        conversationId: widget.conversationId,
        senderId: _currentUserId,
        receiverId: widget.receiverId,
        text: text,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${'error'.tr()}: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('chat'.tr()),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      // FIX 5: resizeToAvoidBottomInset zabezpečí správne správanie klávesnice
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: ChatService.getMessages(widget.conversationId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.teal),
                  );
                }

                // FIX 4: Explicitné spracovanie chyby streamu
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      '${'error'.tr()}: ${snapshot.error}',
                      style: TextStyle(color: Colors.red.shade400),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'startConversation'.tr(),
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                  );
                }

                ChatService.markAsRead(
                  conversationId: widget.conversationId,
                  userId: _currentUserId,
                );

                _scrollToBottom();

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data =
                        docs[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == _currentUserId;
                    final text = data['text'] ?? '';
                    final time = data['createdAt'] as Timestamp?;
                    final timeStr = time != null
                        ? '${time.toDate().hour.toString().padLeft(2, '0')}:${time.toDate().minute.toString().padLeft(2, '0')}'
                        : '';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? Colors.teal
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft:
                                      Radius.circular(isMe ? 16 : 4),
                                  bottomRight:
                                      Radius.circular(isMe ? 4 : 16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    text,
                                    style: TextStyle(
                                      color: isMe
                                          ? Colors.white
                                          : Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    timeStr,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isMe
                                          ? Colors.white70
                                          : Colors.grey.shade400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border:
                  Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: 3,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'typeMessage'.tr(),
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.teal,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}