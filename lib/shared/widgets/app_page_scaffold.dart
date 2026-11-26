import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';

class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    required this.content,
    this.actions,
    this.footer,
    this.showAppBar = true,
    this.title,
    super.key,
  });

  final List<Widget>? actions;
  final List<Widget> content;
  final Widget? footer;
  final bool showAppBar;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return Scaffold(
      backgroundColor: c.canvas,
      appBar: showAppBar
          ? AppBar(
              title: title == null ? null : Text(title!),
              actions: actions,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: c.borderSubtle.withValues(alpha: 0.7),
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.lg,
                  ),
                  children: [
                    ...content,
                    if (footer != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      footer!,
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
