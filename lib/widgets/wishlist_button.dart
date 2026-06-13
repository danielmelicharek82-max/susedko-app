import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/wishlist_provider.dart';

class WishlistButton extends StatefulWidget {
  final String craftsmanId;
  final String craftsmanName;
  final String? imageUrl;
  final bool showLabel;
  final double size;

  const WishlistButton({
    super.key,
    required this.craftsmanId,
    required this.craftsmanName,
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
    if (_isProcessing) return;
    final wasWishlisted = _localIsWishlisted ?? provider.isInWishlist(widget.craftsmanId);
    final adding = !wasWishlisted;
    setState(() { _localIsWishlisted = adding; _isProcessing = true; });
    await _ctrl.reverse();
    await _ctrl.forward();
    await provider.toggle(
      craftsmanId: widget.craftsmanId,
      craftsmanName: widget.craftsmanName,
      craftsmanPhoto: widget.imageUrl,
    );
    if (!mounted) return;
    setState(() => _isProcessing = false);
    final providerState = provider.isInWishlist(widget.craftsmanId);
    if (providerState == adding) setState(() => _localIsWishlisted = null);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(adding ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Text(adding ? 'wishlist_added'.tr() : 'wishlist_removed'.tr(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        ]),
        backgroundColor: adding ? const Color(0xFFE53935) : const Color(0xFF757575),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WishlistProvider>();
    final providerState = provider.isInWishlist(widget.craftsmanId);
    if (_localIsWishlisted != null && !_isProcessing && providerState == _localIsWishlisted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _localIsWishlisted != null) setState(() => _localIsWishlisted = null);
      });
    }
    final isWishlisted = _localIsWishlisted ?? providerState;
    return ScaleTransition(
      scale: _scale,
      child: widget.showLabel
          ? TextButton.icon(
              onPressed: _isProcessing ? null : () => _onTap(provider),
              icon: Icon(isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isWishlisted ? Colors.red : Colors.grey, size: widget.size),
              label: Text(isWishlisted ? 'wishlist_in'.tr() : 'Wishlist',
                  style: TextStyle(color: isWishlisted ? Colors.red : Colors.grey, fontSize: 13)),
            )
          : IconButton(
              onPressed: _isProcessing ? null : () => _onTap(provider),
              icon: Icon(isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isWishlisted ? Colors.red : Colors.grey.shade400, size: widget.size),
              tooltip: isWishlisted ? 'wishlist_remove'.tr() : 'wishlist_add'.tr(),
            ),
    );
  }
}
