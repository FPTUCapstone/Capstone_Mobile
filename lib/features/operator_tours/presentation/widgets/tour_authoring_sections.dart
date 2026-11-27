import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/utils/calendar_date_format.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_detail.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_draft.dart';

const tourPackingQuickTags = [
  'Sports shoes',
  'Swimwear & towel',
  'Raincoat / umbrella',
  'Windbreaker jacket',
  'Personal / motion sickness medicine',
  'ID card / Passport',
];

const _depositPercentPresets = [
  (value: 30, label: '30% · Domestic'),
  (value: 50, label: '50% · Holiday / Flight'),
  (value: 70, label: '70% · International'),
];

const _balanceDueDayPresets = [
  (value: 5, label: '5 days'),
  (value: 7, label: '7 days'),
  (value: 14, label: '14 days'),
  (value: 30, label: '30 days'),
];

final _bulletPrefix = RegExp(r'^[-•*]\s*');

bool hasPackingChecklistTag(String text, String tag) => text
    .split(RegExp(r'\r?\n'))
    .any(
      (line) =>
          line.trim().replaceFirst(_bulletPrefix, '').toLowerCase() ==
          tag.toLowerCase(),
    );

String togglePackingChecklistTag(String text, String tag) {
  final lines = text.split(RegExp(r'\r?\n'));
  final existingIdx = lines.indexWhere(
    (line) =>
        line.trim().replaceFirst(_bulletPrefix, '').toLowerCase() ==
        tag.toLowerCase(),
  );
  if (existingIdx >= 0) {
    final kept = [
      for (var i = 0; i < lines.length; i++)
        if (i != existingIdx) lines[i],
    ];
    return kept.join('\n').trim();
  }
  final trimmed = text.trimRight();
  final entry = '- $tag';
  return trimmed.isEmpty ? entry : '$trimmed\n$entry';
}

String _formatVnd(num value) {
  final rounded = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < rounded.length; i++) {
    final posFromRight = rounded.length - i;
    if (i > 0 && posFromRight % 3 == 0) buffer.write('.');
    buffer.write(rounded[i]);
  }
  return '$buffer VND';
}

String formatVietnamTimestamp(DateTime utcInstant) {
  final utc7 = utcInstant.toUtc().add(const Duration(hours: 7));
  String twoDigits(int v) => v.toString().padLeft(2, '0');
  return '${formatCalendarDate(utc7)} ${twoDigits(utc7.hour)}:${twoDigits(utc7.minute)} (UTC+7)';
}

/// Interactive checklist tags that insert/remove bullet items inside the requirements field.
final class TourPackingChecklistTags extends StatelessWidget {
  const TourPackingChecklistTags({
    required this.requirementsText,
    required this.enabled,
    required this.onToggleTag,
    super.key,
  });

  final String requirementsText;
  final bool enabled;
  final ValueChanged<String> onToggleTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick packing suggestions:',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final tag in tourPackingQuickTags)
              FilterChip(
                label: Text(tag),
                selected: hasPackingChecklistTag(requirementsText, tag),
                onSelected: enabled ? (_) => onToggleTag(tag) : null,
              ),
          ],
        ),
      ],
    );
  }
}

/// Deposit & balance settlement terms card matching backend BR-154 constraints.
final class TourDepositSettingsSection extends StatelessWidget {
  const TourDepositSettingsSection({
    required this.allowDeposit,
    required this.depositPercentController,
    required this.balanceDueDaysController,
    required this.basePrice,
    required this.enabled,
    required this.onAllowDepositChanged,
    required this.onSelectPercentPreset,
    required this.onSelectBalanceDaysPreset,
    super.key,
  });

