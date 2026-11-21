// lib/models/service_request.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum ServiceRequestStatus { pending, accepted, declined, expired, open }
enum ServiceRequestType { direct, broadcast }

class ServiceRequest {
  final String id;
  final String customerId;
  final String? craftsmanId;
  final String? craftsmanName;
  final String customerName;
  final String customerEmail;

  final String profession;
  // ── Viacero profesií pre broadcast dopyt (max 3) ───────────────────────
  // `profession` (vyššie) zostáva vyplnené prvou profesiou zo zoznamu kvôli
  // spätnej kompatibilite so starými dopytmi a queries, ktoré ešte filtrujú
  // len na singulárne pole. Nové queries/UI by mali používať `professions`.
  final List<String> professions;
  final String category;
  final String description;
  final String? estimatedDuration;
  final List<String> photoUrls;
  final double? budget;
  final String? note;
  final String timeframe;
  final String? address;
  final GeoPoint? location;

  final ServiceRequestStatus status;
  final ServiceRequestType type;
  final List<String> interestedCraftsmanIds;
  final DateTime createdAt;
  final String? craftsmanReply;

  // ── Cenové ponuky (len broadcast) ───────────────────────────────────────
  // quoteRequired = remeselník sa môže zapojiť len s cenovou ponukou
  // (práca + materiál). Ponuky sú v subkolekcii quotes (viď Quote).
  final bool quoteRequired;
  final DateTime? quoteDeadline;
  // Podklad pre ponuku: 'documents' = zákazník priložil podklady (fotky, PDF,
  // výkaz výmer), 'inspection' = platená obhliadka (viď inspection.dart).
  // Staršie dopyty bez poľa sa berú ako 'documents'.
  final String quoteBasis;
  // Priložené dokumenty (PDF/Excel/...): [{url, name}]. Fotky ostávajú
  // v photoUrls.
  final List<Map<String, String>> documentUrls;
  // Odhad rozsahu pri platbe podľa hodín: under2h | half_day | full_day |
  // multi_day | unknown (null = nezadané).
  final String? estimatedScope;

  // ── Raw Firestore document data ────────────────────────────────────────
  // toMap()/fromFirestore() only know about the fixed fields above. Dynamic
  // per-craftsman fields written by the web app (e.g. `interest_<uid>` maps
  // containing `customerReply`) aren't part of that fixed schema, so they
  // must be read from here instead of from toMap(). See open_requests_screen.
  final Map<String, dynamic> rawData;

  // ── Admin-only transient fields (not stored in Firestore) ─────────────────
  final String? adminCustomerEmail;
  final String? adminCustomerPhone;
  final String? adminCraftsmanEmail;
  final String? adminCraftsmanPhone;

  ServiceRequest({
    required this.id,
    required this.customerId,
    this.craftsmanId,
    this.craftsmanName,
    required this.customerName,
    required this.customerEmail,
    required this.profession,
    List<String>? professions,
    required this.category,
    required this.description,
    this.estimatedDuration,
    this.photoUrls = const [],
    this.budget,
    this.note,
    required this.timeframe,
    this.address,
    this.location,
    required this.status,
    this.type = ServiceRequestType.direct,
    this.interestedCraftsmanIds = const [],
    required this.createdAt,
    this.craftsmanReply,
    this.quoteRequired = false,
    this.quoteDeadline,
    this.quoteBasis = 'documents',
    this.documentUrls = const [],
    this.estimatedScope,
    this.rawData = const {},
    this.adminCustomerEmail,
    this.adminCustomerPhone,
    this.adminCraftsmanEmail,
    this.adminCraftsmanPhone,
  }) : professions = (professions == null || professions.isEmpty)
            ? [profession]
            : professions;

  bool get isBroadcast => type == ServiceRequestType.broadcast;

  /// Cenová ponuka sa robí po platenej obhliadke.
  bool get quoteByInspection => quoteRequired && quoteBasis == 'inspection';

  /// Termín na ponuky uplynul (platí do konca zvoleného dňa).
  bool get quoteExpired {
    final d = quoteDeadline;
    if (d == null) return false;
    return DateTime.now()
        .isAfter(DateTime(d.year, d.month, d.day, 23, 59, 59));
  }

  Map<String, dynamic> toMap() => {
    'customerId':             customerId,
    'craftsmanId':            craftsmanId,
    'craftsmanName':          craftsmanName,
    'customerName':           customerName,
    'customerEmail':          customerEmail,
    'profession':             profession,
    'professions':            professions,
    'category':               category,
    'description':            description,
    'estimatedDuration':      estimatedDuration,
    'photoUrls':              photoUrls,
    'budget':                 budget,
    'note':                   note,
    'timeframe':              timeframe,
    'address':                address,
    'location':               location,
    'status':                 status.name,
    'type':                   type.name,
    'interestedCraftsmanIds': interestedCraftsmanIds,
    'createdAt':              Timestamp.fromDate(createdAt),
    'craftsmanReply':         craftsmanReply,
    'quoteRequired':          quoteRequired,
    'quoteDeadline':          quoteDeadline != null
        ? Timestamp.fromDate(quoteDeadline!) : null,
    'quoteBasis':             quoteRequired ? quoteBasis : null,
    'documentUrls':           documentUrls,
    'estimatedScope':         quoteRequired ? null : estimatedScope,
    // adminContacts sú transient — neukladáme ich do Firestore
  };

