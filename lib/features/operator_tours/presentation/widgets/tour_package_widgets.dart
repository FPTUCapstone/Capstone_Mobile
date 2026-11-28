import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_detail.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/cubit/create_tour_package_state.dart';

const maxTourDestinations = 10;

const _blockerMessages = {
  'required_fields_missing': 'Hoàn thiện toàn bộ thông tin tour bắt buộc.',
  'itinerary_missing': 'Thêm hoạt động lịch trình cho từng ngày của tour.',
  'primary_image_missing': 'Thêm ảnh bìa (ảnh chính đang hoạt động).',
  'future_departure_missing':
      'Thêm ít nhất một lịch khởi hành sắp tới kèm giá người lớn.',
  'cancellation_policy_missing': 'Chọn chính sách hủy tour.',
  'destination_missing': 'Chọn ít nhất một điểm đến.',
};

const _warningMessages = {
  'duplicate_poi': 'Địa điểm này đã xuất hiện trước đó trong lịch trình.',
  'poi_closed_on_day':
      'Địa điểm này đóng cửa vào ngày tương ứng của chuyến đi.',
  'outside_opening_hours':
      'Thời gian tham quan dự kiến nằm ngoài giờ mở cửa của địa điểm này.',
  'opening_hours_unknown':
      'Chưa có thông tin giờ mở cửa của ngày này nên chưa thể kiểm tra lịch tham quan.',
};

String tourBlockerMessage(String code) =>
    _blockerMessages[code] ??
    'Vui lòng kiểm tra lại các yêu cầu của gói tour trước khi gửi duyệt.';

String tourWarningMessage(String code) =>
    _warningMessages[code] ?? 'Vui lòng xem lại hoạt động lịch trình này.';

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
    this.selectedCategoryId,
    this.onCategoryChanged,
    super.key,
  });
  final CreateTourPackageState state;
  final bool enabled;
  final List<int> selectedDestinationIds;
  final int? selectedPolicyId;
  final ValueChanged<int> onToggleDestination;
  final ValueChanged<int?> onPolicyChanged;
  final VoidCallback onRetry;
  final int? selectedCategoryId;
  final ValueChanged<int?>? onCategoryChanged;

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
                  'Không thể tải danh sách điểm đến và chính sách hủy.',
            ),
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        );
      case TourPackageOptionsStatus.ready:
        final options = state.options!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Điểm đến', style: Theme.of(context).textTheme.titleSmall),
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
              decoration: const InputDecoration(labelText: 'Chính sách hủy'),
              items: [
                for (final policy in options.policies)
                  DropdownMenuItem(
                    value: policy.id,
                    child: Text(policy.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: enabled ? onPolicyChanged : null,
            ),
            if (options.categories.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<int?>(
                initialValue:
                    options.categories.any((c) => c.id == selectedCategoryId)
                    ? selectedCategoryId
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Danh mục (tùy chọn)',
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Không chọn danh mục'),
                  ),
                  for (final category in options.categories)
                    DropdownMenuItem<int?>(
                      value: category.id,
                      child: Text(
                        category.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: enabled ? onCategoryChanged : null,
              ),
            ],
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
        'Hỗ trợ ảnh JPG hoặc PNG tối đa 5 MB. Cần có ảnh bìa trước khi gửi gói tour phê duyệt.',
      ),
      const SizedBox(height: AppSpacing.sm),
      if (media.isEmpty) const Text('Chưa có hình ảnh nào.'),
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
          title: Text(item.isPrimary ? 'Ảnh bìa' : 'Hình ảnh'),
          subtitle: item.altText == null ? null : Text(item.altText!),
          trailing: readOnly
              ? null
              : Wrap(
                  children: [
                    if (!item.isPrimary)
                      IconButton(
                        icon: const Icon(Icons.star_outline),
                        tooltip: 'Đặt làm ảnh bìa',
                        onPressed: busy ? null : () => onSetPrimary(item.id),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Xóa ảnh',
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
            label: Text(busy ? 'Đang xử lý...' : 'Thêm ảnh'),
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
    this.travellerRequirements = '',
    this.policyName,
    this.allowDeposit = false,
    this.depositPercent,
    this.balanceDueDaysBeforeDeparture,
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
  final String travellerRequirements;
  final String? policyName;
  final bool allowDeposit;
  final num? depositPercent;
  final int? balanceDueDaysBeforeDeparture;
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
                    if (durationDays != null) '$durationDays ngày',
                    if (basePrice != null) 'từ $basePrice VND',
                  ].join(' · '),
                ),
                if (coverUrl == null)
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.xs),
                    child: Text('Chưa có ảnh bìa.'),
                  ),
                section('Điểm nổi bật', highlights),
                for (final entry in days.entries)
                  section('Ngày ${entry.key}', entry.value.join(' → ')),
                section('Bao gồm', inclusions),
                section('Không bao gồm', exclusions),
                section('Yêu cầu đối với du khách', travellerRequirements),
                if (policyName != null) section('Chính sách hủy', policyName!),
                section(
                  'Thanh toán & đặt cọc',
                  allowDeposit &&
                          depositPercent != null &&
                          balanceDueDaysBeforeDeparture != null
                      ? 'Đặt cọc $depositPercent% khi đặt tour · Thanh toán phần còn lại trước ngày khởi hành $balanceDueDaysBeforeDeparture ngày'
                      : 'Thanh toán trước 100% khi đặt tour',
                ),
                section('Lịch khởi hành', departures.join('\n')),
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
      return const Text('Đã sẵn sàng gửi phê duyệt.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (blockers.isNotEmpty) ...[
          Text(
            'Cần hoàn thiện trước khi gửi duyệt:',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final code in blockers) Text('• ${tourBlockerMessage(code)}'),
        ],
        if (warnings.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Cảnh báo lịch trình (không chặn lưu bản nháp):',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final warning in warnings)
            Text(
              '• ${[if (warning.dayNo != null) 'Ngày ${warning.dayNo}', if (warning.poiId != null) poiNames[warning.poiId] ?? 'Địa điểm #${warning.poiId}'].join(', ')}: ${tourWarningMessage(warning.code)}',
            ),
        ],
      ],
    );
  }
}
