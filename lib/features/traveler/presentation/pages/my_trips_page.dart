import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/app/theme/coastal_palette.dart';
import 'package:trip_mate_mobile/core/utils/trip_time_format.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_summary.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/my_trips_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/my_trips_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/helpers/itinerary_text.dart';
import 'package:trip_mate_mobile/shared/widgets/app_shimmer.dart';

enum _TripFilter { all, confirmed, draft, shared }

/// The Traveler's trips: every itinerary they planned or joined, leading to the
/// itinerary detail where navigation starts.
final class MyTripsPage extends StatefulWidget {
  const MyTripsPage({super.key});

  @override
  State<MyTripsPage> createState() => _MyTripsPageState();
}

class _MyTripsPageState extends State<MyTripsPage> {
  var _filter = _TripFilter.all;

  @override
  Widget build(BuildContext context) {
    final palette = CoastalPalette.of(context);
    return ColoredBox(
      color: palette.canvas,
      child: BlocBuilder<MyTripsCubit, MyTripsState>(
        builder: (context, state) {
          final cubit = context.read<MyTripsCubit>();
          return RefreshIndicator(
            color: palette.primary,
            onRefresh: cubit.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              children: [
                _HeaderActions(palette: palette, onReturned: cubit.load),
                const SizedBox(height: 12),
                _FilterStrip(
                  selected: _filter,
                  palette: palette,
                  onSelected: (next) => setState(() => _filter = next),
                ),
                const SizedBox(height: AppSpacing.md),
                ..._content(context, state, cubit, palette),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    MyTripsState state,
    MyTripsCubit cubit,
    CoastalPalette palette,
  ) {
    if (state.trips.isEmpty) {
      return switch (state.status) {
        // Nothing animates before the first load: the tab is built offstage.
        MyTripsStatus.initial => const [],
        MyTripsStatus.loading => [_LoadingSkeleton(palette: palette)],
        MyTripsStatus.failure => [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.message ??
                      'Không thể tải danh sách lịch trình lúc này.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: palette.ink),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: cubit.load,
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ],
        MyTripsStatus.ready => [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              children: [
                Icon(Icons.map_outlined, size: 32, color: palette.secondary),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Chưa có lịch trình nào. Tạo lịch trình đầu tiên để bắt đầu khám phá.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: palette.secondary),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: palette.onPrimary,
                  ),
                  onPressed: () async {
                    await context.push(AppRoutes.createItinerary);
                    if (context.mounted) await cubit.load();
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Lập lịch trình đầu tiên'),
                ),
              ],
            ),
          ),
        ],
      };
    }

    final filtered = state.trips
        .where((trip) => _matchesFilter(trip, _filter))
        .toList(growable: false);

    if (filtered.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            children: [
              Text(
                'Không có lịch trình nào trong mục này.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: palette.secondary),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: () => setState(() => _filter = _TripFilter.all),
                child: const Text('Xem tất cả'),
              ),
            ],
          ),
        ),
      ];
    }

    final confirmed = filtered
        .where((trip) => trip.status.toLowerCase() == 'active')
        .toList(growable: false);
    final drafts = filtered
        .where((trip) => trip.status.toLowerCase() != 'active')
        .toList(growable: false);

    Future<void> openTrip(ItinerarySummary trip) async {
      await context.push(AppRoutes.itineraryDetailPath(trip.itineraryId));
      if (context.mounted) await cubit.load();
    }

    return [
      if (state.status == MyTripsStatus.failure && state.message != null)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            state.message!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      if (confirmed.isNotEmpty) ...[
        _SectionLabel(
          dotColor: palette.primary,
          label: 'CHUYẾN SẮP TỚI · ĐÃ CHỐT (${confirmed.length})',
          palette: palette,
        ),
        const SizedBox(height: 8),
        for (final trip in confirmed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ConfirmedTripCard(
              trip: trip,
              palette: palette,
              onTap: () => openTrip(trip),
            ),
          ),
        if (drafts.isNotEmpty) const SizedBox(height: 6),
      ],
      if (drafts.isNotEmpty) ...[
        _SectionLabel(
          dotColor: palette.accent,
          label: 'BẢN NHÁP GẦN ĐÂY',
          palette: palette,
        ),
        const SizedBox(height: 8),
        for (final trip in drafts)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _DraftTripCard(
              trip: trip,
              palette: palette,
              onTap: () => openTrip(trip),
            ),
          ),
      ],
      if (state.hasMore)
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: state.isLoadingMore
                ? const CircularProgressIndicator()
                : OutlinedButton(
                    onPressed: cubit.loadMore,
                    child: const Text('Xem thêm lịch trình'),
                  ),
          ),
        ),
    ];
  }

  static bool _matchesFilter(ItinerarySummary trip, _TripFilter filter) =>
      switch (filter) {
        _TripFilter.all => true,
        _TripFilter.confirmed => trip.status.toLowerCase() == 'active',
        _TripFilter.draft => trip.status.toLowerCase() == 'draft',
        _TripFilter.shared => !trip.canManage,
      };
}

