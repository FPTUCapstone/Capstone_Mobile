import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_detail.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_detail_cubit.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_detail_state.dart';
import 'package:trip_mate_mobile/features/poi/presentation/theme/poi_palette.dart';
import 'package:trip_mate_mobile/features/poi/presentation/widgets/poi_image.dart';
import 'package:trip_mate_mobile/features/poi/presentation/widgets/poi_status_and_rating.dart';

class PoiDetailPage extends StatelessWidget {
  const PoiDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PoiDetailCubit, PoiDetailState>(
      builder: (context, state) {
        return switch (state.status) {
          PoiDetailStatus.initial || PoiDetailStatus.loading => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          PoiDetailStatus.invalid => _DetailMessagePage(
            icon: Icons.link_off,
            title: 'Liên kết không hợp lệ',
            message: 'Mã địa điểm trong liên kết không đúng định dạng.',
            onBack: () => _backToExplore(context),
          ),
          PoiDetailStatus.notFound => _DetailMessagePage(
            icon: Icons.location_off_outlined,
            title: 'Không tìm thấy địa điểm',
            message: 'Địa điểm không tồn tại hoặc đã đóng.',
            onBack: () => _backToExplore(context),
          ),
          PoiDetailStatus.failure => _DetailMessagePage(
            icon: Icons.cloud_off_outlined,
            title: 'Chưa thể tải chi tiết',
            message: state.failure?.message ?? 'Vui lòng thử lại.',
            onBack: () => _backToExplore(context),
            onRetry: context.read<PoiDetailCubit>().retry,
          ),
          PoiDetailStatus.success => _PoiDetailContent(detail: state.detail!),
        };
      },
    );
  }

  static void _backToExplore(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.explore);
    }
  }
}

class _PoiDetailContent extends StatelessWidget {
  const _PoiDetailContent({required this.detail});

