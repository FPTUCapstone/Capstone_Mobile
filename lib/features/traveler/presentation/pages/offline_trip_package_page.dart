import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/offline_trip_package.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/offline_trip_package_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/offline_trip_package_state.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

class OfflineTripPackagePage extends StatelessWidget {
  const OfflineTripPackagePage({
    super.key,
    required this.itineraryId,
    this.title = 'Đà Nẵng City Explorer',
    this.cubit,
  });

  final int itineraryId;
  final String title;
  final OfflineTripPackageCubit? cubit;

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(
        value: cubit!,
        child: const _OfflineTripPackageView(),
      );
    }
    return BlocProvider(
      create: (_) =>
          OfflineTripPackageCubit(itineraryId: itineraryId, title: title),
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
        final pkg = state.package;
        final cubit = context.read<OfflineTripPackageCubit>();
        final isDownloading =
            pkg.status == OfflinePackageStatus.downloading ||
            pkg.status == OfflinePackageStatus.checkingStorage;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Offline Access'),
            actions: [
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
          body: ListView(
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
                          _StatusBadgeForPackage(status: pkg.status),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '${pkg.dateRange ?? 'Upcoming Trip'} · ${pkg.stopsCount} scheduled stops',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
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
              if (pkg.status == OfflinePackageStatus.insufficientStorage) ...[
                AppAlert(
                  type: AppAlertType.error,
                  message:
                      pkg.errorMessage ??
                      'Insufficient storage space. At least 150MB free space required for offline map data.',
                ),
                const SizedBox(height: AppSpacing.md),
              ] else if (pkg.status ==
                  OfflinePackageStatus.networkInterrupted) ...[
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

              // 3. Package Contents Breakdown Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Package Contents',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _ComponentRow(
                        title: 'Map area tiles (Zoom 12-16)',
                        subtitle: '18 km radius around itinerary stops',
                        size: '85.0 MB',
                        icon: Icons.map_outlined,
                      ),
                      const Divider(height: 16),
                      _ComponentRow(
                        title: 'Itinerary schedule & route geometry',
                        subtitle: 'Turn points, timelines, visit durations',
                        size: '2.5 MB',
                        icon: Icons.alt_route_rounded,
                      ),
                      const Divider(height: 16),
                      _ComponentRow(
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

              // 4. Storage & Ceiling Verification Card
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
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      LinearProgressIndicator(
                        value: (pkg.totalSizeMb / pkg.maxLimitMb).clamp(
                          0.0,
                          1.0,
                        ),
                        backgroundColor: AppColors.line,
                        color: pkg.totalSizeMb > pkg.maxLimitMb
                            ? AppColors.error
                            : AppColors.primary,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Device free space: ${(state.deviceFreeStorageMb / 1024).toStringAsFixed(1)} GB available',
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

              // 5. In-Progress Download Status
              if (isDownloading) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              state.downloadStepDescription,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${pkg.progressPercent.toInt()}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        LinearProgressIndicator(
                          value: (pkg.progressPercent / 100.0).clamp(0.0, 1.0),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // 6. Primary Action Buttons
              if (pkg.status == OfflinePackageStatus.notDownloaded ||
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
              ] else if (isDownloading) ...[
                OutlinedButton.icon(
                  onPressed: () => cubit.cancelDownload(),
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel Download'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              ] else if (pkg.status == OfflinePackageStatus.available) ...[
                OutlinedButton.icon(
                  onPressed: () => _confirmRemove(context, cubit),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                  ),
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
              ],
            ],
          ),
        );
      },
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

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusBadgeForPackage extends StatelessWidget {
  const _StatusBadgeForPackage({required this.status});

  final OfflinePackageStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      OfflinePackageStatus.available => const StatusBadge(
        label: 'Available Offline',
        type: StatusBadgeType.success,
      ),
      OfflinePackageStatus.downloading ||
      OfflinePackageStatus.checkingStorage => const StatusBadge(
        label: 'Downloading',
        type: StatusBadgeType.info,
      ),
      OfflinePackageStatus.superseded => const StatusBadge(
        label: 'Update Available',
        type: StatusBadgeType.warning,
      ),
      OfflinePackageStatus.insufficientStorage ||
      OfflinePackageStatus.networkInterrupted ||
      OfflinePackageStatus.error => const StatusBadge(
        label: 'Failed / Incomplete',
        type: StatusBadgeType.error,
      ),
      OfflinePackageStatus.notDownloaded => const StatusBadge(
        label: 'Not Downloaded',
        type: StatusBadgeType.neutral,
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
