// lib/widgets/profession_badge_widget.dart
// 🆕 NOVÉ pre Homie — nahrádza style_badge_widget.dart
// Zobrazuje profesiu / kategóriu remeselníka ako badge

import 'package:flutter/material.dart';

const _kPrimary = Color(0xFF2563EB);

// ─── Základný badge pre profesiu ─────────────────────────────────────────────
class ProfessionBadge extends StatelessWidget {
  final String profession;
  final bool large;

  const ProfessionBadge({
    super.key,
    required this.profession,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: large ? 12 : 8, vertical: large ? 6 : 3),
      decoration: BoxDecoration(
        color: _kPrimary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kPrimary.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.handyman_outlined,
            size: large ? 14 : 11, color: _kPrimary),
        const SizedBox(width: 4),
        Text(profession,
            style: TextStyle(
                fontSize: large ? 13 : 11,
                color: _kPrimary,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ─── Wrap skupiny skill chipov ────────────────────────────────────────────────
class SkillChips extends StatelessWidget {
  final List<String> skills;
  final int maxVisible;
  final bool selectable;
  final List<String> selected;
  final void Function(String)? onToggle;

  const SkillChips({
    super.key,
    required this.skills,
    this.maxVisible = 5,
    this.selectable = false,
    this.selected = const [],
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final visible = skills.take(maxVisible).toList();
    final remaining = skills.length - maxVisible;

    return Wrap(spacing: 6, runSpacing: 6, children: [
      ...visible.map((skill) {
        final isSelected = selected.contains(skill);
        return GestureDetector(
          onTap: selectable && onToggle != null ? () => onToggle!(skill) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected ? _kPrimary : _kPrimary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isSelected ? _kPrimary : _kPrimary.withOpacity(0.2))),
            child: Text(skill,
                style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? Colors.white : _kPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))),
        );
      }),
      if (remaining > 0)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
          child: Text('+$remaining',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
    ]);
  }
}

// ─── Filter chip pre profesiu (v zozname/mape) ────────────────────────────────
class ProfessionFilterChip extends StatelessWidget {
  final String profession;
  final bool selected;
  final VoidCallback onTap;

  const ProfessionFilterChip({
    super.key,
    required this.profession,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _kPrimary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _kPrimary : Colors.grey.shade300)),
        child: Text(profession,
            style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? Colors.white : Colors.grey.shade700)),
      ),
    );
  }
}
