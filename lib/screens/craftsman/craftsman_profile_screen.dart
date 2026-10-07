// lib/screens/craftsman/craftsman_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:share_plus/share_plus.dart';
import 'package:geocoding/geocoding.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:io';
import '../../models/craftsman.dart';
import '../../services/geo_service.dart';
import '../auth/craftsman_register_form.dart';
import '../login_screen.dart';
import 'about_craftsman_app_screen.dart';
import '../../services/chat_service.dart';
import 'craftsman_chat_list_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/geo_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../customer/customer_home.dart';

const _kPrimary = Color(0xFF2563EB);
const _kDeep    = Color(0xFF1E40AF);
const _kAccent  = Color(0xFF60A5FA);
const _kBg      = Color(0xFFF0F4FF);

double _customerPrice(double baseRate) => baseRate * 1.10;

class CraftsmanProfileScreen extends StatefulWidget {
  const CraftsmanProfileScreen({super.key});
  @override
  State<CraftsmanProfileScreen> createState() =>
      _CraftsmanProfileScreenState();
}

class _CraftsmanProfileScreenState extends State<CraftsmanProfileScreen> {
  Craftsman? _craftsman;
  bool _loading         = true;
  bool _saving          = false;
  bool _settingLocation = false;
  bool _uploadingPhoto  = false;
  bool _editMode        = false;

  final _nameController       = TextEditingController();
  final _bioController        = TextEditingController();
  final _cityController       = TextEditingController();
  final _phoneController      = TextEditingController();
  final _hourlyRateController = TextEditingController();
  final Set<String> _selectedProfessions = {};

  @override
  void initState() { super.initState(); _loadProfile(); }