  factory ServiceRequest.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return ServiceRequest(
      id:            doc.id,
      customerId:    map['customerId'] ?? '',
      craftsmanId:   map['craftsmanId'],
      craftsmanName: map['craftsmanName'],
      customerName:  map['customerName'] ?? '',
      customerEmail: map['customerEmail'] ?? '',
      profession:    map['profession'] ?? '',
      professions:   map['professions'] != null
          ? List<String>.from(map['professions'])
          : (map['profession'] != null && (map['profession'] as String).isNotEmpty
              ? [map['profession']]
              : []),
      category:      map['category'] ?? '',
      description:   map['description'] ?? '',
      estimatedDuration: map['estimatedDuration'],
      photoUrls:     List<String>.from(map['photoUrls'] ?? []),
      budget:        map['budget'] != null ? (map['budget'] as num).toDouble() : null,
      note:          map['note'],
      timeframe:     map['timeframe'] ?? 'flexible',
      address:       map['address'],
      location:      map['location'] as GeoPoint?,
      status: ServiceRequestStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ServiceRequestStatus.pending),
      type: ServiceRequestType.values.firstWhere(
        (e) => e.name == (map['type'] ?? 'direct'),
        orElse: () => ServiceRequestType.direct),
      interestedCraftsmanIds:
          List<String>.from(map['interestedCraftsmanIds'] ?? []),
      createdAt:     (map['createdAt'] as Timestamp).toDate(),
      craftsmanReply: map['craftsmanReply'],
      quoteRequired: map['quoteRequired'] == true,
      quoteDeadline: map['quoteDeadline'] is Timestamp
          ? (map['quoteDeadline'] as Timestamp).toDate() : null,
      quoteBasis: map['quoteBasis'] == 'inspection' ? 'inspection' : 'documents',
      documentUrls: (map['documentUrls'] is List)
          ? (map['documentUrls'] as List)
              .whereType<Map>()
              .map((m) => {
                    'url': (m['url'] ?? '').toString(),
                    'name': (m['name'] ?? '').toString(),
                  })
              .toList()
          : const [],
      estimatedScope: map['estimatedScope']?.toString(),
      rawData:       map,
    );
  }

  ServiceRequest copyWith({
    String? profession,
    List<String>? professions,
    String? category,
    String? description,
    String? estimatedDuration,
    List<String>? photoUrls,
    double? budget,
    String? note,
    String? timeframe,
    String? address,
    GeoPoint? location,
    ServiceRequestStatus? status,
    String? craftsmanReply,
    List<String>? interestedCraftsmanIds,
  }) {
    return ServiceRequest(
      id:            id,
      customerId:    customerId,
      craftsmanId:   craftsmanId,
      craftsmanName: craftsmanName,
      customerName:  customerName,
      customerEmail: customerEmail,
      profession:    profession ?? this.profession,
      professions:   professions ?? this.professions,
      category:      category ?? this.category,
      description:   description ?? this.description,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      photoUrls:     photoUrls ?? this.photoUrls,
      budget:        budget ?? this.budget,
      note:          note ?? this.note,
      timeframe:     timeframe ?? this.timeframe,
      address:       address ?? this.address,
      location:      location ?? this.location,
      status:        status ?? this.status,
      type:          type,
      interestedCraftsmanIds:
          interestedCraftsmanIds ?? this.interestedCraftsmanIds,
      createdAt:     createdAt,
      craftsmanReply: craftsmanReply ?? this.craftsmanReply,
      quoteRequired: quoteRequired,
      quoteDeadline: quoteDeadline,
      quoteBasis:    quoteBasis,
      documentUrls:  documentUrls,
      estimatedScope: estimatedScope,
      rawData:       rawData,
      // zachovaj admin kontakty
      adminCustomerEmail:  adminCustomerEmail,
      adminCustomerPhone:  adminCustomerPhone,
      adminCraftsmanEmail: adminCraftsmanEmail,
      adminCraftsmanPhone: adminCraftsmanPhone,
    );
  }

  // ── Admin helper: obohať o kontaktné info bez uloženia do Firestore ────────
  ServiceRequest copyWithAdminContacts({
    String? customerEmail,
    String? customerPhone,
    String? craftsmanEmail,
    String? craftsmanPhone,
  }) {
    return ServiceRequest(
      id:            id,
      customerId:    customerId,
      craftsmanId:   craftsmanId,
      craftsmanName: craftsmanName,
      customerName:  customerName,
      customerEmail: this.customerEmail,
      profession:    profession,
      professions:   professions,
      category:      category,
      description:   description,
      estimatedDuration: estimatedDuration,
      photoUrls:     photoUrls,
      budget:        budget,
      note:          note,
      timeframe:     timeframe,
      address:       address,
      location:      location,
      status:        status,
      type:          type,
      interestedCraftsmanIds: interestedCraftsmanIds,
      createdAt:     createdAt,
      craftsmanReply: craftsmanReply,
      quoteRequired: quoteRequired,
      quoteDeadline: quoteDeadline,
      quoteBasis:    quoteBasis,
      documentUrls:  documentUrls,
      estimatedScope: estimatedScope,
      rawData:       rawData,
      adminCustomerEmail:  customerEmail ?? adminCustomerEmail,
      adminCustomerPhone:  customerPhone ?? adminCustomerPhone,
      adminCraftsmanEmail: craftsmanEmail ?? adminCraftsmanEmail,
      adminCraftsmanPhone: craftsmanPhone ?? adminCraftsmanPhone,
    );
  }
}