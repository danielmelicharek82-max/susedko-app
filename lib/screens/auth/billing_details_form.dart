// lib/screens/auth/billing_details_form.dart
//
// Opakovane použiteľný formulár fakturačných údajov.
//  • v registrácii (showAddress: false) — adresu (ulica, mesto, krajina)
//    drží rodičovský formulár, tu sa pýtame len na PSČ a ostatné údaje,
//  • na samostatnej obrazovke (showAddress: true) — všetky polia.
//
// Rodič drží BillingFormController, volá validate() a toProfile().

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../models/billing_profile.dart';
import '../../utils/billing_validators.dart';

const _kPrimary = Color(0xFF2563EB);

class BillingFormController {
  final TextEditingController phone = TextEditingController();
  final TextEditingController legalName = TextEditingController();
  final TextEditingController street = TextEditingController();
  final TextEditingController city = TextEditingController();
  final TextEditingController zip = TextEditingController();
  final TextEditingController ico = TextEditingController();
  final TextEditingController dic = TextEditingController();
  final TextEditingController icDph = TextEditingController();
  final TextEditingController iban = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  String country = 'Slovakia';
  String countryCode = 'SK';
  bool isCompany = false;
  bool vatPayer = false;
  bool selfBillingConsent = false;

  /// Spustí validáciu všetkých polí formulára (zobrazí chyby pri poliach).
  bool validate() => formKey.currentState?.validate() ?? false;

  void load(BillingProfile p) {
    phone.text = p.phone;
    legalName.text = p.legalName;
    street.text = p.street;
    city.text = p.city;
    zip.text = p.zip;
    if (p.country.isNotEmpty) country = p.country;
    if (p.countryCode.isNotEmpty) countryCode = p.countryCode;
    isCompany = p.isCompany;
    ico.text = p.ico;
    dic.text = p.dic;
    vatPayer = p.vatPayer;
    icDph.text = p.icDph;
    iban.text = p.iban;
    selfBillingConsent = p.selfBillingConsent;
  }

  /// Zloží profil z polí formulára. V registrácii (kde adresu drží rodič)
  /// sa adresa a meno dodajú cez *Override parametre.
  BillingProfile toProfile({
    required String role,
    String? fallbackName,
    String? streetOverride,
    String? cityOverride,
    String? countryOverride,
    String? countryCodeOverride,
  }) {
    final isCraftsman = role == 'craftsman';
    final company = isCraftsman ? true : isCompany;
    final name =
        (company ? legalName.text : (fallbackName ?? legalName.text)).trim();
    final vat = company && vatPayer;

    return BillingProfile(
      role: role,
      phone: phone.text.trim(),
      legalName: name,
      street: (streetOverride ?? street.text).trim(),
      city: (cityOverride ?? city.text).trim(),
      zip: zip.text.trim(),
      country: (countryOverride ?? country).trim(),
      countryCode: countryCodeOverride ?? countryCode,
      isCompany: company,
      ico: company ? ico.text.trim() : '',
      dic: company ? dic.text.trim() : '',
      vatPayer: vat,
      icDph: vat ? icDph.text.replaceAll(RegExp(r'\s+'), '').toUpperCase() : '',
      iban: isCraftsman
          ? iban.text.replaceAll(RegExp(r'\s+'), '').toUpperCase()
          : '',
      selfBillingConsent: isCraftsman ? selfBillingConsent : false,
    );
  }

  void dispose() {
    phone.dispose();
    legalName.dispose();
    street.dispose();
    city.dispose();
    zip.dispose();
    ico.dispose();
    dic.dispose();
    icDph.dispose();
    iban.dispose();
  }
}

class BillingDetailsForm extends StatefulWidget {
  final String role; // 'customer' | 'craftsman'
  final BillingFormController controller;

  /// true = vlastné polia adresy (samostatná obrazovka),
  /// false = adresu drží rodičovský formulár (registrácia).
  final bool showAddress;

  /// false = telefón sa pýta inde (napr. registrácia remeselníka).
  final bool showPhone;

  /// Zoznam krajín — potrebný len pri showAddress: true.
  final List<String> countryNames;
  final Map<String, String> countryMap;

  const BillingDetailsForm({
    super.key,
    required this.role,
    required this.controller,
    this.showAddress = true,
    this.showPhone = true,
    this.countryNames = const [],
    this.countryMap = const {},
  });

  @override
  State<BillingDetailsForm> createState() => _BillingDetailsFormState();
}

