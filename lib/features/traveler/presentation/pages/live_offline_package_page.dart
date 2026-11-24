import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/network/network_info.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/offline_trip_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/live_offline_package_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/offline_confirmation_dialog.dart';
import 'package:trip_mate_mobile/features/traveler/resources/offline_ui_text.dart';

class LiveOfflinePackagePage extends StatelessWidget {
  const LiveOfflinePackagePage({
    required this.itineraryId,
    required this.repository,
    this.title,
    super.key,
  });
  final int itineraryId;
  final OfflineTripRepository repository;
  final String? title;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => LiveOfflinePackageCubit(
      repository,
      itineraryId: itineraryId,
      networkInfo: locateOptional<NetworkInfo>(),
    )..load(),
    child: _LiveOfflinePackageView(title: title, itineraryId: itineraryId),
  );
}

class _LiveOfflinePackageView extends StatelessWidget {
  const _LiveOfflinePackageView({required this.itineraryId, this.title});
  final int itineraryId;
  final String? title;

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<LiveOfflinePackageCubit, LiveOfflinePackageState>(
    listenWhen: (previous, current) =>
        current.completionSequence > previous.completionSequence ||
        (current.isDownloading &&
            (current.progress?.phase == OfflineTransferPhase.itinerary ||
                current.progress?.phase == OfflineTransferPhase.maps) &&
            previous.progress?.phase == OfflineTransferPhase.preparing),
    listener: (context, state) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.isDownloading ? OfflineUiText.starting : OfflineUiText.success,
        ),
      ),
    ),
    builder: (context, state) {
      final cubit = context.read<LiveOfflinePackageCubit>();
      final manifest = state.manifest;
      final progress = state.progress;
      final busy = state.isDownloading || state.isLoading;
      final offlineReadOnly =
          context.watch<AuthSessionCubit?>()?.state.isOfflineReadOnly ?? false;
      final readable =
          manifest != null &&
          !manifest.locked &&
          manifest.mapResourcesAvailable;
      return PopScope(
        canPop: !state.isDownloading,
        onPopInvokedWithResult: (popped, _) async {
          if (popped ||
              !state.isDownloading ||
              state.isCancelling ||
              state.progress?.phase == OfflineTransferPhase.publishing) {
            return;
          }
          final confirmed = await confirmOfflineAction(
            context,
            title: 'Hủy tải và quay lại?',
            description: 'Dữ liệu hoàn tất trước đó vẫn được giữ trên máy.',
            action: OfflineUiText.cancel,
          );
          if (!confirmed || !context.mounted) return;
          await cubit.cancel();
          if (context.mounted && cubit.state.error == null) {
            Navigator.of(context).maybePop();
          }
        },
        child: Scaffold(
          appBar: AppBar(title: const Text(OfflineUiText.accessTitle)),
          body: state.isLoading && manifest == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        manifest?.title ?? title ?? 'Lịch trình #$itineraryId',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      const Text(OfflineUiText.sizeLimit),
                      if (offlineReadOnly)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Đăng nhập lại để tải hoặc cập nhật. Các gói đã tải vẫn có thể đọc offline.',
                          ),
                        ),
                      if (manifest != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Phiên bản ${manifest.version} · ${OfflineUiText.bytes(manifest.totalBytes)}',
                        ),
                        Text(
                          'Đã tải: ${OfflineUiText.date(manifest.downloadedAtUtc)}',
                        ),
                        if (manifest.snapshot.itinerary.validFrom
                            case final from?)
                          Text('Từ ${OfflineUiText.date(from)}'),
                        if (manifest.snapshot.itinerary.validTo case final to?)
                          Text('Đến ${OfflineUiText.date(to)}'),
                        const SizedBox(height: 12),
                        if (manifest.locked)
                          const Text(OfflineUiText.locked)
                        else if (!manifest.mapResourcesAvailable)
                          const Text(
                            'Dữ liệu bản đồ bị thiếu hoặc hỏng. Hãy tải lại gói trước khi mở offline.',
                          )
                        else
                          Text(
                            manifest.superseded
                                ? OfflineUiText.superseded
                                : OfflineUiText.ready,
                          ),
                      ],
                      const SizedBox(height: 16),
                      if (state.error != null)
                        Card(
                          color: Theme.of(context).colorScheme.errorContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(state.error!),
                          ),
                        ),
                      if (state.isDownloading) ...[
                        Text(_phase(progress?.phase)),
                        const SizedBox(height: 8),
                        _component(
                          context,
                          'Lịch trình',
                          progress?.phase != null &&
                              progress!.phase != OfflineTransferPhase.preparing,
                        ),
                        _component(
                          context,
                          'Thông tin điểm đến',
                          progress?.phase != null &&
                              progress!.phase != OfflineTransferPhase.preparing,
                        ),
                        _component(
                          context,
                          'Bản đồ và tuyến đường',
                          progress?.phase == OfflineTransferPhase.verifying ||
                              progress?.phase ==
                                  OfflineTransferPhase.publishing,
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress?.fraction.clamp(0.0, 1.0).toDouble(),
                          semanticsLabel: 'Tiến độ tải dữ liệu offline',
                        ),
                        const SizedBox(height: 8),
                        if (progress?.estimatedBytes case final size?)
                          Text('Ước tính: ${OfflineUiText.bytes(size)}')
                        else
                          const Text(OfflineUiText.estimateUnknown),
                        if (progress != null && progress.completedBytes > 0)
                          Text(
                            'Đã tải: ${OfflineUiText.bytes(progress.completedBytes)}',
                          ),
                        if (manifest != null)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(OfflineUiText.updateHint),
                          ),
                        OutlinedButton.icon(
                          onPressed:
                              state.isCancelling ||
                                  progress?.phase ==
                                      OfflineTransferPhase.publishing
                              ? null
                              : () async {
                                  if (await confirmOfflineAction(
                                        context,
                                        title: 'Hủy tải dữ liệu?',
                                        description:
                                            'Gói đang tải sẽ bị hủy. Bản đã tải hoàn tất trước đó vẫn được giữ.',
                                        action: OfflineUiText.cancel,
                                      ) &&
                                      context.mounted) {
                                    await cubit.cancel();
                                  }
                                },
                          icon: const Icon(Icons.close),
                          label: Text(
                            state.isCancelling
                                ? 'Đang hủy…'
                                : OfflineUiText.cancel,
                          ),
                        ),
                      ] else if (manifest?.locked != true) ...[
                        if (manifest == null)
                          const Text(OfflineUiText.estimateUnknown),
                        if (manifest != null)
                          const Text(OfflineUiText.updateHint),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: busy || offlineReadOnly
                              ? null
                              : () async {
                                  if (!await confirmOfflineAction(
                                    context,
                                    title: manifest == null
                                        ? 'Tải lịch trình để dùng offline?'
                                        : 'Tải lại phiên bản mới nhất?',
                                    description: manifest == null
                                        ? 'Lưu lịch trình, điểm đến, tuyến đường và bản đồ trên điện thoại. Giới hạn mỗi gói là 150 MB.'
                                        : OfflineUiText.updateHint,
                                    action: manifest == null
                                        ? 'Tải xuống'
                                        : OfflineUiText.update,
                                  )) {
                                    return;
                                  }
                                  if (context.mounted) await cubit.download();
                                },
                          icon: const Icon(Icons.download_outlined),
                          label: Text(
                            manifest == null
                                ? OfflineUiText.download
                                : OfflineUiText.update,
                          ),
                        ),
                        if (manifest != null)
                          TextButton(
                            onPressed: busy || offlineReadOnly
                                ? null
                                : cubit.checkForUpdate,
                            child: const Text('Kiểm tra phiên bản mới'),
                          ),
                      ],
                      if (readable) ...[
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: () => context.push(
                            AppRoutes.offlineItinerary(itineraryId),
                          ),
                          icon: const Icon(Icons.list_alt),
                          label: const Text(OfflineUiText.open),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              context.push(AppRoutes.offlineMap(itineraryId)),
                          icon: const Icon(Icons.map_outlined),
                          label: const Text(OfflineUiText.map),
                        ),
                      ],
                      if (manifest != null && !state.isDownloading) ...[
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : () async {
                                  if (await confirmOfflineAction(
                                        context,
                                        title: 'Xóa gói đã tải?',
                                        description:
                                            'Gói sẽ không còn dùng được khi mất mạng. Bạn có thể tải lại khi có kết nối.',
                                        action: 'Xóa',
                                      ) &&
                                      context.mounted) {
                                    await cubit.remove();
                                  }
                                },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text(OfflineUiText.remove),
                        ),
                      ],
                      if (state.error != null && !busy)
                        TextButton(
                          onPressed: cubit.load,
                          child: const Text('Thử lại'),
                        ),
                    ],
                  ),
                ),
        ),
      );
    },
  );

  static String _phase(OfflineTransferPhase? phase) => switch (phase) {
    OfflineTransferPhase.preparing ||
    null => 'Đang kiểm tra dung lượng và quyền truy cập…',
    OfflineTransferPhase.itinerary =>
      'Đang lưu lịch trình và thông tin điểm đến…',
    OfflineTransferPhase.maps => 'Đang tải bản đồ và tuyến đường…',
    OfflineTransferPhase.verifying => 'Đang xác minh dữ liệu đã tải…',
    OfflineTransferPhase.publishing => 'Đang lưu gói dữ liệu…',
  };

  static Widget _component(BuildContext context, String label, bool complete) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              complete ? Icons.check_circle_outline : Icons.more_horiz,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text('$label: ${complete ? 'đã tải' : 'đang chờ'}'),
            ),
          ],
        ),
      );
}
