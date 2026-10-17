import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_detail.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/cubit/create_tour_package_state.dart';

const maxTourDestinations = 10;

const _blockerMessages = {
  'primary_image_missing': 'Add a cover photo (an active primary image).',
  'future_departure_missing':
      'Add at least one future departure with an adult price.',
  'cancellation_policy_missing': 'Select a cancellation policy.',
  'destination_missing': 'Select at least one destination.',
};

const _warningMessages = {
  'duplicate_poi': 'This place already appears earlier in the itinerary.',
  'poi_closed_on_day': 'This place is closed on that day of the trip.',
  'outside_opening_hours':
      'The planned visit is outside the opening hours of this place.',
  'opening_hours_unknown':
      'Opening hours for that day are unknown, so the visit could not be checked.',
};

String tourBlockerMessage(String code) => _blockerMessages[code] ?? code;

String tourWarningMessage(String code) => _warningMessages[code] ?? code;

final class TourPackageBanner extends StatelessWidget {
  const TourPackageBanner({
    required this.icon,
    required this.message,
    super.key,
  });
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      0,
    ),
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(icon),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(message)),
      ],
    ),
  );
}

/// Destination chips and cancellation-policy dropdown backed by the server catalogue.
final class TourOptionsSection extends StatelessWidget {
  const TourOptionsSection({
    required this.state,
    required this.enabled,
    required this.selectedDestinationIds,
    required this.selectedPolicyId,
    required this.onToggleDestination,
    required this.onPolicyChanged,
    required this.onRetry,
    super.key,
  });
  final CreateTourPackageState state;
  final bool enabled;
  final List<int> selectedDestinationIds;
  final int? selectedPolicyId;
  final ValueChanged<int> onToggleDestination;
  final ValueChanged<int?> onPolicyChanged;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    switch (state.optionsStatus) {
      case TourPackageOptionsStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case TourPackageOptionsStatus.failure:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.optionsFailure?.message ??
                  'Could not load destinations and cancellation policies.',
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        );
      case TourPackageOptionsStatus.ready:
        final options = state.options!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Destinations', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final destination in options.destinations)
                  FilterChip(
                    label: Text(destination.name),
                    selected: selectedDestinationIds.contains(destination.id),
                    onSelected: enabled
                        ? (_) => onToggleDestination(destination.id)
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<int>(
              initialValue: selectedPolicyId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Cancellation policy',
              ),
              items: [
                for (final policy in options.policies)
                  DropdownMenuItem(
                    value: policy.id,
                    child: Text(policy.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: enabled ? onPolicyChanged : null,
            ),
          ],
        );
    }
  }
}

/// Cover-photo management for a saved package.
final class TourPhotosSection extends StatelessWidget {
  const TourPhotosSection({
    required this.media,
    required this.busy,
    required this.readOnly,
    required this.onAdd,
    required this.onSetPrimary,
    required this.onDelete,
    super.key,
  });
  final List<TourMediaItem> media;
  final bool busy;
  final bool readOnly;
  final VoidCallback onAdd;
  final ValueChanged<int> onSetPrimary;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'JPG or PNG up to 5 MB. A cover photo is required before the package can be submitted for review.',
      ),
      const SizedBox(height: AppSpacing.sm),
      if (media.isEmpty) const Text('No photos yet.'),
      for (final item in media)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: SizedBox(
            width: 56,
            height: 56,
            child: Image.network(
              item.url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.broken_image_outlined),
            ),
          ),
          title: Text(item.isPrimary ? 'Cover photo' : 'Photo'),
          subtitle: item.altText == null ? null : Text(item.altText!),
          trailing: readOnly
              ? null
              : Wrap(
                  children: [
                    if (!item.isPrimary)
                      IconButton(
                        icon: const Icon(Icons.star_outline),
                        tooltip: 'Make cover photo',
                        onPressed: busy ? null : () => onSetPrimary(item.id),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Remove photo',
                      onPressed: busy ? null : () => onDelete(item.id),
                    ),
                  ],
                ),
        ),
      if (!readOnly)
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: busy ? null : onAdd,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(busy ? 'Working...' : 'Add photo'),
          ),
        ),
    ],
  );
}

/// How the package will read to a customer, built from the current form.
final class TourPreviewCard extends StatelessWidget {
  const TourPreviewCard({
    required this.title,
    required this.destinations,
    required this.days,
    required this.departures,
    this.coverUrl,
    this.durationDays,
    this.basePrice,
    this.highlights = '',
    this.inclusions = '',
    this.exclusions = '',
    this.policyName,
    super.key,
  });
  final String title;
  final String? coverUrl;
  final List<String> destinations;
  final int? durationDays;
  final num? basePrice;
  final String highlights;
  final String inclusions;
  final String exclusions;
  final String? policyName;
  final Map<int, List<String>> days;
  final List<String> departures;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    Widget section(String heading, String body) => body.trim().isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(heading, style: textTheme.titleSmall),
                Text(body.trim()),
              ],
            ),
          );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (coverUrl != null)
            Image.network(
              coverUrl!,
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(
                height: 140,
                child: Center(child: Icon(Icons.broken_image_outlined)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleMedium),
                Text(
                  [
                    if (destinations.isNotEmpty) destinations.join(', '),
                    if (durationDays != null) '$durationDays day(s)',
                    if (basePrice != null) 'from $basePrice VND',
                  ].join(' · '),
                ),
                if (coverUrl == null)
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.xs),
                    child: Text('No cover photo yet.'),
                  ),
                section('Highlights', highlights),
                for (final entry in days.entries)
                  section('Day ${entry.key}', entry.value.join(' → ')),
                section('Included', inclusions),
                section('Not included', exclusions),
                if (policyName != null) section('Cancellation', policyName!),
                section('Departures', departures.join('\n')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Server-reported review blockers and non-blocking itinerary warnings.
final class TourReadinessSection extends StatelessWidget {
  const TourReadinessSection({
    required this.blockers,
    required this.warnings,
    required this.poiNames,
    super.key,
  });
  final List<String> blockers;
  final List<TourWarning> warnings;
  final Map<int, String> poiNames;

  @override
  Widget build(BuildContext context) {
    if (blockers.isEmpty && warnings.isEmpty) {
      return const Text('Ready to submit for review.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (blockers.isNotEmpty) ...[
          Text(
            'Needed before review:',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final code in blockers) Text('• ${tourBlockerMessage(code)}'),
        ],
        if (warnings.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Itinerary warnings (they do not block saving):',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final warning in warnings)
            Text(
              '• ${[if (warning.dayNo != null) 'Day ${warning.dayNo}', if (warning.poiId != null) poiNames[warning.poiId] ?? 'Place #${warning.poiId}'].join(', ')}: ${tourWarningMessage(warning.code)}',
            ),
        ],
      ],
    );
  }
}