class _BillingDetailsFormState extends State<BillingDetailsForm> {
  BillingFormController get _c => widget.controller;
  bool get _isCraftsman => widget.role == 'craftsman';

  Widget _title(IconData icon, String text) => Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _kPrimary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: _kPrimary),
        ),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B))),
      ]);

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        textCapitalization: capitalization,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kPrimary, width: 2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showCompany = _isCraftsman || _c.isCompany;
    final showLegalName = widget.showAddress || showCompany;

    return Form(
      key: _c.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(Icons.receipt_long_outlined, 'billing_title'.tr()),
          const SizedBox(height: 6),
          Text(
            _isCraftsman
                ? 'billing_subtitle_craftsman'.tr()
                : 'billing_subtitle_customer'.tr(),
            style: TextStyle(
                fontSize: 13, color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 14),

          if (widget.showPhone)
            _field(_c.phone, 'billing_phone'.tr(), Icons.phone_outlined,
                validator: BillingValidators.phone,
                keyboardType: TextInputType.phone),

          // Zákazník: prepínač "nakupujem ako firma"
          if (!_isCraftsman)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: _kPrimary,
              value: _c.isCompany,
              onChanged: (v) => setState(() => _c.isCompany = v),
              title: Text('billing_buying_as_company'.tr(),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ),

          if (showLegalName)
            _field(
              _c.legalName,
              showCompany ? 'billing_legal_name'.tr() : 'name'.tr(),
              Icons.badge_outlined,
              validator: BillingValidators.notEmpty,
            ),

          if (widget.showAddress) ...[
            _field(_c.street, 'street'.tr(), Icons.signpost_outlined,
                validator: BillingValidators.notEmpty),
            _field(_c.city, 'city'.tr(), Icons.location_city_outlined,
                validator: BillingValidators.notEmpty),
          ],

          _field(
            _c.zip,
            'billing_zip'.tr(),
            Icons.markunread_mailbox_outlined,
            validator: (v) =>
                BillingValidators.zip(v, countryCode: _c.countryCode),
          ),

          if (widget.showAddress)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                value: widget.countryNames.contains(_c.country)
                    ? _c.country
                    : null,
                isExpanded: true,
                validator: BillingValidators.notEmpty,
                decoration: InputDecoration(
                  labelText: 'country'.tr(),
                  prefixIcon: const Icon(Icons.flag_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: widget.countryNames
                    .map((n) => DropdownMenuItem(
                          value: n,
                          child: Text(n, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) => setState(() {
                  _c.country = v!;
                  _c.countryCode = widget.countryMap[v] ?? 'SK';
                }),
              ),
            ),

          if (showCompany) ...[
            _field(_c.ico, 'billing_ico'.tr(), Icons.numbers_outlined,
                validator: (v) =>
                    BillingValidators.ico(v, countryCode: _c.countryCode),
                keyboardType: TextInputType.text),
            _field(_c.dic, 'billing_dic'.tr(), Icons.numbers_outlined,
                validator: (v) =>
                    BillingValidators.dic(v, countryCode: _c.countryCode),
                keyboardType: TextInputType.text),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: _kPrimary,
              value: _c.vatPayer,
              onChanged: (v) => setState(() => _c.vatPayer = v),
              title: Text('billing_vat_payer'.tr(),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            if (_c.vatPayer)
              _field(
                _c.icDph,
                'billing_ic_dph'.tr(),
                Icons.numbers_outlined,
                validator: (v) =>
                    BillingValidators.icDph(v, countryCode: _c.countryCode),
                capitalization: TextCapitalization.characters,
              ),
          ],

          if (_isCraftsman) ...[
            const SizedBox(height: 4),
            _field(
              _c.iban,
              'billing_iban'.tr(),
              Icons.account_balance_outlined,
              validator: BillingValidators.iban,
              capitalization: TextCapitalization.characters,
            ),
            FormField<bool>(
              validator: (_) => _c.selfBillingConsent
                  ? null
                  : 'billing_consent_required'.tr(),
              builder: (state) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: _kPrimary,
                    value: _c.selfBillingConsent,
                    onChanged: (v) {
                      setState(() => _c.selfBillingConsent = v ?? false);
                      state.didChange(v);
                    },
                    title: Text(
                      'billing_selfbilling_consent'.tr(),
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                  if (state.hasError)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        state.errorText ?? '',
                        style: TextStyle(
                            color: Colors.red.shade700, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
