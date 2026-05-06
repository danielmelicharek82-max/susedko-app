// lib/screens/customer/about_app_screen.dart

import 'package:flutter/material.dart';

const _kPrimary = Color(0xFF2563EB);
const _kDeep    = Color(0xFF1E40AF);
const _kAccent  = Color(0xFF60A5FA);
const _kBg      = Color(0xFFF0F4FF);

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

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
                  // Dekoratívne kruhy
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

                  // Logo + názov
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
                        Text('Remeselníci na pár klikov',
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

                // ── O aplikácii ──────────────────────────────────────────
                _sectionCard(
                  icon: Icons.info_outline_rounded,
                  title: 'O aplikácii',
                  child: Text(
                    'Susedko je aplikácia, ktorá spája ľudí s remeselníkmi '
                    'vo vašom okolí. Potrebujete opravu, pomoc v domácnosti '
                    'alebo odborníka? Stačí pár klikov a riešenie máte '
                    'na dosah.',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700,
                        height: 1.6))),
                const SizedBox(height: 14),

                // ── Ako to funguje ────────────────────────────────────────
                _sectionCard(
                  icon: Icons.help_outline_rounded,
                  title: 'Ako to funguje?',
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                      'Stačí sa lokalizovať vo svojom profile a okamžite '
                      'uvidíte dostupných remeselníkov vo vašom okolí.',
                      style: TextStyle(fontSize: 13,
                          color: Colors.grey.shade600, height: 1.5)),
                    const SizedBox(height: 14),
                    _featureTile(
                      icon: Icons.work_outline_rounded,
                      color: _kPrimary,
                      title: 'Vytvoriť objednávku',
                      text: 'Vyberiete si konkrétneho remeselníka a '
                          'rezervujete termín podľa jeho kalendára.'),
                    _featureTile(
                      icon: Icons.send_outlined,
                      color: Colors.purple,
                      title: 'Servisná požiadavka',
                      text: 'Odošlete požiadavku priamo vybranému '
                          'remeselníkovi a dohodnete si termín.'),
                    _featureTile(
                      icon: Icons.campaign_outlined,
                      color: Colors.orange,
                      title: 'Broadcast požiadavka',
                      text: 'Vaša požiadavka sa zobrazí všetkým '
                          'remeselníkom v kategórii — viac ponúk, lepší výber.'),
                    _featureTile(
                      icon: Icons.notifications_outlined,
                      color: Colors.green,
                      title: 'Okamžité notifikácie',
                      text: 'Push notifikácie o objednávkach, hodinách '
                          'a platbách — vždy pod kontrolou.',
                      last: true),
                  ])),
                const SizedBox(height: 14),

                // ── Platba ────────────────────────────────────────────────
                _sectionCard(
                  icon: Icons.payment_outlined,
                  title: 'Platba',
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    _payStep(
                      number: '1',
                      text: 'Remeselník po dokončení zadá '
                          'odpracované hodiny.'),
                    _payStep(
                      number: '2',
                      text: 'Hodiny vám prídu na schválenie — '
                          'môžete potvrdiť alebo požiadať o úpravu.'),
                    _payStep(
                      number: '3',
                      text: 'Po schválení sa vygeneruje platba, '
                          'ktorú uhradíte priamo v aplikácii.',
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
                          'Platba je zabezpečená cez Stripe. '
                          'Platíte len za odsúhlasené hodiny.',
                          style: TextStyle(fontSize: 12,
                              color: Colors.green.shade700,
                              height: 1.4))),
                      ])),
                  ])),
                const SizedBox(height: 14),

                // ── Pre každého ────────────────────────────────────────────
                _sectionCard(
                  icon: Icons.people_outline_rounded,
                  title: 'Pre každého, kto si chce zarobiť',
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                      'Susedko nie je len pre zákazníkov, ale aj pre všetkých, '
                      'ktorí si chcú privyrobiť.',
                      style: TextStyle(fontSize: 13,
                          color: Colors.grey.shade600, height: 1.5)),
                    const SizedBox(height: 12),
                    _highlightBox(
                      icon: Icons.star_outline_rounded,
                      color: Colors.amber,
                      text: 'Otvorené pre mužov aj ženy — bez ohľadu '
                          'na skúsenosti či profesiu.'),
                    const SizedBox(height: 8),
                    _highlightBox(
                      icon: Icons.trending_up_rounded,
                      color: _kPrimary,
                      text: 'Budujte si vlastný príjem a reputáciu '
                          'vďaka hodnoteniam zákazníkov.'),
                  ])),
                const SizedBox(height: 14),

                // ── Profesie ──────────────────────────────────────────────
                _sectionCard(
                  icon: Icons.handyman_outlined,
                  title: 'Pre koho je Susedko',
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                      'Susedko je pre každého — mužov aj ženy, '
                      'ktorí chcú pomáhať a zároveň si zarobiť.',
                      style: TextStyle(fontSize: 13,
                          color: Colors.grey.shade600, height: 1.5)),
                    const SizedBox(height: 14),

                    _professionGroup(
                      icon: Icons.construction_rounded,
                      color: _kPrimary,
                      title: 'Technické a remeselné profesie',
                      text: 'Inštalatér, elektrikár, kúrenár, plynár, '
                          'klampiar, zvárač, oprava spotrebičov, zámočník, '
                          'murár, maliar, obkladač, podlahár, stolár.'),
                    _professionGroup(
                      icon: Icons.home_outlined,
                      color: Colors.green,
                      title: 'Služby a pomoc v domácnosti',
                      text: 'Upratovanie, záhradník, sťahovanie, '
                          'montáž nábytku, pomoc v domácnosti, IT technik.'),
                    _professionGroup(
                      icon: Icons.favorite_outline_rounded,
                      color: Colors.pink,
                      title: 'Starostlivosť a služby pre ľudí',
                      text: 'Opatrovateľka seniorov, opatrovateľka detí, '
                          'starostlivosť o zvieratá, zdravotný asistent, '
                          'fyzioterapeut, psychológ.'),
                    _professionGroup(
                      icon: Icons.spa_outlined,
                      color: Colors.purple,
                      title: 'Krása, šport a voľný čas',
                      text: 'Kozmetička, kaderníčka, masér, tréner, '
                          'inštruktor plávania, inštruktorka tanca, '
                          'fotograf, organizátor podujatí.',
                      last: true),

                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _kPrimary.withOpacity(0.08),
                            _kAccent.withOpacity(0.04)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _kPrimary.withOpacity(0.15))),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: _kPrimary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.emoji_events_outlined,
                              size: 16, color: _kPrimary)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(
                          'Nezáleží na tom, či ste profesionál alebo '
                          'si chcete len privyrobiť — Susedko je miesto, '
                          'kde si vás zákazníci jednoducho nájdu.',
                          style: TextStyle(fontSize: 12,
                              color: Colors.grey.shade700, height: 1.5))),
                      ])),
                  ])),
                const SizedBox(height: 14),

                // ── Kontakt ───────────────────────────────────────────────
                _sectionCard(
                  icon: Icons.support_agent_outlined,
                  title: 'Kontakt & podpora',
                  child: Column(children: [
                    _contactRow(Icons.email_outlined,
                        'info@susedko.com'),
                    _contactRow(Icons.phone_outlined,
                        '+421 952 452 052'),
                    _contactRow(Icons.language_outlined,
                        'www.susedko.com'),
                  ])),

                const SizedBox(height: 20),

                // ── Verzia ────────────────────────────────────────────────
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
            Text(title, style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15,
                color: Color(0xFF1E293B))),
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
        padding: EdgeInsets.only(bottom: last ? 0 : 12),
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
              decoration: BoxDecoration(
                gradient: const LinearGradient(
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

  static Widget _professionGroup({
    required IconData icon,
    required Color color,
    required String title,
    required String text,
    bool last = false,
  }) =>
      Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.15))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13, color: color)),
            ]),
            const SizedBox(height: 6),
            Text(text, style: TextStyle(
                fontSize: 12, color: Colors.grey.shade600, height: 1.5)),
          ])));

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