import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/network/network_info.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/offline_trip_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/live_offline_package_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/resources/offline_ui_text.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_coastal_app_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/app_empty_state.dart';
import 'package:trip_mate_mobile/shared/widgets/error_view.dart';

class OfflineItineraryPage extends StatelessWidget {
  const OfflineItineraryPage({
    required this.itineraryId,
    this.repository,
    super.key,
  });
  final int itineraryId;
  final OfflineTripRepository? repository;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final repo = repository ?? locateOptional<OfflineTripRepository>();
    if (repo == null) {
      return Scaffold(
        backgroundColor: c.canvas,
        appBar: const AppCoastalAppBar(title: 'Lịch trình ngoại tuyến'),
        body: const AppEmptyState(
          icon: Icons.cloud_off_outlined,
          title: OfflineUiText.loadError,
        ),
      );
    }
    return BlocProvider(
      create: (_) => LiveOfflinePackageCubit(
        repo,
        itineraryId: itineraryId,
        networkInfo: locateOptional<NetworkInfo>(),
      )..load(),
      child: BlocBuilder<LiveOfflinePackageCubit, LiveOfflinePackageState>(
        builder: (context, state) {
          final c = context.tmColors;
          final manifest = state.manifest;
          return Scaffold(
            backgroundColor: c.canvas,
            appBar: const AppCoastalAppBar(title: 'Lịch trình ngoại tuyến'),
            body: state.isLoading
                ? Center(child: CircularProgressIndicator(color: c.brandTeal))
                : manifest?.locked == true
                ? const AppEmptyState(
                    icon: Icons.lock_outline,
                    title: OfflineUiText.locked,
                  )
                : manifest != null && !manifest.mapResourcesAvailable
                ? AppEmptyState(
                    icon: Icons.map_outlined,
                    title:
                        state.error ??
                        'Gói bản đồ không còn đầy đủ. Hãy tải lại để dùng ngoại tuyến.',
                  )
                : manifest == null
                ? ErrorView(
                    message: state.error ?? OfflineUiText.missing,
                    retryLabel: 'Thử lại',
                    onRetry: context.read<LiveOfflinePackageCubit>().load,
                  )
                : ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              manifest.title,
                              style: TextStyle(
                                fontFamily: AppTypography.displayFont,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Phiên bản ${manifest.version} · Đã tải ${OfflineUiText.date(manifest.downloadedAtUtc)}',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: c.textSecondary,
                              ),
                            ),
                            if (manifest.superseded) ...[
                              const SizedBox(height: AppSpacing.sm),
                              const AppAlert(
                                type: AppAlertType.warning,
                                message:
                                    'Bạn đang xem phiên bản đã tải. Có bản mới khi kết nối mạng.',
                              ),
                            ],
                            const SizedBox(height: AppSpacing.md),
                            OutlinedButton.icon(
                              onPressed: () => context.push(
                                AppRoutes.offlineMap(itineraryId),
                              ),
                              icon: const Icon(Icons.map_outlined),
                              label: const Text(OfflineUiText.map),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      for (final item
                          in (manifest.snapshot.itinerary.items.toList()..sort(
                            (a, b) => a.sequenceNo.compareTo(b.sequenceNo),
                          )))
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: AppCard(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color:
                                            item.itemKind ==
                                                ItineraryItemKind.rest
                                            ? c.coralSoftContainer
                                            : c.tealSoftContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        item.itemKind == ItineraryItemKind.rest
                                            ? Icons.coffee_outlined
                                            : Icons.place_outlined,
                                        size: 16,
                                        color:
                                            item.itemKind ==
                                                ItineraryItemKind.rest
                                            ? c.brandCoral
                                            : c.brandTeal,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.poiName ??
                                                (item.itemKind ==
                                                        ItineraryItemKind.rest
                                                    ? 'Nghỉ ngơi'
                                                    : 'Điểm tham quan'),
                                            style: TextStyle(
                                              fontFamily:
                                                  AppTypography.displayFont,
                                              fontSize: 15.5,
                                              fontWeight: FontWeight.w700,
                                              color: c.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${OfflineUiText.date(item.plannedArrival)} – ${OfflineUiText.date(item.plannedDeparture)}',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: c.brandTeal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Thời gian lưu lại: ${item.stayDurationMinutes} phút',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: c.textSecondary,
                                  ),
                                ),
                                if (item.address case final address?)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      address,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: c.textMuted,
                                      ),
                                    ),
                                  ),
                                for (final poi in manifest.snapshot.pois.where(
                                  (poi) => poi.id == item.poiId,
                                ))
                                  ..._poiDetails(context, poi),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  static List<Widget> _poiDetails(BuildContext context, PoiDetail poi) {
    final c = context.tmColors;
    return [
      if (poi.description?.isNotEmpty ?? false)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            poi.description!,
            style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.4),
          ),
        ),
      if (poi.address != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            poi.address!,
            style: TextStyle(fontSize: 12.5, color: c.textMuted),
          ),
        ),
      if (poi.openingHours.isNotEmpty) ...[
        Divider(height: 18, color: c.borderSubtle),
        Text(
          'Giờ mở cửa đã lưu:',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        for (final hours in poi.openingHours)
          Text(
            '${_weekday(hours.dayOfWeek)}: ${hours.isClosed ? 'Đóng cửa' : '${hours.openTime ?? '—'} – ${hours.closeTime ?? '—'}'}',
            style: TextStyle(fontSize: 12.5, color: c.textSecondary),
          ),
      ],
    ];
  }

  static String _weekday(int day) => switch (day) {
    0 => 'Chủ nhật',
    1 => 'Thứ hai',
    2 => 'Thứ ba',
    3 => 'Thứ tư',
    4 => 'Thứ năm',
    5 => 'Thứ sáu',
    6 => 'Thứ bảy',
    _ => 'Ngày $day',
  };
}
