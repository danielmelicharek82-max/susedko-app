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
  'prof_instalater': ['cat_voda_a_odpad', 'cat_wc_a_baterie', 'cat_ine'],
  'prof_elektrikar': ['cat_zasuvky_a_svetla', 'cat_istice', 'cat_ine'],
  'prof_kurenar': ['cat_radiatory', 'cat_kotly', 'cat_podlahove_kurenie', 'cat_ine'],
  'prof_plynar': ['cat_instalacia', 'cat_oprava', 'cat_ine'],
  'prof_klampiar': ['cat_strechy', 'cat_odkvapy', 'cat_plechy', 'cat_ine'],
  'prof_zvarac': ['cat_opravy_kovov', 'cat_konstrukcie', 'cat_ine'],
  'prof_oprava_spotrebicov': ['cat_pracka', 'cat_chladnicka', 'cat_rura', 'cat_ine'],
  'prof_zamocnik': ['cat_zamky', 'cat_dvere', 'cat_otvorenie', 'cat_ine'],
  'prof_maliar': ['cat_maliarske_prace', 'cat_ine'],
  'prof_murar': ['cat_murarske_prace', 'cat_ine'],
  'prof_sadrokarton': ['cat_montaz', 'cat_oprava', 'cat_ine'],
  'prof_obkladac': ['cat_obklady', 'cat_dlazba', 'cat_ine'],
  'prof_podlahar': ['cat_parkety', 'cat_laminat', 'cat_vinyl', 'cat_ine'],
  'prof_montaz_nabytku': ['cat_montaz', 'cat_ine'],
  'prof_stolar': ['cat_vyroba', 'cat_oprava', 'cat_ine'],
  'prof_upratovanie': ['cat_bezne_upratovanie', 'cat_generalne', 'cat_po_rekonstrukcii', 'cat_okna', 'cat_koberce_a_sedacky'],
  'prof_zahradnik': ['cat_kosenie', 'cat_orez_stromov', 'cat_vyrub', 'cat_cistenie_okapov', 'cat_zimna_udrzba', 'cat_dlazba'],
  'prof_stahovanie': ['cat_stahovanie', 'cat_odvoz_odpadu', 'cat_odvoz_nabytku', 'cat_dodavka_s_vodicom'],
  'prof_it_technik': ['cat_oprava_pc', 'cat_oprava_mobilu', 'cat_it_podpora', 'cat_smart_home', 'cat_tv_a_kamery'],
  'prof_opatrovatelka_seniorov': ['cat_denna_starostlivost', 'cat_nocna_starostlivost', 'cat_sprevadzanie', 'cat_ine'],
  'prof_opatrovatelka_deti': ['cat_denna_starostlivost', 'cat_hlidanie', 'cat_vikendy', 'cat_ine'],
  'prof_pomoc_domacnosti': ['cat_varenie', 'cat_upratovanie', 'cat_nakupy', 'cat_zehlenie', 'cat_ine'],
  'prof_starostlivost_zvierata': ['cat_vencenie', 'cat_strazenie', 'cat_krmenie', 'cat_ine'],
  'prof_zdravotny_asistent': ['cat_domaca_starostlivost', 'cat_meranie_tlaku_a_cukru', 'cat_podavanie_liekov', 'cat_ine'],
  'prof_cykloopravar': ['cat_oprava_bicykla', 'cat_servis_brzd_a_prehadzovacky', 'cat_vymena_duse_plasta', 'cat_ine'],
  'prof_tater': ['cat_tetovanie', 'cat_navrh_dizajnu', 'cat_prekrytie_stareho_tetovania', 'cat_ine'],
  'prof_instruktor_plavania': ['cat_vyucba_plavania', 'cat_zlepsenie_techniky', 'cat_kurzy_pre_deti', 'cat_ine'],
  'prof_porodna_asistentka': ['cat_predporodna_starostlivost', 'cat_pomoc_pri_porode', 'cat_poporodna_starostlivost', 'cat_ine'],
  'prof_organizator_podujati': ['cat_svadby', 'cat_firemne_akcie', 'cat_oslavy', 'cat_koordinacia_podujatia', 'cat_ine'],
  'prof_maser': ['cat_klasicka_masaz', 'cat_sportova_masaz', 'cat_relaxacna_masaz', 'cat_rehabilitacna_masaz', 'cat_ine'],
  'prof_trener': ['cat_osobny_trening', 'cat_kondicny_trening', 'cat_online_trening', 'cat_treningovy_plan', 'cat_ine'],
  'prof_instruktorka_tanca': ['cat_individualne_lekcie', 'cat_skupinove_lekcie', 'cat_svadobny_tanec', 'cat_ine'],
  'prof_fyzioterapeut': ['cat_rehabilitacia', 'cat_cvicenia_na_chrbticu', 'cat_pourazova_terapia', 'cat_ine'],
  'prof_fotograf': ['cat_portrety', 'cat_svadby', 'cat_eventy', 'cat_produktova_fotografia', 'cat_ine'],
  'prof_doucovatel': ['cat_zs', 'cat_ss', 'cat_vs', 'cat_priprava_na_skusky', 'cat_ine'],
  'prof_lektor': ['cat_kurzy', 'cat_skolenia', 'cat_workshopy', 'cat_online_vyucba', 'cat_ine'],
  'prof_psycholog': ['cat_konzultacie', 'cat_terapia', 'cat_poradenstvo', 'cat_krizova_intervencia', 'cat_ine'],
  'prof_kozmeticka': ['cat_cistenie_pleti', 'cat_osetrenie_pleti', 'cat_depilacia', 'cat_licenie', 'cat_ine'],
  'prof_kadernicka': ['cat_strihanie', 'cat_farbenie', 'cat_styling', 'cat_uprava_vlasov', 'cat_ine'],
  'prof_automechanik': ['cat_servis_vozidla', 'cat_diagnostika', 'cat_vymena_oleja', 'cat_opravy', 'cat_ine'],
  'prof_kachliar': ['cat_kachlove_pece', 'cat_krby', 'cat_oprava', 'cat_ine'],
  'prof_kominar': ['cat_cistenie_komina', 'cat_kontrola_komina', 'cat_oprava', 'cat_ine'],
  'prof_strechar': ['cat_pokryvacske_prace', 'cat_oprava_strechy', 'cat_izolacia', 'cat_ine'],
  'prof_tesar': ['cat_tesarske_konstrukcie', 'cat_krovove_prace', 'cat_oprava', 'cat_ine'],
  'prof_studniar': ['cat_vrtanie_studni', 'cat_cistenie_studni', 'cat_oprava', 'cat_ine'],
  'prof_bagrista': ['cat_vykopove_prace', 'cat_terenne_upravy', 'cat_ine'],
  'prof_traktorista': ['cat_orba', 'cat_kosenie', 'cat_preprava', 'cat_ine'],
  'prof_drevorubac': ['cat_vyrub_stromov', 'cat_orez', 'cat_stiepanie_dreva', 'cat_ine'],
  'prof_plotar': ['cat_montaz_plota', 'cat_oprava_plota', 'cat_brany', 'cat_ine'],
  'prof_dlazdic_exterier': ['cat_dlazba_exterier', 'cat_chodniky', 'cat_terasy', 'cat_ine'],
  'prof_koziar': ['cat_oprava_koze', 'cat_vyroba_kozeneho_tovaru', 'cat_ine'],
  'prof_kovac': ['cat_kovacske_prace', 'cat_umelecke_kovanie', 'cat_oprava', 'cat_ine'],
  'prof_kosikar': ['cat_pletenie_kosov', 'cat_oprava', 'cat_ine'],
  'prof_hrnciar': ['cat_hrnciarske_vyrobky', 'cat_oprava_keramiky', 'cat_ine'],
  'prof_sindliar': ['cat_sindlove_strechy', 'cat_oprava', 'cat_ine'],
  'prof_veterinar_hospodarske': ['cat_osetrenie_hospodarskych_zvierat', 'cat_ockovanie', 'cat_ine'],
  'prof_strihac_oviec': ['cat_strihanie_oviec', 'cat_ine'],
  'prof_podkuvac_koni': ['cat_podkovanie_koni', 'cat_starostlivost_o_kopyta', 'cat_ine'],
  'prof_restaurator': ['cat_restaurovanie_nabytku', 'cat_restaurovanie_predmetov', 'cat_ine'],
  'prof_oprava_naradia': ['cat_oprava_elektrickeho_naradia', 'cat_oprava_rucneho_naradia', 'cat_ine'],
  'prof_brusic_nozov': ['cat_brusenie_nozov', 'cat_brusenie_noznic', 'cat_brusenie_nastrojov', 'cat_ine'],
  'prof_lakyrnik': ['cat_lakovanie_nabytku', 'cat_lakovanie_aut', 'cat_ine'],
  'prof_calunik': ['cat_calunenie_nabytku', 'cat_oprava_calunenia', 'cat_ine'],
  'prof_kuchar': ['cat_kuchyna', 'cat_menu_na_mieru', 'cat_catering', 'cat_ine'],
  'prof_cukrar': ['cat_torty', 'cat_zakusky', 'cat_svadobne_sladkosti', 'cat_ine'],
  'prof_uctovnik': ['cat_uctovnictvo', 'cat_danove_priznanie', 'cat_mzdy', 'cat_ine'],
  'prof_vizazistka': ['cat_licenie', 'cat_svadobny_makeup', 'cat_spolocenske_licenie', 'cat_ine'],
  'prof_barberka': ['cat_pansky_strih', 'cat_uprava_brady', 'cat_fade_strihy', 'cat_ine'],
  'prof_nechtarka': ['cat_gelove_nechty', 'cat_manikura', 'cat_pedikura', 'cat_ine'],
  'prof_pedikerka': ['cat_sucha_pedikura', 'cat_mokra_pedikura', 'cat_osetrenie_chodidiel', 'cat_ine'],
  'prof_lash_stylistka': ['cat_predlzovanie_mihalnic', 'cat_doplnanie_mihalnic', 'cat_lash_lifting', 'cat_ine'],
  'prof_brow_stylistka': ['cat_uprava_obocia', 'cat_laminacia_obocia', 'cat_farbenie_obocia', 'cat_ine'],
  'prof_skin_expert': ['cat_hlbkove_cistenie_pleti', 'cat_anti_aging_osetrenia', 'cat_analyza_pleti', 'cat_ine'],
  'prof_beauty_konzultantka': ['cat_konzultacia_starostlivosti_o_plet', 'cat_makeup_poradenstvo', 'cat_beauty_rutina', 'cat_ine'],
  'prof_klimatizaciar': ['cat_montaz_klimatizacie', 'cat_servis_klimatizacie', 'cat_oprava', 'cat_ine'],
  'prof_chladiar': ['cat_chladiace_zariadenia', 'cat_servis', 'cat_oprava', 'cat_ine'],
  'prof_revizny_technik': ['cat_revizia_elektroinstalacie', 'cat_revizia_plynu', 'cat_revizia_komina', 'cat_ine'],
  'prof_bleskozvodar': ['cat_montaz_bleskozvodu', 'cat_revizia_bleskozvodu', 'cat_oprava', 'cat_ine'],
  'prof_alarmy_kamery': ['cat_montaz_alarmu', 'cat_kamerovy_system', 'cat_servis', 'cat_ine'],
  'prof_fotovoltika': ['cat_navrh_a_montaz_fve', 'cat_servis_fotovoltiky', 'cat_ine'],
  'prof_fasadar': ['cat_zateplovanie_fasad', 'cat_omietky', 'cat_oprava_fasady', 'cat_ine'],
  'prof_izolater': ['cat_tepelna_izolacia', 'cat_hydroizolacia', 'cat_ine'],
  'prof_buracie_prace': ['cat_buranie_priecok', 'cat_buranie_stavieb', 'cat_odvoz_sute', 'cat_ine'],
  'prof_oknar': ['cat_montaz_okien', 'cat_vymena_okien', 'cat_servis_okien', 'cat_ine'],
  'prof_montaz_dveri': ['cat_montaz_dveri', 'cat_vymena_dveri', 'cat_ine'],
  'prof_lecenar': ['cat_lesenarske_prace', 'cat_prenajom_lesenia', 'cat_ine'],
  'prof_betonar': ['cat_betonarske_prace', 'cat_zaklady', 'cat_betonove_plochy', 'cat_ine'],
  'prof_zeleziar': ['cat_armovanie', 'cat_zvaranie_vystuze', 'cat_ine'],
  'prof_montaz_kuchyn': ['cat_montaz_kuchynskej_linky', 'cat_zameranie_kuchyne', 'cat_ine'],
  'prof_hodinovy_manzel': ['cat_drobne_opravy', 'cat_udrzba_domacnosti', 'cat_ine'],
  'prof_servis_kotlov': ['cat_servis_kotla', 'cat_revizia_kotla', 'cat_oprava', 'cat_ine'],
  'prof_servis_klimatizacii': ['cat_servis_klimatizacie', 'cat_cistenie_klimatizacie', 'cat_ine'],
  'prof_servis_okien': ['cat_servis_okien', 'cat_nastavenie_okien', 'cat_ine'],
  'prof_servis_bazenov': ['cat_servis_bazena', 'cat_chemia_bazena', 'cat_ine'],
  'prof_servis_pc': ['cat_oprava_pc', 'cat_cistenie_pc', 'cat_instalacia_softveru', 'cat_ine'],
  'prof_servis_mobilov': ['cat_oprava_displeja', 'cat_vymena_baterie', 'cat_ine'],
  'prof_pneuservis': ['cat_vymena_pneumatik', 'cat_vyvazenie_kolies', 'cat_oprava_defektu', 'cat_ine'],
  'prof_autoklampiar': ['cat_karosarske_prace', 'cat_oprava_po_nehode', 'cat_ine'],
  'prof_autoelektrikar': ['cat_autoelektrika', 'cat_diagnostika', 'cat_oprava', 'cat_ine'],
  'prof_stahovacie_sluzby': ['cat_stahovanie_bytu', 'cat_stahovanie_firmy', 'cat_ine'],
  'prof_vypratavanie': ['cat_vypratanie_bytu', 'cat_vypratanie_pozemku', 'cat_odvoz_odpadu', 'cat_ine'],
  'prof_kurier': ['cat_dorucenie_zasielky', 'cat_preprava_tovaru', 'cat_ine'],
  'prof_dovoz_materialu': ['cat_dovoz_stavebneho_materialu', 'cat_dovoz_tovaru', 'cat_ine'],
  'prof_odtahova_sluzba': ['cat_odtiahnutie_vozidla', 'cat_preprava_vozidla', 'cat_ine'],
  'prof_arborista': ['cat_rizikovy_vyrub', 'cat_orez_korun', 'cat_osetrenie_stromov', 'cat_ine'],
  'prof_dlazba_zamkova': ['cat_zamkova_dlazba', 'cat_chodniky_a_dvory', 'cat_ine'],
  'prof_bazenar': ['cat_vystavba_bazena', 'cat_udrzba_bazena', 'cat_ine'],
  'prof_zavlahy': ['cat_navrh_zavlahy', 'cat_montaz_zavlahy', 'cat_servis', 'cat_ine'],
  'prof_umyvanie_okien': ['cat_umyvanie_okien', 'cat_umyvanie_fasad', 'cat_ine'],
  'prof_tepovanie': ['cat_tepovanie_kobercov', 'cat_tepovanie_sedaciek', 'cat_ine'],
  'prof_zehlenie': ['cat_zehlenie_bielizne', 'cat_zehlenie_na_objednavku', 'cat_ine'],
  'prof_deratizacia': ['cat_deratizacia_hlodavcov', 'cat_prevencia', 'cat_ine'],
  'prof_dezinsekcia': ['cat_dezinsekcia_hmyzu', 'cat_prevencia', 'cat_ine'],
  'prof_psi_strihac': ['cat_strihanie_psov', 'cat_kupanie_a_uprava', 'cat_ine'],
  'prof_vycvik_psov': ['cat_zakladna_poslusnost', 'cat_specializovany_vycvik', 'cat_ine'],
  'prof_nutricny_terapeut': ['cat_konzultacia_stravovania', 'cat_jedalnicek_na_mieru', 'cat_ine'],
  'prof_logoped': ['cat_naprava_vyslovnosti', 'cat_vyvinova_logopedia', 'cat_ine'],
  'prof_ergoterapeut': ['cat_ergoterapia', 'cat_nacvik_sebestacnosti', 'cat_ine'],
  'prof_permanentny_makeup': ['cat_permanentne_obocie', 'cat_permanentne_pery', 'cat_permanentne_linky', 'cat_ine'],
  'prof_piercer': ['cat_piercing', 'cat_osetrenie_piercingu', 'cat_ine'],
  'prof_spa_terapeutka': ['cat_wellness_procedury', 'cat_relaxacne_ritualy', 'cat_ine'],
  'prof_pekar': ['cat_pecivo_na_objednavku', 'cat_chlieb_a_bagety', 'cat_ine'],
  'prof_catering': ['cat_catering_na_eventy', 'cat_firemny_catering', 'cat_svadobny_catering', 'cat_ine'],
  'prof_barman': ['cat_barmanske_sluzby_na_akciu', 'cat_miesane_napoje', 'cat_ine'],
  'prof_grilmajster': ['cat_grilovanie_na_objednavku', 'cat_bbq_akcie', 'cat_ine'],
  'prof_jazykovy_lektor': ['cat_konverzacny_kurz', 'cat_priprava_na_skusky', 'cat_firemna_vyucba', 'cat_ine'],
  'prof_hudobny_ucitel': ['cat_hra_na_nastroj', 'cat_spev', 'cat_hudobna_teoria', 'cat_ine'],
  'prof_instruktor_jazdy': ['cat_vodicsky_kurz', 'cat_kondicne_jazdy', 'cat_ine'],
  'prof_kameraman': ['cat_svadobne_video', 'cat_firemne_video', 'cat_eventy', 'cat_ine'],
  'prof_dj': ['cat_svadby', 'cat_firemne_akcie', 'cat_oslavy', 'cat_ine'],
  'prof_hudobnik': ['cat_ziva_hudba_na_akciu', 'cat_svadobna_hudba', 'cat_ine'],
  'prof_grafik': ['cat_logo_a_vizual', 'cat_tlacoviny', 'cat_socialne_siete', 'cat_ine'],
  'prof_webdesigner': ['cat_navrh_webstranky', 'cat_ux_ui_dizajn', 'cat_ine'],
  'prof_programator': ['cat_vyvoj_webu', 'cat_vyvoj_aplikacie', 'cat_oprava_chyb', 'cat_ine'],
  'prof_pilot': ['cat_vyhliadkove_lety', 'cat_letecke_snimkovanie_dron', 'cat_ine'],
  'prof_pravnik': ['cat_zmluvy', 'cat_pravne_poradenstvo', 'cat_zastupovanie', 'cat_ine'],
  'prof_notar': ['cat_notarske_overenie', 'cat_notarska_zapisnica', 'cat_ine'],
  'prof_financny_poradca': ['cat_sporenie', 'cat_investicie', 'cat_hypoteka', 'cat_ine'],
  'prof_realitny_makler': ['cat_predaj_nehnutelnosti', 'cat_prenajom_nehnutelnosti', 'cat_odhad_ceny', 'cat_ine'],
  'prof_poistny_poradca': ['cat_poistenie_majetku', 'cat_zivotne_poistenie', 'cat_ine'],
  'prof_prekladatel': ['cat_preklad_dokumentov', 'cat_uradny_preklad', 'cat_tlmocenie', 'cat_ine'],
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
                      child: Text(cat.tr(), style: TextStyle(
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