import 'package:flutter/material.dart';

import '../../core/models/water_unit.dart';

class LocationTagChips extends StatelessWidget {
  const LocationTagChips({super.key, required this.unit});

  final WaterUnit unit;

  @override
  Widget build(BuildContext context) {
    final tags = unit.locationTagEntries;
    if (tags.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tag in tags)
          LocationTagChip(label: tag.label, value: tag.value),
      ],
    );
  }
}

class LocationTagChip extends StatelessWidget {
  const LocationTagChip({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final kind = switch (label) {
      'Wing' => _LocationTagKind.wing,
      'Block' => _LocationTagKind.block,
      _ => _LocationTagKind.floor,
    };
    final (background, foreground) = switch (kind) {
      _LocationTagKind.wing => (
          const Color(0xFFE0F2F1),
          const Color(0xFF00695C),
        ),
      _LocationTagKind.block => (
          const Color(0xFFFFF3E0),
          const Color(0xFFE65100),
        ),
      _LocationTagKind.floor => (
          const Color(0xFFF3E5F5),
          const Color(0xFF6A1B9A),
        ),
    };

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? Color.alphaBlend(foreground.withValues(alpha: 0.18), scheme.surface)
        : background;
    final fg = isDark ? foreground.withValues(alpha: 0.92) : foreground;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label $value',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
              height: 1.2,
            ),
      ),
    );
  }
}

enum _LocationTagKind { wing, block, floor }