  final PoiDetail detail;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PoiPalette.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 310,
            backgroundColor: PoiPalette.navy,
            foregroundColor: Colors.white,
            leading: IconButton(
              onPressed: () => PoiDetailPage._backToExplore(context),
              tooltip: 'Quay lại',
              icon: const Icon(Icons.arrow_back),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _PhotoGallery(
                photos: detail.photos,
                fallbackUrl: detail.photos.firstOrNull?.url,
                poiName: detail.name,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Tag(label: detail.categoryName, emphasized: true),
                          _Tag(
                            label: _indoorOutdoorLabel(detail.indoorOutdoor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        detail.name,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: PoiPalette.navy,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          PoiRating(
                            rating: detail.averageRating,
                            reviewCount: detail.reviewCount,
                          ),
                          PoiOpenStatus(isOpen: detail.isOpenNow),
                        ],
                      ),
                      if (detail.address case final address?) ...[
                        const SizedBox(height: 16),
                        _IconText(icon: Icons.place_outlined, text: address),
                      ],
                      const SizedBox(height: 20),
                      _SectionCard(
                        title: 'Đặc tính tham quan',
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _Attribute(
                              icon: Icons.schedule,
                              label: 'Thời lượng',
                              value:
                                  '${detail.averageVisitDurationMinutes} phút',
                            ),
                            _Attribute(
                              icon: detail.hasShelter
                                  ? Icons.umbrella_outlined
                                  : Icons.wb_sunny_outlined,
                              label: 'Mái che',
                              value: detail.hasShelter ? 'Có' : 'Không',
                            ),
                            if (detail.scenicScore case final score?)
                              _Attribute(
                                icon: Icons.landscape_outlined,
                                label: 'Cảnh quan',
                                value: score.toStringAsFixed(1),
                              ),
                            if (detail.photoRating case final rating?)
                              _Attribute(
                                icon: Icons.photo_camera_outlined,
                                label: 'Chụp ảnh',
                                value: rating.toStringAsFixed(1),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Giới thiệu',
                        child: Text(
                          detail.description,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(height: 1.55),
                        ),
                      ),
                      if (detail.tags.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Điểm nổi bật',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final tag in detail.tags)
                                _Tag(label: tag.name),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Giờ mở cửa',
                        child: _OpeningHoursTable(hours: detail.openingHours),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _indoorOutdoorLabel(String value) => switch (value.toLowerCase()) {
    'indoor' => 'Trong nhà',
    'outdoor' => 'Ngoài trời',
    _ => 'Trong & ngoài trời',
  };
}

class _PhotoGallery extends StatefulWidget {
  const _PhotoGallery({
    required this.photos,
    required this.fallbackUrl,
    required this.poiName,
  });

  final List<PoiPhoto> photos;
  final String? fallbackUrl;
  final String poiName;

  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<_PhotoGallery> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (photos.isEmpty)
          PoiImage(
            url: widget.fallbackUrl,
            semanticLabel: 'Ảnh ${widget.poiName}',
          )
        else
          PageView.builder(
            itemCount: photos.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (_, index) => PoiImage(
              url: photos[index].url,
              semanticLabel: photos[index].caption ?? 'Ảnh ${widget.poiName}',
            ),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black45, Colors.transparent, Colors.black26],
            ),
          ),
        ),
        if (photos.isNotEmpty)
          Positioned(
            right: 16,
            bottom: 18,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text(
                  '${_index + 1} / ${photos.length} ảnh',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PoiPalette.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: PoiPalette.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Attribute extends StatelessWidget {
  const _Attribute({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 180),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: PoiPalette.background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: PoiPalette.teal),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: PoiPalette.muted),
                    ),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpeningHoursTable extends StatelessWidget {
  const _OpeningHoursTable({required this.hours});

  final List<PoiOpeningHour> hours;

  static const _days = [
    'Chủ nhật',
    'Thứ hai',
    'Thứ ba',
    'Thứ tư',
    'Thứ năm',
    'Thứ sáu',
    'Thứ bảy',
  ];

  @override
  Widget build(BuildContext context) {
    final byDay = {for (final hour in hours) hour.dayOfWeek: hour};
    final vietnamNow = DateTime.now().toUtc().add(const Duration(hours: 7));
    final today = vietnamNow.weekday % 7;
    return Column(
      children: [
        for (var day = 0; day < 7; day++) ...[
          _HoursRow(day: day, hour: byDay[day], isToday: day == today),
          if (day < 6) const Divider(height: 1),
        ],
      ],
    );
  }
}

class _HoursRow extends StatelessWidget {
  const _HoursRow({
    required this.day,
    required this.hour,
    required this.isToday,
  });

  final int day;
  final PoiOpeningHour? hour;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final openTime = hour?.openTime;
    final closeTime = hour?.closeTime;
    final hoursLabel =
        hour?.isClosed == false && openTime != null && closeTime != null
        ? '${_time(openTime)} – ${_time(closeTime)}'
        : null;
    final closed = hoursLabel == null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isToday ? PoiPalette.tealSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _OpeningHoursTable._days[day],
                style: TextStyle(
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            Text(
              hoursLabel ?? 'Đóng cửa',
              style: TextStyle(
                color: closed ? PoiPalette.muted : PoiPalette.teal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _time(String value) =>
      value.length >= 5 ? value.substring(0, 5) : value;
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.emphasized = false});
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: emphasized ? PoiPalette.tealSoft : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PoiPalette.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            color: emphasized ? PoiPalette.teal : PoiPalette.navy,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _IconText extends StatelessWidget {
  const _IconText({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: PoiPalette.teal),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _DetailMessagePage extends StatelessWidget {
  const _DetailMessagePage({
    required this.icon,
    required this.title,
    required this.message,
    required this.onBack,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onBack;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: onBack,
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 64, color: PoiPalette.teal),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                if (onRetry != null) ...[
                  FilledButton(
                    onPressed: onRetry,
                    child: const Text('Thử lại'),
                  ),
                  const SizedBox(height: 8),
                ],
                TextButton(onPressed: onBack, child: const Text('Về Khám phá')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
