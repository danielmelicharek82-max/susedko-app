// lib/models/work_order.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum WorkOrderStatus {
  pending,            // zákazník vytvoril, čaká na potvrdenie remeselníka
  confirmed,          // remeselník potvrdil
  inProgress,         // práca prebieha
  hoursLogged,        // remeselník zadal hodiny, čaká na potvrdenie zákazníka
  daysApproved,       // VIACDŇOVÁ zákazka: úplne všetky dni v dailyLogs
                      // schválené (nastavuje automaticky onWorkOrderDailyLogsChanged
                      // trigger, nie klient) — čaká sa len na výber spôsobu platby.
                      // Zámerne SAMOSTATNÝ stav od hoursApproved: ten už v tomto
                      // kóde vždy znamená "platba vybraná (weekly/biweekly)", takže
                      // ho nemožno použiť ako neutrálne "čaká sa na výber".
  hoursApproved,      // zákazník schválil hodiny — čaká na platbu (okamžitú alebo súhrnnú)
  reworkRequested,    // zákazník žiada prepracovanie / úpravu hodín
  craftsmanInsisting, // remeselník trvá na pôvodných hodinách → potenciálny spor
  disputed,           // zákazník potvrdil spor → admin rieši
  paymentDue,         // vybraná okamžitá platba alebo súhrnná faktúra vygenerovaná
  paid,               // zaplatené
  completed,          // dokončené + zaplatené
  cancelled,          // zrušené
}

enum WorkOrderPaymentStatus {
  unpaid,
  approved,   // hodiny schválené, čaká na platbu
  paid,
  refunded,
}

// Stav jedného pracovného dňa vo viacdňovej zákazke (mapa `dailyLogs`
// na WorkOrder). Presná kópia mini-cyklu, ktorý má WorkOrderStatus na
// úrovni celej (jednodňovej) objednávky — len teraz izolovaná na deň,
// aby jeden sporný/prepracovávaný deň neblokoval zvyšok rozsahu.
enum DailyLogStatus {
  notLogged,          // pracovný deň (má sloty), remeselník ešte nezadal hodiny
  logged,             // remeselník zadal hodiny, čaká na zákazníka
  approved,           // zákazník schválil — FINÁLNE, nedá sa vrátiť na prepracovanie
  reworkRequested,    // zákazník žiada prepracovanie hodín za tento deň
  craftsmanInsisting, // remeselník trvá na pôvodných hodinách za tento deň
  disputed,           // eskalované na admina — blokuje len tento deň, nie celý rozsah
}

// Jeden záznam v mape WorkOrder.dailyLogs, kľúčovaný dátumovým stringom
// vo formáte "yyyy-MM-dd" (rovnaký formát ako kľúče v craftsmen/{id}/
// availability/slots, aby sa dali priamo porovnávať/mapovať).
class DailyLog {
  final DailyLogStatus status;
  final double? hours;
  // Sadzba je vždy rovnaká pre celú objednávku (remeselník ju nemení
  // deň od dňa) — ukladá sa sem len ako pohodlná kópia v momente
  // zadania, aby prepočet súčtu nemusel nič dohľadávať odinakiaľ.
  final double? rate;
  final String? craftsmanNote;
  final String? reworkNote;
  final String? craftsmanInsistNote;
  final String? disputeNote;
  final DateTime? loggedAt;
  final DateTime? approvedAt;

  const DailyLog({
    this.status = DailyLogStatus.notLogged,
    this.hours,
    this.rate,
    this.craftsmanNote,
    this.reworkNote,
    this.craftsmanInsistNote,
    this.disputeNote,
    this.loggedAt,
    this.approvedAt,
  });

  double? get total => (hours != null && rate != null) ? hours! * rate! : null;

  Map<String, dynamic> toMap() => {
    'status':              status.name,
    'hours':                hours,
    'rate':                 rate,
    'craftsmanNote':        craftsmanNote,
    'reworkNote':           reworkNote,
    'craftsmanInsistNote':  craftsmanInsistNote,
    'disputeNote':          disputeNote,
    'loggedAt':   loggedAt   != null ? Timestamp.fromDate(loggedAt!)   : null,
    'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
  };

