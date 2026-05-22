// lib/screens/customer/service_request_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:io';

import 'package:homie/models/service_request.dart';
import 'package:homie/services/service_request_service.dart';
import '../auth/craftsman_register_form.dart'; // kProfessionIcons

const _kPrimary = Color(0xFF2563EB);
const _kDeep    = Color(0xFF1E40AF);
const _kAccent  = Color(0xFF60A5FA);
const _kBg      = Color(0xFFF0F4FF);

const Map<String, List<String>> kProfessionCategories = {
  // ── Pôvodné ───────────────────────────────────────────────────────────────
  'prof_instalater':    ['Voda a odpad', 'WC a batérie', 'Iné'],
  'prof_elektrikar':    ['Zásuvky a svetlá', 'Ističe', 'Iné'],
  'prof_kurenar':       ['Radiátory', 'Kotly', 'Podlahové kúrenie', 'Iné'],
  'prof_plynar':        ['Inštalácia', 'Oprava', 'Iné'],
  'prof_klampiar':      ['Strechy', 'Odkvapy', 'Plechy', 'Iné'],
  'prof_zvarac':        ['Opravy kovov', 'Konštrukcie', 'Iné'],
  'prof_oprava_spotrebicov': ['Práčka', 'Chladnička', 'Rúra', 'Iné'],
  'prof_zamocnik':      ['Zámky', 'Dvere', 'Otvorenie', 'Iné'],
  'prof_maliar':        ['Maliarske práce', 'Iné'],
  'prof_murar':         ['Murárske práce', 'Iné'],
  'prof_sadrokarton':   ['Montáž', 'Oprava', 'Iné'],
  'prof_obkladac':      ['Obklady', 'Dlažba', 'Iné'],
  'prof_podlahar':      ['Parkety', 'Laminát', 'Vinyl', 'Iné'],
  'prof_montaz_nabytku':['Montáž', 'Iné'],
  'prof_stolar':        ['Výroba', 'Oprava', 'Iné'],
  'prof_upratovanie':   ['Bežné upratovanie', 'Generálne', 'Po rekonštrukcii', 'Okná', 'Koberce a sedačky'],
  'prof_zahradnik':     ['Kosenie', 'Orez stromov', 'Výrub', 'Čistenie okapov', 'Zimná údržba', 'Dlažba'],
  'prof_stahovanie':    ['Sťahovanie', 'Odvoz odpadu', 'Odvoz nábytku', 'Dodávka s vodičom'],
  'prof_it_technik':    ['Oprava PC', 'Oprava mobilu', 'IT podpora', 'Smart home', 'TV a kamery'],
  'prof_opatrovatelka_seniorov': ['Denná starostlivosť', 'Nočná starostlivosť', 'Sprevádzanie', 'Iné'],
  'prof_opatrovatelka_deti':     ['Denná starostlivosť', 'Hlídanie', 'Víkendy', 'Iné'],
  'prof_pomoc_domacnosti':       ['Varenie', 'Upratovanie', 'Nákupy', 'Žehlenie', 'Iné'],
  'prof_starostlivost_zvierata': ['Venčenie', 'Stráženie', 'Kŕmenie', 'Iné'],
  'prof_zdravotny_asistent': ['Domáca starostlivosť', 'Meranie tlaku a cukru', 'Podávanie liekov', 'Iné'],
  'prof_cykloopravar': ['Oprava bicykla', 'Servis bŕzd a prehadzovačky', 'Výmena duše/plášťa', 'Iné'],
  'prof_tater': ['Tetovanie', 'Návrh dizajnu', 'Prekrytie starého tetovania', 'Iné'],
  'prof_instruktor_plavania': ['Výučba plávania', 'Zlepšenie techniky', 'Kurzy pre deti', 'Iné'],
  'prof_porodna_asistentka': ['Predpôrodná starostlivosť', 'Pomoc pri pôrode', 'Popôrodná starostlivosť', 'Iné'],
  'prof_organizator_podujati': ['Svadby', 'Firemné akcie', 'Oslavy', 'Koordinácia podujatia', 'Iné'],
  'prof_maser': ['Klasická masáž', 'Športová masáž', 'Relaxačná masáž', 'Rehabilitačná masáž', 'Iné'],
  'prof_trener': ['Osobný tréning', 'Kondičný tréning', 'Online tréning', 'Tréningový plán', 'Iné'],
  'prof_instruktorka_tanca': ['Individuálne lekcie', 'Skupinové lekcie', 'Svadobný tanec', 'Iné'],
  'prof_fyzioterapeut': ['Rehabilitácia', 'Cvičenia na chrbticu', 'Poúrazová terapia', 'Iné'],
  'prof_fotograf': ['Portréty', 'Svadby', 'Eventy', 'Produktová fotografia', 'Iné'],
  'prof_doucovatel': ['ZŠ', 'SŠ', 'VŠ', 'Príprava na skúšky', 'Iné'],
  'prof_lektor': ['Kurzy', 'Školenia', 'Workshopy', 'Online výučba', 'Iné'],
  'prof_psycholog': ['Konzultácie', 'Terapia', 'Poradenstvo', 'Krízová intervencia', 'Iné'],
  'prof_kozmeticka': ['Čistenie pleti', 'Ošetrenie pleti', 'Depilácia', 'Líčenie', 'Iné'],
  'prof_kadernicka': ['Strihanie', 'Farbenie', 'Styling', 'Úprava vlasov', 'Iné'],
  'prof_automechanik': ['Servis vozidla', 'Diagnostika', 'Výmena oleja', 'Opravy', 'Iné'],
  // ── Nové ─────────────────────────────────────────────────────────────────
  'prof_kachliar':              ['Kachľové pece', 'Krby', 'Oprava', 'Iné'],
  'prof_kominar':               ['Čistenie komína', 'Kontrola komína', 'Oprava', 'Iné'],
  'prof_strechar':              ['Pokrývačské práce', 'Oprava strechy', 'Izolácia', 'Iné'],
  'prof_tesar':                 ['Tesárske konštrukcie', 'Krovové práce', 'Oprava', 'Iné'],
  'prof_studniar':              ['Vŕtanie studní', 'Čistenie studní', 'Oprava', 'Iné'],
  'prof_bagrista':              ['Výkopové práce', 'Terénne úpravy', 'Iné'],
  'prof_traktorista':           ['Orba', 'Kosenie', 'Preprava', 'Iné'],
  'prof_drevorubac':            ['Výrub stromov', 'Orez', 'Štiepanie dreva', 'Iné'],
  'prof_plotar':                ['Montáž plota', 'Oprava plota', 'Brány', 'Iné'],
  'prof_dlazdic_exterier':      ['Dlažba exteriér', 'Chodníky', 'Terasy', 'Iné'],
  'prof_koziar':                ['Oprava kože', 'Výroba koženého tovaru', 'Iné'],
  'prof_kovac':                 ['Kováčske práce', 'Umelecké kovanie', 'Oprava', 'Iné'],
  'prof_kosikar':               ['Pletenie košov', 'Oprava', 'Iné'],
  'prof_hrnciar':               ['Hrnčiarske výrobky', 'Oprava keramiky', 'Iné'],
  'prof_sindliar':              ['Šindľové strechy', 'Oprava', 'Iné'],
  'prof_veterinar_hospodarske': ['Ošetrenie hospodárskych zvierat', 'Očkovanie', 'Iné'],
  'prof_strihac_oviec':         ['Strihanie oviec', 'Iné'],
  'prof_podkuvac_koni':         ['Podkovanie koní', 'Starostlivosť o kopytá', 'Iné'],
  'prof_restaurator':           ['Reštaurovanie nábytku', 'Reštaurovanie predmetov', 'Iné'],
  'prof_oprava_naradia':        ['Oprava elektrického náradia', 'Oprava ručného náradia', 'Iné'],
  'prof_brusic_nozov':          ['Brúsenie nožov', 'Brúsenie nožníc', 'Brúsenie nástrojov', 'Iné'],
  'prof_lakyrnik':              ['Lakovanie nábytku', 'Lakovanie áut', 'Iné'],
  'prof_calunik':               ['Čalúnenie nábytku', 'Oprava čalúnenia', 'Iné'],
  'prof_kuchar': ['Kuchyňa', 'Menu na mieru', 'Catering', 'Iné'],
  'prof_cukrar': ['Torty', 'Zákusky', 'Svadobné sladkosti', 'Iné'],
  'prof_uctovnik': ['Účtovníctvo', 'Daňové priznanie', 'Mzdy', 'Iné'],
  'prof_vizazistka': ['Líčenie', 'Svadobný makeup', 'Spoločenské líčenie', 'Iné'],
  'prof_barberka': ['Pánsky strih', 'Úprava brady', 'Fade strihy', 'Iné'],
  'prof_nechtarka': ['Gélové nechty', 'Manikúra', 'Pedikúra', 'Iné'],
  'prof_pedikerka': ['Suchá pedikúra', 'Mokrá pedikúra', 'Ošetrenie chodidiel', 'Iné'],
  'prof_lash_stylistka': ['Predlžovanie mihalníc', 'Dopĺňanie mihalníc', 'Lash lifting', 'Iné'],
  'prof_brow_stylistka': ['Úprava obočia', 'Laminácia obočia', 'Farbenie obočia', 'Iné'],
  'prof_skin_expert': ['Hĺbkové čistenie pleti', 'Anti-aging ošetrenia', 'Analýza pleti', 'Iné'],
  'prof_beauty_konzultantka': ['Konzultácia starostlivosti o pleť', 'Makeup poradenstvo', 'Beauty rutina', 'Iné'],
};

