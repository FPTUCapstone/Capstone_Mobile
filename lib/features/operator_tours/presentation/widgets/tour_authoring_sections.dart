import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/utils/calendar_date_format.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_detail.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_draft.dart';

const tourPackingQuickTags = [
  'Giày thể thao',
  'Đồ bơi & khăn tắm',
  'Áo mưa / ô dù',
  'Áo khoác gió',
  'Thuốc cá nhân / chống say xe',
  'CCCD / Hộ chiếu',
];

const _depositPercentPresets = [
  (value: 30, label: '30% · Nội địa'),
  (value: 50, label: '50% · Lễ Tết / Bay'),
  (value: 70, label: '70% · Quốc tế'),
];

const _balanceDueDayPresets = [
  (value: 5, label: '5 ngày'),
  (value: 7, label: '7 ngày'),
  (value: 14, label: '14 ngày'),
  (value: 30, label: '30 ngày'),
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
          'Gợi ý chuẩn bị hành lý nhanh:',
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
            'Cài đặt thanh toán & đặt cọc',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Cho phép du khách thanh toán trước 100% hoặc đặt cọc (10%–90%) và thanh toán phần còn lại trước ngày khởi hành.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: false,
                label: Text('Trả trước 100%'),
                icon: Icon(Icons.payments_outlined),
              ),
              ButtonSegment<bool>(
                value: true,
                label: Text('Cho phép đặt cọc'),
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
            Text('Tỷ lệ đặt cọc (%)', style: theme.textTheme.labelMedium),
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
              decoration: const InputDecoration(
                labelText: 'Tỷ lệ đặt cọc % (10–90)',
              ),
              validator: (value) {
                if (!allowDeposit) return null;
                final parsed = num.tryParse((value ?? '').trim());
                if (parsed == null || parsed < 10 || parsed > 90) {
                  return 'Tỷ lệ đặt cọc phải từ 10% đến 90%.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Hạn thanh toán phần còn lại trước khởi hành (ngày)',
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
                labelText: 'Số ngày trước khởi hành (4–180)',
                helperText:
                    'Tối thiểu 4 ngày trước khởi hành, trước mốc khóa 72 giờ.',
              ),
              validator: (value) {
                if (!allowDeposit) return null;
                final parsed = int.tryParse((value ?? '').trim());
                if (parsed == null || parsed < 4 || parsed > 180) {
                  return 'Hạn thanh toán phần còn lại phải từ 4 đến 180 ngày trước khởi hành.';
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
                    ? 'Đặt cọc $currentPercent% (${_formatVnd(sampleDeposit)}/khách) khi đặt tour; phần còn lại ${100 - currentPercent}% (${_formatVnd(sampleRemaining)}/khách) thanh toán trước ngày khởi hành $currentDays ngày. Đơn đặt trong vòng $currentDays ngày trước khởi hành phải thanh toán trước 100%.'
                    : 'Đặt cọc $currentPercent% khi đặt tour; phần còn lại ${100 - currentPercent}% thanh toán trước ngày khởi hành $currentDays ngày. Đơn đặt trong vòng $currentDays ngày trước khởi hành phải thanh toán trước 100%.',
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
            'Lịch sử phiên bản',
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
                                  ? 'Đang mở'
                                  : (timestamp != null
                                        ? formatVietnamTimestamp(timestamp)
                                        : 'Phiên bản trước'),
                              style: theme.textTheme.bodySmall,
                            ),
                            if (!isCurrent &&
                                item.status == TourPackageStatus.rejected &&
                                item.rejectionReason != null)
                              Text(
                                'Lý do: ${item.rejectionReason}',
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
                        const Chip(
                          label: Text('Hiện tại'),
                          visualDensity: VisualDensity.compact,
                        )
                      else
                        TextButton(
                          onPressed: () => onOpenVersion(item.tourId),
                          child: Text(
                            item.status.isEditable ? 'Chỉnh sửa' : 'Xem',
                          ),
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
          title: const Text('Mở lịch khởi hành mới'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thêm một lịch khởi hành có thể đặt chỗ mà không cần tạo phiên bản tour mới hay ảnh hưởng các đơn đặt hiện tại.',
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ngày khởi hành: ${formatCalendarDate(selectedStart)}',
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
                      child: const Text('Thay đổi'),
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
                  decoration: const InputDecoration(labelText: 'Tổng số chỗ'),
                ),
                TextField(
                  controller: minCapacity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Số khách tối thiểu',
                  ),
                ),
                TextField(
                  controller: adultPrice,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Giá người lớn (VND nguyên)',
                  ),
                ),
                TextField(
                  controller: childPrice,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Giá trẻ em (tùy chọn)',
                  ),
                ),
                TextField(
                  controller: infantPrice,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Giá em bé (tùy chọn)',
                  ),
                ),
                TextField(
                  controller: meetingPoint,
                  decoration: const InputDecoration(labelText: 'Điểm đón'),
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
                          labelText: 'Vĩ độ (tùy chọn)',
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
                          labelText: 'Kinh độ (tùy chọn)',
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
                            ? 'Không có hạn đăng ký'
                            : 'Hạn đăng ký: ${formatCalendarDate(registrationDeadline!)}',
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
                      child: const Text('Đặt'),
                    ),
                    if (registrationDeadline != null)
                      TextButton(
                        onPressed: () =>
                            setDialogState(() => registrationDeadline = null),
                        child: const Text('Xóa'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
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
                        'Số khách tối thiểu phải từ 1 trở lên và không vượt quá tổng số chỗ.',
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
                        'Giá phải là số tiền VND nguyên hợp lệ.',
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
                          'Tọa độ điểm đón yêu cầu có tên điểm đón cùng vĩ độ (-90..90) và kinh độ (-180..180) hợp lệ.',
                    );
                    return;
                  }
                }
                if (registrationDeadline != null &&
                    !registrationDeadline!.isBefore(selectedStart)) {
                  setDialogState(
                    () => validationError =
                        'Hạn đăng ký phải trước ngày khởi hành.',
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
              child: const Text('Mở bán lịch khởi hành'),
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
