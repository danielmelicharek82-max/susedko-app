// lib/screens/craftsman/about_craftsman_app_screen.dart

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

const _kPrimary = Color(0xFF2563EB);
const _kDeep    = Color(0xFF1E40AF);
const _kAccent  = Color(0xFF60A5FA);
const _kBg      = Color(0xFFF0F4FF);

class AboutCraftsmanAppScreen extends StatelessWidget {
  const AboutCraftsmanAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: CustomScrollView(
        slivers: [

          // ── Gradient AppBar ────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: _kPrimary,
            foregroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_kDeep, _kPrimary, Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight)),
                child: Stack(children: [
                  Positioned(right: -40, top: -40,
                    child: Container(width: 180, height: 180,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle))),
                  Positioned(left: -30, bottom: -30,
                    child: Container(width: 130, height: 130,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        shape: BoxShape.circle))),
                  Positioned(right: 60, bottom: -20,
                    child: Container(width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        shape: BoxShape.circle))),
                  Positioned.fill(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 16, offset: const Offset(0, 6))]),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.asset('assets/logo.png',
                                fit: BoxFit.cover))),
                        const SizedBox(height: 12),
                        const Text('Susedko',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5)),
                        const SizedBox(height: 4),
                        Text('aca_tagline'.tr(),
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14)),
                      ])),
                ])),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              child: Column(children: [

                // ── Vitajte ───────────────────────────────────────────────
                _sectionCard(
                  icon: Icons.waving_hand_outlined,
                  title: 'aca_welcome_title'.tr(),
                  child: Text(
                    'aca_welcome_desc'.tr(),
                    style: TextStyle(fontSize: 14,
                        color: Colors.grey.shade700, height: 1.6))),
                const SizedBox(height: 14),

                // ── Verifikácia ───────────────────────────────────────────
                _sectionCard(
                  icon: Icons.verified_outlined,
                  title: 'aca_verification_title'.tr(),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('aca_verification_desc'.tr(),
                        style: TextStyle(fontSize: 13,
                            color: Colors.grey.shade600, height: 1.5)),
                    const SizedBox(height: 12),
                    _highlightBox(
                      icon: Icons.mark_email_unread_outlined,
                      color: _kPrimary,
                      text: 'aca_verification_email'.tr()),
                    const SizedBox(height: 8),
                    _highlightBox(
                      icon: Icons.draw_outlined,
                      color: Colors.purple,
                      text: 'aca_verification_contract'.tr()),
                    const SizedBox(height: 8),
                    _highlightBox(
                      icon: Icons.admin_panel_settings_outlined,
                      color: Colors.orange,
                      text: 'aca_verification_admin'.tr()),
                  ])),
                const SizedBox(height: 14),

                // ── Ako funguje ───────────────────────────────────────────
                _sectionCard(
                  icon: Icons.help_outline_rounded,
                  title: 'aca_howto_title'.tr(),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    _featureTile(
                      icon: Icons.person_outline_rounded,
                      color: _kPrimary,
                      title: 'aca_howto_profile_title'.tr(),
                      text: 'aca_howto_profile_desc'.tr()),
                    _featureTile(
                      icon: Icons.event_available_outlined,
                      color: Colors.green,
                      title: 'aca_howto_calendar_title'.tr(),
                      text: 'aca_howto_calendar_desc'.tr()),
                    _featureTile(
                      icon: Icons.inbox_outlined,
                      color: Colors.purple,
                      title: 'aca_howto_requests_title'.tr(),
                      text: 'aca_howto_requests_desc'.tr()),
                    _featureTile(
                      icon: Icons.campaign_outlined,
                      color: Colors.orange,
                      title: 'aca_howto_broadcast_title'.tr(),
                      text: 'aca_howto_broadcast_desc'.tr()),
                    _featureTile(
                      icon: Icons.payments_outlined,
                      color: Colors.teal,
                      title: 'aca_howto_payment_title'.tr(),
                      text: 'aca_howto_payment_desc'.tr(),
                      last: true),
                  ])),
                const SizedBox(height: 14),

                // ── Kalendár — dôležité! ───────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade600, Colors.green.shade500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 12, offset: const Offset(0, 4))]),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.event_available_rounded,
                            size: 20, color: Colors.white)),
                      const SizedBox(width: 10),
                      Expanded(child: Text('aca_calendar_title'.tr(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold))),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20)),
                        child: Text('aca_calendar_badge'.tr(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold))),
                    ]),
                    const SizedBox(height: 12),
                    Text('aca_calendar_desc'.tr(),
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13, height: 1.5)),
                    const SizedBox(height: 12),
                    _calendarTip('aca_calendar_tip1'.tr()),
                    const SizedBox(height: 6),
                    _calendarTip('aca_calendar_tip2'.tr()),
                    const SizedBox(height: 6),
                    _calendarTip('aca_calendar_tip3'.tr()),
                  ])),
                const SizedBox(height: 14),

                // ── Platba ────────────────────────────────────────────────
                _sectionCard(
                  icon: Icons.payment_outlined,
                  title: 'aca_payment_title'.tr(),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    _payStep(
                      number: '1',
                      text: 'aca_payment_step1'.tr()),
                    _payStep(
                      number: '2',
                      text: 'aca_payment_step2'.tr()),
                    _payStep(
                      number: '3',
                      text: 'aca_payment_step3'.tr()),
                    _payStep(
                      number: '4',
                      text: 'aca_payment_step4'.tr(),
                      last: true),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.green.withOpacity(0.2))),
                      child: Row(children: [
                        Icon(Icons.verified_user_outlined,
                            size: 16, color: Colors.green.shade600),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          'aca_payment_note'.tr(),
                          style: TextStyle(fontSize: 12,
                              color: Colors.green.shade700, height: 1.4))),
                      ])),
                  ])),
                const SizedBox(height: 14),

                // ── Hodnotenia ─────────────────────────────────────────────
                _sectionCard(
                  icon: Icons.star_outline_rounded,
                  title: 'aca_ratings_title'.tr(),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('aca_ratings_desc'.tr(),
                        style: TextStyle(fontSize: 13,
                            color: Colors.grey.shade600, height: 1.5)),
                    const SizedBox(height: 12),
                    _highlightBox(
                      icon: Icons.trending_up_rounded,
                      color: _kPrimary,
                      text: 'aca_ratings_tip1'.tr()),
                    const SizedBox(height: 8),
                    _highlightBox(
                      icon: Icons.thumb_up_outlined,
                      color: Colors.green,
                      text: 'aca_ratings_tip2'.tr()),
                  ])),
                const SizedBox(height: 14),

                // ── Podpora ───────────────────────────────────────────────
                _sectionCard(
                  icon: Icons.support_agent_outlined,
                  title: 'aca_support_title'.tr(),
                  child: Column(children: [
                    _contactRow(Icons.email_outlined, 'info@susedko.com'),
                    _contactRow(Icons.phone_outlined, '+421 952 452 052'),
                    _contactRow(Icons.language_outlined, 'www.susedko.com'),
                  ])),

                const SizedBox(height: 20),
                Text('verzia 1.0.0',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade400)),
                const SizedBox(height: 4),
                Text('© 2025 Susedko',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade400)),
              ]))),
        ]));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  static Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
            color: _kPrimary.withOpacity(0.05),
            blurRadius: 12, offset: const Offset(0, 4))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.09),
                borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 16, color: _kPrimary)),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15,
                color: Color(0xFF1E293B)))),
          ]),
          const SizedBox(height: 14),
          child,
        ]));

  static Widget _featureTile({
    required IconData icon,
    required Color color,
    required String title,
    required String text,
    bool last = false,
  }) =>
      Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: color)),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13,
                color: Color(0xFF1E293B))),
            const SizedBox(height: 3),
            Text(text, style: TextStyle(
                fontSize: 12, color: Colors.grey.shade600, height: 1.5)),
          ])),
        ]));

  static Widget _payStep({
    required String number,
    required String text,
    bool last = false,
  }) =>
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(children: [
            Container(
              width: 26, height: 26,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_kDeep, _kPrimary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
                shape: BoxShape.circle),
              child: Center(child: Text(number,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12,
                      fontWeight: FontWeight.bold)))),
            if (!last)
              Expanded(child: Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: _kPrimary.withOpacity(0.15))),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : 16),
            child: Text(text, style: TextStyle(
                fontSize: 13, color: Colors.grey.shade700, height: 1.5)))),
        ]));

  static Widget _highlightBox({
    required IconData icon,
    required Color color,
    required String text,
  }) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2))),
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(
              fontSize: 12, color: Colors.grey.shade700, height: 1.4))),
        ]));

  static Widget _calendarTip(String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: TextStyle(
          fontSize: 12, color: Colors.white.withOpacity(0.9), height: 1.4))),
    ]);

  static Widget _contactRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: _kPrimary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 15, color: _kPrimary)),
      const SizedBox(width: 12),
      Text(text, style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: _kPrimary)),
    ]));
}