  factory DailyLog.fromMap(Map<String, dynamic> map) => DailyLog(
    status: DailyLogStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => DailyLogStatus.notLogged),
    hours: map['hours'] != null ? (map['hours'] as num).toDouble() : null,
    rate:  map['rate']  != null ? (map['rate']  as num).toDouble() : null,
    craftsmanNote:       map['craftsmanNote'],
    reworkNote:          map['reworkNote'],
    craftsmanInsistNote: map['craftsmanInsistNote'],
    disputeNote:         map['disputeNote'],
    loggedAt:   map['loggedAt']   != null ? (map['loggedAt']   as Timestamp).toDate() : null,
    approvedAt: map['approvedAt'] != null ? (map['approvedAt'] as Timestamp).toDate() : null,
  );

  DailyLog copyWith({
    DailyLogStatus? status,
    double? hours,
    double? rate,
    String? craftsmanNote,
    String? reworkNote,
    String? craftsmanInsistNote,
    String? disputeNote,
    DateTime? loggedAt,
    DateTime? approvedAt,
  }) => DailyLog(
    status:              status              ?? this.status,
    hours:               hours               ?? this.hours,
    rate:                rate                ?? this.rate,
    craftsmanNote:       craftsmanNote       ?? this.craftsmanNote,
    reworkNote:          reworkNote          ?? this.reworkNote,
    craftsmanInsistNote: craftsmanInsistNote ?? this.craftsmanInsistNote,
    disputeNote:         disputeNote         ?? this.disputeNote,
    loggedAt:            loggedAt            ?? this.loggedAt,
    approvedAt:          approvedAt          ?? this.approvedAt,
  );
}

// Typ platby ktorý zákazník zvolí po schválení hodín
enum PaymentMode {
  immediate,  // zaplatiť hneď
  weekly,     // pridať do týždennej faktúry
  biweekly,   // pridať do dvojtýždennej faktúry
}

class WorkOrder {
  final String id;
  final String customerId;
  final String craftsmanId;

  final Map<String, dynamic>? customerSnapshot;
  final Map<String, dynamic>? craftsmanSnapshot;

  final String? profession;
  final String? category;
  final String? description;
  final String? address;
  final String? note;
  final List<String> photoUrls;

  final DateTime scheduledAt;
  // Nepovinné — vyplnené len pri viacdňovej zákazke (rozsah dní vybraný
  // v kalendári). null = jednodňová zákazka, presne ako doteraz.
  final DateTime? scheduledEndAt;
  final int estimatedHours;

  final String? serviceRequestId;

  final double? loggedHours;
  final double? hourlyRate;
  final double? totalAmount;

  /// Sadzba DPH (v %) uplatnená na túto zákazku. Nastavuje ju SERVER pri
  /// vytvorení zákazky. Staršie zákazky ju nemajú (0) — ich sumy ostávajú
  /// bez DPH, ako doteraz.
  final double vatPercent;
  final String? craftsmanNote;
  final String? disputeNote;
  final String? reworkNote;
  final String? craftsmanInsistNote;

  final WorkOrderPaymentStatus paymentStatus;
  final String? paymentIntentId;

  // Nové polia pre súhrnné platby
  final PaymentMode? paymentMode;
  final String? weeklyInvoiceId; // ID súhrnnej faktúry ak je súčasťou

  final WorkOrderStatus status;
  final bool isReviewed;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? hoursApprovedAt; // kedy zákazník schválil hodiny

  // Per-deň záznamy pre viacdňové zákazky (scheduledEndAt != null).
  // Kľúč = "yyyy-MM-dd". Jednodňové zákazky (scheduledEndAt == null)
  // toto pole vôbec nepoužívajú — bežia po starom, cez loggedHours/
  // hourlyRate/totalAmount/status priamo na objednávke, bezo zmeny.
  final Map<String, DailyLog> dailyLogs;

