// lib/screens/admin/admin_chat_screen.dart

import 'package:flutter/material.dart';

class AdminChatScreen extends StatelessWidget {
  const AdminChatScreen({super.key});

  static const _kPrimary = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chaty', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _kPrimary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView.builder(
        itemCount: 10,
        itemBuilder: (context, index) {
          return ListTile(
            leading: const Icon(Icons.chat_outlined),
            title: Text('Konverzácia $index'),
            subtitle: const Text('Posledná správa: Ahoj!'),
            onTap: () {},
          );
        },
      ),
    );
  }
}