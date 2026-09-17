import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_summary.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_list_cubit.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_list_state.dart';
import 'package:trip_mate_mobile/features/poi/presentation/theme/poi_palette.dart';
import 'package:trip_mate_mobile/features/poi/presentation/widgets/poi_image.dart';
import 'package:trip_mate_mobile/features/poi/presentation/widgets/poi_map_projection.dart';
import 'package:trip_mate_mobile/features/poi/presentation/widgets/poi_status_and_rating.dart';

class PoiMapPreview extends StatelessWidget {
  const PoiMapPreview({required this.state, required this.cubit, super.key});

  final PoiListState state;
  final PoiListCubit cubit;

  @override
  Widget build(BuildContext context) {
    if (state.items.isEmpty) {
      return _EmptyMap(onReset: cubit.resetFilters);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final markerArea = Size(
          constraints.maxWidth,
          constraints.maxHeight * (state.selectedPoi == null ? 0.84 : 0.58),
        );
        final points = PoiMapProjection.project(
          state.items,
          markerArea,
          padding: 48,
        );
        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned.fill(child: _MapBackdrop()),
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: PoiPalette.navy.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 10, color: Color(0xFF62E6D5)),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Bản đồ minh họa vị trí',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            for (final poi in state.items)
              if (points[poi.id] case final point?)
                Positioned(
                  left: point.dx - 24,
                  top: point.dy + 46,
                  child: _PoiMarker(
                    poi: poi,
                    selected: state.selectedPoiId == poi.id,
                    onTap: () => cubit.selectPoi(poi.id),
                  ),
                ),
            Positioned(
              right: 16,
              top: 72,
              child: Semantics(
                button: true,
                label: 'Dùng vị trí hiện tại',
                child: Material(
                  elevation: 3,
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: IconButton(
                    constraints: const BoxConstraints.tightFor(
                      width: 48,
                      height: 48,
                    ),
                    onPressed: state.isLocating ? null : cubit.requestLocation,
                    tooltip: 'Vị trí của tôi',
                    icon: state.isLocating
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.my_location_rounded,
                            color: PoiPalette.teal,
                          ),
                  ),
                ),
              ),
            ),
            if (state.selectedPoi case final poi?)
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: constraints.maxHeight * 0.65,
                    ),
                    child: SingleChildScrollView(
                      reverse: true,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (state.canLoadMore)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: FilledButton.icon(
                                onPressed: state.isLoadingMore
                                    ? null
                                    : cubit.loadNextPage,
                                icon: state.isLoadingMore
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.add),
                                label: Text(
                                  'Xem thêm ${state.totalCount - state.items.length} địa điểm',
                                ),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                  backgroundColor: Colors.white,
                                  foregroundColor: PoiPalette.teal,
                                ),
                              ),
                            ),
                          _MapPreviewCard(
                            poi: poi,
                            onDetails: () =>
                                context.push(AppRoutes.poiDetail(poi.id)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PoiMarker extends StatelessWidget {
  const _PoiMarker({
    required this.poi,
    required this.selected,
    required this.onTap,
  });

  final PoiSummary poi;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Chọn ${poi.name} trên bản đồ minh họa',
      child: IconButton.filled(
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        onPressed: onTap,
        tooltip: poi.name,
        style: IconButton.styleFrom(
          backgroundColor: selected ? PoiPalette.teal : PoiPalette.navy,
          side: BorderSide(
            color: selected ? const Color(0xFF62E6D5) : Colors.white,
            width: 3,
          ),
        ),
        icon: Icon(
          selected ? Icons.landscape : Icons.place,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _MapPreviewCard extends StatelessWidget {
  const _MapPreviewCard({required this.poi, required this.onDetails});

  final PoiSummary poi;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final imageSize = constraints.maxWidth < 300 ? 72.0 : 84.0;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox.square(
                    dimension: imageSize,
                    child: PoiImage(url: poi.thumbnailUrl),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ĐANG CHỌN',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: PoiPalette.teal,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        poi.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: PoiPalette.navy,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          PoiRating(
                            rating: poi.averageRating,
                            reviewCount: poi.reviewCount,
                          ),
                          if (poi.distanceKm != null)
                            Text(
                              '${poi.distanceKm!.toStringAsFixed(1).replaceAll('.', ',')} km',
                            ),
                          PoiOpenStatus(isOpen: poi.isOpenNow),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: onDetails,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 44),
                          ),
                          child: const Text('Xem chi tiết'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MapBackdrop extends StatelessWidget {
  const _MapBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BackdropPainter());
  }
}

class _BackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = PoiPalette.land);
    final water = Path()
      ..moveTo(size.width * 0.58, 0)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.45,
        size.width * 0.6,
        size.height,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(water, Paint()..color = PoiPalette.water);
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.86)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawPath(
      Path()
        ..moveTo(-20, size.height * 0.35)
        ..quadraticBezierTo(
          size.width * 0.42,
          size.height * 0.3,
          size.width * 0.72,
          size.height * 0.55,
        ),
      roadPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.12, size.height)
        ..quadraticBezierTo(
          size.width * 0.08,
          size.height * 0.62,
          size.width * 0.28,
          size.height * 0.5,
        ),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EmptyMap extends StatelessWidget {
  const _EmptyMap({required this.onReset});
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 56, color: PoiPalette.teal),
            const SizedBox(height: 12),
            const Text(
              'Không có địa điểm để hiển thị trên bản đồ.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onReset, child: const Text('Đặt lại')),
          ],
        ),
      ),
    );
  }
}
