// lib/screens/auth/craftsman_register_form.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:math';
import '../utils/countries.dart';

const _kPrimary = Color(0xFF2563EB);

// ── Profession keys (used for translation + Firestore) ────────────────────────
const List<String> kAllProfessionKeys = [

  // 🔧 REMESLÁ – TECHNICKÉ
  'prof_instalater',
  'prof_elektrikar',
  'prof_kurenar',
  'prof_plynar',
  'prof_klampiar',
  'prof_zvarac',
  'prof_zamocnik',
  'prof_kachliar',
  'prof_kominar',
  'prof_strechar',
  'prof_tesar',
  'prof_studniar',

  // 🏗️ STAVEBNÍCTVO
  'prof_murar',
  'prof_sadrokarton',
  'prof_obkladac',
  'prof_dlazdic_exterier',
  'prof_podlahar',
  'prof_maliar',

  // 🪵 DREVO & VÝROBA
  'prof_stolar',
  'prof_montaz_nabytku',
  'prof_calunik',
  'prof_restaurator',

  // ⚙️ OPRAVY & SERVIS
  'prof_oprava_spotrebicov',
  'prof_oprava_naradia',
  'prof_brusic_nozov',
  'prof_lakyrnik',
  'prof_cykloopravar',
  'prof_automechanik',

  // 🌿 EXTERIÉR / POZEMOK
  'prof_zahradnik',
  'prof_bagrista',
  'prof_traktorista',
  'prof_drevorubac',
  'prof_plotar',

  // 🧹 DOMÁCNOSŤ & STAROSTLIVOSŤ
  'prof_upratovanie',
  'prof_pomoc_domacnosti',
  'prof_opatrovatelka_seniorov',
  'prof_opatrovatelka_deti',
  'prof_starostlivost_zvierata',

  // 🏥 ZDRAVIE & WELLNESS
  'prof_zdravotny_asistent',
  'prof_fyzioterapeut',
  'prof_maser',
  'prof_psycholog',

  // 💄 BEAUTY & KOZMETIKA
  'prof_kozmeticka',
  'prof_kadernicka',
  'prof_vizazistka',
  'prof_barberka',
  'prof_nechtarka',
  'prof_pedikerka',
  'prof_lash_stylistka',
  'prof_brow_stylistka',
  'prof_skin_expert',
  'prof_beauty_konzultantka',
  'prof_spa_terapeutka',

  // 🍰 GASTRO
  'prof_kuchar',
  'prof_cukrar',
  'prof_pekar',

  // 🎓 VZDELÁVANIE
  'prof_doucovatel',
  'prof_lektor',

  // 🎭 VOĽNÝ ČAS & SLUŽBY
  'prof_fotograf',
  'prof_tater',
  'prof_instruktor_plavania',
  'prof_instruktorka_tanca',
  'prof_trener',
  'prof_organizator_podujati',

  // 💼 PROFESIONÁLNE SLUŽBY
  'prof_pravnik',
  'prof_uctovnik',

  // 🐄 TRADIČNÉ REMESLÁ / VIDIEK
  'prof_koziar',
  'prof_kovac',
  'prof_kosikar',
  'prof_hrnciar',
  'prof_sindliar',
  'prof_veterinar_hospodarske',
  'prof_strihac_oviec',
  'prof_podkuvac_koni',
];


