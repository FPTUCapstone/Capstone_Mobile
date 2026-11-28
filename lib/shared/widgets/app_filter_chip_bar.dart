import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';

/// Immutable option model for [AppFilterChipBar].
@immutable
class AppFilterOption<T> {
  const AppFilterOption({required this.value, required this.label, this.count});

  final T value;
  final String label;
  final int? count;

  String get displayLabel => count != null ? '$label ($count)' : label;
}

/// Canonical Template T4 horizontal Coastal Heritage filter chip bar.
///
/// Builds styled Material [ChoiceChip] widgets with accessible `>= 48dp`
/// padded touch targets, Light/Dark token adaptation via `context.tmColors`,
/// and intrinsic height so `200%` text scaling never clips labels.
class AppFilterChipBar<T> extends StatelessWidget {
  const AppFilterChipBar({
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    this.padding,
    this.showBottomBorder = false,
    super.key,
  });

  final List<AppFilterOption<T>> options;
  final T selectedValue;
  final ValueChanged<T> onSelected;
  final EdgeInsetsGeometry? padding;
  final bool showBottomBorder;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;

    final scroller = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding:
          padding ??
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xs),
            _buildChip(c, options[i]),
          ],
        ],
      ),
    );

    if (!showBottomBorder) return scroller;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceCard,
        border: Border(bottom: BorderSide(color: c.borderSubtle, width: 1)),
      ),
      child: scroller,
    );
  }

  Widget _buildChip(TripMateColors c, AppFilterOption<T> option) {
    final isSelected = option.value == selectedValue;
    return ChoiceChip(
      label: Text(option.displayLabel),
      selected: isSelected,
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      backgroundColor: c.surfaceCard,
      selectedColor: c.tealSoftContainer,
      side: BorderSide(
        color: isSelected ? c.brandTeal : c.borderSubtle,
        width: isSelected ? 1.25 : 1.0,
      ),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      labelStyle: TextStyle(
        fontFamily: AppTypography.uiFont,
        fontSize: 12.5,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
        color: isSelected ? c.brandTeal : c.textSecondary,
      ),
      onSelected: (_) => onSelected(option.value),
    );
  }
}