  // ── Zákazka s PEVNOU CENOU (z cenovej ponuky) ─────────────────────────
  // pricingMode == 'fixed': cenu určuje ponuka, nie hodiny. totalAmount je
  // netto cena pre zákazníka (práca + materiál s prirážkou). Všetko
  // nastavuje SERVER pri vytvorení; klient tieto polia nemení.
  final String pricingMode;            // 'hourly' | 'fixed'
  final double? fixedLaborNet;         // práca pre zákazníka, netto
  final double? fixedMaterialNet;      // materiál pre zákazníka, netto
  final String? fixedMaterialNote;
  final String? fixedDuration;
  final double? craftsmanFixedNet;     // odmena remeselníka (bez prirážky), netto
  final double? craftsmanFixedLabor;
  final double? craftsmanFixedMaterial;
  final double depositGross;           // záloha na materiál s DPH
  // none | due | paid | refunded | refund_pending_decision | kept | refund_failed
  final String depositStatus;
  final DateTime? depositPaidAt;
  // Kontakty druhej strany (server ich zapíše po prijatí zákazky)
  final Map<String, dynamic>? contacts;

  WorkOrder({
    required this.id,
    required this.customerId,
    required this.craftsmanId,
    this.customerSnapshot,
    this.craftsmanSnapshot,
    this.profession,
    this.category,
    this.description,
    this.address,
    this.note,
    this.photoUrls = const [],
    required this.scheduledAt,
    this.scheduledEndAt,
    this.estimatedHours = 2,
    this.serviceRequestId,
    this.loggedHours,
    this.hourlyRate,
    this.totalAmount,
    this.vatPercent = 0,
    this.craftsmanNote,
    this.disputeNote,
    this.reworkNote,
    this.craftsmanInsistNote,
    this.paymentStatus = WorkOrderPaymentStatus.unpaid,
    this.paymentIntentId,
    this.paymentMode,
    this.weeklyInvoiceId,
    this.status = WorkOrderStatus.pending,
    this.isReviewed = false,
    required this.createdAt,
    this.completedAt,
    this.hoursApprovedAt,
    this.dailyLogs = const {},
    this.pricingMode = 'hourly',
    this.fixedLaborNet,
    this.fixedMaterialNet,
    this.fixedMaterialNote,
    this.fixedDuration,
    this.craftsmanFixedNet,
    this.craftsmanFixedLabor,
    this.craftsmanFixedMaterial,
    this.depositGross = 0,
    this.depositStatus = 'none',
    this.depositPaidAt,
    this.contacts,
  });

  // ── Pevná cena ──────────────────────────────────────────────────────────
  bool get isFixed => pricingMode == 'fixed';
  bool get depositDue => isFixed && depositStatus == 'due';
  bool get depositPaid => isFixed && depositStatus == 'paid';
  /// Záloha je buď zaplatená, alebo sa neúčtuje — práca sa môže začať.
  bool get depositSettled => !isFixed || depositStatus != 'due';
  bool get depositNeedsDecision => depositStatus == 'refund_pending_decision';

  /// Doplatok (s DPH) = celkom − zaplatená záloha.
  double? get balanceGross {
    final total = totalWithVat;
    if (total == null) return null;
    final paid = depositStatus == 'paid' ? depositGross : 0;
    return ((total - paid) * 100).roundToDouble() / 100;
  }

  /// Kontakt druhej strany (telefón/e-mail) — dostupný po prijatí zákazky.
  Map<String, dynamic>? contactOf(bool forCustomer) {
    final c = contacts;
    if (c == null) return null;
    final m = c[forCustomer ? 'customer' : 'craftsman'];
    return m is Map ? Map<String, dynamic>.from(m) : null;
  }

  double? get calculatedTotal {
    if (totalAmount != null) return totalAmount;
    if (loggedHours != null && hourlyRate != null) {
      return loggedHours! * hourlyRate!;
    }
    return null;
  }

  /// DPH z [calculatedTotal] (základ bez DPH), zaokrúhlené na centy.
  double get vatAmount {
    final net = calculatedTotal ?? 0;
    return (net * vatPercent).roundToDouble() / 100;
  }