  final bool allowDeposit;
  final TextEditingController depositPercentController;
  final TextEditingController balanceDueDaysController;
  final num? basePrice;
  final bool enabled;
  final ValueChanged<bool> onAllowDepositChanged;
  final ValueChanged<int> onSelectPercentPreset;
  final ValueChanged<int> onSelectBalanceDaysPreset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentPercent =
        num.tryParse(depositPercentController.text.trim()) ?? 30;
    final currentDays = int.tryParse(balanceDueDaysController.text.trim()) ?? 7;
    final effectiveBase = basePrice != null && basePrice! > 0 ? basePrice! : 0;
    final sampleDeposit = effectiveBase > 0
        ? (effectiveBase * currentPercent / 100).round()
        : 0;
    final sampleRemaining = effectiveBase > 0
        ? (effectiveBase - sampleDeposit).round()
        : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment & Deposit Setup',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Allow travelers to pay 100% upfront or leave a deposit (10%–90%) and settle the balance before departure.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: false,
                label: Text('100% upfront'),
                icon: Icon(Icons.payments_outlined),
              ),
              ButtonSegment<bool>(
                value: true,
                label: Text('Allow deposit'),
                icon: Icon(Icons.percent),
              ),
            ],
            selected: {allowDeposit},
            onSelectionChanged: enabled
                ? (selection) => onAllowDepositChanged(selection.first)
                : null,
          ),
          if (allowDeposit) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Deposit percentage (%)', style: theme.textTheme.labelMedium),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final preset in _depositPercentPresets)
                  ChoiceChip(
                    label: Text(preset.label),
                    selected:
                        num.tryParse(depositPercentController.text.trim()) ==
                        preset.value,
                    onSelected: enabled
                        ? (_) => onSelectPercentPreset(preset.value)
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              controller: depositPercentController,
              enabled: enabled,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Deposit % (10–90)'),
              validator: (value) {
                if (!allowDeposit) return null;
                final parsed = num.tryParse((value ?? '').trim());
                if (parsed == null || parsed < 10 || parsed > 90) {
                  return 'Deposit percentage must be between 10% and 90%.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Balance due before departure (days)',
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final preset in _balanceDueDayPresets)
                  ChoiceChip(
                    label: Text(preset.label),
                    selected:
                        int.tryParse(balanceDueDaysController.text.trim()) ==
                        preset.value,
                    onSelected: enabled
                        ? (_) => onSelectBalanceDaysPreset(preset.value)
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              controller: balanceDueDaysController,
              enabled: enabled,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Balance due days (4–180)',
                helperText:
                    'At least 4 days before departure before the 72-hour cutoff (BR-154).',
              ),
              validator: (value) {
                if (!allowDeposit) return null;
                final parsed = int.tryParse((value ?? '').trim());
                if (parsed == null || parsed < 4 || parsed > 180) {
                  return 'Balance deadline must be between 4 and 180 days before departure.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.35,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                effectiveBase > 0
                    ? 'Deposit $currentPercent% (${_formatVnd(sampleDeposit)}/guest) at booking; remaining ${100 - currentPercent}% (${_formatVnd(sampleRemaining)}/guest) due $currentDays days before departure. Bookings placed inside $currentDays days require 100% upfront payment.'
                    : 'Deposit $currentPercent% at booking; remaining ${100 - currentPercent}% due $currentDays days before departure. Bookings placed inside $currentDays days require 100% upfront payment.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Clickable version history timeline (v1, v2...) linking across package versions.
final class TourVersionHistorySection extends StatelessWidget {
  const TourVersionHistorySection({
    required this.currentDetail,
    required this.statusLabelBuilder,
    required this.onOpenVersion,
    super.key,
  });

  final TourPackageDetail currentDetail;
  final String Function(TourPackageStatus status, DateTime? publishedAtUtc)
  statusLabelBuilder;
  final ValueChanged<int> onOpenVersion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = currentDetail.versions.isNotEmpty
        ? currentDetail.versions
        : [
            TourVersionHistoryItem(
              tourId: currentDetail.id,
              versionNo: currentDetail.versionNo,
              status: currentDetail.status,
              publishedAtUtc: currentDetail.publishedAtUtc,
              rejectionReason: currentDetail.rejectionReason,
            ),
          ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Version History',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final item in items) ...[
            const SizedBox(height: AppSpacing.xs),
            Builder(
              builder: (context) {
                final isCurrent = item.tourId == currentDetail.id;
                final timestamp = item.publishedAtUtc ?? item.createdAtUtc;
                final label = statusLabelBuilder(
                  item.status,
                  item.publishedAtUtc,
                );
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? theme.colorScheme.surfaceContainerHighest
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'v${item.versionNo} · $label',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: isCurrent
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            Text(
                              isCurrent
                                  ? 'Currently open'
                                  : (timestamp != null
                                        ? formatVietnamTimestamp(timestamp)
                                        : 'Previous version'),
                              style: theme.textTheme.bodySmall,
                            ),
                            if (!isCurrent &&
                                item.status == TourPackageStatus.rejected &&
                                item.rejectionReason != null)
                              Text(
                                'Reason: ${item.rejectionReason}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      if (isCurrent)
                        Chip(
                          label: const Text('Current'),
                          visualDensity: VisualDensity.compact,
                        )
                      else
                        TextButton(
                          onPressed: () => onOpenVersion(item.tourId),
                          child: Text(item.status.isEditable ? 'Edit' : 'View'),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Dialog allowing operators to reopen/add a future departure on a live published tour.
Future<TourScheduleDraft?> showAddTourDepartureDialog(
  BuildContext context, {
  required TourPackageDetail detail,
}) async {
  final now = DateTime.now();
  final minFuture = DateTime(
    now.year,
    now.month,
    now.day,
  ).add(const Duration(days: 7));
  final activeDepartures =
      detail.departures.where((d) => d.status != 'Cancelled').toList()
        ..sort((a, b) => b.startAtUtc.compareTo(a.startAtUtc));
  final latestActive = activeDepartures.firstOrNull;
  final initialDate = latestActive != null
      ? (() {
          final candidate = latestActive.startAtUtc.toLocal().add(
            const Duration(days: 1),
          );
          return candidate.isAfter(minFuture) ? candidate : minFuture;
        })()
      : minFuture;
  final initialStart = DateTime(
    initialDate.year,
    initialDate.month,
    initialDate.day,
    8,
    0,
  );
  final initialEnd = initialStart.add(
    Duration(
      days: detail.durationDays > 0 ? detail.durationDays - 1 : 0,
      hours: 8,
    ),
  );
  final capacity = TextEditingController(
    text: '${latestActive?.totalCapacity ?? 20}',
  );
  final minCapacity = TextEditingController(
    text: '${latestActive?.minimumCapacity ?? 1}',
  );
  final adultPrice = TextEditingController(
    text: '${latestActive?.adultPrice ?? detail.basePrice}',
  );
  final childPrice = TextEditingController(
    text: latestActive?.childPrice?.toString() ?? '',
  );
  final infantPrice = TextEditingController(
    text: latestActive?.infantPrice?.toString() ?? '',
  );
  final meetingPoint = TextEditingController(
    text: latestActive?.meetingPoint ?? '',
  );
  final meetingLat = TextEditingController(
    text: latestActive?.meetingLatitude?.toString() ?? '',
  );
  final meetingLng = TextEditingController(
    text: latestActive?.meetingLongitude?.toString() ?? '',
  );

  var selectedStart = initialStart;
  DateTime? registrationDeadline = selectedStart.subtract(
    const Duration(days: 2),
  );
  if (!registrationDeadline.isAfter(now)) {
    registrationDeadline = DateTime(now.year, now.month, now.day + 1, 8);
    if (!registrationDeadline.isBefore(selectedStart)) {
      registrationDeadline = null;
    }
  }
  String? validationError;

  final result = await showDialog<TourScheduleDraft>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        final end = selectedStart.add(
          Duration(
            days: detail.durationDays > 1 ? detail.durationDays - 1 : 0,
            hours: initialEnd.difference(initialStart).inHours > 0 ? 8 : 8,
          ),
        );
        return AlertDialog(
          title: const Text('Open new departure'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Adds a bookable departure without cloning the tour or changing existing bookings.',
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Departure: ${formatCalendarDate(selectedStart)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: selectedStart,
                          firstDate: DateTime(now.year, now.month, now.day + 1),
                          lastDate: now.add(const Duration(days: 730)),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedStart = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              8,
                              0,
                            );
                            if (registrationDeadline != null &&
                                !registrationDeadline!.isBefore(
                                  selectedStart,
                                )) {
                              registrationDeadline = selectedStart.subtract(
                                const Duration(days: 1),
                              );
                            }
                          });
                        }
                      },
                      child: const Text('Change'),
                    ),
                  ],
                ),
                if (validationError != null) ...[
                  Text(
                    validationError!,
                    style: TextStyle(
                      color: Theme.of(dialogContext).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                TextField(
                  controller: capacity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Total capacity',
                  ),
                ),
                TextField(
                  controller: minCapacity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Minimum passengers',
                  ),
                ),
                TextField(
                  controller: adultPrice,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Adult price (whole VND)',
                  ),
                ),
                TextField(
                  controller: childPrice,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Child price (optional)',
                  ),
                ),
                TextField(
                  controller: infantPrice,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Infant price (optional)',
                  ),
                ),
                TextField(
                  controller: meetingPoint,
                  decoration: const InputDecoration(labelText: 'Meeting point'),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: meetingLat,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Latitude (optional)',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextField(
                        controller: meetingLng,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Longitude (optional)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        registrationDeadline == null
                            ? 'No registration deadline'
                            : 'Register by ${formatCalendarDate(registrationDeadline!)}',
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: selectedStart.subtract(
                            const Duration(days: 1),
                          ),
                          firstDate: now,
                          lastDate: selectedStart.subtract(
                            const Duration(days: 1),
                          ),
                        );
                        if (picked != null) {
                          setDialogState(() => registrationDeadline = picked);
                        }
                      },
                      child: const Text('Set'),
                    ),
                    if (registrationDeadline != null)
                      TextButton(
                        onPressed: () =>
                            setDialogState(() => registrationDeadline = null),
                        child: const Text('Clear'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final cap = int.tryParse(capacity.text.trim());
                final minCap = int.tryParse(minCapacity.text.trim()) ?? 1;
                final adult = num.tryParse(adultPrice.text.trim());
                final child = childPrice.text.trim().isEmpty
                    ? null
                    : num.tryParse(childPrice.text.trim());
                final infant = infantPrice.text.trim().isEmpty
                    ? null
                    : num.tryParse(infantPrice.text.trim());
                final latText = meetingLat.text.trim();
                final lngText = meetingLng.text.trim();
                final hasAnyCoord = latText.isNotEmpty || lngText.isNotEmpty;
                final lat = latText.isEmpty ? null : double.tryParse(latText);
                final lng = lngText.isEmpty ? null : double.tryParse(lngText);

                if (cap == null || cap <= 0 || minCap <= 0 || minCap > cap) {
                  setDialogState(
                    () => validationError =
                        'Minimum capacity must be at least 1 and no more than total capacity.',
                  );
                  return;
                }
                if (adult == null ||
                    adult <= 0 ||
                    adult != adult.truncate() ||
                    (child != null &&
                        (child < 0 || child != child.truncate())) ||
                    (infant != null &&
                        (infant < 0 || infant != infant.truncate()))) {
                  setDialogState(
                    () => validationError =
                        'Prices must be valid whole VND amounts.',
                  );
                  return;
                }
                if (hasAnyCoord) {
                  if (meetingPoint.text.trim().isEmpty ||
                      lat == null ||
                      lng == null ||
                      lat < -90 ||
                      lat > 90 ||
                      lng < -180 ||
                      lng > 180) {
                    setDialogState(
                      () => validationError =
                          'Meeting coordinates require a meeting point and valid latitude (-90..90) and longitude (-180..180).',
                    );
                    return;
                  }
                }
                if (registrationDeadline != null &&
                    !registrationDeadline!.isBefore(selectedStart)) {
                  setDialogState(
                    () => validationError =
                        'Registration deadline must be before the departure date.',
                  );
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  TourScheduleDraft(
                    startAtUtc: selectedStart.toUtc(),
                    endAtUtc: end.toUtc(),
                    totalCapacity: cap,
                    minimumCapacity: minCap,
                    registrationDeadlineAtUtc: registrationDeadline?.toUtc(),
                    adultPrice: adult,
                    childPrice: child,
                    infantPrice: infant,
                    meetingPoint: meetingPoint.text,
                    meetingLatitude: lat,
                    meetingLongitude: lng,
                  ),
                );
              },
              child: const Text('Publish departure'),
            ),
          ],
        );
      },
    ),
  );

  capacity.dispose();
  minCapacity.dispose();
  adultPrice.dispose();
  childPrice.dispose();
  infantPrice.dispose();
  meetingPoint.dispose();
  meetingLat.dispose();
  meetingLng.dispose();
  return result;
}
