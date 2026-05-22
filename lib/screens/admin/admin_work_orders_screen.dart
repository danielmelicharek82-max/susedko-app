// lib/screens/admin/admin_work_orders_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/work_order.dart';
import '../../providers/admin_provider.dart';

class AdminWorkOrdersScreen extends StatefulWidget {
  const AdminWorkOrdersScreen({super.key});

  @override
  State<AdminWorkOrdersScreen> createState() => _AdminWorkOrdersScreenState();
}

class _AdminWorkOrdersScreenState extends State<AdminWorkOrdersScreen>
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
    final disputed = provider.disputedWorkOrders;

    final all = provider.workOrders.where((w) {
      final q = _search.toLowerCase();
      return w.customerSnapshot?['name']?.toString().toLowerCase().contains(q) == true ||
          w.customerSnapshot?['email']?.toString().toLowerCase().contains(q) == true ||
          w.craftsmanSnapshot?['name']?.toString().toLowerCase().contains(q) == true ||
          w.craftsmanSnapshot?['email']?.toString().toLowerCase().contains(q) == true ||
          (w.profession ?? '').toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Zákazky',
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
            Tab(text: 'Všetky (${all.length})'),
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('Spory'),
                if (disputed.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('${disputed.length}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ]),
            ),
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
              _WorkOrderList(workOrders: all, showDispute: false),
              _WorkOrderList(workOrders: disputed, showDispute: true),
            ],
          ),
        ),
      ]),
    );
  }
}

class _WorkOrderList extends StatelessWidget {
  final List<WorkOrder> workOrders;
  final bool showDispute;

  const _WorkOrderList({required this.workOrders, required this.showDispute});

  static const _kPrimary = Color(0xFF2563EB);

  Color _statusColor(WorkOrderStatus s) {
    switch (s) {
      case WorkOrderStatus.pending:            return Colors.orange;
      case WorkOrderStatus.confirmed:          return _kPrimary;
      case WorkOrderStatus.inProgress:         return Colors.blue;
      case WorkOrderStatus.hoursLogged:        return Colors.purple;
      case WorkOrderStatus.reworkRequested:    return Colors.orange;
      case WorkOrderStatus.craftsmanInsisting: return Colors.red;
      case WorkOrderStatus.disputed:           return Colors.red;
      case WorkOrderStatus.paymentDue:         return Colors.amber.shade700;
      case WorkOrderStatus.paid:               return Colors.green;
      case WorkOrderStatus.completed:          return Colors.green.shade700;
      case WorkOrderStatus.cancelled:          return Colors.grey;
    }
  }

