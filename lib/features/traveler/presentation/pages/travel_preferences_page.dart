import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/tripmate_visual_tokens.dart';
import 'package:trip_mate_mobile/shared/widgets/anchored_action_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';
import 'package:trip_mate_mobile/shared/widgets/section_card.dart';

/// UC-09 Travel Preferences (Screen #46).
///
/// Report 3 defines three preference groups whose option sets are owned by
/// system configuration. The Backend does not yet expose the option sets, the
/// Traveler's current preferences or a way to save them, so each group keeps
/// its designed section but shows an unavailable option surface: no option is
/// listed, nothing is pre-selected and nothing can be saved or claimed as saved.
class TravelPreferencesPage extends StatelessWidget {
  const TravelPreferencesPage({super.key});

  static const _groups = <_PreferenceGroup>[
    _PreferenceGroup(
      title: 'Interest tags',
      selectionHint: 'Select any that apply',
      icon: Icons.interests_outlined,
    ),
    _PreferenceGroup(
      title: 'Travel style',
      selectionHint: 'Select one',
      icon: Icons.groups_outlined,
    ),
    _PreferenceGroup(
      title: 'Budget level',
      selectionHint: 'Select one',
      icon: Icons.payments_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return TripMateVisualTheme(
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return Scaffold(
            appBar: AppBar(
              shape: const Border(),
              actions: const [
                IconButton(
                  onPressed: null,
                  tooltip: 'Reset preferences (unavailable)',
                  icon: Icon(Icons.refresh),
                ),
                SizedBox(width: AppSpacing.xxs),
              ],
            ),
            bottomNavigationBar: AnchoredActionBar(
              child: Theme(
                // Stitch uses the navy primary action on this screen.
                data: theme.copyWith(
                  filledButtonTheme: FilledButtonThemeData(
                    style: theme.filledButtonTheme.style?.copyWith(
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.disabled)
                            ? TripMateVisualTokens.navyDeep.withValues(
                                alpha: 0.32,
                              )
                            : TripMateVisualTokens.navyDeep,
                      ),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const CapabilityNote(
                      message:
                          "Saving travel preferences isn't available in the "
                          'app yet.',
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const AppButton(label: 'Save preferences', onPressed: null),
                    TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('Skip'),
                    ),
                  ],
                ),
              ),
            ),
            body: AppPageScaffold(
              showAppBar: false,
              content: [
                Semantics(
                  header: true,
                  child: Text(
                    'Travel Preferences',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Preferences are soft constraints used to personalise '
                  'itineraries and recommendations. They never block '
                  'itinerary generation.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const CapabilityNote(
                  message:
                      "Options are configured by TripMate and aren't "
                      'available in the app yet.',
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final (index, group) in _groups.indexed) ...[
                  SectionHeader(
                    number: index + 1,
                    icon: group.icon,
                    title: group.title,
                    trailing: group.selectionHint,
                  ),
                  _UnavailableOptionSurface(icon: group.icon),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PreferenceGroup {
  const _PreferenceGroup({
    required this.title,
    required this.selectionHint,
    required this.icon,
  });

  final IconData icon;
  final String selectionHint;
  final String title;
}

/// The Stitch option-card shell, showing that no option set is available.
/// It is not selectable and lists no option values.
class _UnavailableOptionSurface extends StatelessWidget {
  const _UnavailableOptionSurface({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(TripMateVisualTokens.cardRadius),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: TripMateVisualTokens.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            IconTile(icon: icon, muted: true),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Options unavailable',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'No options to choose from yet.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
