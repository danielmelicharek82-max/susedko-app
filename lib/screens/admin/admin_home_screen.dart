// lib/screens/admin/admin_home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/admin_provider.dart';
import 'admin_users_screen.dart';
import 'admin_craftsmen_screen.dart';
import 'admin_reviews_screen.dart';
import 'admin_service_requests_screen.dart';
import 'admin_work_orders_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;

  static const _kPrimary = Color(0xFF2563EB);
  static const _kBg      = Color(0xFFF8FAFC);

  final List<Widget> _screens = const [
    _AdminDashboard(),
    AdminUsersScreen(),
    AdminCraftsmenScreen(),
    AdminServiceRequestsScreen(),
    AdminWorkOrdersScreen(),
    AdminReviewsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchAllData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final disputedCount = provider.disputedCount;

    return Scaffold(
      backgroundColor: _kBg,
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.white,
        selectedItemColor: _kPrimary,
        unselectedItemColor: Colors.grey.shade400,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        items: [
          // 0 — Dashboard
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard'),

          // 1 — Používatelia
          const BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Užívatelia'),

          // 2 — Remeselníci
          BottomNavigationBarItem(
            icon: Stack(children: [
              const Icon(Icons.handyman_outlined),
              if (provider.pendingCraftsmen.isNotEmpty)
                Positioned(right: 0, top: 0,
                    child: _dot(Colors.red)),
            ]),
            activeIcon: const Icon(Icons.handyman),
            label: 'Remeselníci'),

          // 4 — Požiadavky
          const BottomNavigationBarItem(
            icon: Icon(Icons.campaign_outlined),
            activeIcon: Icon(Icons.campaign),
            label: 'Požiadavky'),

          // 5 — Zákazky
          BottomNavigationBarItem(
            icon: Stack(children: [
              const Icon(Icons.work_outline),
              if (disputedCount > 0)
                Positioned(right: 0, top: 0,
                    child: _dot(Colors.red)),
            ]),
            activeIcon: const Icon(Icons.work),
            label: 'Zákazky'),

          // 6 — Recenzie
          const BottomNavigationBarItem(
            icon: Icon(Icons.star_outline),
            activeIcon: Icon(Icons.star),
            label: 'Recenzie'),
        ],
      ),
    );
  }

  Widget _dot(Color color) => Container(
    width: 8, height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard
// ─────────────────────────────────────────────────────────────────────────────
class _AdminDashboard extends StatelessWidget {
  const _AdminDashboard();

  static const _kPrimary = Color(0xFF2563EB);
  static const _kAccent  = Color(0xFF60A5FA);
  static const _kBg      = Color(0xFFF8FAFC);
  static const _kText    = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AdminProvider>();

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('Susedko Admin',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: _kPrimary,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => context.read<AdminProvider>().fetchAllData()),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Odhlásiť sa',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (route) => false);
              }
            }),
        ],
      ),
      body: p.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => context.read<AdminProvider>().fetchAllData(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 4),

                  // ── Sekcia: Používatelia & remeselníci ──────────────────
                  _sectionTitle('Používatelia'),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2, shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12, mainAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _StatCard(
                        label: 'Všetci užívatelia',
                        value: '${p.users.length}',
                        icon: Icons.people,
                        color: _kPrimary),
                      _StatCard(
                        label: 'Remeselníci',
                        value: '${p.craftsmen.length}',
                        icon: Icons.handyman,
                        color: Colors.orange),
                      _StatCard(
                        label: 'Čakajú na verif.',
                        value: '${p.pendingCraftsmen.length}',
                        icon: Icons.pending_outlined,
                        color: Colors.red,
                        urgent: p.pendingCraftsmen.isNotEmpty),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Sekcia: Aktivita ────────────────────────────────────
                  _sectionTitle('Aktivita'),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2, shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12, mainAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _StatCard(
                        label: 'Broadcast požiadavky',
                        value: '${p.openBroadcastCount}',
                        icon: Icons.campaign,
                        color: Colors.teal),
                      _StatCard(
                        label: 'Všetky požiadavky',
                        value: '${p.serviceRequests.length}',
                        icon: Icons.inbox_outlined,
                        color: Colors.blueGrey),
                      _StatCard(
                        label: 'Zákazky',
                        value: '${p.workOrders.length}',
                        icon: Icons.work_outline,
                        color: _kAccent),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Sekcia: Financie & kvalita ──────────────────────────
                  _sectionTitle('Financie & kvalita'),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2, shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12, mainAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _StatCard(
                        label: 'Príjem (zaplatené)',
                        value: '${p.totalRevenue.toStringAsFixed(0)} €',
                        icon: Icons.euro,
                        color: Colors.green.shade700),
                      _StatCard(
                        label: 'Aktívne spory',
                        value: '${p.disputedCount}',
                        icon: Icons.gavel_outlined,
                        color: Colors.red,
                        urgent: p.disputedCount > 0),
                      _StatCard(
                        label: 'Čakajú na platbu',
                        value: '${p.pendingWorkOrderCount}',
                        icon: Icons.payments_outlined,
                        color: Colors.amber.shade700),
                      _StatCard(
                        label: 'Recenzie',
                        value: '${p.reviews.length}',
                        icon: Icons.star,
                        color: _kAccent),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String text) => Text(
    text,
    style: const TextStyle(
        fontSize: 16, fontWeight: FontWeight.bold, color: _kText),
  );
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool urgent;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.urgent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: urgent
            ? Border.all(color: color.withOpacity(0.5), width: 1.5)
            : null,
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 22),
          if (urgent) ...[
            const Spacer(),
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                  color: color, shape: BoxShape.circle),
            ),
          ],
        ]),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color)),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}