final class _HeaderActions extends StatelessWidget {
  const _HeaderActions({required this.palette, required this.onReturned});

  final CoastalPalette palette;
  final Future<void> Function() onReturned;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Lịch trình của tôi',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontFamily: AppTypography.displayFont,
                  fontWeight: FontWeight.w700,
                  color: palette.ink,
                ),
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: palette.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontFamily: AppTypography.uiFont,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () async {
                await context.push(AppRoutes.createItinerary);
                if (context.mounted) await onReturned();
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Lập lịch mới'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _CompactSecondaryButton(
                icon: Icons.group_add_outlined,
                label: 'Vào nhóm',
                palette: palette,
                onTap: () async {
                  await context.push(AppRoutes.joinTravelGroup);
                  if (context.mounted) await onReturned();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CompactSecondaryButton(
                icon: Icons.history_outlined,
                label: 'Lịch sử chuyến đi',
                palette: palette,
                onTap: () => context.push(AppRoutes.tripHistory),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

final class _CompactSecondaryButton extends StatelessWidget {
  const _CompactSecondaryButton({
    required this.icon,
    required this.label,
    required this.palette,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final CoastalPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(11),
        side: BorderSide(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: palette.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.uiFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: palette.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.selected,
    required this.palette,
    required this.onSelected,
  });

  final _TripFilter selected;
  final CoastalPalette palette;
  final ValueChanged<_TripFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    const items = [
      (_TripFilter.all, 'Tất cả'),
      (_TripFilter.confirmed, 'Đã chốt'),
      (_TripFilter.draft, 'Bản nháp'),
      (_TripFilter.shared, 'Được chia sẻ'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (filter, label) in items) ...[
            GestureDetector(
              onTap: () => onSelected(filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: filter == selected ? palette.primary : palette.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: filter == selected
                        ? palette.primary
                        : palette.border,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppTypography.uiFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: filter == selected ? palette.onPrimary : palette.ink,
                  ),
                ),
              ),
            ),
            if (filter != _TripFilter.shared) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

final class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.dotColor,
    required this.label,
    required this.palette,
  });

  final Color dotColor;
  final String label;
  final CoastalPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: AppTypography.uiFont,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: palette.ink,
          ),
        ),
      ],
    );
  }
}

final class _ConfirmedTripCard extends StatelessWidget {
  const _ConfirmedTripCard({
    required this.trip,
    required this.palette,
    required this.onTap,
  });

  final ItinerarySummary trip;
  final CoastalPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayTitle = formatTripDisplayTitle(
      title: trip.title,
      previewStopNames: trip.previewStopNames,
      validFrom: trip.validFrom,
    );
    final routePreview = formatRoutePreview(
      trip.previewStopNames,
      trip.stopCount,
    );
    final metaLine = _buildTripMeta(trip);

