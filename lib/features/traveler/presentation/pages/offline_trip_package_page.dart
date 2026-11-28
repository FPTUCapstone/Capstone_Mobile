import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/offline_trip_package.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/offline_trip_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/offline_trip_package_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/offline_trip_package_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/live_offline_package_page.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_bottom_sheet_scaffold.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_coastal_app_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/app_section_card.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

class OfflineTripPackagePage extends StatefulWidget {
  const OfflineTripPackagePage({
    super.key,
    required this.itineraryId,
    this.title,
    this.cubit,
    this.repository,
    this.offlineRepository,
    this.isDemoMode = false,
  });

  final int itineraryId;
  final String? title;
  final OfflineTripPackageCubit? cubit;
  final ItineraryRepository? repository;
  final OfflineTripRepository? offlineRepository;
  final bool isDemoMode;

  @override
  State<OfflineTripPackagePage> createState() => _OfflineTripPackagePageState();
}

class _OfflineTripPackagePageState extends State<OfflineTripPackagePage> {
  OfflineTripRepository? get _liveRepository =>
      widget.offlineRepository ?? locateOptional<OfflineTripRepository>();
  late bool _isLoadingMetadata;
  String? _metadataError;
  String? _resolvedTitle;
  int? _resolvedVersion;

  @override
  void initState() {
    super.initState();
    if (!widget.isDemoMode && widget.cubit == null && _liveRepository != null) {
      _isLoadingMetadata = false;
      return;
    }
    final hasInitialTitle =
        widget.title != null && widget.title!.trim().isNotEmpty;
    if (widget.isDemoMode || hasInitialTitle || widget.cubit != null) {
      _isLoadingMetadata = false;
      _resolvedTitle =
          widget.title ?? (widget.isDemoMode ? 'Khám phá Đà Nẵng' : null);
    } else {
      _isLoadingMetadata = true;
      _fetchMetadata();
    }
  }

