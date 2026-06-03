// lib/screens/customer/customer_home.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/work_order_service.dart';
import 'customer_craftsmen.dart';
import 'craftsman_map_screen.dart';
import 'customer_work_orders_screen.dart';
import 'customer_profile_screen.dart';
import 'broadcast_request_screen.dart';
import 'customer_requests_screen.dart';
import '../login_screen.dart';

const _kPrimary = Color(0xFF2563EB);
const _kBg      = Color(0xFFF0F4FF);

class CustomerHomeScreen extends StatefulWidget {
  final bool isGuest;
  const CustomerHomeScreen({super.key, this.isGuest = true});
  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _currentIndex = 0;

  List<Widget> get _screens => [
    CustomerCraftsmenScreen(),
    CraftsmanMapScreen(),
    if (!widget.isGuest) CustomerWorkOrdersScreen(),
    if (!widget.isGuest) CustomerRequestsScreen(),
    if (!widget.isGuest) CustomerProfileScreen(),
  ];

  // Ak je guest a klepne na chránenú záložku, zobrazíme výzvu na prihlásenie
  void _onDestinationSelected(int index) {
    if (widget.isGuest && index >= 2) {
      _showLoginPrompt();
      return;
    }
    setState(() => _currentIndex = index);
  }

  void _showLoginPrompt() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            const Icon(Icons.lock_outline_rounded,
                size: 48, color: _kPrimary),
            const SizedBox(height: 16),
            Text(
              'guestLoginRequired'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'guestLoginRequiredDesc'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14, color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
                child: Text('signInBtn'.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)))),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('continueAsGuest'.tr(),
                    style: TextStyle(color: Colors.grey.shade500)))),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: _kBg,
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(_screens.length, (i) {
          if (i != _currentIndex) return const SizedBox.shrink();
          return _screens[i];
        }),
      ),
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
          onDestinationSelected: _onDestinationSelected,
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
              icon: widget.isGuest
                  ? const Icon(Icons.work_outline)
                  : StreamBuilder<int>(
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
              selectedIcon: Icon(Icons.work,
                  color: widget.isGuest ? Colors.grey : _kPrimary),
              label: 'customerHome_orders'.tr(),
            ),
            NavigationDestination(
              icon: const Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt,
                  color: widget.isGuest ? Colors.grey : _kPrimary),
              label: 'customerHome_requests'.tr(),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person,
                  color: widget.isGuest ? Colors.grey : _kPrimary),
              label: 'profile'.tr(),
            ),
          ],
        ),
      ),
    );
  }
}