    return Material(
      key: ValueKey('trip_${trip.itineraryId}'),
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: palette.primary),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _StatusPill(
                            label: 'Đã chốt',
                            bg: palette.softAccent,
                            fg: palette.primary,
                          ),
                          if (trip.isTripInProgress) ...[
                            const SizedBox(width: 5),
                            _StatusPill(
                              label: 'Đang dẫn đường',
                              bg: palette.success.withValues(alpha: 0.14),
                              fg: palette.success,
                            ),
                          ],
                          if (!trip.canManage) ...[
                            const SizedBox(width: 5),
                            _StatusPill(
                              label: 'Được chia sẻ',
                              bg: palette.canvas,
                              fg: palette.secondary,
                            ),
                          ],
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '#${trip.itineraryId} · v${trip.version}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: palette.secondary,
                              ),
                            ),
                          ),
                          if (trip.validFrom case final from?) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: palette.canvas,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                vietnameseShortDate(from),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: palette.secondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: palette.ink,
                        ),
                      ),
                      if (routePreview != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          routePreview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: palette.secondary,
                          ),
                        ),
                      ],
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Divider(color: palette.border, height: 1),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              metaLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: palette.secondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Mở lịch →',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: palette.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _DraftTripCard extends StatelessWidget {
  const _DraftTripCard({
    required this.trip,
    required this.palette,
    required this.onTap,
  });

  final ItinerarySummary trip;
  final CoastalPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayTitle = formatTripDisplayTitle(
      title: trip.title,
      previewStopNames: trip.previewStopNames,
      validFrom: trip.validFrom,
    );
    final routePreview = formatRoutePreview(
      trip.previewStopNames,
      trip.stopCount,
    );
    final metaLine = _buildTripMeta(trip);
    final vnFrom = trip.validFrom != null
        ? tripLocalTime(trip.validFrom!)
        : null;

    return Material(
      key: ValueKey('trip_${trip.itineraryId}'),
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (vnFrom != null) ...[
                Container(
                  width: 48,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: palette.canvas,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    children: [
                      Text(
                        vietnameseWeekdayStub(trip.validFrom!),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: palette.secondary,
                        ),
                      ),
                      Text(
                        '${vnFrom.day}',
                        style: TextStyle(
                          fontFamily: AppTypography.displayFont,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: palette.ink,
                          height: 1.15,
                        ),
                      ),
                      Text(
                        'Th${vnFrom.month}',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: palette.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 11),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _StatusPill(
                          label: trip.status.toLowerCase() == 'draft'
                              ? 'Bản nháp'
                              : trip.status,
                          bg: palette.warningBg,
                          fg: palette.warningText,
                        ),
                        if (trip.isTripInProgress)
                          _StatusPill(
                            label: 'Đang dẫn đường',
                            bg: palette.success.withValues(alpha: 0.14),
                            fg: palette.success,
                          ),
                        if (!trip.canManage)
                          _StatusPill(
                            label: 'Được chia sẻ',
                            bg: palette.canvas,
                            fg: palette.secondary,
                          ),
                        Text(
                          '#${trip.itineraryId} · v${trip.version}',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: palette.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: palette.ink,
                      ),
                    ),
                    if (routePreview != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        routePreview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.secondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      metaLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: palette.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: palette.secondary),
            ],
          ),
        ),
      ),
    );
  }
}

final class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTypography.uiFont,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

final class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton({required this.palette});

  final CoastalPalette palette;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Column(
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.border),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 90, height: 14),
                  SizedBox(height: 8),
                  SkeletonBox(width: 220, height: 18),
                  SizedBox(height: 6),
                  SkeletonBox(width: 160, height: 12),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _buildTripMeta(ItinerarySummary trip) {
  final parts = <String>[];
  final from = trip.validFrom;
  final to = trip.validTo;
  if (from != null && to != null) {
    final durationMinutes = to.difference(from).inMinutes;
    final window = '${tripClock(from)} – ${tripClock(to)}';
    parts.add(
      durationMinutes > 0
          ? '$window (${vietnameseCompactDuration(durationMinutes)})'
          : window,
    );
  } else if (from != null) {
    parts.add(tripClock(from));
  }
  parts.add('${trip.stopCount} điểm');
  if (trip.transportMode case final mode?) {
    parts.add(transportLabel(mode));
  }
  return parts.join(' · ');
}
