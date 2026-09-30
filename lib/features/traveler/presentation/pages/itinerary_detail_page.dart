import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_detail_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_detail_state.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';
import 'package:trip_mate_mobile/shared/widgets/error_view.dart';

final class ItineraryDetailPage extends StatefulWidget {
  const ItineraryDetailPage({required this.itineraryId, super.key});

  final int itineraryId;

  @override
  State<ItineraryDetailPage> createState() => _ItineraryDetailPageState();
}

final class _ItineraryDetailPageState extends State<ItineraryDetailPage> {
  @override
  void initState() {
    super.initState();
    context.read<ItineraryDetailCubit>().load(widget.itineraryId);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ItineraryDetailCubit, ItineraryDetailState>(
      listener: (context, state) {
        if (state.status == ItineraryDetailStatus.failure &&
            state.message != null &&
            state.detail != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message!)));
        }
      },
      builder: (context, state) {
        if (state.status == ItineraryDetailStatus.loading &&
            state.detail == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state.detail == null) {
          return Scaffold(
            body: ErrorView(
              message: state.message ?? 'Your itinerary is unavailable.',
              onRetry: () =>
                  context.read<ItineraryDetailCubit>().load(widget.itineraryId),
            ),
          );
        }
        return _DetailContent(state: state);
      },
    );
  }
}

final class _DetailContent extends StatelessWidget {
  const _DetailContent({required this.state});

  final ItineraryDetailState state;

  @override
  Widget build(BuildContext context) {
    final detail = state.detail!;
    final cubit = context.read<ItineraryDetailCubit>();
    final isDraft = detail.status == 'Draft';
    return AppPageScaffold(
      title: detail.title ?? 'Your itinerary',
      actions: [
        if (detail.canManage)
          IconButton(
            tooltip: 'Regenerate itinerary',
            onPressed: state.isBusy ? null : cubit.regenerate,
            icon: const Icon(Icons.refresh),
          ),
      ],
      content: [
        Row(
          children: [
            Chip(label: Text('Version ${detail.version}')),
            const SizedBox(width: AppSpacing.xs),
            Chip(label: Text(detail.status)),
            const Spacer(),
            Flexible(
              child: Text(
                detail.canManage ? 'Owner' : 'Read-only access (Group member)',
                textAlign: TextAlign.end,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${_duration(detail.totalDurationMinutes)} · Estimated ${_formatVnd(detail.totalEstimatedCost)}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        ...detail.items.asMap().entries.expand((entry) {
          final item = entry.value;
          final travelMinutes = item.travelDurationFromPreviousMinutes;
          return [
            if (travelMinutes != null && entry.key > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text('Travel: $travelMinutes min'),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _DetailItemCard(item: item),
            ),
          ];
        }),
        if (detail.canManage && isDraft) ...[
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Accept itinerary',
            onPressed: state.isBusy ? null : cubit.accept,
          ),
        ],
        if (detail.canManage) ...[
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: state.isBusy ? null : () => _openEditor(context, detail),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Reorder or remove places'),
          ),
        ],
      ],
    );
  }

  Future<void> _openEditor(BuildContext context, ItineraryDetail detail) async {
    final ids = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditItemsSheet(items: detail.visitItems),
    );
    if (ids != null && context.mounted) {
      await context.read<ItineraryDetailCubit>().adjustItems(ids);
    }
  }
}

final class _DetailItemCard extends StatelessWidget {
  const _DetailItemCard({required this.item});

  final ItineraryDetailItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRest = item.itemKind == ItineraryItemKind.rest;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              child: Text(
                _formatTime(item.plannedArrival),
                style: theme.textTheme.labelLarge,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRest ? 'Suggested break' : (item.poiName ?? 'Visit'),
                    style: theme.textTheme.titleSmall,
                  ),
                  if (item.category != null) Text(item.category!),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    isRest
                        ? (item.poiName ??
                              item.recommendationReason ??
                              'Free/rest time')
                        : (item.recommendationReason ?? 'Suggested location'),
                    style: theme.textTheme.bodySmall,
                  ),
                  if (item.isMandatory) const Text('Must-see'),
                  if (item.isUnavailable)
                    Text(
                      'This place is currently unavailable.',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                ],
              ),
            ),
            Text('${item.stayDurationMinutes} min'),
          ],
        ),
      ),
    );
  }
}

final class _EditItemsSheet extends StatefulWidget {
  const _EditItemsSheet({required this.items});

  final List<ItineraryDetailItem> items;

  @override
  State<_EditItemsSheet> createState() => _EditItemsSheetState();
}

final class _EditItemsSheetState extends State<_EditItemsSheet> {
  late final List<ItineraryDetailItem> _items = [...widget.items];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Adjust places',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: ReorderableListView.builder(
                shrinkWrap: true,
                itemCount: _items.length,
                onReorder: (oldIndex, newIndex) => setState(() {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final item = _items.removeAt(oldIndex);
                  _items.insert(newIndex, item);
                }),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return ListTile(
                    key: ValueKey(item.itemId),
                    title: Text(item.poiName ?? 'Visit'),
                    subtitle: Text(item.isMandatory ? 'Must-see' : 'Suggested'),
                    trailing: item.isMandatory
                        ? const Icon(Icons.lock_outline)
                        : IconButton(
                            tooltip: 'Remove place',
                            onPressed: () =>
                                setState(() => _items.removeAt(index)),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Save adjustment',
              onPressed: _items.isEmpty
                  ? null
                  : () => Navigator.of(context).pop(
                      _items.map((item) => item.poiId!).toList(growable: false),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime value) {
  final vietnamTime = value.toUtc().add(const Duration(hours: 7));
  return '${vietnamTime.hour.toString().padLeft(2, '0')}:${vietnamTime.minute.toString().padLeft(2, '0')}';
}

String _duration(int minutes) {
  final hours = minutes ~/ 60;
  final remaining = minutes % 60;
  if (hours == 0) return '$remaining min';
  return remaining == 0 ? '$hours h' : '$hours h $remaining min';
}

String _formatVnd(double amount) => '₫${amount.round()}';
