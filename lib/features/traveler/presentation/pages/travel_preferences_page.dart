import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_preferences_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_preferences_state.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';

/// UC-09: loads real options and saved preferences from the Backend on
/// entry (triggered by the router when the Cubit is created) and saves the
/// full five-field state. Interests and food are multi-select; Preferred
/// Transport, Travel Pace, and Risk Tolerance are single-choice with an
/// explicit "No preference" option that clears the field to `null`
/// (spec §5/§7).
class TravelPreferencesPage extends StatelessWidget {
  const TravelPreferencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TravelPreferencesCubit, TravelPreferencesState>(
      listener: (context, state) {
        if (state.requiresSignIn) {
          // A 401 means the locally persisted session is no longer usable.
          // AuthSessionCubit clears it and the shared router guard returns the
          // user to sign-in.
          context.read<AuthSessionCubit>().signOut();
          return;
        }
        if (state.status == TravelPreferencesStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Travel preferences saved.')),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<TravelPreferencesCubit>();

        if (state.isLoading) {
          return const AppPageScaffold(
            title: 'Travel Preferences',
            content: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          );
        }

        if (state.status == TravelPreferencesStatus.error &&
            state.options.preferredTransportModes.isEmpty) {
          return AppPageScaffold(
            title: 'Travel Preferences',
            content: [
              AppAlert(
                message: state.errorMessage ?? 'Something went wrong.',
                type: AppAlertType.error,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(label: 'Retry', onPressed: cubit.load),
            ],
          );
        }

        return AppPageScaffold(
          title: 'Travel Preferences',
          content: [
            const AppAlert(
              message:
                  'Preferences are soft constraints. The planner uses them when it can, but a valid itinerary may deviate from them.',
            ),
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: 'Preferred transport',
              error: state.fieldErrors['preferredTransportMode']?.firstOrNull,
              child: Wrap(
                spacing: AppSpacing.xs,
                children: [
                  ChoiceChip(
                    label: const Text('No preference'),
                    selected: state.preferences.preferredTransportMode == null,
                    onSelected: (_) => cubit.setPreferredTransportMode(null),
                  ),
                  ...state.options.preferredTransportModes.map(
                    (value) => ChoiceChip(
                      label: Text(_label(value)),
                      selected:
                          state.preferences.preferredTransportMode == value,
                      onSelected: (_) => cubit.setPreferredTransportMode(value),
                    ),
                  ),
                ],
              ),
            ),
            _Section(
              title: 'Travel pace',
              error: state.fieldErrors['travelPace']?.firstOrNull,
              child: Wrap(
                spacing: AppSpacing.xs,
                children: [
                  ChoiceChip(
                    label: const Text('No preference'),
                    selected: state.preferences.travelPace == null,
                    onSelected: (_) => cubit.setTravelPace(null),
                  ),
                  ...state.options.travelPaces.map(
                    (value) => ChoiceChip(
                      label: Text(_label(value)),
                      selected: state.preferences.travelPace == value,
                      onSelected: (_) => cubit.setTravelPace(value),
                    ),
                  ),
                ],
              ),
            ),
            _Section(
              title: 'Interests',
              error: state.fieldErrors['interests']?.firstOrNull,
              child: Wrap(
                spacing: AppSpacing.xs,
                children: state.options.interests
                    .map(
                      (option) => FilterChip(
                        label: Text(option.key),
                        selected: state.preferences.interests.contains(
                          option.key,
                        ),
                        onSelected: (_) => cubit.toggleInterest(option.key),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            _Section(
              title: 'Food preference',
              error: state.fieldErrors['foodPreferences']?.firstOrNull,
              child: Wrap(
                spacing: AppSpacing.xs,
                children: state.options.foodPreferences
                    .map(
                      (value) => FilterChip(
                        label: Text(_label(value)),
                        selected: state.preferences.foodPreferences.contains(
                          value,
                        ),
                        onSelected: (_) => cubit.toggleFoodPreference(value),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            _Section(
              title: 'Risk tolerance',
              error: state.fieldErrors['riskTolerance']?.firstOrNull,
              child: Wrap(
                spacing: AppSpacing.xs,
                children: [
                  ChoiceChip(
                    label: const Text('No preference'),
                    selected: state.preferences.riskTolerance == null,
                    onSelected: (_) => cubit.setRiskTolerance(null),
                  ),
                  ...state.options.riskTolerances.map(
                    (value) => ChoiceChip(
                      label: Text(_label(value)),
                      selected: state.preferences.riskTolerance == value,
                      onSelected: (_) => cubit.setRiskTolerance(value),
                    ),
                  ),
                ],
              ),
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppAlert(message: state.errorMessage!, type: AppAlertType.error),
            ],
          ],
          footer: AppButton(
            label: 'Save preferences',
            isLoading: state.isSaving,
            onPressed: state.isSaving ? null : cubit.save,
          ),
        );
      },
    );
  }

  static String _label(String value) {
    final buffer = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      final char = value[i];
      if (i > 0 && char == char.toUpperCase() && char != char.toLowerCase()) {
        buffer.write(' ');
      }
      buffer.write(i == 0 ? char.toUpperCase() : char);
    }
    return buffer.toString();
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.child, required this.title, this.error});

  final Widget child;
  final String title;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          child,
          if (error != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
