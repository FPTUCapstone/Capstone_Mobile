import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/tour_discovery/domain/entities/tour_discovery_item.dart';
import 'package:trip_mate_mobile/features/tour_discovery/presentation/widgets/tour_discovery_feed_states.dart';
import 'package:trip_mate_mobile/features/tour_discovery/presentation/widgets/traveler_tour_discovery_section.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/cubit/tour_search_cubit.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/cubit/tour_search_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/my_trips_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/my_trips_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/traveler_profile_cubit.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_shimmer.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

/// Traveler Home / Dashboard screen implementing SRS #44.
class TravelerHomeDashboardView extends StatefulWidget {
  const TravelerHomeDashboardView({
    super.key,
    this.tourSearchCubit,
    this.isActive = true,
    this.onOpenTours,
    this.onOpenExplore,
  });

  final bool isActive;
  final VoidCallback? onOpenTours;
  final VoidCallback? onOpenExplore;

  final TourSearchCubit? tourSearchCubit;

  @override
  State<TravelerHomeDashboardView> createState() =>
      _TravelerHomeDashboardViewState();
}

class _TravelerHomeDashboardViewState extends State<TravelerHomeDashboardView> {
  TourSearchCubit? _tourCubit;
  bool _ownsCubit = false;
  late final TravelerProfileCubit _profileCubit;

  @override
  void initState() {
    super.initState();
    _profileCubit = serviceLocator<TravelerProfileCubit>();
    unawaited(_profileCubit.load());
    if (widget.tourSearchCubit != null) {
      _tourCubit = widget.tourSearchCubit;
      _ownsCubit = false;
    } else if (serviceLocator.isRegistered<TourSearchCubit>()) {
      _tourCubit = serviceLocator<TourSearchCubit>();
      _ownsCubit = true;
      unawaited(_tourCubit!.loadInitial());
    }
  }

