import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';

/// A section heading with an optional number badge and a trailing hint (for
/// example "Select one"), as used by the numbered Stitch form sections.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.icon,
    this.number,
    this.trailing,
    super.key,
  });

  final IconData? icon;
  final int? number;
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (number != null && icon == null) ...[
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: SizedBox.square(
                dimension: 24,
                child: Center(
                  child: Text(
                    '$number',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          if (icon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 20, color: scheme.primary),
            ),
            const SizedBox(width: AppSpacing.xs),
            if (number != null)
              Text(
                '$number. ',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
          Expanded(
            flex: 3,
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  trailing!,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A rounded surface that groups related content, optionally with a titled
/// header (tonal icon tile + title + subtitle).
class SectionCard extends StatelessWidget {
  const SectionCard({
    this.child,
    this.icon,
    this.subtitle,
    this.title,
    this.trailing,
    super.key,
  });

  final Widget? child;
  final IconData? icon;
  final String? subtitle;
  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null) ...[
                    IconTile(icon: icon!),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            title!,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: scheme.secondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    trailing!,
                  ],
                ],
              ),
              if (child != null) const SizedBox(height: AppSpacing.sm),
            ],
            ?child,
          ],
        ),
      ),
    );
  }
}

/// A small rounded tile that gives an icon a tonal background.
class IconTile extends StatelessWidget {
  const IconTile({required this.icon, this.muted = false, super.key});

  final IconData icon;

  /// A neutral tile, for content that is not currently available.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: muted ? scheme.surfaceContainerHigh : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Icon(
          icon,
          color: muted ? scheme.onSurfaceVariant : scheme.primary,
        ),
      ),
    );
  }
}

/// A compact, neutral inline note for a capability that is not available yet.
/// Lighter than an alert: use it for context, not for errors.
class CapabilityNote extends StatelessWidget {
  const CapabilityNote({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.info_outline,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The label above a form field, with an optional required marker and an
/// optional trailing widget (for example a "Read only" chip).
class FieldLabel extends StatelessWidget {
  const FieldLabel(
    this.text, {
    this.isRequired = false,
    this.trailing,
    this.uppercase = false,
    super.key,
  });

  final bool isRequired;
  final String text;
  final Widget? trailing;
  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = uppercase
        ? theme.textTheme.labelSmall?.copyWith(
            color: scheme.secondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          )
        : theme.textTheme.bodyMedium?.copyWith(
            color: scheme.secondary,
            fontWeight: FontWeight.w500,
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    uppercase ? text.toUpperCase() : text,
                    style: style,
                  ),
                ),
                if (isRequired)
                  ExcludeSemantics(
                    child: Text(
                      ' *',
                      style: style?.copyWith(color: scheme.error),
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A read-only value presented in the shape of a form field: readable,
/// clearly not editable, and never an input control.
class ReadOnlyField extends StatelessWidget {
  const ReadOnlyField({
    required this.icon,
    required this.placeholder,
    this.helper,
    this.tinted = false,
    this.value,
    super.key,
  });

  final String? helper;
  final IconData icon;
  final String placeholder;

  /// Uses the read-only surface (for values that can never be edited here).
  final bool tinted;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasValue = value != null && value!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tinted
                  ? scheme.surfaceContainerHigh
                  : scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: scheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      hasValue ? value! : placeholder,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 15,
                        fontWeight: hasValue
                            ? FontWeight.w500
                            : FontWeight.w400,
                        color: hasValue
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: AppSpacing.xxs),
            child: Text(
              helper!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
