import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/network/network_info.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/offline_trip_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/offline_packages_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/offline_confirmation_dialog.dart';
import 'package:trip_mate_mobile/features/traveler/resources/offline_ui_text.dart';

class OfflinePackagesPage extends StatelessWidget {
  const OfflinePackagesPage({this.repository, super.key});
  final OfflineTripRepository? repository;

  @override
  Widget build(BuildContext context) {
    final repo = repository ?? locateOptional<OfflineTripRepository>();
    if (repo == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(OfflineUiText.title)),
        body: const Center(child: Text(OfflineUiText.loadError)),
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
      final cubit = context.read<OfflinePackagesCubit>();
      final auth = context.watch<AuthSessionCubit?>();
      final offlineSession = auth?.state.isOfflineReadOnly ?? false;
      final signingOut = auth?.state.operation == AuthSessionOperation.signOut;
      return Scaffold(
        appBar: AppBar(
          title: const Text(OfflineUiText.title),
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
                              title: 'Khóa dữ liệu offline?',
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
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: cubit.load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (state.error != null)
                      Card(
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(state.error!),
                              TextButton(
                                onPressed: cubit.load,
                                child: const Text('Thử lại'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (state.unreadable.isNotEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(OfflineUiText.corruption),
                              for (var i = 0; i < state.unreadable.length; i++)
                                TextButton.icon(
                                  icon: const Icon(Icons.delete_outline),
                                  label: Text(
                                    'Xóa gói không đọc được ${i + 1}',
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
                      ),
                    if (state.packages.isEmpty && state.error == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: Column(
                          children: [
                            Icon(Icons.download_for_offline_outlined, size: 48),
                            SizedBox(height: 16),
                            Text(OfflineUiText.empty),
                            SizedBox(height: 8),
                            Text(
                              OfflineUiText.emptyHint,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    for (final package in state.packages)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                package.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Phiên bản ${package.version} · ${OfflineUiText.bytes(package.totalBytes)}',
                              ),
                              Text(
                                'Đã tải ${OfflineUiText.date(package.downloadedAtUtc)}',
                              ),
                              if (package.snapshot.itinerary.validFrom
                                  case final from?)
                                Text('Từ ${OfflineUiText.date(from)}'),
                              if (package.snapshot.itinerary.validTo
                                  case final to?)
                                Text('Đến ${OfflineUiText.date(to)}'),
                              const SizedBox(height: 8),
                              Text(
                                package.locked
                                    ? OfflineUiText.locked
                                    : !package.mapResourcesAvailable
                                    ? 'Bản đồ không còn đầy đủ. Cần tải lại.'
                                    : package.superseded
                                    ? OfflineUiText.superseded
                                    : OfflineUiText.ready,
                              ),
                              const SizedBox(height: 12),
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
