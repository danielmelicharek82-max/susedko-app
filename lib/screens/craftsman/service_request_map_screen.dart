// lib/screens/craftsman/service_request_map_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/service_request.dart';
import '../../services/service_request_service.dart';
import 'open_requests_screen.dart';
import 'dart:math';

const _kPrimary = Color(0xFF2563EB);
const _kAccent  = Color(0xFF60A5FA);
const _kBg      = Color(0xFFF8FAFC);

const _kRadiusOptions = [5, 10, 25, 50, 100];

// Rovnaký kľúč ako pri zadávaní hromadného dopytu (broadcast_request_screen).
const _kGeoApiKey = 'AIzaSyBXuhp1jKR6dbxhAvOo7_WkX3wSZTAyyNE';

/// Súradnice dopytov, ktoré ich v databáze nemajú (napr. dopyty zadané cez web
/// portál, kde sa adresa nepreveduje na súradnice). Drží sa počas behu appky.
final Map<String, GeoPoint?> _geoCache = {};

Future<GeoPoint?> _geocode(String address) async {
  try {
    final addr = address.trim();
    final query = (addr.toLowerCase().contains('slovak') ||
            addr.toLowerCase().contains('slovensko'))
        ? addr : '$addr, Slovakia';
    final url = Uri.parse('https://maps.googleapis.com/maps/api/geocode/json'
        '?address=${Uri.encodeComponent(query)}&key=$_kGeoApiKey');
    final res = await http.get(url).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (json['status'] != 'OK') return null;
    final results = json['results'] as List;
    if (results.isEmpty) return null;
    final loc = results[0]['geometry']['location'];
    return GeoPoint((loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble());
  } catch (e) {
    debugPrint('Geocoding error: $e');
    return null;
  }
}

/// Vzdialenosť dvoch bodov v km (haversine). Predchádzajúci výpočet nepoužíval
/// sin/asin, takže vracal výrazne príliš malé vzdialenosti.
double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  double rad(double d) => d * pi / 180.0;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(rad(lat1)) * cos(rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
  return r * 2 * asin(min(1.0, sqrt(a)));
}

class ServiceRequestMapScreen extends StatefulWidget {
  final List<String> professions;
  final LatLng craftsmanLocation;

  const ServiceRequestMapScreen({
    super.key,
    required this.professions,
    required this.craftsmanLocation,
  });

  @override
  State<ServiceRequestMapScreen> createState() => _ServiceRequestMapScreenState();
}

class _ServiceRequestMapScreenState extends State<ServiceRequestMapScreen> {
  final Completer<GoogleMapController> _mapController = Completer();

  int _selectedRadius = 25;
  String? _selectedProfession;

  List<ServiceRequest> _allRequests = [];
  List<ServiceRequest> _filteredRequests = [];
  StreamSubscription? _sub;

  Set<Marker> _markers = {};
  bool _loading = true;
  int _withoutLocation = 0;   // dopyty bez adresy/súradníc (na mape nie sú)
  bool _fitted = false;       // kamera sa automaticky prispôsobí po prvých dátach

  @override
  void initState() { super.initState(); _startListening(); }

  @override
  void dispose() { _sub?.cancel(); super.dispose(); }

  void _startListening() {
    _sub?.cancel();
    _sub = ServiceRequestService.watchOpenRequests(widget.professions).listen(
      (requests) {
        if (!mounted) return;
        _allRequests = requests;
        _applyFilters();
        _geocodeMissing();
        setState(() => _loading = false);
        // Kamera sa musí prispôsobiť až KEĎ prídu dáta (predtým sa to
        // skúsilo len 500 ms po vytvorení mapy, typicky ešte bez dopytov).
        if (!_fitted && _filteredRequests.isNotEmpty && _mapController.isCompleted) {
          _fitted = true;
          _moveCameraToFit();
        }
      },
      onError: (e) {
        // Chýbajúci Firestore index sa ukáže tu — vypíš ho do konzoly.
        debugPrint('ServiceRequestMapScreen: chyba streamu dopytov: $e');
        if (mounted) setState(() => _loading = false);
      },
    );
  }

  /// Dopyty bez súradníc, ktoré majú adresu, doplníme zo cache.
  List<ServiceRequest> _withResolvedLocations() => _allRequests.map((r) {
        if (r.location != null) return r;
        final g = _geoCache[r.id];
        return g != null ? r.copyWith(location: g) : r;
      }).toList();

  /// Súradnice sa doplnia na pozadí (Geocoding); mapa sa potom obnoví.
  Future<void> _geocodeMissing() async {
    final todo = _allRequests.where((r) =>
        r.location == null &&
        !_geoCache.containsKey(r.id) &&
        (r.address ?? '').trim().isNotEmpty).take(30).toList();
    if (todo.isEmpty) return;
    for (final r in todo) {
      _geoCache[r.id] = await _geocode(r.address!);
      if (!mounted) return;
    }
    _applyFilters();
    setState(() {});
    if (_filteredRequests.isNotEmpty && _mapController.isCompleted) {
      _fitted = true;
      _moveCameraToFit();
    }
  }

  void _applyFilters() {
    final resolved = _withResolvedLocations();
    _withoutLocation = resolved.where((r) => r.location == null).length;
    List<ServiceRequest> filtered = resolved.where((r) => r.location != null).toList();
    if (_selectedProfession != null) {
      // Dopyt môže mať viac profesií — porovnávame aj so zoznamom `professions`.
      filtered = filtered.where((r) =>
          r.profession == _selectedProfession ||
          r.professions.contains(_selectedProfession)).toList();
    }
    filtered = filtered.where((r) {
      final dist = _haversineKm(
        widget.craftsmanLocation.latitude, widget.craftsmanLocation.longitude,
        r.location!.latitude, r.location!.longitude,
      );
      return dist <= _selectedRadius;
    }).toList();
    _filteredRequests = filtered;
    _buildMarkers();
  }

  void _buildMarkers() {
    _markers = _filteredRequests.map((r) {
      final profLabel = r.profession.startsWith('prof_') ? r.profession.tr() : r.profession;
      return Marker(
        markerId: MarkerId(r.id),
        position: LatLng(r.location!.latitude, r.location!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(title: profLabel, snippet: r.category),
        onTap: () => _showBottomSheet(r),
      );
    }).toSet();
  }

  void _showBottomSheet(ServiceRequest request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RequestBottomSheet(
        request: request,
        craftsmanLocation: widget.craftsmanLocation,
        onDetailTap: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const OpenRequestsScreen()));
        },
      ),
    );
  }

  Future<void> _moveCameraToFit() async {
    if (_filteredRequests.isEmpty) return;
    final ctrl = await _mapController.future;
    if (_filteredRequests.length == 1) {
      ctrl.animateCamera(CameraUpdate.newLatLngZoom(
        LatLng(_filteredRequests.first.location!.latitude, _filteredRequests.first.location!.longitude), 12));
      return;
    }
    double minLat = _filteredRequests.first.location!.latitude;
    double maxLat = minLat;
    double minLng = _filteredRequests.first.location!.longitude;
    double maxLng = minLng;
    for (final r in _filteredRequests) {
      if (r.location!.latitude  < minLat) minLat = r.location!.latitude;
      if (r.location!.latitude  > maxLat) maxLat = r.location!.latitude;
      if (r.location!.longitude < minLng) minLng = r.location!.longitude;
      if (r.location!.longitude > maxLng) maxLng = r.location!.longitude;
    }
    ctrl.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(minLat - 0.05, minLng - 0.05),
        northeast: LatLng(maxLat + 0.05, maxLng + 0.05),
      ), 60));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text('map_requests_title'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _kPrimary, foregroundColor: Colors.white, elevation: 0,
        actions: [
          if (!_loading)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20)),
                child: Text(
                  'requestsCount'.tr(namedArgs: {'count': _filteredRequests.length.toString()}),
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ),
        ],
      ),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _filterChip(
                    label: 'allProfessions'.tr(),
                    selected: _selectedProfession == null,
                    onTap: () { setState(() => _selectedProfession = null); _applyFilters(); },
                  ),
                  ...widget.professions.map((p) => _filterChip(
                    label: p.startsWith('prof_') ? p.tr() : p,
                    selected: _selectedProfession == p,
                    onTap: () { setState(() => _selectedProfession = p); _applyFilters(); },
                  )),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _showRadiusPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kPrimary.withOpacity(0.3))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.radar, size: 16, color: _kPrimary),
                  const SizedBox(width: 4),
                  Text('$_selectedRadius km',
                      style: TextStyle(fontSize: 13, color: _kPrimary, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ]),
        ),
        Expanded(
          child: Stack(children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: widget.craftsmanLocation, zoom: 10),
              onMapCreated: (ctrl) {
                _mapController.complete(ctrl);
                Future.delayed(const Duration(milliseconds: 500), _moveCameraToFit);
              },
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),
            if (!_loading && _withoutLocation > 0)
              Positioned(
                left: 12, right: 12, top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8)]),
                  child: Row(children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'map_requests_hidden_no_address'.tr(namedArgs: {'count': _withoutLocation.toString()}),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
                  ]))),
            if (_loading)
              const Center(child: CircularProgressIndicator(color: _kPrimary)),
            if (!_loading && _filteredRequests.isEmpty)
              Center(
                child: Container(
                  margin: const EdgeInsets.all(32),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12)]),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text('openRequests_empty'.tr(),
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                  ]),
                ),
              ),
          ]),
        ),
      ]),
      floatingActionButton: _filteredRequests.isNotEmpty
          ? FloatingActionButton.small(
              backgroundColor: _kPrimary, foregroundColor: Colors.white,
              tooltip: 'showAll'.tr(),
              onPressed: _moveCameraToFit,
              child: const Icon(Icons.fit_screen))
          : null,
    );
  }

  void _showRadiusPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('map_requests_filter_radius'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          ..._kRadiusOptions.map((r) => ListTile(
            leading: Icon(Icons.radar, color: _selectedRadius == r ? _kPrimary : Colors.grey),
            title: Text('$r km'),
            trailing: _selectedRadius == r ? Icon(Icons.check, color: _kPrimary) : null,
            onTap: () { setState(() => _selectedRadius = r); _applyFilters(); Navigator.pop(context); },
          )),
        ]),
      ),
    );
  }

  Widget _filterChip({required String label, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _kPrimary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _kPrimary : Colors.grey.shade300)),
        child: Text(label,
            style: TextStyle(fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? Colors.white : Colors.grey.shade700)),
      ),
    );
  }
}