  /// Suma, ktorú zákazník reálne zaplatí (základ + DPH).
  /// Pri zákazkách bez DPH (vatPercent == 0) sa rovná [calculatedTotal].
  double? get totalWithVat {
    final net = calculatedTotal;
    if (net == null) return null;
    return ((net + vatAmount) * 100).roundToDouble() / 100;
  }

  bool get isPaid => paymentStatus == WorkOrderPaymentStatus.paid;
  bool get needsPayment =>
      status == WorkOrderStatus.paymentDue && !isPaid;
  bool get isAwaitingPaymentChoice =>
      status == WorkOrderStatus.hoursApproved && weeklyInvoiceId == null;

  // ── Viacdňová zákazka (dailyLogs) ────────────────────────────────────
  // Viacdňovosť je daná výhradne rozsahom scheduledAt→scheduledEndAt, NIE
  // tým, či už niekto do dailyLogs niečo zapísal. Predtým vyžadovalo
  // `dailyLogs.isNotEmpty`, čo pri objednávke vytvorenej cez web portál
  // (kde dailyLogs na začiatku vôbec neexistuje) vyhodnocovalo isMultiDay
  // ako false — kým remeselník cez web nezadal aspoň jeden deň, appka
  // zákazku ukazovala ako jednodňovú; a keď už jeden deň v mape bol,
  // ukázala len TEN jeden deň namiesto celého rozsahu.
  bool get isMultiDay =>
      scheduledEndAt != null && !_isSameDate(scheduledAt, scheduledEndAt!);

