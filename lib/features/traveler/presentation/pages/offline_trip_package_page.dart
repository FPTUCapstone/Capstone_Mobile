import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/offline_trip_package.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/offline_trip_package_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/offline_trip_package_state.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

class OfflineTripPackagePage extends StatefulWidget {
  const OfflineTripPackagePage({
    super.key,
    required this.itineraryId,
    this.title,
    this.cubit,
    this.repository,
    this.isDemoMode = false,
  });

  final int itineraryId;
  final String? title;
  final OfflineTripPackageCubit? cubit;
  final ItineraryRepository? repository;
  final bool isDemoMode;

  @override
  State<OfflineTripPackagePage> createState() => _OfflineTripPackagePageState();
}

class _OfflineTripPackagePageState extends State<OfflineTripPackagePage> {
  late bool _isLoadingMetadata;
  String? _metadataError;
  String? _resolvedTitle;
  int? _resolvedVersion;

  @override
  void initState() {
    super.initState();
    final hasInitialTitle =
        widget.title != null && widget.title!.trim().isNotEmpty;
    if (widget.isDemoMode || hasInitialTitle || widget.cubit != null) {
      _isLoadingMetadata = false;
      _resolvedTitle =
          widget.title ?? (widget.isDemoMode ? 'Đà Nẵng City Explorer' : null);
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
        _resolvedTitle = detail.title ?? 'Trip #${widget.itineraryId}';
        _resolvedVersion = detail.version;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMetadata = false;
        _metadataError = 'Trip information unavailable.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingMetadata) {
      return Scaffold(
        appBar: AppBar(title: const Text('Offline Access')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: AppSpacing.md),
              Text('Loading trip information...'),
            ],
          ),
        ),
      );
    }

    if (_metadataError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Offline Access')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _metadataError!,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Could not load itinerary #${widget.itineraryId}.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Go back'),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    FilledButton(
                      onPressed: _fetchMetadata,
                      child: const Text('Retry'),
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
        title: _resolvedTitle ?? 'Trip #${widget.itineraryId}',
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
    return BlocConsumer<OfflineTripPackageCubit, OfflineTripPackageState>(
      listener: (context, state) {
        if (state.package.status == OfflinePackageStatus.available) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Trip package downloaded! Itinerary is now available offline without internet.',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<OfflineTripPackageCubit>();
        final isDemo = state.isDemoMode;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Offline Access'),
            actions: [
              if (isDemo)
                IconButton(
                  icon: const Icon(
                    Icons.build_circle_outlined,
                    color: AppColors.warning,
                  ),
                  tooltip: 'DEMO_ONLY Controls',
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
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.bug_report_outlined,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'DEMO_ONLY Test Controls',
                    style: Theme.of(sheetContext).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(height: 20),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.wifi_off, size: 16),
                    label: const Text('Simulate Network Loss (MSG106)'),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      cubit.demoSimulateNetworkInterruption();
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.warning, size: 16),
                    label: const Text('Simulate Package > 150MB (MSG107)'),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      cubit.demoSimulateOversizePackage();
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.update, size: 16),
                    label: const Text('Simulate Superseded Update'),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      cubit.demoSimulateSuperseded();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
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
    final pkg = state.package;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // 1. Trip Identity Header Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primarySoft,
                  child: const Icon(
                    Icons.offline_pin_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pkg.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Itinerary #${pkg.itineraryId} · Version ${pkg.version}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const StatusBadge(
                  label: 'Unavailable',
                  type: StatusBadgeType.warning,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // 2. Main Unavailable Notice Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 48,
                  color: AppColors.muted,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Offline package is not available yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Offline map and itinerary download is not currently available because the required trip-package service and local persistence integration are not yet connected.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // 3. Actions
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back to itinerary'),
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
                      customLabel: isRefreshing ? 'UPDATING...' : null,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${pkg.dateRange ?? 'Upcoming Trip'} · ${pkg.stopsCount} scheduled stops',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.xs),
                if (pkg.lastDownloadedAt != null)
                  Text(
                    'Last downloaded: ${_formatDateTime(pkg.lastDownloadedAt!)} (v${pkg.version})',
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
                'Insufficient storage space. At least 150MB free space required for offline map data.',
          ),
          const SizedBox(height: AppSpacing.md),
        ] else if (state.replacementPackage?.status ==
            OfflinePackageStatus.networkInterrupted) ...[
          AppAlert(
            type: AppAlertType.warning,
            message:
                state.replacementPackage?.errorMessage ??
                'Download interrupted due to connection loss. Existing offline data remains usable.',
          ),
          const SizedBox(height: AppSpacing.md),
        ] else if (isRefreshing) ...[
          AppAlert(
            type: AppAlertType.info,
            message:
                'Downloading updated version (v${state.replacementPackage!.version}). Your current offline package (v${pkg.version}) remains usable.',
          ),
          const SizedBox(height: AppSpacing.md),
        ] else if (pkg.status == OfflinePackageStatus.insufficientStorage) ...[
          AppAlert(
            type: AppAlertType.error,
            message:
                pkg.errorMessage ??
                'Insufficient storage space. At least 150MB free space required for offline map data.',
          ),
          const SizedBox(height: AppSpacing.md),
        ] else if (pkg.status == OfflinePackageStatus.networkInterrupted) ...[
          AppAlert(
            type: AppAlertType.warning,
            message:
                pkg.errorMessage ??
                'Download interrupted due to connection loss. Partial download discarded. Please retry.',
          ),
          const SizedBox(height: AppSpacing.md),
        ] else if (pkg.status == OfflinePackageStatus.superseded) ...[
          const AppAlert(
            type: AppAlertType.info,
            message:
                'A newer itinerary version exists on the server. Your existing offline copy remains usable.',
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // 3. Package Contents Breakdown Card (DEMO_ONLY)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Package Contents',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.sm),
                const _ComponentRow(
                  title: 'Map area tiles (Zoom 12-16)',
                  subtitle: '18 km radius around itinerary stops',
                  size: '85.0 MB',
                  icon: Icons.map_outlined,
                ),
                const Divider(height: 16),
                const _ComponentRow(
                  title: 'Itinerary schedule & route geometry',
                  subtitle: 'Turn points, timelines, visit durations',
                  size: '2.5 MB',
                  icon: Icons.alt_route_rounded,
                ),
                const Divider(height: 16),
                const _ComponentRow(
                  title: 'POI descriptions & entry guides',
                  subtitle: 'Key attraction data and opening hours',
                  size: '31.0 MB',
                  icon: Icons.place_outlined,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // 4. Storage & Ceiling Verification Card (DEMO_ONLY)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Estimated Package Size',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${pkg.totalSizeMb.toStringAsFixed(1)} MB',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Configured storage ceiling: ${pkg.maxLimitMb.toInt()} MB limit (BR-37)',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: AppSpacing.xs),
                LinearProgressIndicator(
                  value: (pkg.totalSizeMb / pkg.maxLimitMb).clamp(0.0, 1.0),
                  backgroundColor: AppColors.line,
                  color: pkg.totalSizeMb > pkg.maxLimitMb
                      ? AppColors.error
                      : AppColors.primary,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Device free space: ${(state.deviceFreeStorageMb / 1024).toStringAsFixed(1)} GB available',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
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
            label: Text(isRefreshing ? 'Cancel Update' : 'Cancel Download'),
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
            label: const Text('Download for Offline Use'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ] else if (pkg.status == OfflinePackageStatus.available) ...[
          OutlinedButton.icon(
            onPressed: () => _confirmRemove(context, cubit),
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            label: const Text(
              'Remove Offline Data',
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
            label: const Text('Refresh Offline Data'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => _confirmRemove(context, cubit),
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            label: const Text(
              'Remove Offline Data',
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
        title: const Text('Remove offline data?'),
        content: const Text(
          'This itinerary and cached map tiles will no longer be available without an internet connection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(dialogContext);
              cubit.removeOfflineData();
            },
            child: const Text('Remove'),
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
        label: 'AVAILABLE OFFLINE',
        type: StatusBadgeType.success,
      ),
      OfflinePackageStatus.downloading ||
      OfflinePackageStatus.checkingStorage => const StatusBadge(
        label: 'DOWNLOADING',
        type: StatusBadgeType.info,
      ),
      OfflinePackageStatus.superseded => const StatusBadge(
        label: 'UPDATE AVAILABLE',
        type: StatusBadgeType.warning,
      ),
      OfflinePackageStatus.insufficientStorage ||
      OfflinePackageStatus.networkInterrupted ||
      OfflinePackageStatus.error => const StatusBadge(
        label: 'FAILED / INCOMPLETE',
        type: StatusBadgeType.error,
      ),
      OfflinePackageStatus.notDownloaded => const StatusBadge(
        label: 'NOT DOWNLOADED',
        type: StatusBadgeType.neutral,
      ),
      OfflinePackageStatus.unavailable => const StatusBadge(
        label: 'UNAVAILABLE',
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
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        Text(
          size,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}