  String _statusLabel(WorkOrderStatus s) {
    switch (s) {
      case WorkOrderStatus.pending:            return 'Čaká';
      case WorkOrderStatus.confirmed:          return 'Potvrdená';
      case WorkOrderStatus.inProgress:         return 'Prebieha';
      case WorkOrderStatus.hoursLogged:        return 'Hodiny zadané';
      case WorkOrderStatus.reworkRequested:    return 'Žiadosť o úpravu';
      case WorkOrderStatus.craftsmanInsisting: return 'Nezhoda';
      case WorkOrderStatus.disputed:           return 'Spor ⚠️';
      case WorkOrderStatus.paymentDue:         return 'Na zaplatenie';
      case WorkOrderStatus.paid:               return 'Zaplatená';
      case WorkOrderStatus.completed:          return 'Dokončená';
      case WorkOrderStatus.cancelled:          return 'Zrušená';
    }
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Skopírované: $text'),
            duration: const Duration(seconds: 2)));
  }

  void _showDetailDialog(BuildContext context, WorkOrder w) {
    final customerName  = w.customerSnapshot?['name']  ?? w.customerId.substring(0, 6);
    final customerEmail = w.customerSnapshot?['email'] ?? '—';
    final customerPhone = w.customerSnapshot?['phone'] ?? '—';
    final craftsmanName  = w.craftsmanSnapshot?['name']  ?? w.craftsmanId.substring(0, 6);
    final craftsmanEmail = w.craftsmanSnapshot?['email'] ?? '—';
    final craftsmanPhone = w.craftsmanSnapshot?['phone'] ?? '—';

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
                  color: _statusColor(w.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.work_outline,
                    color: _statusColor(w.status), size: 24)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(w.profession ?? 'Zákazka',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                Text('${w.scheduledAt.day}.${w.scheduledAt.month}.${w.scheduledAt.year}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusColor(w.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20)),
                child: Text(_statusLabel(w.status),
                    style: TextStyle(color: _statusColor(w.status),
                        fontWeight: FontWeight.bold, fontSize: 12))),
            ]),
            const SizedBox(height: 20),

            // Zákazník
            _ContactSection(
              title: 'Zákazník',
              icon: Icons.person_outline,
              color: _kPrimary,
              name: customerName,
              email: customerEmail,
              phone: customerPhone,
              onCopy: (v) => _copyToClipboard(context, v),
            ),
            const SizedBox(height: 12),

            // Remeselník
            _ContactSection(
              title: 'Remeselník',
              icon: Icons.handyman_outlined,
              color: Colors.orange,
              name: craftsmanName,
              email: craftsmanEmail,
              phone: craftsmanPhone,
              onCopy: (v) => _copyToClipboard(context, v),
            ),
            const SizedBox(height: 16),

            // Detail zákazky
            _DetailSection(children: [
              if (w.description != null && w.description!.isNotEmpty)
                _DetailRow(label: 'Popis', value: w.description!),
              if (w.address != null)
                _DetailRow(label: 'Adresa', value: w.address!),
              _DetailRow(label: 'Odhadované hodiny',
                  value: '${w.estimatedHours} hod'),
              if (w.loggedHours != null)
                _DetailRow(label: 'Odpracované hodiny',
                    value: '${w.loggedHours} hod'),
              if (w.calculatedTotal != null)
                _DetailRow(label: 'Suma',
                    value: '${w.calculatedTotal!.toStringAsFixed(2)} €'),
              if (w.disputeNote != null && w.disputeNote!.isNotEmpty)
                _DetailRow(label: 'Poznámka (spor)',
                    value: w.disputeNote!, isAlert: true),
            ]),

            if (w.status == WorkOrderStatus.disputed) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.gavel_outlined),
                  label: const Text('Riešiť spor'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                  onPressed: () {
                    Navigator.pop(context);
                    _showResolveDisputeDialog(context, w);
                  })),
            ],
          ]),
        ),
      ),
    );
  }

  void _showResolveDisputeDialog(BuildContext context, WorkOrder w) {
    final noteController = TextEditingController();
    WorkOrderStatus resolution = WorkOrderStatus.completed;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Riešiť spor'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Vyber výsledok sporu:', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            DropdownButtonFormField<WorkOrderStatus>(
              value: resolution,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              items: const [
                DropdownMenuItem(value: WorkOrderStatus.completed,
                    child: Text('Dokončená — zákazník platí')),
                DropdownMenuItem(value: WorkOrderStatus.cancelled,
                    child: Text('Zrušená — vrátenie platby')),
                DropdownMenuItem(value: WorkOrderStatus.paymentDue,
                    child: Text('Čaká na platbu')),
              ],
              onChanged: (v) => setS(() => resolution = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Poznámka admina (voliteľné)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(12))),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Zrušiť')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                Navigator.pop(context);
                await context.read<AdminProvider>().resolveDispute(
                  w.id,
                  resolution: resolution,
                  adminNote: noteController.text.trim().isEmpty
                      ? null : noteController.text.trim());
              },
              child: const Text('Potvrdiť')),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (workOrders.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(showDispute ? Icons.gavel_outlined : Icons.work_off_outlined,
              size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(showDispute ? 'Žiadne aktívne spory' : 'Žiadne zákazky',
              style: TextStyle(color: Colors.grey.shade500)),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: workOrders.length,
      itemBuilder: (ctx, i) {
        final w = workOrders[i];
        final color = _statusColor(w.status);
        final customerName  = w.customerSnapshot?['name']  ?? w.customerId.substring(0, 6);
        final customerEmail = w.customerSnapshot?['email'] as String?;
        final customerPhone = w.customerSnapshot?['phone'] as String?;
        final craftsmanName  = w.craftsmanSnapshot?['name']  ?? w.craftsmanId.substring(0, 6);
        final craftsmanEmail = w.craftsmanSnapshot?['email'] as String?;
        final craftsmanPhone = w.craftsmanSnapshot?['phone'] as String?;
        final amount = w.calculatedTotal;

        return GestureDetector(
          onTap: () => _showDetailDialog(ctx, w),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: w.status == WorkOrderStatus.disputed
                  ? Border.all(color: Colors.red.shade300, width: 1.5)
                  : Border.all(color: Colors.grey.shade100),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8, offset: const Offset(0, 2))]),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Header row
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.work_outline, color: color, size: 18)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(w.profession ?? 'Zákazka',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(_statusLabel(w.status),
                        style: TextStyle(fontSize: 11, color: color,
                            fontWeight: FontWeight.bold))),
                ]),
                const SizedBox(height: 10),

                // Zákazník
                _ContactRow(
                  icon: Icons.person_outline,
                  color: _kPrimary,
                  name: customerName,
                  email: customerEmail,
                  phone: customerPhone,
                  onCopy: (v) => _copyToClipboard(ctx, v),
                ),
                const SizedBox(height: 6),

                // Remeselník
                _ContactRow(
                  icon: Icons.handyman_outlined,
                  color: Colors.orange,
                  name: craftsmanName,
                  email: craftsmanEmail,
                  phone: craftsmanPhone,
                  onCopy: (v) => _copyToClipboard(ctx, v),
                ),

                if (w.disputeNote != null && w.disputeNote!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 14, color: Colors.red),
                      const SizedBox(width: 6),
                      Expanded(child: Text(w.disputeNote!,
                          style: const TextStyle(fontSize: 11, color: Colors.red),
                          maxLines: 2, overflow: TextOverflow.ellipsis)),
                    ])),
                ],

                const SizedBox(height: 8),
                Row(children: [
                  if (amount != null) ...[
                    Icon(Icons.euro, size: 12, color: Colors.grey.shade400),
                    Text(' ${amount.toStringAsFixed(2)} €  ',
                        style: TextStyle(fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600)),
                  ],
                  if (w.loggedHours != null) ...[
                    Icon(Icons.timer_outlined, size: 12, color: Colors.grey.shade400),
                    Text(' ${w.loggedHours}h  ',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                  const Spacer(),
                  Text(
                    '${w.scheduledAt.day}.${w.scheduledAt.month}.${w.scheduledAt.year}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade400),
                    onSelected: (val) async {
                      final provider = context.read<AdminProvider>();
                      switch (val) {
                        case 'resolve': _showResolveDisputeDialog(ctx, w); break;
                        case 'cancel':
                          await provider.updateWorkOrderStatus(w.id, WorkOrderStatus.cancelled);
                          break;
                        case 'complete':
                          await provider.updateWorkOrderStatus(w.id, WorkOrderStatus.completed);
                          break;
                        case 'delete':
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Zmazať zákazku?'),
                              content: const Text('Táto akcia je nenávratná.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Zrušiť')),
                                ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red, foregroundColor: Colors.white),
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Zmazať')),
                              ]));
                          if (confirm == true) await provider.deleteWorkOrder(w.id);
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      if (w.status == WorkOrderStatus.disputed)
                        const PopupMenuItem(value: 'resolve', child: Text('Riešiť spor')),
                      if (w.status != WorkOrderStatus.completed && w.status != WorkOrderStatus.cancelled)
                        const PopupMenuItem(value: 'complete', child: Text('Označiť ako dokončenú')),
                      if (w.status != WorkOrderStatus.cancelled)
                        const PopupMenuItem(value: 'cancel', child: Text('Zrušiť zákazku')),
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

// ── Zdieľané helper widgety ───────────────────────────────────────────────────

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String name;
  final String? email;
  final String? phone;
  final void Function(String) onCopy;

  const _ContactRow({
    required this.icon, required this.color, required this.name,
    this.email, this.phone, required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 6),
      Expanded(child: Text(name,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis)),
      if (email != null && email!.isNotEmpty) ...[
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => onCopy(email!),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.email_outlined, size: 10, color: Colors.grey.shade500),
              const SizedBox(width: 3),
              Text(email!,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis),
            ]))),
      ],
      if (phone != null && phone!.isNotEmpty) ...[
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => onCopy(phone!),
          child: Container(
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
      ],
    ]);
  }
}

