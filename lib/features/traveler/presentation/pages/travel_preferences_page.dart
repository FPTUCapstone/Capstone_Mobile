import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_preferences_cubit.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';

class TravelPreferencesPage extends StatelessWidget {
  const TravelPreferencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TravelPreferencesCubit, TravelPreferencesState>(
      builder: (context, state) {
        final cubit = context.read<TravelPreferencesCubit>();
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
              child: Wrap(
                spacing: AppSpacing.xs,
                children: PreferredTransport.values
                    .map(
                      (value) => ChoiceChip(
                        label: Text(_transportLabel(value)),
                        selected: state.transport == value,
                        onSelected: (_) => cubit.setTransport(value),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            _Section(
              title: 'Travel pace',
              child: SegmentedButton<TravelPace>(
                segments: TravelPace.values
                    .map(
                      (value) => ButtonSegment(
                        value: value,
                        label: Text(_titleCase(value.name)),
                      ),
                    )
                    .toList(growable: false),
                selected: {state.pace},
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    cubit.setPace(selection.first),
              ),
            ),
            _Section(
              title: 'Interests',
              child: Wrap(
                spacing: AppSpacing.xs,
                children: TravelInterest.values
                    .map(
                      (value) => FilterChip(
                        label: Text(_interestLabel(value)),
                        selected: state.interests.contains(value),
                        onSelected: (_) => cubit.toggleInterest(value),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            _Section(
              title: 'Food preference',
              child: Wrap(
                spacing: AppSpacing.xs,
                children: FoodPreference.values
                    .map(
                      (value) => ChoiceChip(
                        label: Text(_foodLabel(value)),
                        selected: state.food == value,
                        onSelected: (_) => cubit.setFood(value),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            _Section(
              title: 'Risk tolerance',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<RiskTolerance>(
                    segments: RiskTolerance.values
                        .map(
                          (value) => ButtonSegment(
                            value: value,
                            label: Text(_titleCase(value.name)),
                          ),
                        )
                        .toList(growable: false),
                    selected: {state.risk},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) =>
                        cubit.setRisk(selection.first),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Medium allows outdoor stops when weather is uncertain but not severe.',
                  ),
                ],
              ),
            ),
            Card(
              child: SwitchListTile(
                title: const Text(
                  'Apply preferences to new plans automatically',
                ),
                value: state.autoApply,
                onChanged: (value) => cubit.setAutoApply(value: value),
              ),
            ),
          ],
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppButton(
                label: 'Save preferences',
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Travel preferences saved locally for demo.'),
                  ),
                ),
              ),
              TextButton(
                onPressed: cubit.reset,
                child: const Text('Reset to default'),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _foodLabel(FoodPreference value) => switch (value) {
    FoodPreference.noRestriction => 'No restriction',
    FoodPreference.vegetarian => 'Vegetarian',
    FoodPreference.halal => 'Halal',
    FoodPreference.noSeafood => 'No seafood',
  };

  static String _interestLabel(TravelInterest value) => switch (value) {
    TravelInterest.beach => 'Beach',
    TravelInterest.heritage => 'Heritage',
    TravelInterest.museum => 'Museum',
    TravelInterest.localFood => 'Local food',
    TravelInterest.nature => 'Nature',
    TravelInterest.nightlife => 'Nightlife',
  };

  static String _titleCase(String value) =>
      '${value[0].toUpperCase()}${value.substring(1)}';

  static String _transportLabel(PreferredTransport value) => switch (value) {
    PreferredTransport.motorbike => 'Motorbike',
    PreferredTransport.car => 'Car',
    PreferredTransport.walking => 'Walking',
    PreferredTransport.publicBus => 'Public bus',
  };
}

class _Section extends StatelessWidget {
  const _Section({required this.child, required this.title});

  final Widget child;
  final String title;

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
        ],
      ),
    );
  }
}