  Future<void> _fetchMetadata() async {
    setState(() {
      _isLoadingMetadata = true;
      _metadataError = null;
    });
    try {
      final repo =
          widget.repository ??
          (serviceLocator.isRegistered<ItineraryRepository>()
              ? serviceLocator<ItineraryRepository>()
              : null);
      if (repo == null) {
        throw const FormatException('Itinerary service unavailable.');
      }
      final detail = await repo.getById(widget.itineraryId);
      if (!mounted) return;
      setState(() {
        _isLoadingMetadata = false;
        _resolvedTitle = detail.title ?? 'Chuyến đi #${widget.itineraryId}';
        _resolvedVersion = detail.version;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMetadata = false;
        _metadataError = 'Không thể tải thông tin chuyến đi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveRepository = _liveRepository;
    if (!widget.isDemoMode && widget.cubit == null && liveRepository != null) {
      return LiveOfflinePackagePage(
        itineraryId: widget.itineraryId,
        repository: liveRepository,
        title: widget.title,
      );
    }
    final c = context.tmColors;
    if (_isLoadingMetadata) {
      return Scaffold(
        backgroundColor: c.canvas,
        appBar: const AppCoastalAppBar(title: 'Truy cập ngoại tuyến'),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: c.brandTeal),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Đang tải thông tin chuyến đi...',
                style: TextStyle(color: c.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (_metadataError != null) {
      return Scaffold(
        backgroundColor: c.canvas,
        appBar: const AppCoastalAppBar(title: 'Truy cập ngoại tuyến'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: c.errorContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.error_outline, size: 32, color: c.error),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _metadataError!,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Không thể tải lịch trình #${widget.itineraryId}.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Quay lại'),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    FilledButton(
                      onPressed: _fetchMetadata,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (widget.cubit != null) {
      return BlocProvider.value(
        value: widget.cubit!,
        child: const _OfflineTripPackageView(),
      );
    }

    return BlocProvider(
      create: (_) => OfflineTripPackageCubit(
        itineraryId: widget.itineraryId,
        title: _resolvedTitle ?? 'Chuyến đi #${widget.itineraryId}',
        version: _resolvedVersion ?? 1,
        isDemoMode: widget.isDemoMode,
      ),
      child: const _OfflineTripPackageView(),
    );
  }
}

class _OfflineTripPackageView extends StatelessWidget {
  const _OfflineTripPackageView();

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return BlocConsumer<OfflineTripPackageCubit, OfflineTripPackageState>(
      listener: (context, state) {
        if (state.package.status == OfflinePackageStatus.available) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Đã tải gói lịch trình! Lịch trình hiện có thể xem ngoại tuyến không cần mạng.',
              ),
              backgroundColor: c.success,
            ),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<OfflineTripPackageCubit>();
        final isDemo = state.isDemoMode;

        return Scaffold(
          backgroundColor: c.canvas,
          appBar: AppCoastalAppBar(
            title: 'Truy cập ngoại tuyến',
            actions: [
              if (isDemo)
                IconButton(
                  icon: Icon(Icons.build_circle_outlined, color: c.warning),
                  tooltip: 'Điều khiển demo',
                  onPressed: () => _showDemoControls(context, cubit),
                ),
            ],
          ),
          body: isDemo
              ? _DemoPackageContentView(state: state)
              : _ProductionUnavailableView(state: state),
        );
      },
    );
  }

  void _showDemoControls(BuildContext context, OfflineTripPackageCubit cubit) {
    showAppModalBottomSheet<void>(
      context: context,
      title: 'Điều khiển thử nghiệm (Demo)',
      builder: (sheetContext) => Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          ActionChip(
            avatar: const Icon(Icons.wifi_off, size: 16),
            label: const Text('Giả lập mất kết nối (MSG106)'),
            onPressed: () {
              Navigator.pop(sheetContext);
              cubit.demoSimulateNetworkInterruption();
            },
          ),
          ActionChip(
            avatar: const Icon(Icons.warning, size: 16),
            label: const Text('Giả lập gói > 150 MB (MSG107)'),
            onPressed: () {
              Navigator.pop(sheetContext);
              cubit.demoSimulateOversizePackage();
            },
          ),
          ActionChip(
            avatar: const Icon(Icons.update, size: 16),
            label: const Text('Giả lập có bản cập nhật mới'),
            onPressed: () {
              Navigator.pop(sheetContext);
              cubit.demoSimulateSuperseded();
            },
          ),
        ],
      ),
    );
  }
}

/// Truthful production view when offline package backend/persistence capability is unavailable.
class _ProductionUnavailableView extends StatelessWidget {
  const _ProductionUnavailableView({required this.state});

  final OfflineTripPackageState state;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final pkg = state.package;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: c.tealSoftContainer,
                child: Icon(Icons.offline_pin_outlined, color: c.brandTeal),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pkg.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Lịch trình #${pkg.itineraryId} · Phiên bản ${pkg.version}',
                      style: TextStyle(color: c.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const StatusBadge(
                label: 'Không khả dụng',
                type: StatusBadgeType.warning,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: c.surfaceElevated,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_off_rounded,
                  size: 32,
                  color: c.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Gói ngoại tuyến hiện chưa khả dụng',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Tính năng tải bản đồ và lịch trình ngoại tuyến hiện chưa khả dụng do dịch vụ gói chuyến đi và lưu trữ cục bộ chưa được kết nối.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: c.textSecondary,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Quay lại lịch trình'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
          ),
        ),
      ],
    );
  }
}

/// Rich interactive preview rendered exclusively when [isDemoMode] is true.
class _DemoPackageContentView extends StatelessWidget {
  const _DemoPackageContentView({required this.state});

  final OfflineTripPackageState state;

