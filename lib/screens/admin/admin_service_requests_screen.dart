// lib/screens/admin/admin_service_requests_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/service_request.dart';
import '../../providers/admin_provider.dart';

class AdminServiceRequestsScreen extends StatefulWidget {
  const AdminServiceRequestsScreen({super.key});

  @override
  State<AdminServiceRequestsScreen> createState() =>
      _AdminServiceRequestsScreenState();
}

class _AdminServiceRequestsScreenState
    extends State<AdminServiceRequestsScreen>
    with SingleTickerProviderStateMixin {
  static const _kPrimary = Color(0xFF2563EB);

  late TabController _tabs;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final all = provider.serviceRequests;

    final broadcast = all.where((r) =>
        r.isBroadcast &&
        (_matchesSearch(r, _search))).toList();

    final direct = all.where((r) =>
        !r.isBroadcast &&
        (_matchesSearch(r, _search))).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Požiadavky',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: _kPrimary,
        elevation: 0,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: 'Broadcast (${broadcast.length})'),
            Tab(text: 'Priame (${direct.length})'),
          ],
        ),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Hľadať podľa mena, emailu, profesie...',
              prefixIcon: const Icon(Icons.search, color: _kPrimary),
              filled: true, fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _RequestList(requests: broadcast, isBroadcast: true),
              _RequestList(requests: direct,    isBroadcast: false),
            ],
          ),
        ),
      ]),
    );
  }

  bool _matchesSearch(ServiceRequest r, String q) {
    if (q.isEmpty) return true;
    final ql = q.toLowerCase();
    return r.customerName.toLowerCase().contains(ql) ||
        r.profession.toLowerCase().contains(ql) ||
        r.category.toLowerCase().contains(ql) ||
        (r.adminCustomerEmail?.toLowerCase().contains(ql) ?? false) ||
        (r.craftsmanName?.toLowerCase().contains(ql) ?? false) ||
        (r.adminCraftsmanEmail?.toLowerCase().contains(ql) ?? false);
  }
}

class _RequestList extends StatelessWidget {
  final List<ServiceRequest> requests;
  final bool isBroadcast;

  const _RequestList({required this.requests, required this.isBroadcast});

  static const _kPrimary = Color(0xFF2563EB);

  Color _statusColor(ServiceRequestStatus s) {
    switch (s) {
      case ServiceRequestStatus.open:     return Colors.green;
      case ServiceRequestStatus.pending:  return Colors.orange;
      case ServiceRequestStatus.accepted: return _kPrimary;
      case ServiceRequestStatus.declined: return Colors.red;
      case ServiceRequestStatus.expired:  return Colors.grey;
    }
  }

