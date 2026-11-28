import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/network/network_info.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/offline_trip_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/live_offline_package_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/offline_confirmation_dialog.dart';
import 'package:trip_mate_mobile/features/traveler/resources/offline_ui_text.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_coastal_app_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/app_section_card.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

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
      final c = context.tmColors;
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
          backgroundColor: c.canvas,
          appBar: const AppCoastalAppBar(title: OfflineUiText.accessTitle),
          body: state.isLoading && manifest == null
              ? Center(child: CircularProgressIndicator(color: c.brandTeal))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: c.tealSoftContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    manifest != null
                                        ? Icons.offline_pin_outlined
                                        : Icons.cloud_download_outlined,
                                    color: c.brandTeal,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        manifest?.title ??
                                            title ??
                                            'Lịch trình #$itineraryId',
                                        style: TextStyle(
                                          fontFamily: AppTypography.displayFont,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: c.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        OfflineUiText.sizeLimit,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: c.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (manifest != null) ...[
                                  const SizedBox(width: AppSpacing.xs),
                                  StatusBadge(
                                    label: manifest.locked
                                        ? 'Đã khóa'
                                        : !manifest.mapResourcesAvailable
                                        ? 'Thiếu bản đồ'
                                        : manifest.superseded
                                        ? 'Có bản mới'
                                        : 'Sẵn sàng',
                                    type:
                                        manifest.locked ||
                                            !manifest.mapResourcesAvailable
                                        ? StatusBadgeType.error
                                        : manifest.superseded
                                        ? StatusBadgeType.warning
                                        : StatusBadgeType.success,
                                  ),
                                ],
                              ],
                            ),
                            if (manifest != null) ...[
                              Divider(height: 22, color: c.borderSubtle),
                              Text(
                                'Phiên bản ${manifest.version} · ${OfflineUiText.bytes(manifest.totalBytes)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: c.brandTeal,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Đã tải: ${OfflineUiText.date(manifest.downloadedAtUtc)}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: c.textSecondary,
                                ),
                              ),
                              if (manifest.snapshot.itinerary.validFrom
                                  case final from?)
                                Text(
                                  'Từ ${OfflineUiText.date(from)}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: c.textSecondary,
                                  ),
                                ),
                              if (manifest.snapshot.itinerary.validTo
                                  case final to?)
                                Text(
                                  'Đến ${OfflineUiText.date(to)}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: c.textSecondary,
                                  ),
                                ),
                              const SizedBox(height: AppSpacing.sm),
                              if (manifest.locked)
                                const AppAlert(
                                  type: AppAlertType.error,
                                  message: OfflineUiText.locked,
                                )
                              else if (!manifest.mapResourcesAvailable)
                                const AppAlert(
                                  type: AppAlertType.error,
                                  message:
                                      'Dữ liệu bản đồ bị thiếu hoặc hỏng. Hãy tải lại gói trước khi mở ngoại tuyến.',
                                )
                              else
                                AppAlert(
                                  type: manifest.superseded
                                      ? AppAlertType.warning
                                      : AppAlertType.success,
                                  message: manifest.superseded
                                      ? OfflineUiText.superseded
                                      : OfflineUiText.ready,
                                ),
                            ],
                          ],
                        ),
                      ),
                      if (offlineReadOnly) ...[
                        const SizedBox(height: AppSpacing.md),
                        const AppAlert(
                          type: AppAlertType.info,
                          message:
                              'Đăng nhập lại để tải hoặc cập nhật. Các gói đã tải vẫn có thể đọc ngoại tuyến.',
                        ),
                      ],
                      if (state.error != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        AppAlert(
                          type: AppAlertType.error,
                          message: state.error!,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      if (state.isDownloading) ...[
                        AppSectionCard(
                          title: _phase(progress?.phase),
                          icon: Icons.downloading_rounded,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _component(
                                context,
                                'Lịch trình',
                                progress?.phase != null &&
                                    progress!.phase !=
                                        OfflineTransferPhase.preparing,
                              ),
                              _component(
                                context,
                                'Thông tin điểm đến',
                                progress?.phase != null &&
                                    progress!.phase !=
                                        OfflineTransferPhase.preparing,
                              ),
                              _component(
                                context,
                                'Bản đồ và tuyến đường',
                                progress?.phase ==
                                        OfflineTransferPhase.verifying ||
                                    progress?.phase ==
                                        OfflineTransferPhase.publishing,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  minHeight: 7,
                                  backgroundColor: c.surfaceElevated,
                                  color: c.brandTeal,
                                  value: progress?.fraction
                                      .clamp(0.0, 1.0)
                                      .toDouble(),
                                  semanticsLabel:
                                      'Tiến độ tải dữ liệu ngoại tuyến',
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              if (progress?.estimatedBytes case final size?)
                                Text(
                                  'Ước tính: ${OfflineUiText.bytes(size)}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: c.textSecondary,
                                  ),
                                )
                              else
                                Text(
                                  OfflineUiText.estimateUnknown,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: c.textSecondary,
                                  ),
                                ),
                              if (progress != null &&
                                  progress.completedBytes > 0)
                                Text(
                                  'Đã tải: ${OfflineUiText.bytes(progress.completedBytes)}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: c.brandTeal,
                                  ),
                                ),
                              if (manifest != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: AppSpacing.sm,
                                  ),
                                  child: Text(
                                    OfflineUiText.updateHint,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: c.textSecondary,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: AppSpacing.md),
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
                            ],
                          ),
                        ),
                      ] else if (manifest?.locked != true) ...[
                        AppSectionCard(
                          title: manifest == null
                              ? 'Tải gói ngoại tuyến'
                              : 'Cập nhật dữ liệu',
                          icon: Icons.download_for_offline_outlined,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                manifest == null
                                    ? OfflineUiText.estimateUnknown
                                    : OfflineUiText.updateHint,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: c.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              FilledButton.icon(
                                onPressed: busy || offlineReadOnly
                                    ? null
                                    : () async {
                                        if (!await confirmOfflineAction(
                                          context,
                                          title: manifest == null
                                              ? 'Tải lịch trình để dùng ngoại tuyến?'
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
                                        if (context.mounted) {
                                          await cubit.download();
                                        }
                                      },
                                icon: const Icon(Icons.download_outlined),
                                label: Text(
                                  manifest == null
                                      ? OfflineUiText.download
                                      : OfflineUiText.update,
                                ),
                              ),
                              if (manifest != null) ...[
                                const SizedBox(height: AppSpacing.xs),
                                TextButton(
                                  onPressed: busy || offlineReadOnly
                                      ? null
                                      : cubit.checkForUpdate,
                                  child: const Text('Kiểm tra phiên bản mới'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      if (readable) ...[
                        const SizedBox(height: AppSpacing.md),
                        FilledButton.tonalIcon(
                          onPressed: () => context.push(
                            AppRoutes.offlineItinerary(itineraryId),
                          ),
                          icon: const Icon(Icons.list_alt),
                          label: const Text(OfflineUiText.open),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        OutlinedButton.icon(
                          onPressed: () =>
                              context.push(AppRoutes.offlineMap(itineraryId)),
                          icon: const Icon(Icons.map_outlined),
                          label: const Text(OfflineUiText.map),
                        ),
                      ],
                      if (manifest != null && !state.isDownloading) ...[
                        const SizedBox(height: AppSpacing.md),
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
                          style: OutlinedButton.styleFrom(
                            foregroundColor: c.error,
                            side: BorderSide(
                              color: c.error.withValues(alpha: 0.45),
                            ),
                          ),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text(OfflineUiText.remove),
                        ),
                      ],
                      if (state.error != null && !busy) ...[
                        const SizedBox(height: AppSpacing.xs),
                        TextButton(
                          onPressed: cubit.load,
                          child: const Text('Thử lại'),
                        ),
                      ],
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

  static Widget _component(BuildContext context, String label, bool complete) {
    final c = context.tmColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            complete ? Icons.check_circle_outline : Icons.more_horiz,
            size: 20,
            color: complete ? c.success : c.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: ${complete ? 'đã tải' : 'đang chờ'}',
              style: TextStyle(
                fontSize: 13,
                color: complete ? c.textPrimary : c.textSecondary,
                fontWeight: complete ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
