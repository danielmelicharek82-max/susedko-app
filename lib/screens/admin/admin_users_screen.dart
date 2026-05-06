// lib/screens/admin/admin_users_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../models/app_user.dart';
import 'admin_user_detail_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  static const _kPrimary = Color(0xFF2563EB);
  static const _kBg = Color(0xFFF8FAFC);

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _roleFilter = 'all';

  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    if (provider.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final users = provider.users.where((u) {
      if (u.role == 'admin') return false;
      if (_roleFilter != 'all' && u.role != _roleFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return u.name.toLowerCase().contains(q) || u.email.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text('Používatelia (${users.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _kPrimary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Hľadať podľa mena, emailu...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); }) : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: [
            _FilterChip(label: 'Všetci', selected: _roleFilter == 'all', color: Colors.grey, onTap: () => setState(() => _roleFilter = 'all')),
            const SizedBox(width: 8),
            _FilterChip(label: 'Zákazníci', selected: _roleFilter == 'customer', color: _kPrimary, onTap: () => setState(() => _roleFilter = 'customer')),
            const SizedBox(width: 8),
            _FilterChip(label: 'Remeselníci', selected: _roleFilter == 'craftsman', color: Colors.orange, onTap: () => setState(() => _roleFilter = 'craftsman')),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: users.isEmpty
              ? const Center(child: Text('Žiadni používatelia'))
              : ListView.builder(itemCount: users.length, itemBuilder: (context, index) => _UserTile(user: users[index])),
        ),
      ]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label; final bool selected; final Color color; final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: selected ? color.withOpacity(0.15) : Colors.grey.shade100, borderRadius: BorderRadius.circular(20), border: Border.all(color: selected ? color : Colors.grey.shade300)),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.bold : FontWeight.normal, color: selected ? color : Colors.grey.shade600)),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final AppUser user;
  const _UserTile({required this.user});

  Color _roleColor(String role) {
    switch (role) {
      case 'craftsman': return Colors.orange;
      case 'customer': return const Color(0xFF2563EB);
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
    return ListTile(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminUserDetailScreen(user: user))),
      leading: CircleAvatar(backgroundColor: _roleColor(user.role), child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white))),
      title: Text(user.name.isNotEmpty ? user.name : user.email),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(user.email, style: const TextStyle(fontSize: 13)),
        Text(_roleLabel(user.role), style: TextStyle(color: _roleColor(user.role), fontSize: 12, fontWeight: FontWeight.bold)),
      ]),
      isThreeLine: true,
      trailing: IconButton(
        icon: const Icon(Icons.block, size: 20),
        color: Colors.red,
        onPressed: () => provider.toggleUserBlocked(user.id, true),
      ),
    );
  }
}