class _ContactSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String name;
  final String email;
  final String phone;
  final void Function(String) onCopy;

  const _ContactSection({
    required this.title, required this.icon, required this.color,
    required this.name, required this.email, required this.phone,
    required this.onCopy,
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
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(fontSize: 12,
              color: color, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        if (email != '—') GestureDetector(
          onTap: () => onCopy(email),
          child: Row(children: [
            Icon(Icons.email_outlined, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 6),
            Expanded(child: Text(email,
                style: const TextStyle(fontSize: 13, color: Color(0xFF2563EB)))),
            Icon(Icons.copy, size: 13, color: Colors.grey.shade400),
          ])),
        if (phone != '—') ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => onCopy(phone),
            child: Row(children: [
              Icon(Icons.phone_outlined, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Expanded(child: Text(phone,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF2563EB)))),
              Icon(Icons.copy, size: 13, color: Colors.grey.shade400),
            ])),
        ],
      ]),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final List<Widget> children;
  const _DetailSection({required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: children));
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isAlert;
  const _DetailRow({required this.label, required this.value, this.isAlert = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 130,
            child: Text(label, style: TextStyle(
                fontSize: 12, color: Colors.grey.shade500))),
        Expanded(child: Text(value, style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isAlert ? Colors.red : null))),
      ]));
  }
}