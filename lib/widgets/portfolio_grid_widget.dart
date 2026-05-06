// lib/widgets/portfolio_grid_widget.dart
// 🆕 NOVÉ pre Homie — portfólio prác remeselníka
// Namiesto tetovacích štýlov zobrazuje fotky dokončených prác

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/portfolio_item.dart';

const _kPrimary = Color(0xFF2563EB);

// ─── Grid portfólia (na detail screene) ──────────────────────────────────────
class PortfolioGrid extends StatelessWidget {
  final String craftsmanId;
  final int crossAxisCount;
  final int limit;
  final bool showTitle;

  const PortfolioGrid({
    super.key,
    required this.craftsmanId,
    this.crossAxisCount = 3,
    this.limit = 12,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('craftsmen').doc(craftsmanId)
          .collection('portfolio')
          .orderBy('createdAt', descending: true).limit(limit).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Padding(padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.photo_library_outlined, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text('Zatiaľ žiadne fotky prác',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ])));
        }

        final items = snapshot.data!.docs
            .map((doc) => PortfolioItem.fromFirestore(doc)).toList();

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount, crossAxisSpacing: 6, mainAxisSpacing: 6),
          itemCount: items.length,
          itemBuilder: (context, i) => _PortfolioTile(
            item: items[i],
            onTap: () => _openFullscreen(context, items, i)));
      });
  }

  void _openFullscreen(BuildContext context, List<PortfolioItem> items, int index) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _PortfolioFullscreen(items: items, initialIndex: index)));
  }
}

// ─── Horizontálny zoznam (na home screene) ───────────────────────────────────
class PortfolioHorizontalList extends StatelessWidget {
  final String craftsmanId;
  final double height;
  final int limit;

  const PortfolioHorizontalList({
    super.key,
    required this.craftsmanId,
    this.height = 120,
    this.limit = 8,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('craftsmen').doc(craftsmanId)
          .collection('portfolio')
          .orderBy('createdAt', descending: true).limit(limit).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
        final items = snapshot.data!.docs.map((doc) => PortfolioItem.fromFirestore(doc)).toList();
        return SizedBox(height: height,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => _PortfolioFullscreen(items: items, initialIndex: i))),
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                width: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200)),
                child: ClipRRect(borderRadius: BorderRadius.circular(10),
                  child: Image.network(items[i].imageUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: _kPrimary.withOpacity(0.05),
                      child: Icon(Icons.image_outlined, color: _kPrimary.withOpacity(0.3)))))))));
      });
  }
}

// ─── PRIVATE tile ─────────────────────────────────────────────────────────────
class _PortfolioTile extends StatelessWidget {
  final PortfolioItem item;
  final VoidCallback? onTap;
  const _PortfolioTile({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(fit: StackFit.expand, children: [
          Image.network(item.imageUrl, fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) => progress == null ? child
                : Container(color: Colors.grey.shade100,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
            errorBuilder: (_, __, ___) => Container(color: _kPrimary.withOpacity(0.05),
                child: Icon(Icons.broken_image_outlined, color: _kPrimary.withOpacity(0.3)))),
          if (item.title != null && item.title!.isNotEmpty)
            Positioned(bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent])),
                child: Text(item.title!, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 10,
                        fontWeight: FontWeight.bold)))),
        ])));
  }
}

// ─── Fullscreen galéria ───────────────────────────────────────────────────────
class _PortfolioFullscreen extends StatefulWidget {
  final List<PortfolioItem> items;
  final int initialIndex;
  const _PortfolioFullscreen({required this.items, required this.initialIndex});

  @override
  State<_PortfolioFullscreen> createState() => _PortfolioFullscreenState();
}

class _PortfolioFullscreenState extends State<_PortfolioFullscreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() { _pageController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white),
        title: Text('${_currentIndex + 1} / ${widget.items.length}',
            style: const TextStyle(color: Colors.white, fontSize: 14))),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.items.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, i) {
          final item = widget.items[i];
          return Column(children: [
            Expanded(child: InteractiveViewer(
              child: Image.network(item.imageUrl, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image, color: Colors.grey, size: 64))))),
            if (item.title != null && item.title!.isNotEmpty)
              Padding(padding: const EdgeInsets.all(16),
                child: Text(item.title!, textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 14))),
          ]);
        }),
    );
  }
}
