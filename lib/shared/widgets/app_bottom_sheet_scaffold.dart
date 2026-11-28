import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';

/// Canonical Template T5 modal bottom sheet container for TripMate Mobile.
///
/// Provides Coastal Heritage `20dp` top corners, a centered drag handle pill,
/// header with title, optional [subtitle], accessible `44dp` close button,
/// 1px hairline divider, scrollable body, and automatic keyboard + [SafeArea]
/// bottom inset handling.
class AppBottomSheetScaffold extends StatelessWidget {
  const AppBottomSheetScaffold({
    required this.title,
    required this.child,
    this.subtitle,
    this.footer,
    this.showDragHandle = true,
    this.showCloseButton = true,
    this.closeTooltip = 'Đóng',
    this.onClose,
    this.bodyPadding,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? footer;
  final bool showDragHandle;
  final bool showCloseButton;
  final String closeTooltip;
  final VoidCallback? onClose;
  final EdgeInsetsGeometry? bodyPadding;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: c.surfaceCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: c.borderSubtle, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showDragHandle)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 4),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.borderStrong,
                      borderRadius: BorderRadius.circular(TripMateRadius.pill),
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  showDragHandle ? 6 : AppSpacing.md,
                  showCloseButton ? AppSpacing.xs : AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontFamily: AppTypography.displayFont,
                              fontSize: 17.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              color: c.textPrimary,
                            ),
                          ),
                          if (subtitle != null &&
                              subtitle!.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              style: TextStyle(
                                fontFamily: AppTypography.uiFont,
                                fontSize: 12.5,
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (showCloseButton)
                      IconButton(
                        tooltip: closeTooltip,
                        onPressed:
                            onClose ?? () => Navigator.of(context).maybePop(),
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        icon: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: c.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: c.borderSubtle),
              Flexible(
                child: SingleChildScrollView(
                  padding:
                      bodyPadding ??
                      const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.lg,
                      ),
                  child: child,
                ),
              ),
              if (footer != null) ...[
                Divider(height: 1, thickness: 1, color: c.borderSubtle),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: footer!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Presents a canonical Coastal Heritage modal bottom sheet wrapped in
/// [AppBottomSheetScaffold].
Future<T?> showAppModalBottomSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  String? subtitle,
  Widget? footer,
  bool isScrollControlled = true,
  bool showDragHandle = true,
  bool showCloseButton = true,
  String closeTooltip = 'Đóng',
  EdgeInsetsGeometry? bodyPadding,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => AppBottomSheetScaffold(
      title: title,
      subtitle: subtitle,
      footer: footer,
      showDragHandle: showDragHandle,
      showCloseButton: showCloseButton,
      closeTooltip: closeTooltip,
      bodyPadding: bodyPadding,
      child: builder(sheetContext),
    ),
  );
}