// ── ICONS MAP ────────────────────────────────────────────────────────────────
const Map<String, IconData> kProfessionIcons = {

  // TECHNICKÉ
  'prof_instalater': Icons.water_drop_outlined,
  'prof_elektrikar': Icons.bolt_outlined,
  'prof_kurenar': Icons.local_fire_department_outlined,
  'prof_plynar': Icons.gas_meter_outlined,
  'prof_klampiar': Icons.roofing_outlined,
  'prof_zvarac': Icons.hardware_outlined,
  'prof_zamocnik': Icons.lock_outline,
  'prof_kachliar': Icons.fireplace_outlined,
  'prof_kominar': Icons.vertical_align_top_outlined,
  'prof_strechar': Icons.roofing_outlined,
  'prof_tesar': Icons.carpenter_outlined,
  'prof_studniar': Icons.water_outlined,

  // STAVEBNÍCTVO
  'prof_murar': Icons.foundation_outlined,
  'prof_sadrokarton': Icons.grid_view_outlined,
  'prof_obkladac': Icons.grid_on_outlined,
  'prof_dlazdic_exterier': Icons.grid_3x3_outlined,
  'prof_podlahar': Icons.square_foot_outlined,
  'prof_maliar': Icons.format_paint_outlined,

  // DREVO
  'prof_stolar': Icons.carpenter_outlined,
  'prof_montaz_nabytku': Icons.chair_outlined,
  'prof_calunik': Icons.chair_alt_outlined,
  'prof_restaurator': Icons.auto_fix_high_outlined,

  // SERVIS
  'prof_oprava_spotrebicov': Icons.kitchen_outlined,
  'prof_oprava_naradia': Icons.build_outlined,
  'prof_brusic_nozov': Icons.content_cut_outlined,
  'prof_lakyrnik': Icons.format_paint_outlined,
  'prof_cykloopravar': Icons.pedal_bike_outlined,
  'prof_automechanik': Icons.directions_car_outlined,

  // EXTERIÉR
  'prof_zahradnik': Icons.grass_outlined,
  'prof_bagrista': Icons.construction_outlined,
  'prof_traktorista': Icons.agriculture_outlined,
  'prof_drevorubac': Icons.park_outlined,
  'prof_plotar': Icons.fence_outlined,

  // DOMÁCNOSŤ
  'prof_upratovanie': Icons.cleaning_services_outlined,
  'prof_pomoc_domacnosti': Icons.home_outlined,
  'prof_opatrovatelka_seniorov': Icons.elderly_outlined,
  'prof_opatrovatelka_deti': Icons.child_care_outlined,
  'prof_starostlivost_zvierata': Icons.pets_outlined,

  // ZDRAVIE
  'prof_zdravotny_asistent': Icons.medical_services_outlined,
  'prof_fyzioterapeut': Icons.healing_outlined,
  'prof_maser': Icons.spa_outlined,
  'prof_psycholog': Icons.psychology_outlined,

  // BEAUTY
  'prof_kozmeticka': Icons.face_retouching_natural_outlined,
  'prof_kadernicka': Icons.content_cut_outlined,
  'prof_vizazistka': Icons.brush_outlined,
  'prof_barberka': Icons.content_cut_outlined,
  'prof_nechtarka': Icons.back_hand_outlined,
  'prof_pedikerka': Icons.spa_outlined,
  'prof_lash_stylistka': Icons.remove_red_eye_outlined,
  'prof_brow_stylistka': Icons.architecture_outlined,
  'prof_skin_expert': Icons.face_outlined,
  'prof_beauty_konzultantka': Icons.support_agent_outlined,

  // GASTRO
  'prof_kuchar': Icons.restaurant_outlined,
  'prof_cukrar': Icons.cake_outlined,
  'prof_pekar': Icons.bakery_dining_outlined,

  // SLUŽBY
  'prof_fotograf': Icons.camera_alt_outlined,
  'prof_tater': Icons.brush_outlined,
  'prof_instruktor_plavania': Icons.pool_outlined,
  'prof_instruktorka_tanca': Icons.music_note_outlined,
  'prof_trener': Icons.fitness_center_outlined,
  'prof_organizator_podujati': Icons.event_outlined,

  // PROFESIE
  'prof_pravnik': Icons.gavel_outlined,
  'prof_uctovnik': Icons.calculate_outlined,

  // TRADIČNÉ
  'prof_koziar': Icons.checkroom_outlined,
  'prof_kovac': Icons.hardware_outlined,
  'prof_kosikar': Icons.shopping_basket_outlined,
  'prof_hrnciar': Icons.circle_outlined,
  'prof_sindliar': Icons.cabin_outlined,
};

class CraftsmanRegisterForm extends StatefulWidget {
  const CraftsmanRegisterForm({super.key});

  @override
  State<CraftsmanRegisterForm> createState() => _CraftsmanRegisterFormState();
}

class _CraftsmanRegisterFormState extends State<CraftsmanRegisterForm> {
  final _emailController       = TextEditingController();
  final _passwordController    = TextEditingController();
  final _nameController        = TextEditingController();
  final _cityController        = TextEditingController();
  final _streetController      = TextEditingController();
  final _phoneController       = TextEditingController();
  final _descriptionController = TextEditingController();
  final _hourlyRateController  = TextEditingController();

  bool _isLoading       = false;
  bool _passwordVisible = false;
  final Set<String> _selectedProfessionKeys = {};

  late final List<String> _countryNames;
  String _selectedCountry     = 'Slovakia';
  String _selectedCountryCode = 'SK';

  @override
  void initState() {
    super.initState();
    _countryNames = countryMap.keys.toList()..sort();
  }

  @override
  void dispose() {
    _emailController.dispose(); _passwordController.dispose();
    _nameController.dispose(); _cityController.dispose();
    _streetController.dispose(); _phoneController.dispose();
    _descriptionController.dispose(); _hourlyRateController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);

  String _generateReferralCode(String name) {
    final prefix = name.trim().length >= 4
        ? name.trim().substring(0, 4).toUpperCase()
        : name.trim().toUpperCase();
    return '$prefix${Random().nextInt(9000) + 1000}';
  }

