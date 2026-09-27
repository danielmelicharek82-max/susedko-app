import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/wishlist_item.dart';
import '../providers/wishlist_provider.dart';

class WishlistButton extends StatefulWidget {
  final WishlistType type;
  final String targetId;
  final String targetName;
  final String? imageUrl;
  final bool showLabel;
  final double size;

  const WishlistButton({
    super.key,
    required this.type,
    required this.targetId,
    required this.targetName,
    this.imageUrl,
    this.showLabel = false,
    this.size = 24,
  });

  @override
  State<WishlistButton> createState() => _WishlistButtonState();
}

class _WishlistButtonState extends State<WishlistButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  // Lokálny optimistický stav — null znamená "použi provider"
  bool? _localIsWishlisted;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      lowerBound: 0.8,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = _ctrl;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onTap(WishlistProvider provider) async {
    if (_isProcessing) return; // Zabráň dvojkliku

    final wasWishlisted = _localIsWishlisted ?? provider.isInWishlist(widget.targetId);
    final adding = !wasWishlisted;

    // 1. Okamžite zmeň UI
    setState(() {
      _localIsWishlisted = adding;
      _isProcessing = true;
    });

    // 2. Animácia
    await _ctrl.reverse();
    await _ctrl.forward();

    // 3. Firestore na pozadí
    await provider.toggle(
      type: widget.type,
      targetId: widget.targetId,
      targetName: widget.targetName,
      imageUrl: widget.imageUrl,
    );

    if (!mounted) return;

    // 4. NERESETUJ _localIsWishlisted hneď — počkaj kým provider stream
    //    potvrdí zmenu, potom až resetni
    setState(() => _isProcessing = false);

    // 5. Skontroluj či provider už má správny stav
    final providerState = provider.isInWishlist(widget.targetId);
    if (providerState == adding) {
      // Provider je synced — môžeme pustiť lokálny stav
      setState(() => _localIsWishlisted = null);
    }
    // Ak nie je ešte synced, _localIsWishlisted zostane ako je
    // a provider stream ho prepíše keď príde snapshot

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                adding ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                adding ? 'wishlist_added'.tr() : 'wishlist_removed'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          backgroundColor: adding
              ? const Color(0xFFE53935)
              : const Color(0xFF757575),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WishlistProvider>();

    // Keď provider stream príde a _localIsWishlisted je nastavený,
    // skontroluj či sa zhodujú — ak áno, resetni lokálny stav
    final providerState = provider.isInWishlist(widget.targetId);
    if (_localIsWishlisted != null && !_isProcessing && providerState == _localIsWishlisted) {
      // Použij post-frame callback aby sme nevolali setState počas buildu
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _localIsWishlisted != null) {
          setState(() => _localIsWishlisted = null);
        }
      });
    }

    final isWishlisted = _localIsWishlisted ?? providerState;

    return ScaleTransition(
      scale: _scale,
      child: widget.showLabel
          ? TextButton.icon(
              onPressed: _isProcessing ? null : () => _onTap(provider),
              icon: Icon(
                isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isWishlisted ? Colors.red : Colors.grey,
                size: widget.size,
              ),
              label: Text(
                isWishlisted ? 'wishlist_in'.tr() : 'Wishlist',
                style: TextStyle(
                  color: isWishlisted ? Colors.red : Colors.grey,
                  fontSize: 13,
                ),
              ),
            )
          : IconButton(
              onPressed: _isProcessing ? null : () => _onTap(provider),
              icon: Icon(
                isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isWishlisted ? Colors.red : Colors.grey.shade400,
                size: widget.size,
              ),
              tooltip: isWishlisted ? 'wishlist_remove'.tr() : 'wishlist_add'.tr(),
            ),
    );
  }
}