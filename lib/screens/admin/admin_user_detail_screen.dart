// lib/screens/admin/admin_user_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_user.dart';
import '../../providers/admin_provider.dart';

class AdminUserDetailScreen extends StatelessWidget {
  final AppUser user;
  const AdminUserDetailScreen({super.key, required this.user});

  static const _kPrimary = Color(0xFF2563EB);
  static const _kBg = Color(0xFFF8FAFC);
  static const _kText = Color(0xFF111827);

  Color _roleColor(String role) {
    switch (role) {
      case 'craftsman': return Colors.orange;
      case 'customer': return _kPrimary;
      default: return Colors.grey;
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'craftsman': return 'Remeselník';
      case 'customer': return 'Zákazník';
      default: return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AdminProvider>();
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text(user.name.isNotEmpty ? user.name : user.email, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _kPrimary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Center(child: Column(children: [
          CircleAvatar(radius: 40, backgroundColor: _roleColor(user.role), child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold))),
          const SizedBox(height: 12),
          Text(user.name.isNotEmpty ? user.name : '—', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _kText)),
          const SizedBox(height: 4),
          Text(user.email, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: _roleColor(user.role).withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: _roleColor(user.role).withOpacity(0.4))),
            child: Text(_roleLabel(user.role), style: TextStyle(color: _roleColor(user.role), fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ])),
        const SizedBox(height: 24),
        const Divider(),
        _InfoRow(label: 'ID', value: user.id),
        _InfoRow(label: 'Registrovaný', value: user.createdAt != null ? '${user.createdAt!.day}.${user.createdAt!.month}.${user.createdAt!.year}' : '—'),
        const SizedBox(height: 32),
        OutlinedButton.icon(
          icon: const Icon(Icons.block, color: Colors.red),
          label: const Text('Zablokovať používateľa', style: TextStyle(color: Colors.red)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: () { provider.toggleUserBlocked(user.id, true); Navigator.pop(context); },
        ),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label; final String value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 110, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}