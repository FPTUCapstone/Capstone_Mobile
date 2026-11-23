import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/network/network_info.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/offline_trip_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/live_offline_package_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/resources/offline_ui_text.dart';

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
    final repo = repository ?? locateOptional<OfflineTripRepository>();
    if (repo == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lịch trình offline')),
        body: const Center(child: Text(OfflineUiText.loadError)),
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
          final manifest = state.manifest;
          return Scaffold(
            appBar: AppBar(title: const Text('Lịch trình offline')),
            body: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : manifest?.locked == true
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(OfflineUiText.locked),
                    ),
                  )
                : manifest != null && !manifest.mapResourcesAvailable
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        state.error ??
                            'Gói bản đồ không còn đầy đủ. Hãy tải lại để dùng offline.',
                      ),
                    ),
                  )
                : manifest == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(state.error ?? OfflineUiText.missing),
                          TextButton(
                            onPressed: context
                                .read<LiveOfflinePackageCubit>()
                                .load,
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        manifest.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        'Phiên bản ${manifest.version} · Đã tải ${OfflineUiText.date(manifest.downloadedAtUtc)}',
                      ),
                      if (manifest.superseded)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Bạn đang xem phiên bản đã tải. Có bản mới khi kết nối mạng.',
                          ),
                        ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () =>
                            context.push(AppRoutes.offlineMap(itineraryId)),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text(OfflineUiText.map),
                      ),
                      for (final item
                          in (manifest.snapshot.itinerary.items.toList()..sort(
                            (a, b) => a.sequenceNo.compareTo(b.sequenceNo),
                          )))
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.poiName ??
                                      (item.itemKind == ItineraryItemKind.rest
                                          ? 'Nghỉ ngơi'
                                          : 'Điểm tham quan'),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                Text(
                                  '${OfflineUiText.date(item.plannedArrival)} – ${OfflineUiText.date(item.plannedDeparture)}',
                                ),
                                Text(
                                  'Thời gian lưu lại: ${item.stayDurationMinutes} phút',
                                ),
                                if (item.address case final address?)
                                  Text(address),
                                for (final poi in manifest.snapshot.pois.where(
                                  (poi) => poi.id == item.poiId,
                                ))
                                  ..._poiDetails(poi),
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

  static List<Widget> _poiDetails(PoiDetail poi) => [
    if (poi.description?.isNotEmpty ?? false)
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(poi.description!),
      ),
    if (poi.address != null) Text(poi.address!),
    if (poi.openingHours.isNotEmpty) ...[
      const SizedBox(height: 8),
      const Text('Giờ mở cửa đã lưu:'),
      for (final hours in poi.openingHours)
        Text(
          '${_weekday(hours.dayOfWeek)}: ${hours.isClosed ? 'Đóng cửa' : '${hours.openTime ?? '—'} – ${hours.closeTime ?? '—'}'}',
        ),
    ],
  ];
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