  String _statusLabel(ServiceRequestStatus s) {
    switch (s) {
      case ServiceRequestStatus.open:     return 'Otvorená';
      case ServiceRequestStatus.pending:  return 'Čaká';
      case ServiceRequestStatus.accepted: return 'Prijatá';
      case ServiceRequestStatus.declined: return 'Odmietnutá';
      case ServiceRequestStatus.expired:  return 'Expirovaná';
    }
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Skopírované: $text'),
            duration: const Duration(seconds: 2)));
  }

  void _showDetail(BuildContext context, ServiceRequest r) {
    final color = _statusColor(r.status);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 20),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)))),

            // Hlavička
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.campaign_outlined,
                    color: _kPrimary, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${r.profession} · ${r.category}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                Text('${r.createdAt.day}.${r.createdAt.month}.${r.createdAt.year}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(_statusLabel(r.status),
                    style: TextStyle(color: color,
                        fontWeight: FontWeight.bold, fontSize: 12))),
            ]),
            const SizedBox(height: 20),

            // Zákazník
            _ContactBlock(
              title: 'Zákazník',
              icon: Icons.person_outline,
              color: _kPrimary,
              name: r.customerName,
              email: r.adminCustomerEmail ?? r.customerEmail,
              phone: r.adminCustomerPhone,
              onCopy: (v) => _copyToClipboard(context, v),
            ),

            // Remeselník (ak priradený)
            if (r.craftsmanName != null || r.adminCraftsmanEmail != null) ...[
              const SizedBox(height: 12),
              _ContactBlock(
                title: 'Remeselník',
                icon: Icons.handyman_outlined,
                color: Colors.orange,
                name: r.craftsmanName ?? '—',
                email: r.adminCraftsmanEmail,
                phone: r.adminCraftsmanPhone,
                onCopy: (v) => _copyToClipboard(context, v),
              ),
            ],
            const SizedBox(height: 16),

            // Detail
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _DRow(label: 'Popis', value: r.description),
                if (r.address != null) _DRow(label: 'Adresa', value: r.address!),
                if (r.budget != null)
                  _DRow(label: 'Rozpočet', value: '${r.budget!.toStringAsFixed(0)} €'),
                _DRow(label: 'Termín', value: _timeframe(r.timeframe)),
                if (isBroadcast)
                  _DRow(label: 'Záujemcov',
                      value: '${r.interestedCraftsmanIds.length}'),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  String _timeframe(String tf) {
    const map = {
      'asap': 'Čo najskôr', '1_3_days': 'Do 3 dní',
      '1_2_weeks': 'Do 2 týždňov', '1_3_months': 'Do 3 mesiacov',
      'no_rush': 'Bez spěchu',
    };
    return map[tf] ?? tf;
  }

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('Žiadne požiadavky',
              style: TextStyle(color: Colors.grey.shade500)),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (ctx, i) {
        final r = requests[i];
        final color = _statusColor(r.status);

        return GestureDetector(
          onTap: () => _showDetail(ctx, r),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8, offset: const Offset(0, 2))]),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Header
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: _kPrimary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.campaign_outlined,
                        color: _kPrimary, size: 16)),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${r.profession} · ${r.category}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(_statusLabel(r.status),
                        style: TextStyle(fontSize: 11, color: color,
                            fontWeight: FontWeight.bold))),
                ]),
                const SizedBox(height: 10),

                // Zákazník kontakt
                _InlineContact(
                  icon: Icons.person_outline,
                  color: _kPrimary,
                  name: r.customerName,
                  email: r.adminCustomerEmail ?? r.customerEmail,
                  phone: r.adminCustomerPhone,
                  onCopy: (v) => _copyToClipboard(ctx, v),
                ),

                // Remeselník (ak je)
                if (r.craftsmanName != null) ...[
                  const SizedBox(height: 4),
                  _InlineContact(
                    icon: Icons.handyman_outlined,
                    color: Colors.orange,
                    name: r.craftsmanName!,
                    email: r.adminCraftsmanEmail,
                    phone: r.adminCraftsmanPhone,
                    onCopy: (v) => _copyToClipboard(ctx, v),
                  ),
                ],

                const SizedBox(height: 8),
                Row(children: [
                  if (r.budget != null) ...[
                    Icon(Icons.euro, size: 12, color: Colors.grey.shade400),
                    Text(' ${r.budget!.toStringAsFixed(0)} €  ',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                  if (isBroadcast) ...[
                    Icon(Icons.people, size: 12, color: Colors.grey.shade400),
                    Text(' ${r.interestedCraftsmanIds.length} záujemcov',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                  const Spacer(),
                  Text(
                    '${r.createdAt.day}.${r.createdAt.month}.${r.createdAt.year}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade400),
                    onSelected: (val) async {
                      final provider = context.read<AdminProvider>();
                      switch (val) {
                        case 'close':
                          await provider.updateServiceRequestStatus(
                              r.id, ServiceRequestStatus.expired);
                          break;
                        case 'open':
                          await provider.updateServiceRequestStatus(
                              r.id, ServiceRequestStatus.open);
                          break;
                        case 'delete':
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Zmazať požiadavku?'),
                              content: const Text('Táto akcia je nenávratná.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Zrušiť')),
                                ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white),
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Zmazať')),
                              ]));
                          if (confirm == true) await provider.deleteServiceRequest(r.id);
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      if (r.status != ServiceRequestStatus.expired)
                        const PopupMenuItem(value: 'close', child: Text('Uzavrieť')),
                      if (r.status == ServiceRequestStatus.expired)
                        const PopupMenuItem(value: 'open', child: Text('Znovu otvoriť')),
                      const PopupMenuItem(value: 'delete',
                          child: Text('Zmazať', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ]),
              ]),
            ),
          ),
        );
      },
    );
  }
}

// ── Pomocné widgety ───────────────────────────────────────────────────────────

class _InlineContact extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String name;
  final String? email;
  final String? phone;
  final void Function(String) onCopy;

  const _InlineContact({
    required this.icon, required this.color, required this.name,
    this.email, this.phone, required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 5),
      Expanded(child: Text(name,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis)),
      if (email != null && email!.isNotEmpty)
        GestureDetector(
          onTap: () => onCopy(email!),
          child: Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.email_outlined, size: 10, color: Colors.grey.shade500),
              const SizedBox(width: 3),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(email!,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                    overflow: TextOverflow.ellipsis)),
            ]))),
      if (phone != null && phone!.isNotEmpty)
        GestureDetector(
          onTap: () => onCopy(phone!),
          child: Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(6)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.phone_outlined, size: 10, color: Colors.green.shade600),
              const SizedBox(width: 3),
              Text(phone!,
                  style: TextStyle(fontSize: 10, color: Colors.green.shade700)),
            ]))),
    ]);
  }
}

class _ContactBlock extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String name;
  final String? email;
  final String? phone;
  final void Function(String) onCopy;

  const _ContactBlock({
    required this.title, required this.icon, required this.color,
    required this.name, this.email, this.phone, required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(title, style: TextStyle(fontSize: 11, color: color,
              fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 6),
        Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        if (email != null && email!.isNotEmpty) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => onCopy(email!),
            child: Row(children: [
              Icon(Icons.email_outlined, size: 13, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Expanded(child: Text(email!,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF2563EB)))),
              Icon(Icons.copy, size: 12, color: Colors.grey.shade400),
            ])),
        ],
        if (phone != null && phone!.isNotEmpty) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => onCopy(phone!),
            child: Row(children: [
              Icon(Icons.phone_outlined, size: 13, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Expanded(child: Text(phone!,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF2563EB)))),
              Icon(Icons.copy, size: 12, color: Colors.grey.shade400),
            ])),
        ],
      ]),
    );
  }
}

class _DRow extends StatelessWidget {
  final String label;
  final String value;
  const _DRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 100,
            child: Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
        Expanded(child: Text(value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      ]));
  }
}