  @override
  void dispose() {
    _nameController.dispose(); _bioController.dispose();
    _cityController.dispose(); _phoneController.dispose();
    _hourlyRateController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { if (mounted) setState(() => _loading = false); return; }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('craftsmen').doc(uid).get();
      if (!doc.exists || !mounted) {
        setState(() => _loading = false); return;
      }
      final c = Craftsman.fromFirestore(doc);
      setState(() {
        _craftsman = c; _loading = false;
        _nameController.text       = c.name;
        _bioController.text        = c.bio ?? '';
        _cityController.text       = c.cityName ?? '';
        _phoneController.text      = (doc.data()?['phone'] ?? '') as String;
        _hourlyRateController.text = c.hourlyRate?.toStringAsFixed(0) ?? '';
        _selectedProfessions
          ..clear()
          ..addAll(c.skills.isNotEmpty ? c.skills
              : [if (c.profession.isNotEmpty) c.profession]);
      });
    } catch (e) {
      debugPrint('>>> ERROR: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final ref = FirebaseStorage.instance
          .ref().child('craftsmen/$uid/profile.jpg');
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('craftsmen').doc(uid).update({'profileImage': url});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('cp_photoUpdated'.tr()),
            backgroundColor: Colors.green));
        await _loadProfile();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'error'.tr()}: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _shareProfile() async {
    final c = _craftsman;
    if (c == null) return;
    final professions = c.skills.isNotEmpty
        ? c.skills.map((s) => s.tr()).join(', ')
        : c.profession.tr();
    final rate = c.hourlyRate != null
        ? '\n💶 ${_customerPrice(c.hourlyRate!).toStringAsFixed(0)} €/hod' : '';
    final city = c.cityName != null ? '\n📍 ${c.cityName}' : '';
    final text = '🔧 ${c.name} — Susedko\n\n'
        '${'cp_shareServices'.tr()}:\n$professions$city$rate\n\n'
        '⭐ ${'cp_shareRating'.tr()}: ${c.rating.toStringAsFixed(1)}/5.0\n\n'
        '📲 ${'cp_shareAppCta'.tr()}';
    await Share.share(text, subject: '${c.name} na Susedko');
  }

  Future<void> _setLocation() async {
    setState(() => _settingLocation = true);
    try {
      final position = await GeoService.getCurrentPosition();
      if (position == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('locationError'.tr()),
            backgroundColor: Colors.red));
        return;
      }

      // Reverse geocoding: GPS súradnice → čitateľný názov mesta.
      // Predtým sa tu ukladal len geoPoint a cityName ostávalo prázdne,
      // kým si ho remeselník sám nedopísal do formulára a neuložil
      // profil zvlášť. Web (index.html) ale zobrazuje výhradne cityName,
      // nie geoPoint — takže bez tohto kroku bol remeselník na webe
      // "neviditeľný" aj keď mal reálnu polohu uloženú.
      String resolvedCity = '';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          resolvedCity = (p.locality != null && p.locality!.isNotEmpty)
              ? p.locality!
              : (p.subAdministrativeArea ?? p.administrativeArea ?? '');
        }
      } catch (e) {
        debugPrint('Reverse geocoding zlyhalo: $e');
        // Nekritické — geoPoint sa aj tak uloží nižšie, len sa mesto
        // nedoplní automaticky a používateľ si ho môže dopísať ručne.
      }

      final uid = FirebaseAuth.instance.currentUser!.uid;
      final updateData = <String, dynamic>{
        'geoPoint': GeoPoint(position.latitude, position.longitude),
      };
      if (resolvedCity.isNotEmpty) {
        updateData['cityName'] = resolvedCity;
        _cityController.text = resolvedCity; // hneď viditeľné aj vo formulári
      }

      await FirebaseFirestore.instance.collection('craftsmen').doc(uid).update(updateData);

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              resolvedCity.isNotEmpty
                  ? '${'locationSuccess'.tr()} ($resolvedCity)'
                  : 'locationSuccess'.tr()),
          backgroundColor: Colors.green));
      await _loadProfile();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'error'.tr()}: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _settingLocation = false);
    }
  }

  // Remeselník sa chce prepnúť do zákazníckeho režimu (objednať/napísať
  // inému remeselníkovi). Rolu v users/{uid} zámerne NEMENÍME — zostáva
  // 'craftsman', takže _AuthGate v main.dart ho pri ďalšom reštarte appky
  // vždy vráti do CraftsmanHome. GeoProvider a WishlistProvider _AuthGate
  // pre rolu 'craftsman' nikdy nezapne (pozri main.dart), preto ich tu
  // musíme spustiť ručne — inak by CustomerCraftsmenScreen/mapa zostali
  // prázdne, keďže by nikdy nezačali sledovať dáta.
  void _switchToCustomerMode() {
    context.read<GeoProvider>().init();
    context.read<WishlistProvider>().listenToWishlist();
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const CustomerHomeScreen()));
  }

  Future<void> _save() async {
    if (_selectedProfessions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('selectAtLeastOneProfession'.tr()),
          backgroundColor: Colors.orange));
      return;
    }
    setState(() => _saving = true);
    try {
      final uid      = FirebaseAuth.instance.currentUser!.uid;
      final profList = _selectedProfessions.toList();
      final baseRate = double.tryParse(_hourlyRateController.text.trim());
      await FirebaseFirestore.instance.collection('craftsmen').doc(uid).update({
        'name':     _nameController.text.trim(),
        'bio':      _bioController.text.trim(),
        'cityName': _cityController.text.trim(),
        'phone':    _phoneController.text.trim(),
        'hourlyRate': baseRate,
        'hourlyRateCustomer': baseRate != null
            ? double.parse(_customerPrice(baseRate).toStringAsFixed(2)) : null,
        'profession': profList.first,
        'skills':     profList,
      });
      await _loadProfile();
      if (mounted) {
        setState(() => _editMode = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('profileSavedSuccess'.tr()),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'error'.tr()}: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false);
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kPrimary))
          : _craftsman == null
              ? _buildNotFound()
              : _editMode ? _buildEditView() : _buildReadView(),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    title: Text(_editMode ? 'editProfileTitle'.tr() : 'myProfile'.tr(),
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold)),
    backgroundColor: _kPrimary, elevation: 0,
    automaticallyImplyLeading: false,
    flexibleSpace: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kDeep, _kPrimary, Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight))),
    actions: [
      // Chat — vždy viditeľné, nezávisle od read/edit módu, s badge
      // počtu konverzácií s neprečítanou správou.
      IconButton(
        icon: StreamBuilder<int>(
          stream: FirebaseAuth.instance.currentUser == null
              ? Stream.value(0)
              : ChatService.getUnreadCount(
                  FirebaseAuth.instance.currentUser!.uid),
          builder: (ctx, snap) {
            final count = snap.data ?? 0;
            return Stack(clipBehavior: Clip.none, children: [
              const Icon(Icons.chat_bubble_outline, color: Colors.white),
              if (count > 0)
                Positioned(
                  right: -4, top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text('$count',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
            ]);
          },
        ),
        tooltip: 'myMessages'.tr(),
        onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const CraftsmanChatListScreen())),
      ),
      if (!_editMode && _craftsman != null)
        IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            onPressed: () => setState(() => _editMode = true)),
      if (_editMode)
        TextButton(
            onPressed: () => setState(() => _editMode = false),
            child: Text('cancel'.tr(),
                style: const TextStyle(color: Colors.white70))),
      if (!_editMode && _craftsman != null)
        IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            onPressed: _shareProfile,
            tooltip: 'shareProfile'.tr()),
      IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: _logout),
    ]);

  // ── NOT FOUND ──────────────────────────────────────────────────────────────
  Widget _buildNotFound() => Scaffold(
    backgroundColor: _kBg,
    appBar: _buildAppBar(),
    body: Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.07), shape: BoxShape.circle),
          child: Icon(Icons.person_off_outlined,
              size: 48, color: Colors.red.withOpacity(0.5))),
        const SizedBox(height: 16),
        Text('profileNotFound'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold,
                fontSize: 18, color: Color(0xFF1E293B))),
        const SizedBox(height: 6),
        Text('profileNotFoundDesc'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        const SizedBox(height: 24),
        _gradientBtn(label: 'logout'.tr(),
            icon: Icons.logout, onTap: _logout),
      ]))));

  // ── READ VIEW ──────────────────────────────────────────────────────────────
  Widget _buildReadView() {
    final c = _craftsman!;
    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Hero karta ────────────────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(
                  color: _kPrimary.withOpacity(0.08),
                  blurRadius: 20, offset: const Offset(0, 6))]),
            child: Column(children: [
              Container(
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_kDeep, _kPrimary, _kAccent.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20)))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Transform.translate(
                    offset: const Offset(0, -36),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end, children: [
                      GestureDetector(
                        onTap: _pickAndUploadPhoto,
                        child: Stack(children: [
                          Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [BoxShadow(
                                  color: _kPrimary.withOpacity(0.2),
                                  blurRadius: 10)]),
                            child: ClipOval(child: c.profileImage != null
                                ? Image.network(c.profileImage!, fit: BoxFit.cover)
                                : Container(
                                    color: _kPrimary.withOpacity(0.1),
                                    child: const Icon(Icons.handyman,
                                        size: 36, color: _kPrimary)))),
                          Positioned(bottom: 2, right: 2,
                            child: Container(
                              width: 24, height: 24,
                              decoration: BoxDecoration(
                                color: _kPrimary, shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2)),
                              child: _uploadingPhoto
                                  ? const Padding(padding: EdgeInsets.all(4),
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.camera_alt,
                                      size: 12, color: Colors.white))),
                        ])),
                      const SizedBox(width: 12),
                      Expanded(child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(c.name, style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B))),
                          if (c.cityName != null) Row(children: [
                            Icon(Icons.location_on,
                                size: 13, color: Colors.grey.shade400),
                            const SizedBox(width: 3),
                            Text(c.cityName!, style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 13)),
                          ]),
                        ]))),
                      if (c.hourlyRate != null)
                        Column(crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                          Text('${c.hourlyRate!.toStringAsFixed(0)} €',
                              style: const TextStyle(fontSize: 24,
                                  fontWeight: FontWeight.bold, color: _kPrimary)),
                          Text('cp_perHour'.tr(), style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade400)),
                        ]),
                    ])),

                  Transform.translate(
                    offset: const Offset(0, -28),
                    child: Row(children: [
                      Icon(Icons.camera_alt_outlined,
                          size: 11, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text('tapPhotoToChange'.tr(),
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade400)),
                    ])),

                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.amber.withOpacity(0.3))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.star_rounded,
                            size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text('${c.rating.toStringAsFixed(1)} '
                            '(${c.reviewCount} ${'reviewsCount'.tr()})',
                            style: const TextStyle(fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber)),
                      ])),
                    const SizedBox(width: 8),
                    if (c.isVerified)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.green.withOpacity(0.3))),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.verified_rounded,
                              size: 13, color: Colors.green.shade600),
                          const SizedBox(width: 4),
                          Text('verified'.tr(), style: TextStyle(fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700)),
                        ])),
                  ]),

                  if (c.bio != null && c.bio!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(c.bio!, style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 13, height: 1.6)),
                  ],
                ])),
            ])),
          const SizedBox(height: 14),

          _messagesBanner(),
          const SizedBox(height: 14),

          // ── Poloha ────────────────────────────────────────────────────
          if (c.geoPoint == null) ...[
            _alertBox(color: Colors.orange,
                icon: Icons.location_off_outlined,
                title: 'locationNotSet'.tr(),
                text: 'locationNotSetDesc'.tr()),
            const SizedBox(height: 10),
            _gradientBtn(
                label: _settingLocation ? 'detecting'.tr() : 'setLocation'.tr(),
                icon: Icons.my_location_rounded,
                color: Colors.orange.shade600,
                onTap: _settingLocation ? null : _setLocation,
                loading: _settingLocation),
            const SizedBox(height: 14),
          ],
          if (c.geoPoint != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.green.shade200)),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.location_on_rounded,
                      color: Colors.green.shade700, size: 15)),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  'locationVisible'.tr(),
                  style: TextStyle(fontSize: 12, color: Colors.green.shade800))),
                TextButton(
                  onPressed: _settingLocation ? null : _setLocation,
                  child: Text('updateLocation'.tr(),
                      style: TextStyle(fontSize: 11,
                          color: Colors.green.shade700))),
              ])),
            const SizedBox(height: 14),
          ],

          // ── Profesie ──────────────────────────────────────────────────
          _sectionCard(title: 'myProfessions'.tr(), icon: Icons.handyman_outlined,
            child: c.skills.isEmpty
                ? _emptyHint('noProfessions'.tr())
                : Wrap(spacing: 8, runSpacing: 8,
                    children: c.skills.map((s) {
                      final icon = kProfessionIcons[s] ?? Icons.handyman_outlined;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            _kPrimary.withOpacity(0.12),
                            _kAccent.withOpacity(0.08)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _kPrimary.withOpacity(0.25))),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(icon, size: 14, color: _kPrimary),
                          const SizedBox(width: 6),
                          Text(s.tr(), style: const TextStyle(color: _kPrimary,
                              fontSize: 13, fontWeight: FontWeight.w600)),
                        ]));
                    }).toList())),
          const SizedBox(height: 14),

          // ── Kontakt ───────────────────────────────────────────────────
          _sectionCard(title: 'contactInfo'.tr(), icon: Icons.info_outline,
            child: Column(children: [
              if (c.email != null) _infoRow(Icons.email_outlined, c.email!),
              _infoRow(Icons.payments_outlined,
                  'deposit30'.tr(namedArgs: {'pct': c.depositPercent.toStringAsFixed(0)})),
              _infoRow(Icons.verified_outlined,
                  c.isVerified ? 'cp_verifiedProfile'.tr() : 'waitingForVerification'.tr()),
            ])),
          const SizedBox(height: 14),

          // ── Zdieľať ───────────────────────────────────────────────────
          _sectionCard(title: 'shareProfile'.tr(), icon: Icons.share_outlined,
            child: Column(children: [
              Text('shareProfileDesc'.tr(),
                  style: TextStyle(fontSize: 12,
                      color: Colors.grey.shade500, height: 1.5)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _socialBtn(label: 'Facebook',
                    icon: Icons.facebook, color: const Color(0xFF1877F2),
                    onTap: _shareProfile)),
                const SizedBox(width: 10),
                Expanded(child: _socialBtn(label: 'Instagram',
                    icon: Icons.camera_alt_outlined,
                    color: const Color(0xFFE1306C), onTap: _shareProfile)),
              ]),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                icon: const Icon(Icons.ios_share_outlined, size: 16),
                label: Text('other'.tr(), style: const TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kPrimary,
                  side: const BorderSide(color: _kPrimary),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
                onPressed: _shareProfile)),
            ])),
          const SizedBox(height: 14),

          // ── Zákaznícky režim ──────────────────────────────────────────
          _sectionCard(title: 'switchToCustomerMode_title'.tr(), icon: Icons.swap_horiz_rounded,
            child: Column(children: [
              Text('switchToCustomerMode_desc'.tr(),
                  style: TextStyle(fontSize: 12,
                      color: Colors.grey.shade500, height: 1.5)),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: Text('switchToCustomerMode_btn'.tr(), style: const TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kPrimary,
                  side: const BorderSide(color: _kPrimary),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
                onPressed: _switchToCustomerMode)),
            ])),
          const SizedBox(height: 14),

          _gradientBtn(label: 'editProfile'.tr(),
              icon: Icons.edit_outlined,
              onTap: () => setState(() => _editMode = true)),
          const SizedBox(height: 10),

          // ── O aplikácii ───────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                color: _kPrimary.withOpacity(0.05),
                blurRadius: 10, offset: const Offset(0, 3))]),
            child: ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              leading: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.info_outline,
                    size: 18, color: _kPrimary)),
              title: Text('aboutApp'.tr(),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              trailing: Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: Colors.grey.shade400),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => AboutCraftsmanAppScreen())),
            )),
          const SizedBox(height: 10),

          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: Text('logout'.tr()),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
            onPressed: _logout)),
          const SizedBox(height: 24),
        ])));
  }

  // ── EDIT VIEW ──────────────────────────────────────────────────────────────
  Widget _buildEditView() => Scaffold(
    backgroundColor: _kBg,
    appBar: _buildAppBar(),
    body: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        _alertBox(color: _kPrimary, icon: Icons.edit_note_rounded,
            title: 'editProfileTitle'.tr(),
            text: 'editProfileDesc'.tr()),
        const SizedBox(height: 20),

        _editSection('cp_basicData'.tr(), Icons.person_outline_rounded),
        const SizedBox(height: 12),
        _editField(_nameController, 'fullName'.tr(), Icons.badge_outlined),
        const SizedBox(height: 12),
        _editField(_cityController, 'city'.tr(), Icons.location_city_outlined),
        const SizedBox(height: 12),
        _editField(_phoneController, 'phone'.tr(), Icons.phone_outlined,
            keyboardType: TextInputType.phone),
        const SizedBox(height: 12),

        TextField(
          controller: _hourlyRateController,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'yourHourlyRate'.tr(),
            prefixIcon: const Icon(Icons.euro_outlined),
            filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kPrimary, width: 2)),
            helperText: () {
              final val = double.tryParse(_hourlyRateController.text.trim());
              if (val == null) return 'hourlyRateHelper'.tr();
              return 'cp_customerSeesRate'.tr(namedArgs: {
                'rate': _customerPrice(val).toStringAsFixed(0),
              });
            }())),
        const SizedBox(height: 12),

        TextField(
          controller: _bioController, maxLines: 3, maxLength: 400,
          decoration: InputDecoration(
            labelText: 'aboutMe'.tr(),
            prefixIcon: const Icon(Icons.description_outlined),
            filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kPrimary, width: 2)))),
        const SizedBox(height: 24),

        _editSection('myProfessions'.tr(), Icons.handyman_outlined),
        const SizedBox(height: 4),
        Text('selectAllProfessions'.tr(),
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        const SizedBox(height: 12),

        Wrap(
          spacing: 8, runSpacing: 8,
          children: kAllProfessionKeys.map((prof) {
            final selected = _selectedProfessions.contains(prof);
            final icon = kProfessionIcons[prof] ?? Icons.handyman_outlined;
            return GestureDetector(
              onTap: () => setState(() {
                selected ? _selectedProfessions.remove(prof)
                    : _selectedProfessions.add(prof);
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? _kPrimary : Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                      color: selected ? _kPrimary : Colors.grey.shade300,
                      width: selected ? 2 : 1),
                  boxShadow: selected ? [BoxShadow(
                      color: _kPrimary.withOpacity(0.25),
                      blurRadius: 6, offset: const Offset(0, 2))] : []),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 15,
                      color: selected ? Colors.white : Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(prof.tr(), style: TextStyle(fontSize: 13,
                      fontWeight: selected
                          ? FontWeight.bold : FontWeight.normal,
                      color: selected ? Colors.white : Colors.grey.shade700)),
                ])));
          }).toList()),

        if (_selectedProfessions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _kPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20)),
            child: Text(
              'selectedCount'.tr(namedArgs: {
                'count': _selectedProfessions.length.toString(),
              }),
              style: const TextStyle(fontSize: 12, color: _kPrimary,
                  fontWeight: FontWeight.w600))),
        ],
        const SizedBox(height: 28),

        _saving
            ? const Center(child: CircularProgressIndicator(color: _kPrimary))
            : _gradientBtn(
                label: 'saveChanges'.tr(),
                icon: Icons.save_rounded,
                onTap: _save),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.logout),
          label: Text('logout'.tr()),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
          onPressed: _logout),
        const SizedBox(height: 24),
      ])));

  // ── HELPERS ────────────────────────────────────────────────────────────────
  Widget _gradientBtn({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    Color? color,
    bool loading = false,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: color != null
                  ? [color, color.withOpacity(0.85)]
                  : [_kDeep, _kPrimary],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(
              color: (color ?? _kPrimary).withOpacity(0.3),
              blurRadius: 10, offset: const Offset(0, 4))]),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            loading
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold,
                fontSize: 15)),
          ])));

  Widget _socialBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(11),
            boxShadow: [BoxShadow(color: color.withOpacity(0.3),
                blurRadius: 6, offset: const Offset(0, 3))]),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Colors.white, size: 17),
            const SizedBox(width: 7),
            Text(label, style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.w600, fontSize: 13)),
          ])));

  Widget _messagesBanner() => GestureDetector(
    onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => const CraftsmanChatListScreen())),
    child: StreamBuilder<int>(
      stream: FirebaseAuth.instance.currentUser == null
          ? Stream.value(0)
          : ChatService.getUnreadCount(FirebaseAuth.instance.currentUser!.uid),
      builder: (ctx, snap) {
        final count = snap.data ?? 0;
        final accent = count > 0 ? Colors.red : _kPrimary;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: count > 0
                ? Border.all(color: Colors.red.withOpacity(0.25))
                : null,
            boxShadow: [BoxShadow(
                color: _kPrimary.withOpacity(0.05),
                blurRadius: 12, offset: const Offset(0, 3))]),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: accent.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.chat_bubble_outline,
                  color: accent, size: 20)),
            const SizedBox(width: 14),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('myMessages'.tr(), style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14,
                  color: Color(0xFF1E293B))),
              const SizedBox(height: 2),
              Text(
                  count > 0
                      ? 'unreadMessagesCount'
                          .tr(namedArgs: {'count': count.toString()})
                      : 'noNewMessages'.tr(),
                  style: TextStyle(fontSize: 12.5,
                      color: count > 0
                          ? Colors.red.shade400 : Colors.grey.shade500,
                      fontWeight: count > 0
                          ? FontWeight.w600 : FontWeight.normal)),
            ])),
            if (count > 0)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20)),
                child: Text('$count', style: const TextStyle(
                    color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.bold))),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ]));
      },
    ));

  Widget _alertBox({
    required Color color,
    required IconData icon,
    required String title,
    required String text,
  }) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color)),
          const SizedBox(width: 10),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold,
                fontSize: 13, color: color)),
            const SizedBox(height: 3),
            Text(text, style: TextStyle(fontSize: 12,
                color: Colors.grey.shade600, height: 1.4)),
          ])),
        ]));

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) =>
      Container(
        width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: _kPrimary.withOpacity(0.05),
              blurRadius: 12, offset: const Offset(0, 3))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 15, color: _kPrimary)),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold,
                fontSize: 14, color: Color(0xFF1E293B))),
          ]),
          const SizedBox(height: 14),
          child,
        ]));

  Widget _infoRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Icon(icon, size: 15, color: Colors.grey.shade400),
      const SizedBox(width: 8),
      Expanded(child: Text(text,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
    ]));

  Widget _editSection(String text, IconData icon) => Row(children: [
    Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _kPrimary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 16, color: _kPrimary)),
    const SizedBox(width: 8),
    Text(text, style: const TextStyle(fontSize: 15,
        fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
  ]);

  Widget _editField(TextEditingController ctrl, String label, IconData icon,
      {TextInputType keyboardType = TextInputType.text}) =>
      TextField(
        controller: ctrl, keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label, prefixIcon: Icon(icon),
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kPrimary, width: 2))));

  Widget _emptyHint(String text) => Row(children: [
    Icon(Icons.info_outline, size: 14, color: Colors.grey.shade400),
    const SizedBox(width: 6),
    Text(text, style: TextStyle(fontSize: 13,
        color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
  ]);
}