  @override
  void didUpdateWidget(covariant TravelerHomeDashboardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      unawaited(_profileCubit.load());
    }
  }

  @override
  void dispose() {
    _profileCubit.close();
    if (_ownsCubit) {
      _tourCubit?.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.secondary,
      onRefresh: () async {
        await Future.wait([
          _profileCubit.load(),
          context.read<MyTripsCubit>().load(),
          if (_tourCubit != null) _tourCubit!.refresh(),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          const SizedBox(height: AppSpacing.sm),
          // User Greeting & Search Entry
          BlocBuilder<TravelerProfileCubit, TravelerProfileState>(
            bloc: _profileCubit,
            builder: (context, state) => _buildGreetingHeader(
              context,
              state.profile?.fullName.trim() ?? '',
              state.profile?.avatarUrl,
            ),
          ),
          const SizedBox(height: 12),

          // Hero Smart Itinerary Banner (SRS #47)
          _buildSmartPlannerHero(context),
          const SizedBox(height: AppSpacing.md),

          // Active Trip Glance (SRS #52)
          _buildActiveTripGlance(context),

          // Quick Action Hub
          _buildQuickActionHub(context),
          const SizedBox(height: AppSpacing.md),

          // Featured Central Vietnam Tours (SRS #63, #64)
          _buildTourDiscoverySection(context),
          const SizedBox(height: AppSpacing.md),

          // Top Destinations / POIs (SRS #50)
          _buildFeaturedPoisSection(context),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildTourDiscoverySection(BuildContext context) {
    final cubit = _tourCubit;
    if (cubit == null) {
      return TravelerTourDiscoverySection(
        feedState: TourDiscoveryFeedState.empty,
        tours: [],
        onOpenSearch: () => _openTours(context),
      );
    }

    return BlocBuilder<TourSearchCubit, TourSearchState>(
      bloc: cubit,
      builder: (context, state) {
        final TourDiscoveryFeedState feedState;
        final List<TourDiscoveryItem> tours;
        VoidCallback? onRetry;

        if (state.status == TourSearchStatus.loading && state.items.isEmpty) {
          feedState = TourDiscoveryFeedState.loading;
          tours = const [];
          onRetry = null;
        } else if (state.status == TourSearchStatus.failure &&
            state.items.isEmpty) {
          feedState = TourDiscoveryFeedState.error;
          tours = const [];
          onRetry = () => cubit.retryFailedQuery();
        } else if (state.items.isEmpty) {
          feedState = TourDiscoveryFeedState.empty;
          tours = const [];
          onRetry = null;
        } else {
          feedState = TourDiscoveryFeedState.content;
          tours = state.items
              .map(TourDiscoveryItem.fromSummary)
              .toList(growable: false);
          onRetry = null;
        }

        return TravelerTourDiscoverySection(
          onOpenSearch: () => _openTours(context),
          feedState: feedState,
          tours: tours,
          onRetryFeed: onRetry,
        );
      },
    );
  }

  void _openTours(BuildContext context) {
    if (widget.onOpenTours case final callback?) {
      callback();
    } else {
      context.push(AppRoutes.tourSearch);
    }
  }

  void _openExplore(BuildContext context) {
    if (widget.onOpenExplore case final callback?) {
      callback();
    } else {
      context.push(AppRoutes.explore);
    }
  }

  Widget _buildGreetingHeader(
    BuildContext context,
    String name,
    String? avatarUrl,
  ) {
    final fallback = Text(
      name.isNotEmpty ? name[0].toUpperCase() : 'T',
      key: const Key('traveler-home-avatar-fallback'),
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: AppColors.secondary,
      ),
    );
    final imageUrl = avatarUrl?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'Xin chào' : 'Xin chào, $name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Bạn muốn khám phá địa điểm nào hôm nay?',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 19,
              backgroundColor: AppColors.primarySoft,
              child: imageUrl == null || imageUrl.isEmpty
                  ? fallback
                  : ClipOval(
                      child: Image.network(
                        imageUrl,
                        key: const Key('traveler-home-avatar-image'),
                        width: 38,
                        height: 38,
                        fit: BoxFit.cover,
                        semanticLabel: 'Ảnh đại diện của $name',
                        frameBuilder: (_, child, frame, _) =>
                            frame == null ? fallback : child,
                        errorBuilder: (_, _, _) => fallback,
                      ),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Compact single-line search bar launcher
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openTours(context),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: AppColors.secondary,
                  size: 19,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Tìm tour, điểm đến miền Trung...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.muted, fontSize: 13.5),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Tour & POI',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSmartPlannerHero(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F0EA), Color(0xFFF3F6F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC8D7CE)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 12, color: AppColors.primary),
                SizedBox(width: 4),
                Text(
                  'TRỢ LÝ LỊCH TRÌNH AI',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Lên lịch trình thông minh\nchỉ trong 30 giây',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tự động tối ưu điểm tham quan, tuyến đường và chi phí cho hành trình Đà Nẵng - Hội An - Huế.',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.push(AppRoutes.createItinerary),
            icon: const Icon(Icons.auto_awesome_outlined, size: 16),
            label: const Text('Bắt đầu lên lịch trình'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTripGlance(BuildContext context) {
    return BlocBuilder<MyTripsCubit, MyTripsState>(
      builder: (context, state) {
        Widget child;
        if (state.status == MyTripsStatus.loading && state.trips.isEmpty) {
          child = Padding(
            key: const ValueKey('active-trip-loading'),
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: AppShimmer(
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(width: 140, height: 16),
                    SizedBox(height: AppSpacing.sm),
                    SkeletonBox(width: 220, height: 20),
                    SizedBox(height: AppSpacing.xs),
                    SkeletonBox(width: 160, height: 14),
                    SizedBox(height: AppSpacing.md),
                    SkeletonBox(
                      width: double.infinity,
                      height: 42,
                      borderRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
          );
        } else if (state.trips.isNotEmpty) {
          final activeTrip = state.trips.first;
          child = Padding(
            key: const ValueKey('active-trip-content'),
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'CHUYẾN ĐI CỦA BẠN',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      StatusBadge(
                        label: activeTrip.status.toUpperCase(),
                        type: StatusBadgeType.info,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    activeTrip.title ?? 'Chuyến đi khám phá miền Trung',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${activeTrip.stopCount} điểm dừng · Cập nhật gần nhất',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: () => context.push(
                      AppRoutes.itineraryDetailPath(activeTrip.itineraryId),
                    ),
                    icon: const Icon(Icons.navigation_outlined, size: 16),
                    label: const Text('Xem chi tiết & Điều hướng'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          child = const SizedBox.shrink(key: ValueKey('active-trip-empty'));
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: child,
        );
      },
    );
  }

  Widget _buildQuickActionHub(BuildContext context) {
    final actions = [
      const _QuickActionItem(
        icon: Icons.tour_outlined,
        label: 'Tìm tour',
        route: AppRoutes.tourSearch,
        color: Color(0xFF174B4A),
      ),
      const _QuickActionItem(
        icon: Icons.auto_awesome_outlined,
        label: 'Gợi ý tour',
        route: AppRoutes.tourRecommendations,
        color: Color(0xFFB96D4C),
      ),
      const _QuickActionItem(
        icon: Icons.group_add_outlined,
        label: 'Vào nhóm',
        route: AppRoutes.joinTravelGroup,
        color: Color(0xFF286664),
      ),
      const _QuickActionItem(
        icon: Icons.download_for_offline_outlined,
        label: 'Ngoại tuyến',
        route: AppRoutes.offlinePackages,
        color: Color(0xFF995436),
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (actions[i].route == AppRoutes.tourSearch) {
                  _openTours(context);
                } else {
                  context.push(actions[i].route);
                }
              },
              child: Container(
                height: 82,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: actions[i].color.withValues(alpha: 0.12),
                      child: Icon(
                        actions[i].icon,
                        size: 18,
                        color: actions[i].color,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      actions[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFeaturedPoisSection(BuildContext context) {
    const pois = [
      (
        name: 'Cầu Rồng Đà Nẵng',
        cat: 'Danh lam',
        city: 'Đà Nẵng',
        asset: 'assets/images/destinations/danang_dragon_night.jpg',
      ),
      (
        name: 'Phố cổ Hội An',
        cat: 'Di sản',
        city: 'Quảng Nam',
        asset: 'assets/images/destinations/hoian_ancient_town.jpg',
      ),
      (
        name: 'Đại nội Huế',
        cat: 'Lịch sử',
        city: 'Huế',
        asset: 'assets/images/destinations/hue_ngo_mon.jpg',
      ),
      (
        name: 'Ngũ Hành Sơn',
        cat: 'Tâm linh',
        city: 'Đà Nẵng',
        asset: 'assets/images/destinations/marble_mountains.jpg',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Điểm đến không thể bỏ lỡ',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            TextButton(
              onPressed: () => _openExplore(context),
              child: const Text('Khám phá'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.48,
          ),
          itemCount: pois.length,
          itemBuilder: (context, index) {
            final poi = pois[index];
            return InkWell(
              onTap: () => _openExplore(context),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      poi.asset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF174B4A), Color(0xFF0E3231)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.0, 0.45, 1.0],
                          colors: [
                            Color(0x280A2423),
                            Color(0x220A2423),
                            Color(0xCC0A2423),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.42),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          poi.cat,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 9,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            poi.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 11,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  poi.city,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: Colors.white.withValues(alpha: 0.88),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _QuickActionItem {
  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String route;
  final Color color;
}
