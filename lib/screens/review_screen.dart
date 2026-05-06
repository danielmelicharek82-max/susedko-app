// lib/screens/review_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/review_provider.dart';

const _kPrimary = Color(0xFF2563EB);
const _kDeep    = Color(0xFF1E40AF);
const _kBg      = Color(0xFFF0F4FF);

class ReviewScreen extends StatefulWidget {
  final String craftsmanId;
  final String craftsmanName;
  final String bookingId;
  final String? workImage;

  const ReviewScreen({
    super.key,
    required this.craftsmanId,
    required this.craftsmanName,
    required this.bookingId,
    this.workImage,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  double _rating = 0;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ratingRequired'.tr())),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final provider = context.read<ReviewProvider>();

    final success = await provider.submitReview(
      customerId: user.uid,
      customerName: user.displayName ?? 'customer'.tr(),
      craftsmanId: widget.craftsmanId,
      bookingId: widget.bookingId,
      rating: _rating,
      comment: _commentController.text.trim().isEmpty
          ? null
          : _commentController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('reviewSent'.tr())),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'error'.tr()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<ReviewProvider>().isLoading;

    return Scaffold(
      backgroundColor: _kBg,

      // ─────────────────────────────────────────────
      //  UNIFIED APP BAR (rovnaký štýl ako WorkOrders)
      // ─────────────────────────────────────────────
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(120),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_kDeep, _kPrimary, Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Positioned(
                  right: -30,
                  top: -30,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  left: -20,
                  bottom: -20,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Hodnotenie'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── CARD ─────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: widget.workImage != null &&
                            widget.workImage!.isNotEmpty
                        ? Image.network(
                            widget.workImage!,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                          )
                        : _placeholder(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.craftsmanName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'craftsman'.tr(),
                          style: const TextStyle(
                            fontSize: 13,
                            color: _kPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            Text(
              'rating'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            _StarSelector(
              rating: _rating,
              onChanged: (val) => setState(() => _rating = val),
            ),

            const SizedBox(height: 30),

            Text(
              'commentOptional'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _commentController,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'commentHint'.tr(),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'submitReview'.tr(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 64,
        height: 64,
        color: _kPrimary.withOpacity(0.08),
        child: Icon(
          Icons.handyman_outlined,
          color: _kPrimary.withOpacity(0.4),
          size: 28,
        ),
      );
}

class _StarSelector extends StatelessWidget {
  final double rating;
  final ValueChanged<double> onChanged;

  const _StarSelector({
    required this.rating,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(5, (i) {
        final val = i + 1.0;
        final filled = rating >= val;

        return GestureDetector(
          onTap: () => onChanged(val),
          child: Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            color: filled ? Colors.amber : Colors.grey.shade300,
            size: 40,
          ),
        );
      }),
    );
  }
}