  void _toggleProfession(String key) => setState(() {
    if (_selectedProfessionKeys.contains(key)) {
      _selectedProfessionKeys.remove(key);
    } else {
      _selectedProfessionKeys.add(key);
    }
  });

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty ||
        _cityController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('fillAllFields'.tr())));
      return;
    }
    if (!_isValidEmail(_emailController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('enterValidEmail'.tr())));
      return;
    }
    if (_passwordController.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('passwordMinLength'.tr())));
      return;
    }
    if (_selectedProfessionKeys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('selectAtLeastOneProfession'.tr()),
          backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final uid = credential.user!.uid;
      final professionsList = _selectedProfessionKeys.toList();

      await FirebaseFirestore.instance.collection('craftsmen').doc(uid).set({
        'name':          _nameController.text.trim(),
        'email':         _emailController.text.trim(),
        'cityName':      _cityController.text.trim(),
        'streetAddress': _streetController.text.trim(),
        'phone':         _phoneController.text.trim(),
        'bio':           _descriptionController.text.trim(),
        'profession':    professionsList.first,
        'category':      '',
        'skills':        professionsList,
        'country':       _selectedCountry,
        'countryCode':   _selectedCountryCode,
        'hourlyRate':    double.tryParse(_hourlyRateController.text.trim()),
        'depositPercent': 30.0,
        'isVerified':    false,
        'isActive':      true,
        'rating':        0.0,
        'reviewCount':   0,
        'createdAt':     FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email':           _emailController.text.trim(),
        'role':            'craftsman',
        'createdAt':       FieldValue.serverTimestamp(),
        'referralCode':    _generateReferralCode(_nameController.text.trim()),
        'discountPercent': 0,
      });

      await credential.user!.sendEmailVerification();
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;

      await showDialog(
        context: context, barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Row(children: [
            Icon(Icons.mark_email_unread_outlined, color: _kPrimary),
            const SizedBox(width: 8),
            Text('emailVerification'.tr()),
          ]),
          content: Text('emailVerificationSent'.tr()),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('ok'.tr()),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'registrationError'.tr())));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('craftsmanRegistration'.tr()),
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 8),
          Image.asset('assets/logo.png', height: 70, width: 70),
          const SizedBox(height: 24),

          _sectionTitle('basicInfo'.tr(), Icons.person_outline_rounded),
          const SizedBox(height: 12),
          _buildField(_emailController, 'email'.tr(), Icons.email_outlined,
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: !_passwordVisible,
            decoration: InputDecoration(
              labelText: 'password'.tr(),
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kPrimary, width: 2)),
              suffixIcon: IconButton(
                icon: Icon(_passwordVisible
                    ? Icons.visibility_off : Icons.visibility),
                onPressed: () =>
                    setState(() => _passwordVisible = !_passwordVisible),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildField(_nameController, 'name'.tr(), Icons.badge_outlined),
          const SizedBox(height: 12),
          _buildField(_phoneController, 'phone'.tr(), Icons.phone_outlined,
              keyboardType: TextInputType.phone),
          const SizedBox(height: 24),

          _sectionTitle('address'.tr(), Icons.location_on_outlined),
          const SizedBox(height: 12),
          _buildField(_cityController, 'city'.tr(), Icons.location_city_outlined),
          const SizedBox(height: 12),
          _buildField(_streetController, 'street'.tr(), Icons.signpost_outlined),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedCountry,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'country'.tr(),
              prefixIcon: const Icon(Icons.flag_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kPrimary, width: 2)),
            ),
            items: _countryNames
                .map((n) => DropdownMenuItem(
                    value: n,
                    child: Text(n, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (val) => setState(() {
              _selectedCountry = val!;
              _selectedCountryCode = countryMap[val] ?? 'SK';
            }),
          ),
          const SizedBox(height: 24),

          _sectionTitle('yourProfessions'.tr(), Icons.handyman_outlined),
          const SizedBox(height: 4),
          Text('selectAllProfessions'.tr(),
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kAllProfessionKeys.map((key) {
              final selected = _selectedProfessionKeys.contains(key);
              final icon = kProfessionIcons[key] ?? Icons.handyman_outlined;
              return GestureDetector(
                onTap: () => _toggleProfession(key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? _kPrimary : Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: selected ? _kPrimary : Colors.grey.shade300,
                      width: selected ? 2 : 1,
                    ),
                    boxShadow: selected
                        ? [BoxShadow(
                            color: _kPrimary.withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2))]
                        : [],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, size: 15,
                        color: selected ? Colors.white : Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(key.tr(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          color: selected ? Colors.white : Colors.grey.shade700,
                        )),
                  ]),
                ),
              );
            }).toList(),
          ),
          if (_selectedProfessionKeys.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'selectedCount'.tr(namedArgs: {
                'count': _selectedProfessionKeys.length.toString(),
              }),
              style: const TextStyle(
                  fontSize: 12, color: _kPrimary, fontWeight: FontWeight.w500),
            ),
          ],
          const SizedBox(height: 24),

          _sectionTitle('pricingInfo'.tr(), Icons.euro_outlined),
          const SizedBox(height: 12),
          _buildField(_hourlyRateController, 'hourlyRateLabel'.tr(),
              Icons.euro_outlined, keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            maxLength: 400,
            decoration: InputDecoration(
              labelText: 'description'.tr(),
              hintText: 'descriptionHint'.tr(),
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              prefixIcon: const Icon(Icons.description_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kPrimary, width: 2)),
            ),
          ),
          const SizedBox(height: 28),

          _isLoading
              ? const Center(child: CircularProgressIndicator(color: _kPrimary))
              : ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('register'.tr(),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String text, IconData icon) => Row(children: [
        Icon(icon, size: 18, color: _kPrimary),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
      ]);

  Widget _buildField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) =>
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kPrimary, width: 2)),
        ),
      );
}