class ServiceRequestScreen extends StatefulWidget {
  final String craftsmanId;
  final String craftsmanName;
  final String? initialProfession;

  const ServiceRequestScreen({
    super.key,
    required this.craftsmanId,
    required this.craftsmanName,
    this.initialProfession,
  });

  @override
  State<ServiceRequestScreen> createState() => _ServiceRequestScreenState();
}

class _ServiceRequestScreenState extends State<ServiceRequestScreen> {
  final _formKey          = GlobalKey<FormState>();
  final _descController   = TextEditingController();
  final _budgetController = TextEditingController();
  final _addressController = TextEditingController();

  late String _selectedProfession;
  late String _selectedCategory;
  String _selectedTimeframe = '1_3_months';

  final List<File> _photos = [];
  bool _submitting      = false;
  bool _uploadingImages = false;

  @override
  void initState() {
    super.initState();
    _selectedProfession = widget.initialProfession != null &&
            kProfessionCategories.containsKey(widget.initialProfession)
        ? widget.initialProfession!
        : kProfessionCategories.keys.first;
    _selectedCategory =
        kProfessionCategories[_selectedProfession]!.first;
  }

  @override
  void dispose() {
    _descController.dispose();
    _budgetController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _onProfessionChanged(String profession) {
    setState(() {
      _selectedProfession = profession;
      _selectedCategory   = kProfessionCategories[profession]!.first;
    });
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) return;
    setState(() => _photos.add(File(picked.path)));
  }

