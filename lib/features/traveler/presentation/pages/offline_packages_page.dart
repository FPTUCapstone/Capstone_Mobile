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
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/offline_trip_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/offline_packages_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/offline_confirmation_dialog.dart';
import 'package:trip_mate_mobile/features/traveler/resources/offline_ui_text.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_coastal_app_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/app_empty_state.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

class OfflinePackagesPage extends StatelessWidget {
  const OfflinePackagesPage({this.repository, super.key});
  final OfflineTripRepository? repository;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final repo = repository ?? locateOptional<OfflineTripRepository>();
    if (repo == null) {
      return Scaffold(
        backgroundColor: c.canvas,
        appBar: const AppCoastalAppBar(title: OfflineUiText.title),
        body: const AppEmptyState(
          icon: Icons.cloud_off_outlined,
          title: OfflineUiText.loadError,
        ),
      );
    }
    return BlocProvider(
      create: (_) =>
          OfflinePackagesCubit(repo, networkInfo: locateOptional<NetworkInfo>())
            ..load(),
      child: const _OfflinePackagesView(),
    );
  }
}

class _OfflinePackagesView extends StatelessWidget {
  const _OfflinePackagesView();

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<OfflinePackagesCubit, OfflinePackagesState>(
    builder: (context, state) {
      final c = context.tmColors;
      final cubit = context.read<OfflinePackagesCubit>();
      final auth = context.watch<AuthSessionCubit?>();
      final offlineSession = auth?.state.isOfflineReadOnly ?? false;
      final signingOut = auth?.state.operation == AuthSessionOperation.signOut;

      return Scaffold(
        backgroundColor: c.canvas,
        appBar: AppCoastalAppBar(
          title: OfflineUiText.title,
          actions: [
            if (offlineSession) ...[
              IconButton(
                onPressed: signingOut
                    ? null
                    : () => context.go(AppRoutes.login),
                tooltip: 'Đăng nhập',
                icon: const Icon(Icons.login),
              ),
              IconButton(
                onPressed: signingOut
                    ? null
                    : () async {
                        if (await confirmOfflineAction(
                              context,
                              title: 'Khóa dữ liệu ngoại tuyến?',
                              description:
                                  'Bạn cần đăng nhập lại cùng tài khoản để xem các gói đã tải.',
                              action: 'Khóa',
                            ) &&
                            context.mounted) {
                          await auth!.signOut();
                        }
                      },
                tooltip: 'Khóa dữ liệu và đăng xuất',
                icon: const Icon(Icons.lock_outline),
              ),
            ],
            IconButton(
              onPressed: state.isLoading ? null : cubit.load,
              tooltip: 'Làm mới danh sách đã tải',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: state.isLoading && state.packages.isEmpty
            ? Center(child: CircularProgressIndicator(color: c.brandTeal))
            : RefreshIndicator(
                color: c.brandTeal,
                onRefresh: cubit.load,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (state.error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: c.errorContainer,
                          borderRadius: BorderRadius.circular(
                            TripMateRadius.lg,
                          ),
                          border: Border.all(
                            color: c.error.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 20,
                                  color: c.error,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Text(
                                    state.error!,
                                    style: TextStyle(
                                      color: c.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            TextButton(
                              onPressed: cubit.load,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (state.unreadable.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: c.warningContainer,
                          borderRadius: BorderRadius.circular(
                            TripMateRadius.lg,
                          ),
                          border: Border.all(
                            color: c.warning.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 20,
                                  color: c.warning,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Text(
                                    OfflineUiText.corruption,
                                    style: TextStyle(
                                      color: c.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            for (var i = 0; i < state.unreadable.length; i++)
                              TextButton.icon(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: c.error,
                                ),
                                label: Text(
                                  'Xóa gói không đọc được ${i + 1}',
                                  style: TextStyle(color: c.error),
                                ),
                                onPressed: () async {
                                  if (await confirmOfflineAction(
                                        context,
                                        title: 'Xóa gói dữ liệu bị hỏng?',
                                        description:
                                            'Chỉ gói không đọc được này sẽ bị xóa. Các gói còn lại được giữ nguyên.',
                                        action: 'Xóa',
                                      ) &&
                                      context.mounted) {
                                    await cubit.removeUnreadable(
                                      state.unreadable[i],
                                    );
                                  }
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (state.packages.isEmpty && state.error == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: AppEmptyState(
                          icon: Icons.download_for_offline_outlined,
                          title: OfflineUiText.empty,
                          message: OfflineUiText.emptyHint,
                        ),
                      ),
                    for (final package in state.packages)
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
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: c.tealSoftContainer,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      package.locked
                                          ? Icons.lock_outline
                                          : Icons.offline_pin_outlined,
                                      size: 20,
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
                                          package.title,
                                          style: TextStyle(
                                            fontFamily:
                                                AppTypography.displayFont,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: c.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Phiên bản ${package.version} · ${OfflineUiText.bytes(package.totalBytes)}',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: c.brandTeal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  StatusBadge(
                                    label: package.locked
                                        ? 'Đã khóa'
                                        : !package.mapResourcesAvailable
                                        ? 'Thiếu bản đồ'
                                        : package.superseded
                                        ? 'Có bản mới'
                                        : 'Sẵn sàng',
                                    type:
                                        package.locked ||
                                            !package.mapResourcesAvailable
                                        ? StatusBadgeType.error
                                        : package.superseded
                                        ? StatusBadgeType.warning
                                        : StatusBadgeType.success,
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Đã tải ${OfflineUiText.date(package.downloadedAtUtc)}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: c.textSecondary,
                                ),
                              ),
                              if (package.snapshot.itinerary.validFrom
                                  case final from?)
                                Text(
                                  'Từ ${OfflineUiText.date(from)}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: c.textSecondary,
                                  ),
                                ),
                              if (package.snapshot.itinerary.validTo
                                  case final to?)
                                Text(
                                  'Đến ${OfflineUiText.date(to)}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: c.textSecondary,
                                  ),
                                ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                package.locked
                                    ? OfflineUiText.locked
                                    : !package.mapResourcesAvailable
                                    ? 'Bản đồ không còn đầy đủ. Cần tải lại.'
                                    : package.superseded
                                    ? OfflineUiText.superseded
                                    : OfflineUiText.ready,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color:
                                      package.locked ||
                                          !package.mapResourcesAvailable
                                      ? c.error
                                      : package.superseded
                                      ? c.warning
                                      : c.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                              Divider(height: 20, color: c.borderSubtle),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton(
                                    onPressed:
                                        package.locked ||
                                            !package.mapResourcesAvailable
                                        ? null
                                        : () => context.push(
                                            AppRoutes.offlineItinerary(
                                              package.itineraryId,
                                            ),
                                          ),
                                    child: const Text('Mở'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => context
                                        .push(
                                          AppRoutes.offlinePackage(
                                            package.itineraryId,
                                          ),
                                          extra: package.title,
                                        )
                                        .then((_) {
                                          if (context.mounted) cubit.load();
                                        }),
                                    child: Text(
                                      package.superseded ||
                                              !package.mapResourcesAvailable
                                          ? OfflineUiText.update
                                          : 'Quản lý',
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      if (await confirmOfflineAction(
                                            context,
                                            title: 'Xóa gói đã tải?',
                                            description:
                                                'Gói này sẽ không còn dùng được khi mất mạng.',
                                            action: 'Xóa',
                                          ) &&
                                          context.mounted) {
                                        await cubit.remove(package.itineraryId);
                                      }
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: c.error,
                                    ),
                                    child: const Text('Xóa'),
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
      );
    },
  );
}
