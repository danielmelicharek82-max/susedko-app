// lib/screens/customer/craftsman_map_screen.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../models/craftsman.dart';
import '../../providers/geo_provider.dart';
import 'craftsman_detail_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';

const _kPrimary = Color(0xFF2563EB);
const _kDeep    = Color(0xFF1E40AF);
const _kAccent  = Color(0xFF60A5FA);
const _kBg      = Color(0xFFF0F4FF);

class CraftsmanMapScreen extends StatefulWidget {
  const CraftsmanMapScreen({super.key});
  @override
  State<CraftsmanMapScreen> createState() => _CraftsmanMapScreenState();
}

class _CraftsmanMapScreenState extends State<CraftsmanMapScreen> {
  GoogleMapController? _mapController;
  Craftsman? _selectedCraftsman;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final geo = Provider.of<GeoProvider>(context, listen: false);
      if (!geo.hasLocation) geo.init();
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Set<Marker> _buildMarkers(GeoProvider geo) {
    final markers = <Marker>{};
    if (geo.currentPosition != null) {
      markers.add(Marker(
        markerId: const MarkerId('customer'),
        position: LatLng(
          geo.currentPosition!.latitude,
          geo.currentPosition!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: 'you'.tr())));
    }
    for (final item in geo.nearbyCraftsmen) {
      final craftsman = item.craftsman;
      if (craftsman.geoPoint == null) continue;
      markers.add(Marker(
        markerId: MarkerId(craftsman.id),
        position: LatLng(
            craftsman.geoPoint!.latitude,
            craftsman.geoPoint!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueCyan),
        infoWindow: InfoWindow(
          title: craftsman.name,
          snippet:
              '${craftsman.profession.startsWith('prof_') ? craftsman.profession.tr() : craftsman.profession} · ${item.formattedDistance}'),
        onTap: () =>
            setState(() => _selectedCraftsman = craftsman)));
    }
    return markers;
  }

  void _animateToUser(GeoProvider geo) {
    if (_mapController == null || geo.currentPosition == null) return;
    _mapController!.animateCamera(CameraUpdate.newLatLngZoom(
      LatLng(geo.currentPosition!.latitude,
          geo.currentPosition!.longitude),
      12));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: _kPrimary,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_kDeep, _kPrimary, Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight)),
                child: Stack(children: [
                  Positioned(right: -30, top: -30,
                    child: Container(width: 140, height: 140,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 52, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('craftsmanMap'.tr(),
                          style: const TextStyle(
                            color: Colors.white, fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5)),
                        const SizedBox(height: 2),
                        Text('findYourArtist'.tr(),
                          style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                      ])),
                ])),
            ),
            actions: [
              Consumer<GeoProvider>(
                builder: (_, geo, __) => Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => _animateToUser(geo),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3))),
                      child: const Icon(Icons.my_location,
                          color: Colors.white, size: 18))))),
            ],
          ),
        ],
        body: Consumer<GeoProvider>(
          builder: (context, geo, _) {
            if (geo.locationDenied) {
              return Center(child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.07),
                      shape: BoxShape.circle),
                    child: Icon(Icons.location_off_outlined,
                        size: 48, color: Colors.red.withOpacity(0.5))),
                  const SizedBox(height: 16),
                  Text('locationDenied'.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold,
                          fontSize: 16, color: Color(0xFF1E293B))),
                  const SizedBox(height: 6),
                  Text('locationDeniedDesc'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13,
                          color: Colors.grey.shade500, height: 1.5)),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: geo.init,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_kDeep, _kPrimary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(
                          color: _kPrimary.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4))]),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.my_location_rounded,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text('enableLocation'.tr(),
                            style: const TextStyle(color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                      ]))),
                ])));
            }

            if (!geo.hasLocation) {
              return const Center(
                  child: CircularProgressIndicator(color: _kPrimary));
            }

            final initialPos = LatLng(
              geo.currentPosition!.latitude,
              geo.currentPosition!.longitude);

return Stack(
  children: [
    GoogleMap(
  initialCameraPosition: CameraPosition(target: initialPos, zoom: 12),
  markers: _buildMarkers(geo),

  myLocationEnabled: true,
  myLocationButtonEnabled: false,
  zoomControlsEnabled: false,

  zoomGesturesEnabled: true,
  scrollGesturesEnabled: true,
  rotateGesturesEnabled: true,
  tiltGesturesEnabled: true,

  gestureRecognizers: {
    Factory<OneSequenceGestureRecognizer>(
      () => EagerGestureRecognizer(),
    ),
  },

  onMapCreated: (ctrl) => _mapController = ctrl,
  onTap: (_) => setState(() => _selectedCraftsman = null),
),

              // Loading overlay
              if (geo.isLoading)
                Positioned(
                  top: 16, left: 0, right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8)]),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _kPrimary)),
                        const SizedBox(width: 8),
                        Text('loading'.tr(),
                            style: TextStyle(color: _kPrimary,
                                fontWeight: FontWeight.w500)),
                      ])))),

              // Count badge
              if (!geo.isLoading && geo.nearbyCraftsmen.isNotEmpty)
                Positioned(
                  top: 16, left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _kPrimary.withOpacity(0.2)),
                      boxShadow: [BoxShadow(
                          color: _kPrimary.withOpacity(0.15),
                          blurRadius: 10)]),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _kPrimary.withOpacity(0.1),
                          shape: BoxShape.circle),
                        child: const Icon(Icons.handyman_outlined,
                            size: 12, color: _kPrimary)),
                      const SizedBox(width: 6),
                      Text(
                        'mapCraftsmenNearby'.tr(namedArgs: {
                          'count': geo.nearbyCraftsmen.length.toString(),
                        }),
                        style: TextStyle(color: _kPrimary,
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    ]))),

              // Selected craftsman card
              if (_selectedCraftsman != null)
                Positioned(
                  bottom: 24, left: 16, right: 16,
                  child: _CraftsmanMapCard(
                    craftsman: _selectedCraftsman!,
                    distance: geo.nearbyCraftsmen
                        .firstWhere(
                          (c) => c.craftsman.id == _selectedCraftsman!.id,
                          orElse: () => geo.nearbyCraftsmen.first)
                        .formattedDistance,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) =>
                            CraftsmanDetailScreen(
                                craftsman: _selectedCraftsman!))),
                    onClose: () =>
                        setState(() => _selectedCraftsman = null))),
            ]);
          }),
      ),
    );
  }
}

class _CraftsmanMapCard extends StatelessWidget {
  final Craftsman craftsman;
  final String distance;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _CraftsmanMapCard({
    required this.craftsman,
    required this.distance,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final profLabel = craftsman.profession.startsWith('prof_')
        ? craftsman.profession.tr()
        : craftsman.profession;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _kPrimary.withOpacity(0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: Row(
            children: [
              // avatar
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _kPrimary.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: craftsman.profileImage != null
                      ? Image.network(craftsman.profileImage!, fit: BoxFit.cover)
                      : Container(
                          color: _kPrimary.withOpacity(0.1),
                          child: const Icon(Icons.handyman,
                              size: 32, color: _kPrimary),
                        ),
                ),
              ),

              const SizedBox(width: 12),

              // text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      craftsman.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profLabel,
                      style: const TextStyle(
                        color: _kPrimary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      distance,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              // close button
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}