  Future<List<String>> _uploadPhotos() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    final urls = <String>[];
    for (final file in _photos) {
      final ref = FirebaseStorage.instance.ref().child(
          'service_requests/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(file);
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _submitting = true);
    try {
      final hasPending = await ServiceRequestService.hasPendingRequest(
          user.uid, widget.craftsmanId);
      if (hasPending && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('pendingRequest'.tr()),
            backgroundColor: Colors.orange));
        setState(() => _submitting = false);
        return;
      }

      setState(() => _uploadingImages = true);
      final photoUrls = await _uploadPhotos();
      setState(() => _uploadingImages = false);

      final request = ServiceRequest(
        id:            '',
        customerId:    user.uid,
        craftsmanId:   widget.craftsmanId,
        craftsmanName: widget.craftsmanName,
        customerName:  user.displayName ?? user.email ?? '',
        customerEmail: user.email ?? '',
        profession:    _selectedProfession,
        category:      _selectedCategory,
        description:   _descController.text.trim(),
        address:       _addressController.text.trim().isEmpty
                           ? null : _addressController.text.trim(),
        budget:        double.tryParse(_budgetController.text.trim()),
        photoUrls:     photoUrls,
        timeframe:     _selectedTimeframe,
        status:        ServiceRequestStatus.pending,
        createdAt:     DateTime.now(),
      );