  static String _dailyKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // Zoznam VŠETKÝCH dní v rozsahu scheduledAt→scheduledEndAt (vrátane),
  // nie len tých, ktoré už majú záznam v dailyLogs. Dni bez záznamu sa
  // doplnia predvolenou hodnotou DailyLogStatus.notLogged.
  List<MapEntry<String, DailyLog>> get sortedDailyLogs {
    if (scheduledEndAt == null) {
      final entries = dailyLogs.entries.toList();
      entries.sort((a, b) => a.key.compareTo(b.key));
      return entries;
    }
    final entries = <MapEntry<String, DailyLog>>[];
    var cursor = DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day);
    final end = DateTime(
        scheduledEndAt!.year, scheduledEndAt!.month, scheduledEndAt!.day);
    while (!cursor.isAfter(end)) {
      final key = _dailyKey(cursor);
      entries.add(MapEntry(key, dailyLogs[key] ?? const DailyLog()));
      cursor = cursor.add(const Duration(days: 1));
    }
    return entries;
  }

  bool get allDailyLogsApproved =>
      sortedDailyLogs.isNotEmpty &&
      sortedDailyLogs.every((e) => e.value.status == DailyLogStatus.approved);

  int get approvedDaysCount =>
      sortedDailyLogs.where((e) => e.value.status == DailyLogStatus.approved).length;

  double get dailyLogsTotalHours => dailyLogs.values
      .where((d) => d.status == DailyLogStatus.approved)
      .fold(0.0, (sum, d) => sum + (d.hours ?? 0));

  double get dailyLogsTotalAmount => dailyLogs.values
      .where((d) => d.status == DailyLogStatus.approved)
      .fold(0.0, (sum, d) => sum + (d.total ?? 0));

  Map<String, dynamic> toMap() => {
    'customerId':          customerId,
    'craftsmanId':         craftsmanId,
    'customerSnapshot':    customerSnapshot,
    'craftsmanSnapshot':   craftsmanSnapshot,
    'profession':          profession,
    'category':            category,
    'description':         description,
    'address':             address,
    'note':                note,
    'photoUrls':           photoUrls,
    'scheduledAt':         Timestamp.fromDate(scheduledAt),
    'scheduledEndAt':      scheduledEndAt != null
        ? Timestamp.fromDate(scheduledEndAt!) : null,
    'estimatedHours':      estimatedHours,
    'serviceRequestId':    serviceRequestId,
    'loggedHours':         loggedHours,
    'hourlyRate':          hourlyRate,
    'totalAmount':         totalAmount,
    'vatPercent':          vatPercent,
    'craftsmanNote':       craftsmanNote,
    'disputeNote':         disputeNote,
    'reworkNote':          reworkNote,
    'craftsmanInsistNote': craftsmanInsistNote,
    'paymentStatus':       paymentStatus.name,
    'paymentIntentId':     paymentIntentId,
    'paymentMode':         paymentMode?.name,
    'weeklyInvoiceId':     weeklyInvoiceId,
    'status':              status.name,
    'isReviewed':          isReviewed,
    'createdAt':           Timestamp.fromDate(createdAt),
    'completedAt':         completedAt != null
        ? Timestamp.fromDate(completedAt!) : null,
    'hoursApprovedAt':     hoursApprovedAt != null
        ? Timestamp.fromDate(hoursApprovedAt!) : null,
    'dailyLogs':           dailyLogs.map((k, v) => MapEntry(k, v.toMap())),
    // Polia pevnej ceny sa do Firestore z klienta NEZAPISUJÚ (vytvára ich
    // server cez createWorkOrder), preto tu zámerne nie sú.
  };

  factory WorkOrder.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return WorkOrder(
      id:            doc.id,
      customerId:    map['customerId'] ?? '',
      craftsmanId:   map['craftsmanId'] ?? '',
      customerSnapshot: map['customerSnapshot'] != null
          ? Map<String, dynamic>.from(map['customerSnapshot']) : null,
      craftsmanSnapshot: map['craftsmanSnapshot'] != null
          ? Map<String, dynamic>.from(map['craftsmanSnapshot']) : null,
      profession:    map['profession'],
      category:      map['category'],
      description:   map['description'],
      address:       map['address'],
      note:          map['note'],
      photoUrls:     List<String>.from(map['photoUrls'] ?? []),
      scheduledAt:   (map['scheduledAt'] as Timestamp).toDate(),
      scheduledEndAt: map['scheduledEndAt'] != null
          ? (map['scheduledEndAt'] as Timestamp).toDate() : null,
      estimatedHours: map['estimatedHours'] ?? 2,
      serviceRequestId: map['serviceRequestId'],
      loggedHours:   map['loggedHours'] != null
          ? (map['loggedHours'] as num).toDouble() : null,
      hourlyRate:    map['hourlyRate'] != null
          ? (map['hourlyRate'] as num).toDouble() : null,
      vatPercent:    (map['vatPercent'] as num?)?.toDouble() ?? 0,
      totalAmount:   map['totalAmount'] != null
          ? (map['totalAmount'] as num).toDouble() : null,
      craftsmanNote:       map['craftsmanNote'],
      disputeNote:         map['disputeNote'],
      reworkNote:          map['reworkNote'],
      craftsmanInsistNote: map['craftsmanInsistNote'],
      paymentStatus: WorkOrderPaymentStatus.values.firstWhere(
          (e) => e.name == map['paymentStatus'],
          orElse: () => WorkOrderPaymentStatus.unpaid),
      paymentIntentId: map['paymentIntentId'],
      paymentMode: map['paymentMode'] != null
          ? PaymentMode.values.firstWhere(
              (e) => e.name == map['paymentMode'],
              orElse: () => PaymentMode.immediate)
          : null,
      weeklyInvoiceId: map['weeklyInvoiceId'],
      status: WorkOrderStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => WorkOrderStatus.pending),
      isReviewed:    map['isReviewed'] ?? false,
      createdAt:     (map['createdAt'] as Timestamp).toDate(),
      completedAt:   map['completedAt'] != null
          ? (map['completedAt'] as Timestamp).toDate() : null,
      hoursApprovedAt: map['hoursApprovedAt'] != null
          ? (map['hoursApprovedAt'] as Timestamp).toDate() : null,
      dailyLogs: map['dailyLogs'] != null
          ? Map<String, dynamic>.from(map['dailyLogs']).map((k, v) =>
              MapEntry(k, DailyLog.fromMap(Map<String, dynamic>.from(v))))
          : const {},
      pricingMode:       (map['pricingMode'] as String?) ?? 'hourly',
      fixedLaborNet:     (map['fixedLaborNet'] as num?)?.toDouble(),
      fixedMaterialNet:  (map['fixedMaterialNet'] as num?)?.toDouble(),
      fixedMaterialNote: map['fixedMaterialNote'] as String?,
      fixedDuration:     map['fixedDuration'] as String?,
      craftsmanFixedNet:      (map['craftsmanFixedNet'] as num?)?.toDouble(),
      craftsmanFixedLabor:    (map['craftsmanFixedLabor'] as num?)?.toDouble(),
      craftsmanFixedMaterial: (map['craftsmanFixedMaterial'] as num?)?.toDouble(),
      depositGross:  (map['depositGross'] as num?)?.toDouble() ?? 0,
      depositStatus: (map['depositStatus'] as String?) ?? 'none',
      depositPaidAt: map['depositPaidAt'] is Timestamp
          ? (map['depositPaidAt'] as Timestamp).toDate() : null,
      contacts: map['contacts'] is Map
          ? Map<String, dynamic>.from(map['contacts']) : null,
    );
  }

  WorkOrder copyWith({
    WorkOrderStatus? status,
    WorkOrderPaymentStatus? paymentStatus,
    Map<String, dynamic>? customerSnapshot,
    Map<String, dynamic>? craftsmanSnapshot,
    double? loggedHours,
    double? hourlyRate,
    double? totalAmount,
    double? vatPercent,
    String? craftsmanNote,
    String? disputeNote,
    String? reworkNote,
    String? craftsmanInsistNote,
    String? paymentIntentId,
    PaymentMode? paymentMode,
    String? weeklyInvoiceId,
    bool? isReviewed,
    DateTime? completedAt,
    DateTime? hoursApprovedAt,
    Map<String, DailyLog>? dailyLogs,
  }) {
    return WorkOrder(
      id: id, customerId: customerId, craftsmanId: craftsmanId,
      customerSnapshot:  customerSnapshot  ?? this.customerSnapshot,
      craftsmanSnapshot: craftsmanSnapshot ?? this.craftsmanSnapshot,
      profession: profession, category: category, description: description,
      address: address, note: note, photoUrls: photoUrls,
      scheduledAt: scheduledAt, scheduledEndAt: scheduledEndAt, estimatedHours: estimatedHours,
      serviceRequestId: serviceRequestId,
      loggedHours:         loggedHours         ?? this.loggedHours,
      hourlyRate:          hourlyRate           ?? this.hourlyRate,
      totalAmount:         totalAmount          ?? this.totalAmount,
      vatPercent:          vatPercent           ?? this.vatPercent,
      craftsmanNote:       craftsmanNote        ?? this.craftsmanNote,
      disputeNote:         disputeNote          ?? this.disputeNote,
      reworkNote:          reworkNote           ?? this.reworkNote,
      craftsmanInsistNote: craftsmanInsistNote  ?? this.craftsmanInsistNote,
      paymentStatus:       paymentStatus        ?? this.paymentStatus,
      paymentIntentId:     paymentIntentId      ?? this.paymentIntentId,
      paymentMode:         paymentMode          ?? this.paymentMode,
      weeklyInvoiceId:     weeklyInvoiceId      ?? this.weeklyInvoiceId,
      status:              status               ?? this.status,
      isReviewed:          isReviewed           ?? this.isReviewed,
      createdAt:           createdAt,
      completedAt:         completedAt          ?? this.completedAt,
      hoursApprovedAt:     hoursApprovedAt      ?? this.hoursApprovedAt,
      dailyLogs:           dailyLogs            ?? this.dailyLogs,
      pricingMode: pricingMode, fixedLaborNet: fixedLaborNet,
      fixedMaterialNet: fixedMaterialNet, fixedMaterialNote: fixedMaterialNote,
      fixedDuration: fixedDuration, craftsmanFixedNet: craftsmanFixedNet,
      craftsmanFixedLabor: craftsmanFixedLabor,
      craftsmanFixedMaterial: craftsmanFixedMaterial,
      depositGross: depositGross, depositStatus: depositStatus,
      depositPaidAt: depositPaidAt, contacts: contacts,
    );
  }
}