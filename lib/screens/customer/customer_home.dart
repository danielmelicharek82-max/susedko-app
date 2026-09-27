// lib/screens/customer/customer_home.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/work_order_service.dart';
import 'customer_craftsmen.dart';
import 'craftsman_map_screen.dart';
import 'customer_work_orders_screen.dart';
import 'customer_profile_screen.dart';
import 'broadcast_request_screen.dart';
import 'customer_requests_screen.dart';

const _kPrimary = Color(0xFF2563EB);
const _kBg      = Color(0xFFF0F4FF);

class CustomerHomeScreen extends StatefulWidget {
  // Externý signál "prepni na túto hlavnú záložku" pre už bežiacu inštanciu
  // CustomerHomeScreen (napr. z weekly_invoice_screen.dart po úspešnej
  // platbe, aby zákazník po Navigator.popUntil(isFirst) pristál rovno na
  // záložke Objednávky namiesto prvej — Remeselníci). Rovnaký princíp ako
  // CustomerWorkOrdersScreen.requestedTab.
  // 0 = Remeselníci, 1 = Mapa, 2 = Objednávky, 3 = Dopyty, 4 = Profil.
  static final ValueNotifier<int?> requestedIndex = ValueNotifier<int?>(null);

  const CustomerHomeScreen({super.key});
  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _currentIndex = 0;
  bool _isCraftsmanInCustomerMode = false;

  final List<Widget> _screens = [
    CustomerCraftsmenScreen(),
    CraftsmanMapScreen(),
    CustomerWorkOrdersScreen(),
    CustomerRequestsScreen(),
    CustomerProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _checkIfCraftsmanMode();
    CustomerHomeScreen.requestedIndex.addListener(_onIndexRequested);
  }

  void _onIndexRequested() {
    final index = CustomerHomeScreen.requestedIndex.value;
    if (index == null || !mounted) return;
    setState(() => _currentIndex = index);
    CustomerHomeScreen.requestedIndex.value = null; // spotrebované
  }

  @override
  void dispose() {
    CustomerHomeScreen.requestedIndex.removeListener(_onIndexRequested);
    super.dispose();
  }

  // Zistí, či je prihlásený uid v skutočnosti remeselník, ktorý sa cez
  // craftsman_profile_screen.dart prepol do zákazníckeho režimu (rola v
  // databáze ostáva 'craftsman' — nemeníme ju, len mu sprístupníme tento
  // zákaznícky pohľad navyše). _AuthGate v main.dart pri role=='craftsman'
  // inicializuje len ChatProvider, takže providre pre tento pohľad
  // (GeoProvider, WishlistProvider) sme mu museli spustiť ručne pri
  // prepnutí — pozri _switchToCustomerMode() v craftsman_profile_screen.dart.
  Future<void> _checkIfCraftsmanMode() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final role = (doc.data()?['role'] as String?)?.trim().toLowerCase();
    if (mounted && role == 'craftsman') {
      setState(() => _isCraftsmanInCustomerMode = true);
    }
  }

  Widget _buildCraftsmanModeBanner() {
    return Container(
      width: double.infinity,
      color: _kPrimary.withOpacity(0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        const Icon(Icons.swap_horiz_rounded, size: 16, color: _kPrimary),
        const SizedBox(width: 8),
        Expanded(
          child: Text('craftsmanInCustomerMode_banner'.tr(),
              style: const TextStyle(fontSize: 12.5, color: _kPrimary,
                  fontWeight: FontWeight.w600))),
        GestureDetector(
          onTap: () {
            if (Navigator.canPop(context)) Navigator.pop(context);
          },
          child: Text('craftsmanInCustomerMode_back'.tr(),
              style: const TextStyle(fontSize: 12.5, color: _kPrimary,
                  fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(children: [
        if (_isCraftsmanInCustomerMode) _buildCraftsmanModeBanner(),
        Expanded(child: IndexedStack(index: _currentIndex, children: _screens)),
      ]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: _kPrimary.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4)),
          ]),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          backgroundColor: Colors.white,
          elevation: 0,
          indicatorColor: _kPrimary.withOpacity(0.12),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.groups_outlined),
              selectedIcon: const Icon(Icons.groups, color: _kPrimary),
              label: 'customerHome_craftsmen'.tr(),
            ),
            NavigationDestination(
              icon: const Icon(Icons.map_outlined),
              selectedIcon: const Icon(Icons.map, color: _kPrimary),
              label: 'customerHome_map'.tr(),
            ),
            NavigationDestination(
              icon: StreamBuilder<int>(
                stream: uid.isEmpty
                    ? Stream.value(0)
                    : WorkOrderService.watchPaymentDueCount(uid),
                builder: (ctx, snap) {
                  final count = snap.data ?? 0;
                  return Stack(children: [
                    const Icon(Icons.work_outline),
                    if (count > 0)
                      Positioned(
                        right: 0, top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red, shape: BoxShape.circle),
                          constraints: const BoxConstraints(
                              minWidth: 14, minHeight: 14),
                          child: Text('$count',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 9,
                                  fontWeight: FontWeight.bold)))),
                  ]);
                }),
              selectedIcon: const Icon(Icons.work, color: _kPrimary),
              label: 'customerHome_orders'.tr(),
            ),
            NavigationDestination(
              icon: const Icon(Icons.list_alt_outlined),
              selectedIcon: const Icon(Icons.list_alt, color: _kPrimary),
              label: 'customerHome_requests'.tr(),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person, color: _kPrimary),
              label: 'profile'.tr(),
            ),
          ],
        ),
      ),
    );
  }
}