      await ServiceRequestService.submitRequest(request);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('requestSentSuccess'.tr()),
            backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'error'.tr()}: $e'),
              backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = kProfessionCategories[_selectedProfession] ?? [];

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
                        Text('tattooRequest'.tr(),
                          style: const TextStyle(
                            color: Colors.white, fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5)),
                        const SizedBox(height: 2),
                        Text(widget.craftsmanName,
                          style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
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

              // ── Info banner ────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kPrimary.withOpacity(0.2))),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: _kPrimary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(9)),
                    child: const Icon(Icons.info_outline,
                        size: 15, color: _kPrimary)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(
                    'requestInfoBanner'.tr(namedArgs: {
                      'name': widget.craftsmanName,
                    }),
                    style: TextStyle(fontSize: 13,
                        color: _kPrimary.withOpacity(0.85),
                        height: 1.4))),
                ])),
              const SizedBox(height: 20),

              // ── Profession ─────────────────────────────────────────────
              _sectionTitle('selectProfession'.tr(), Icons.handyman_outlined),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
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
                                  size: 16, color: _kPrimary),
                              const SizedBox(width: 8),
                              Text(key.tr()),
                            ]))).toList(),
                    onChanged: (v) => _onProfessionChanged(v!)))),
              const SizedBox(height: 20),

              // ── Category ───────────────────────────────────────────────
              _sectionTitle('selectCategory'.tr(), Icons.category_outlined),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: categories.map((cat) {
                  final sel = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: sel ? _kPrimary : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: sel ? _kPrimary : Colors.grey.shade300,
                            width: sel ? 2 : 1),
                        boxShadow: sel ? [BoxShadow(
                            color: _kPrimary.withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2))] : []),
                      child: Text(cat, style: TextStyle(
                          fontSize: 13,
                          color: sel ? Colors.white : Colors.grey.shade700,
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal))));
                }).toList()),
              const SizedBox(height: 20),

              // ── Description ────────────────────────────────────────────
              _sectionTitle('describeIssue'.tr(), Icons.description_outlined),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
                child: TextFormField(
                  controller: _descController,
                  maxLines: 4, maxLength: 600,
                  decoration: InputDecoration(
                    hintText: 'describeIssuePlaceholder'.tr(),
                    hintStyle: TextStyle(
                        color: Colors.grey.shade400, fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(14)),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'descRequired'.tr() : null)),
              const SizedBox(height: 20),

              // ── Address ────────────────────────────────────────────────
              _sectionTitle('addressOptional'.tr(), Icons.location_on_outlined),
              const SizedBox(height: 10),
              _inputField(
                controller: _addressController,
                hint: 'broadcastRequest_address_hint'.tr(),
                icon: Icons.location_on_outlined),
              const SizedBox(height: 20),

              // ── Budget ─────────────────────────────────────────────────
              _sectionTitle('budgetEur'.tr(), Icons.euro_outlined),
              const SizedBox(height: 10),
              _inputField(
                controller: _budgetController,
                hint: 'budgetPlaceholder'.tr(),
                icon: Icons.euro_outlined,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v != null && v.isNotEmpty &&
                      double.tryParse(v) == null) {
                    return 'requestBudgetError'.tr();
                  }
                  return null;
                }),
              const SizedBox(height: 20),

              // ── Timeframe ──────────────────────────────────────────────
              _sectionTitle('whenNeeded'.tr(), Icons.schedule_outlined),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedTimeframe,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(value: 'asap',
                          child: Text('broadcastRequest_timeframe_asap'.tr())),
                      DropdownMenuItem(value: '1_3_days',
                          child: Text('broadcastRequest_timeframe_3days'.tr())),
                      DropdownMenuItem(value: '1_2_weeks',
                          child: Text('broadcastRequest_timeframe_2weeks'.tr())),
                      DropdownMenuItem(value: '1_3_months',
                          child: Text('broadcastRequest_timeframe_3months'.tr())),
                      DropdownMenuItem(value: 'no_rush',
                          child: Text('broadcastRequest_timeframe_no_rush'.tr())),
                    ],
                    onChanged: (v) => setState(() => _selectedTimeframe = v!)))),
              const SizedBox(height: 20),

              // ── Photos ─────────────────────────────────────────────────
              _sectionTitle('photosMax'.tr(), Icons.photo_library_outlined),
              const SizedBox(height: 10),
              if (_photos.isNotEmpty) ...[
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photos.length,
                    itemBuilder: (context, i) => Stack(children: [
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                              image: FileImage(_photos[i]),
                              fit: BoxFit.cover))),
                      Positioned(top: 4, right: 12,
                        child: GestureDetector(
                          onTap: () => setState(() => _photos.removeAt(i)),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                                color: Colors.red, shape: BoxShape.circle),
                            child: const Icon(Icons.close,
                                size: 14, color: Colors.white)))),
                    ]))),
                const SizedBox(height: 10),
              ],
              if (_photos.length < 5)
                GestureDetector(
                  onTap: _pickPhoto,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _kPrimary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kPrimary.withOpacity(0.25))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.add_photo_alternate_outlined,
                          color: _kPrimary, size: 18),
                      const SizedBox(width: 8),
                      Text('addPhotoBtn'.tr(), style: const TextStyle(
                          color: _kPrimary, fontWeight: FontWeight.w600)),
                    ]))),
              const SizedBox(height: 32),

              // ── Submit ─────────────────────────────────────────────────
              GestureDetector(
                onTap: _submitting ? null : _submit,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    gradient: _submitting
                        ? LinearGradient(colors: [
                            Colors.grey.shade400, Colors.grey.shade300])
                        : const LinearGradient(
                            colors: [_kDeep, _kPrimary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _submitting ? [] : [BoxShadow(
                      color: _kPrimary.withOpacity(0.3),
                      blurRadius: 10, offset: const Offset(0, 4))]),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    if (_submitting)
                      const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    else
                      const Icon(Icons.send_rounded,
                          color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      _submitting
                          ? (_uploadingImages
                              ? 'uploadingPhotos'.tr()
                              : 'submitting'.tr())
                          : 'sendRequest'.tr(),
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
    Text(text, style: const TextStyle(
        fontSize: 15, fontWeight: FontWeight.bold,
        color: Color(0xFF1E293B))),
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
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(icon, color: _kPrimary.withOpacity(0.6), size: 18),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _kPrimary, width: 2)))));
}