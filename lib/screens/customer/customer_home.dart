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

const _kPrimary = Color(0xFF2563EB);
const _kBg      = Color(0xFFF0F4FF);

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});
  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    CustomerCraftsmenScreen(),
    CraftsmanMapScreen(),
    CustomerWorkOrdersScreen(),
    CustomerRequestsScreen(),
    CustomerProfileScreen(),
  ];

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