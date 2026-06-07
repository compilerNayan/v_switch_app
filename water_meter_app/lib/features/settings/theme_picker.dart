import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';

class ThemePicker extends ConsumerWidget {
  const ThemePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(appThemeIdProvider);
    final prefsAsync = ref.watch(preferencesStorageProvider);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: AppThemeId.values.map((themeId) {
        final colors = themeId.previewColors;
        final isSelected = selected == themeId;

        return SizedBox(
          width: 100,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: prefsAsync.hasValue
                  ? () async {
                      ref.read(appThemeIdProvider.notifier).state = themeId;
                      await prefsAsync.value!.setAppThemeId(themeId);
                    }
                  : null,
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 32,
                        child: Row(
                          children: [
                            Expanded(child: ColoredBox(color: colors.primary)),
                            Expanded(child: ColoredBox(color: colors.secondary)),
                            Expanded(child: ColoredBox(color: colors.surface)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      themeId.label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    if (isSelected)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(
                          Icons.check_circle,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
