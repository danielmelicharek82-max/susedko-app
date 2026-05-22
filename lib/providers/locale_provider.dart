import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LocaleProvider extends ChangeNotifier {
  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'sk', 'name': 'Slovenčina'},
    {'code': 'cs', 'name': 'Čeština'},
    {'code': 'en', 'name': 'English'},
    {'code': 'uk', 'name': 'Українська'},
    {'code': 'hu', 'name': 'Magyar'},
    {'code': 'pl', 'name': 'Polski'},
    {'code': 'de', 'name': 'Deutsch'},
    {'code': 'fr', 'name': 'Français'},
    {'code': 'es', 'name': 'Español'},
    {'code': 'it', 'name': 'Italiano'},
    {'code': 'ru', 'name': 'Русский'},
    {'code': 'tr', 'name': 'Türkçe'},
    {'code': 'nl', 'name': 'Nederlands'},
    {'code': 'da', 'name': 'Dansk'},
    {'code': 'sv', 'name': 'Svenska'},
    {'code': 'no', 'name': 'Norsk'},
    {'code': 'fi', 'name': 'Suomi'},
    {'code': 'hr', 'name': 'Hrvatski'},
    {'code': 'pt', 'name': 'Português'},
    {'code': 'zh', 'name': '中文'},
    {'code': 'hi', 'name': 'हिन्दी'},
    {'code': 'sw', 'name': 'Kiswahili'},
    {'code': 'ar', 'name': 'العربية'},
    {'code': 'ja', 'name': '日本語'},
    {'code': 'ro', 'name': 'Română'},
    {'code': 'el', 'name': 'Ελληνικά'},
    {'code': 'sr', 'name': 'Srpski'},
    {'code': 'bg', 'name': 'Български'},
  ];

  Future<void> changeLanguage(BuildContext context, String languageCode) async {
    await context.setLocale(Locale(languageCode));
    notifyListeners();
    await _saveLanguageToFirestore(languageCode);
  }

  Future<void> _saveLanguageToFirestore(String languageCode) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'language': languageCode});
    } catch (e) {
      debugPrint('Chyba pri ukladaní jazyka do Firestore: $e');
    }
  }

  Future<void> syncLanguageOnStartup(BuildContext context) async {
    final currentCode = context.locale.languageCode;
    await _saveLanguageToFirestore(currentCode);
  }
}