  @override
  Widget build(BuildContext context) {
    final pkg = state.package;
    final cubit = context.read<OfflineTripPackageCubit>();
    final isDownloading =
        pkg.status == OfflinePackageStatus.downloading ||
        pkg.status == OfflinePackageStatus.checkingStorage;
    final isRefreshing =
        state.isRefreshing &&
        (state.replacementPackage?.status == OfflinePackageStatus.downloading ||
            state.replacementPackage?.status ==
                OfflinePackageStatus.checkingStorage);
    final activeDownloadPkg = isRefreshing
        ? (state.replacementPackage ?? pkg)
        : pkg;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // 1. Itinerary Header Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        pkg.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    _StatusBadgeForPackage(
                      status: isRefreshing
                          ? OfflinePackageStatus.downloading
                          : pkg.status,
                      customLabel: isRefreshing ? 'ĐANG CẬP NHẬT...' : null,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${pkg.dateRange ?? 'Chuyến đi sắp tới'} · ${pkg.stopsCount} điểm dừng dự kiến',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.xs),
                if (pkg.lastDownloadedAt != null)
                  Text(
                    'Tải lần cuối: ${_formatDateTime(pkg.lastDownloadedAt!)} (v${pkg.version})',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // 2. Error / Notice Alerts
        if (state.replacementPackage?.status ==
            OfflinePackageStatus.insufficientStorage) ...[
          AppAlert(
            type: AppAlertType.error,
            message:
                state.replacementPackage?.errorMessage ??
                'Không đủ dung lượng bộ nhớ. Cần ít nhất 150 MB trống để lưu dữ liệu bản đồ ngoại tuyến.',
          ),
          const SizedBox(height: AppSpacing.md),
        ] else if (state.replacementPackage?.status ==
            OfflinePackageStatus.networkInterrupted) ...[
          AppAlert(
            type: AppAlertType.warning,
            message:
                state.replacementPackage?.errorMessage ??
                'Tải xuống bị gián đoạn do mất kết nối. Dữ liệu ngoại tuyến hiện có vẫn dùng được.',
          ),
          const SizedBox(height: AppSpacing.md),
        ] else if (isRefreshing) ...[
          AppAlert(
            type: AppAlertType.info,
            message:
                'Đang tải phiên bản mới (v${state.replacementPackage!.version}). Gói ngoại tuyến hiện tại (v${pkg.version}) vẫn có thể sử dụng.',
          ),
          const SizedBox(height: AppSpacing.md),
        ] else if (pkg.status == OfflinePackageStatus.insufficientStorage) ...[
          AppAlert(
            type: AppAlertType.error,
            message:
                pkg.errorMessage ??
                'Không đủ dung lượng bộ nhớ. Cần ít nhất 150 MB trống để lưu dữ liệu bản đồ ngoại tuyến.',
          ),
          const SizedBox(height: AppSpacing.md),
        ] else if (pkg.status == OfflinePackageStatus.networkInterrupted) ...[
          AppAlert(
            type: AppAlertType.warning,
            message:
                pkg.errorMessage ??
                'Tải xuống bị gián đoạn do mất kết nối. Dữ liệu tải dở đã bị hủy. Vui lòng thử lại.',
          ),
          const SizedBox(height: AppSpacing.md),
        ] else if (pkg.status == OfflinePackageStatus.superseded) ...[
          const AppAlert(
            type: AppAlertType.info,
            message:
                'Có phiên bản lịch trình mới hơn trên máy chủ. Bản sao ngoại tuyến hiện tại vẫn dùng được.',
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // 3. Package Contents Breakdown Card (DEMO_ONLY)
        AppSectionCard(
          title: 'Nội dung gói dữ liệu',
          icon: Icons.inventory_2_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ComponentRow(
                title: 'Bản đồ khu vực (Mức thu phóng 12–16)',
                subtitle: 'Bán kính 18 km quanh các điểm dừng',
                size: '85.0 MB',
                icon: Icons.map_outlined,
              ),
              Divider(height: 16, color: context.tmColors.borderSubtle),
              const _ComponentRow(
                title: 'Lịch trình & dữ liệu tuyến đường',
                subtitle: 'Điểm rẽ, mốc thời gian, thời lượng tham quan',
                size: '2.5 MB',
                icon: Icons.alt_route_rounded,
              ),
              Divider(height: 16, color: context.tmColors.borderSubtle),
              const _ComponentRow(
                title: 'Mô tả điểm đến & hướng dẫn vào cửa',
                subtitle: 'Thông tin địa điểm chính và giờ mở cửa',
                size: '31.0 MB',
                icon: Icons.place_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // 4. Storage & Ceiling Verification Card (DEMO_ONLY)
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Dung lượng gói ước tính',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: context.tmColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${pkg.totalSizeMb.toStringAsFixed(1)} MB',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.tmColors.brandTeal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Giới hạn dung lượng cho phép: tối đa ${pkg.maxLimitMb.toInt()} MB',
                style: TextStyle(
                  color: context.tmColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  value: (pkg.totalSizeMb / pkg.maxLimitMb).clamp(0.0, 1.0),
                  backgroundColor: context.tmColors.surfaceElevated,
                  color: pkg.totalSizeMb > pkg.maxLimitMb
                      ? context.tmColors.error
                      : context.tmColors.brandTeal,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Dung lượng trống trên thiết bị: còn ${(state.deviceFreeStorageMb / 1024).toStringAsFixed(1)} GB',
                style: TextStyle(
                  fontSize: 11.5,
                  color: context.tmColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // 5. In-Progress Download Status
        if (isDownloading || isRefreshing) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          state.downloadStepDescription,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${activeDownloadPkg.progressPercent.toInt()}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  LinearProgressIndicator(
                    value: (activeDownloadPkg.progressPercent / 100.0).clamp(
                      0.0,
                      1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // 6. Primary Action Buttons
        if (isDownloading || isRefreshing) ...[
          OutlinedButton.icon(
            onPressed: () => cubit.cancelDownload(),
            icon: const Icon(Icons.close),
            label: Text(isRefreshing ? 'Hủy cập nhật' : 'Hủy tải'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ] else if (pkg.status == OfflinePackageStatus.notDownloaded ||
            pkg.status == OfflinePackageStatus.networkInterrupted ||
            pkg.status == OfflinePackageStatus.insufficientStorage) ...[
          FilledButton.icon(
            onPressed: isDownloading ? null : () => cubit.startDownload(),
            icon: const Icon(Icons.download_rounded),
            label: const Text('Tải về xem ngoại tuyến'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ] else if (pkg.status == OfflinePackageStatus.available) ...[
          OutlinedButton.icon(
            onPressed: () => _confirmRemove(context, cubit),
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            label: const Text(
              'Xóa dữ liệu ngoại tuyến',
              style: TextStyle(color: AppColors.error),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ] else if (pkg.status == OfflinePackageStatus.superseded) ...[
          FilledButton.icon(
            onPressed: () => cubit.refreshSupersededPackage(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Cập nhật dữ liệu ngoại tuyến'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => _confirmRemove(context, cubit),
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            label: const Text(
              'Xóa dữ liệu ngoại tuyến',
              style: TextStyle(color: AppColors.error),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ],
      ],
    );
  }

  void _confirmRemove(BuildContext context, OfflineTripPackageCubit cubit) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa dữ liệu ngoại tuyến?'),
        content: const Text(
          'Lịch trình và dữ liệu bản đồ đã lưu sẽ không còn khả dụng khi không có kết nối mạng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(dialogContext);
              cubit.removeOfflineData();
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusBadgeForPackage extends StatelessWidget {
  const _StatusBadgeForPackage({required this.status, this.customLabel});

  final OfflinePackageStatus status;
  final String? customLabel;

  @override
  Widget build(BuildContext context) {
    if (customLabel != null) {
      return StatusBadge(label: customLabel!, type: StatusBadgeType.info);
    }
    return switch (status) {
      OfflinePackageStatus.available => const StatusBadge(
        label: 'SẴN SÀNG NGOẠI TUYẾN',
        type: StatusBadgeType.success,
      ),
      OfflinePackageStatus.downloading ||
      OfflinePackageStatus.checkingStorage => const StatusBadge(
        label: 'ĐANG TẢI',
        type: StatusBadgeType.info,
      ),
      OfflinePackageStatus.superseded => const StatusBadge(
        label: 'CÓ BẢN CẬP NHẬT',
        type: StatusBadgeType.warning,
      ),
      OfflinePackageStatus.insufficientStorage ||
      OfflinePackageStatus.networkInterrupted ||
      OfflinePackageStatus.error => const StatusBadge(
        label: 'LỖI / CHƯA HOÀN TẤT',
        type: StatusBadgeType.error,
      ),
      OfflinePackageStatus.notDownloaded => const StatusBadge(
        label: 'CHƯA TẢI',
        type: StatusBadgeType.neutral,
      ),
      OfflinePackageStatus.unavailable => const StatusBadge(
        label: 'KHÔNG KHẢ DỤNG',
        type: StatusBadgeType.warning,
      ),
    };
  }
}

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({
    required this.title,
    required this.subtitle,
    required this.size,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: c.tealSoftContainer,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 18, color: c.brandTeal),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: c.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(color: c.textSecondary, fontSize: 11.5),
              ),
            ],
          ),
        ),
        Text(
          size,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: c.textPrimary,
          ),
        ),
      ],
    );
  }
}
