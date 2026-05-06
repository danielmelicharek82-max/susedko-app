// lib/screens/customer/broadcast_request_screen.dart

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../../models/service_request.dart';
import '../../services/service_request_service.dart';
import '../auth/craftsman_register_form.dart'; // kProfessionIcons
import 'service_request_screen.dart'; // kProfessionCategories

const _kPrimary = Color(0xFF2563EB);
const _kDeep    = Color(0xFF1E40AF);
const _kAccent  = Color(0xFF60A5FA);
const _kBg      = Color(0xFFF0F4FF);

const _kGeoApiKey = 'AIzaSyD3GvOCDdd9YuXqecXs-z4eOx6yz1efvow';

class BroadcastRequestScreen extends StatefulWidget {
  final ServiceRequest? existingRequest;
  const BroadcastRequestScreen({super.key, this.existingRequest});
  bool get isEditing => existingRequest != null;

  @override
  State<BroadcastRequestScreen> createState() =>
      _BroadcastRequestScreenState();
}

class _BroadcastRequestScreenState
    extends State<BroadcastRequestScreen> {
  final _formKey           = GlobalKey<FormState>();
  final _descController    = TextEditingController();
  final _budgetController  = TextEditingController();
  final _addressController = TextEditingController();

  late String _selectedProfession;
  late String _selectedCategory;
  String _selectedTimeframe = '1_3_months';

  final List<File>   _newPhotos    = [];
  final List<String> _existingUrls = [];
  bool _submitting      = false;
  bool _uploadingImages = false;

  @override
  void initState() {
    super.initState();
    final r = widget.existingRequest;
    if (r != null) {
      _selectedProfession =
          kProfessionCategories.containsKey(r.profession)
              ? r.profession : kProfessionCategories.keys.first;
      _selectedCategory =
          kProfessionCategories[_selectedProfession]!
                  .contains(r.category)
              ? r.category
              : kProfessionCategories[_selectedProfession]!.first;
      _selectedTimeframe      = r.timeframe;
      _descController.text    = r.description;
      _budgetController.text  = r.budget?.toStringAsFixed(0) ?? '';
      _addressController.text = r.address ?? '';
      _existingUrls.addAll(r.photoUrls);
    } else {
      _selectedProfession = kProfessionCategories.keys.first;
      _selectedCategory =
          kProfessionCategories[_selectedProfession]!.first;
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _budgetController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _onProfessionChanged(String p) {
    setState(() {
      _selectedProfession = p;
      _selectedCategory   = kProfessionCategories[p]!.first;
    });
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) return;
    setState(() => _newPhotos.add(File(picked.path)));
  }

  Future<List<String>> _uploadNewPhotos() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    final urls = <String>[];
    for (final file in _newPhotos) {
      final ref = FirebaseStorage.instance.ref().child(
          'service_requests/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(file);
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  Future<GeoPoint?> _geocodeAddress(String address) async {
    if (address.trim().isEmpty) return null;
    try {
      final encoded  = Uri.encodeComponent(address.trim());
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=$encoded&key=$_kGeoApiKey');
      final response =
          await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] != 'OK') return null;
      final results = json['results'] as List;
      if (results.isEmpty) return null;
      final loc = results[0]['geometry']['location'];
      return GeoPoint((loc['lat'] as num).toDouble(),
          (loc['lng'] as num).toDouble());
    } catch (e) {
      debugPrint('Geocoding error: $e');
      return null;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _submitting = true);
    try {
      setState(() => _uploadingImages = true);
      final newUrls = await _uploadNewPhotos();
      setState(() => _uploadingImages = false);

      final allPhotoUrls = [..._existingUrls, ...newUrls];
      final addressText  = _addressController.text.trim();

      GeoPoint? geoPoint;
      if (addressText.isNotEmpty) {
        final oldAddress = widget.existingRequest?.address;
        final oldGeo     = widget.existingRequest?.location;
        if (widget.isEditing &&
            oldAddress == addressText &&
            oldGeo != null) {
          geoPoint = oldGeo;
        } else {
          geoPoint = await _geocodeAddress(addressText);
          if (geoPoint == null) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content:
                        Text('broadcastRequest_address_error'.tr()),
                    backgroundColor: Colors.red));
            setState(() => _submitting = false);
            return;
          }
        }
      }

      if (widget.isEditing) {
        await ServiceRequestService.updateBroadcastRequest(
          requestId:   widget.existingRequest!.id,
          profession:  _selectedProfession,
          category:    _selectedCategory,
          description: _descController.text.trim(),
          address:     addressText.isEmpty ? null : addressText,
          location:    geoPoint,
          budget:      double.tryParse(_budgetController.text.trim()),
          photoUrls:   allPhotoUrls,
          timeframe:   _selectedTimeframe,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('broadcastRequest_updated'.tr()),
              backgroundColor: Colors.green));
          Navigator.pop(context, true);
        }
      } else {
        final request = ServiceRequest(
          id:            '',
          customerId:    user.uid,
          customerName:  user.displayName ?? user.email ?? '',
          customerEmail: user.email ?? '',
          profession:    _selectedProfession,
          category:      _selectedCategory,
          description:   _descController.text.trim(),
          address:       addressText.isEmpty ? null : addressText,
          location:      geoPoint,
          budget:        double.tryParse(_budgetController.text.trim()),
          photoUrls:     allPhotoUrls,
          timeframe:     _selectedTimeframe,
          status:        ServiceRequestStatus.open,
          type:          ServiceRequestType.broadcast,
          createdAt:     DateTime.now(),
        );
        await ServiceRequestService.submitBroadcastRequest(request);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('broadcastRequest_success'.tr()),
              backgroundColor: Colors.green));
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${'error'.tr()}: $e'),
          backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  int get _totalPhotos => _existingUrls.length + _newPhotos.length;

  @override
  Widget build(BuildContext context) {
    final categories = kProfessionCategories[_selectedProfession] ?? [];
    final isEditing  = widget.isEditing;

    return Scaffold(
      backgroundColor: _kBg,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
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
                    child: Container(width: 150, height: 150,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle))),
                  Positioned(left: -20, bottom: -20,
                    child: Container(width: 100, height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        shape: BoxShape.circle))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 52, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isEditing
                              ? 'broadcastRequest_edit_title'.tr()
                              : 'broadcastRequest_title'.tr(),
                          style: const TextStyle(
                            color: Colors.white, fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5)),
                        const SizedBox(height: 2),
                        Text('broadcastRequest_info'.tr(),
                          style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      ])),
                ])),
            ),
          ),
        ],
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 60),
          child: Form(
            key: _formKey,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Info banner (new only) ─────────────────────────────
              if (!isEditing) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: _kPrimary.withOpacity(0.2))),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: _kPrimary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(9)),
                      child: const Icon(Icons.campaign_outlined,
                          color: _kPrimary, size: 16)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(
                      'broadcastRequest_info'.tr(),
                      style: TextStyle(fontSize: 13,
                          color: _kPrimary.withOpacity(0.85),
                          height: 1.4))),
                  ])),
                const SizedBox(height: 20),
              ],

              // ── Profession ─────────────────────────────────────────
              _sectionTitle('broadcastRequest_profession'.tr(),
                  Icons.handyman_outlined),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8)]),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedProfession,
                    isExpanded: true,
                    items: kProfessionCategories.keys.map((key) =>
                        DropdownMenuItem(
                            value: key,
                            child: Row(children: [
                              Icon(kProfessionIcons[key] ??
                                  Icons.handyman_outlined,
                                  size: 15, color: _kPrimary),
                              const SizedBox(width: 8),
                              Text(key.tr(),
                                  style: const TextStyle(fontSize: 14)),
                            ]))).toList(),
                    onChanged: (v) => _onProfessionChanged(v!)))),
              const SizedBox(height: 20),

              // ── Category ───────────────────────────────────────────
              _sectionTitle('broadcastRequest_category'.tr(),
                  Icons.category_outlined),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: categories.map((cat) {
                  final sel = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: sel ? _kPrimary : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: sel
                                ? _kPrimary : Colors.grey.shade300,
                            width: sel ? 2 : 1),
                        boxShadow: sel ? [BoxShadow(
                            color: _kPrimary.withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2))] : []),
                      child: Text(cat, style: TextStyle(fontSize: 13,
                          fontWeight: sel
                              ? FontWeight.bold : FontWeight.normal,
                          color: sel
                              ? Colors.white
                              : Colors.grey.shade700))));
                }).toList()),
              const SizedBox(height: 20),

              // ── Description ────────────────────────────────────────
              _sectionTitle('broadcastRequest_desc'.tr(),
                  Icons.description_outlined),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8)]),
                child: TextFormField(
                  controller: _descController,
                  maxLines: 4, maxLength: 600,
                  decoration: InputDecoration(
                    hintText: 'broadcastRequest_desc_hint'.tr(),
                    hintStyle: TextStyle(
                        color: Colors.grey.shade400, fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(14)),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'broadcastRequest_desc_required'.tr() : null)),
              const SizedBox(height: 20),

              // ── Address ────────────────────────────────────────────
              _sectionTitle('broadcastRequest_address'.tr(),
                  Icons.location_on_outlined),
              const SizedBox(height: 6),
              Text('broadcastRequest_address_info'.tr(),
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade500)),
              const SizedBox(height: 8),
              _inputField(
                controller: _addressController,
                hint: 'broadcastRequest_address_hint'.tr(),
                icon: Icons.location_on_outlined),
              const SizedBox(height: 20),

              // ── Budget ─────────────────────────────────────────────
              _sectionTitle('broadcastRequest_budget'.tr(),
                  Icons.euro_outlined),
              const SizedBox(height: 10),
              _inputField(
                controller: _budgetController,
                hint: 'requestBudgetHint'.tr(),
                icon: Icons.euro_outlined,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v != null &&
                      v.isNotEmpty &&
                      double.tryParse(v) == null) {
                    return 'broadcastRequest_budget_error'.tr();
                  }
                  return null;
                }),
              const SizedBox(height: 20),

              // ── Timeframe ──────────────────────────────────────────
              _sectionTitle('broadcastRequest_timeframe'.tr(),
                  Icons.schedule_outlined),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8)]),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedTimeframe,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(
                          value: 'asap',
                          child: Text(
                              'broadcastRequest_timeframe_asap'.tr())),
                      DropdownMenuItem(
                          value: '1_3_days',
                          child: Text(
                              'broadcastRequest_timeframe_3days'.tr())),
                      DropdownMenuItem(
                          value: '1_2_weeks',
                          child: Text(
                              'broadcastRequest_timeframe_2weeks'.tr())),
                      DropdownMenuItem(
                          value: '1_3_months',
                          child: Text(
                              'broadcastRequest_timeframe_3months'.tr())),
                      DropdownMenuItem(
                          value: 'no_rush',
                          child: Text(
                              'broadcastRequest_timeframe_no_rush'.tr())),
                    ],
                    onChanged: (v) =>
                        setState(() => _selectedTimeframe = v!)))),
              const SizedBox(height: 20),

              // ── Photos ─────────────────────────────────────────────
              _sectionTitle('broadcastRequest_photos'.tr(),
                  Icons.photo_library_outlined),
              const SizedBox(height: 10),

              // Existing photos
              if (_existingUrls.isNotEmpty) ...[
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _existingUrls.length,
                    itemBuilder: (ctx, i) => Stack(children: [
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                              image: NetworkImage(_existingUrls[i]),
                              fit: BoxFit.cover))),
                      Positioned(top: 4, right: 12,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _existingUrls.removeAt(i)),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.close,
                                size: 14, color: Colors.white)))),
                    ]))),
                const SizedBox(height: 8),
              ],

              // New photos
              if (_newPhotos.isNotEmpty) ...[
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _newPhotos.length,
                    itemBuilder: (ctx, i) => Stack(children: [
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                              image: FileImage(_newPhotos[i]),
                              fit: BoxFit.cover))),
                      Positioned(top: 4, right: 12,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _newPhotos.removeAt(i)),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.close,
                                size: 14, color: Colors.white)))),
                    ]))),
                const SizedBox(height: 8),
              ],

              if (_totalPhotos < 5)
                GestureDetector(
                  onTap: _pickPhoto,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _kPrimary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _kPrimary.withOpacity(0.25))),
                    child: Row(mainAxisSize: MainAxisSize.min,
                        children: [
                      const Icon(Icons.add_photo_alternate_outlined,
                          color: _kPrimary, size: 18),
                      const SizedBox(width: 8),
                      Text('broadcastRequest_add_photo'.tr(),
                          style: const TextStyle(color: _kPrimary,
                              fontWeight: FontWeight.w600)),
                    ]))),
              const SizedBox(height: 32),

              // ── Submit ─────────────────────────────────────────────
              GestureDetector(
                onTap: _submitting ? null : _submit,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    gradient: _submitting
                        ? LinearGradient(colors: [
                            Colors.grey.shade400,
                            Colors.grey.shade300])
                        : const LinearGradient(
                            colors: [_kDeep, _kPrimary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _submitting ? [] : [BoxShadow(
                      color: _kPrimary.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4))]),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    if (_submitting)
                      const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    else
                      Icon(isEditing
                          ? Icons.save_outlined
                          : Icons.campaign_outlined,
                          color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      _submitting
                          ? (_uploadingImages
                              ? 'broadcastRequest_uploading'.tr()
                              : isEditing
                                  ? 'broadcastRequest_saving'.tr()
                                  : 'broadcastRequest_submitting'.tr())
                          : (isEditing
                              ? 'broadcastRequest_save'.tr()
                              : 'broadcastRequest_submit'.tr()),
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  ]))),
            ])),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, IconData icon) => Row(children: [
    Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _kPrimary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 15, color: _kPrimary)),
    const SizedBox(width: 8),
    Text(text, style: const TextStyle(fontSize: 15,
        fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
  ]);

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) =>
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(icon,
                color: _kPrimary.withOpacity(0.6), size: 18),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                    color: _kPrimary, width: 2)))));
}