class _RequestBottomSheet extends StatelessWidget {
  final ServiceRequest request;
  final LatLng craftsmanLocation;
  final VoidCallback onDetailTap;

  const _RequestBottomSheet({
    required this.request,
    required this.craftsmanLocation,
    required this.onDetailTap,
  });

  String _timeframeLabel(String v) {
    const map = {
      'asap': 'timeframe_asap', '1_3_days': 'timeframe_1_3_days',
      '1_2_weeks': 'timeframe_1_2_weeks', '1_3_months': 'timeframe_1_3_months',
      '3_6_months': 'timeframe_3_6_months', 'over_6_months': 'timeframe_over_6_months',
      'no_rush': 'timeframe_no_rush',
    };
    final key = map[v];
    return key != null ? key.tr() : v;
  }

  double _distanceKm() => _haversineKm(
      craftsmanLocation.latitude, craftsmanLocation.longitude,
      request.location!.latitude, request.location!.longitude);

  @override
  Widget build(BuildContext context) {
    final dist = _distanceKm();
    final profLabel = request.profession.startsWith('prof_')
        ? request.profession.tr() : request.profession;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(profLabel, style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.bold, fontSize: 13))),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.near_me, size: 12, color: Colors.green),
                  const SizedBox(width: 4),
                  Text('${dist.toStringAsFixed(1)} km',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                ])),
            ]),
            const SizedBox(height: 12),
            Text(request.category, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              request.description.length > 120
                  ? '${request.description.substring(0, 120)}...'
                  : request.description,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            Row(children: [
              if (request.budget != null) ...[
                _metaChip(Icons.euro, '${request.budget!.toStringAsFixed(0)} €', Colors.orange),
                const SizedBox(width: 8),
              ],
              _metaChip(Icons.schedule, _timeframeLabel(request.timeframe), Colors.blue),
              const SizedBox(width: 8),
              if (request.address != null)
                Expanded(child: _metaChip(Icons.location_on, request.address!, Colors.red)),
            ]),
            const SizedBox(height: 8),
            if (request.interestedCraftsmanIds.isNotEmpty)
              Text(
                'openRequests_interested_count'.tr(namedArgs: {'count': request.interestedCraftsmanIds.length.toString()}),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text('view'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: onDetailTap)),
            const SizedBox(height: 20),
          ]),
        ),
      ]),
    );
  }

  Widget _metaChip(IconData icon, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      Flexible(child: Text(label, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
    ]);
}