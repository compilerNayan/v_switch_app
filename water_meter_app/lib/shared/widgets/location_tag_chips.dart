import 'package:flutter/material.dart';

import '../../core/models/water_unit.dart';

class LocationTagChips extends StatelessWidget {
  const LocationTagChips({
    super.key,
    required this.unit,
    this.compact = false,
  });

  final WaterUnit unit;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tags = unit.locationTagEntries;
    if (tags.isEmpty) return const SizedBox.shrink();

    final chips = [
      for (final tag in tags)
        LocationTagChip(
          label: tag.label,
          value: tag.value,
          compact: compact,
        ),
    ];

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            chips[i],
          ],
        ],
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: chips,
    );
  }
}

class LocationTagChip extends StatelessWidget {
  const LocationTagChip({
    super.key,
    required this.label,
    required this.value,
    this.compact = false,
  });

  final String label;
  final String value;
  final bool compact;

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
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
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
              height: compact ? 1.0 : 1.2,
              fontSize: compact ? 10 : null,
            ),
      ),
    );
  }
}

enum _LocationTagKind { wing, block, floor }
