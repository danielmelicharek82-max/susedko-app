// lib/screens/craftsman/craftsman_home.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/work_order_service.dart';
import '../../services/service_request_service.dart';
import 'craftsman_work_orders_screen.dart';
import 'craftsman_requests_screen.dart';
import 'open_requests_screen.dart';
import 'craftsman_calendar_screen.dart';
import 'craftsman_portfolio_screen.dart';
import 'craftsman_profile_screen.dart';
import 'service_request_map_screen.dart';

class CraftsmanHome extends StatefulWidget {
  const CraftsmanHome({super.key});
  @override
  State<CraftsmanHome> createState() => _CraftsmanHomeState();
}

class _CraftsmanHomeState extends State<CraftsmanHome> {
  int _currentIndex = 0;
  List<String> _myProfessions = [];
  LatLng? _craftsmanLocation;
  String? _uid;

  // ← Kľúč ktorý sa zmení keď prídu profesie — donúti StreamBuilder rebuild
  Key _streamKey = UniqueKey();

  static const _kPrimary = Color(0xFF2563EB);
  static const _kBg      = Color(0xFFF8FAFC);

  final List<Widget> _screens = [
    const CraftsmanWorkOrdersScreen(),
    const CraftsmanRequestsScreen(),
    const OpenRequestsScreen(),
    const CraftsmanPortfolioScreen(),
    const CraftsmanCalendarScreen(),
    const CraftsmanProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _loadCraftsmanData();
  }

  Future<void> _loadCraftsmanData() async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;

    final doc = await FirebaseFirestore.instance
        .collection('craftsmen').doc(uid).get();
    if (!doc.exists || !mounted) return;

    final data = doc.data()!;

    final skills     = List<String>.from(data['skills'] ?? []);
    final profession = data['profession'] as String? ?? '';
    final professions = skills.isNotEmpty
        ? skills
        : [if (profession.isNotEmpty) profession];

    LatLng? location;
    final gp = data['geoPoint'];
    if (gp is GeoPoint) {
      location = LatLng(gp.latitude, gp.longitude);
    }

    if (mounted) {
      setState(() {
        _myProfessions     = professions;
        _craftsmanLocation = location;
        // ← Nový kľúč donúti StreamBuilder vytvoriť nový stream s profesií
        _streamKey         = UniqueKey();
      });
    }
  }

  void _openRequestMap() {
    if (_craftsmanLocation == null) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.location_off, color: Colors.orange),
            const SizedBox(width: 10),
            Text('locationNotSet'.tr()),
          ]),
          content: Text(
            'map_requests_no_location_desc'.tr(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('cancel'.tr())),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 5);
              },
              child: Text('map_requests_go_profile'.tr())),
          ],
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceRequestMapScreen(
          professions: _myProfessions,
          craftsmanLocation: _craftsmanLocation!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid ?? '';

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
        selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 10),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        items: [

          // 0 — Work Orders
          BottomNavigationBarItem(
            icon: StreamBuilder<int>(
              stream: uid.isEmpty
                  ? Stream.value(0)
                  : WorkOrderService.watchPendingCount(uid),
              builder: (ctx, snap) {
                final count = snap.data ?? 0;
                return Stack(children: [
                  const Icon(Icons.work_outline),
                  if (count > 0) Positioned(right: 0, top: 0,
                      child: _badge(count, Colors.red)),
                ]);
              }),
            activeIcon: const Icon(Icons.work),
            label: 'craftsmanHome_orders'.tr()),

          // 1 — Direct požiadavky
          BottomNavigationBarItem(
            icon: const Icon(Icons.inbox_outlined),
            activeIcon: const Icon(Icons.inbox),
            label: 'craftsmanHome_requests'.tr()),

          // 2 — Broadcast zákazky
          BottomNavigationBarItem(
            // ← _streamKey zabezpečí že StreamBuilder sa prebuduje
            //   s reálnymi profesiami po načítaní z Firestore
            icon: StreamBuilder<int>(
              key: _streamKey,
              stream: _myProfessions.isEmpty
                  ? Stream.value(0)
                  : ServiceRequestService
                      .watchOpenRequestsCount(_myProfessions),
              builder: (ctx, snap) {
                final count = snap.data ?? 0;
                return Stack(children: [
                  const Icon(Icons.campaign_outlined),
                  if (count > 0) Positioned(right: 0, top: 0,
                      child: _badge(count, Colors.orange)),
                ]);
              }),
            activeIcon: const Icon(Icons.campaign),
            label: 'craftsmanHome_open'.tr()),

          // 3 — Portfólio
          BottomNavigationBarItem(
            icon: const Icon(Icons.photo_library_outlined),
            activeIcon: const Icon(Icons.photo_library),
            label: 'craftsmanHome_portfolio'.tr()),

          // 4 — Kalendár
          BottomNavigationBarItem(
            icon: const Icon(Icons.event_available_outlined),
            activeIcon: const Icon(Icons.event_available),
            label: 'craftsmanHome_calendar'.tr()),

          // 5 — Profil
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: 'craftsmanHome_profile'.tr()),
        ],
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: (_currentIndex == 3 ||
              _currentIndex == 4 ||
              _currentIndex == 5)
          ? null
          : FloatingActionButton.extended(
              onPressed: _openRequestMap,
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              elevation: 3,
              icon: const Icon(Icons.map_outlined),
              label: Text('map_requests_map_btn'.tr(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
            ),
    );
  }

  Widget _badge(int count, Color color) => Container(
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
    child: Text('$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold)),
  );
}