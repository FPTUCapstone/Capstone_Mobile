import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/my_trips_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/my_trips_state.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_shimmer.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

/// Traveler Home / Dashboard screen implementing SRS #44.
class TravelerHomeDashboardView extends StatelessWidget {
  const TravelerHomeDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    const name = 'Nguyen Minh Phuc';

    return RefreshIndicator(
      color: AppColors.secondary,
      onRefresh: () async {
        await context.read<MyTripsCubit>().load();
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          const SizedBox(height: AppSpacing.sm),
          // User Greeting & Search Entry
          _buildGreetingHeader(context, name),
          const SizedBox(height: AppSpacing.md),

          // Hero Smart Itinerary Banner (SRS #47)
          _buildSmartPlannerHero(context),
          const SizedBox(height: AppSpacing.lg),

          // Active Trip Glance (SRS #52)
          _buildActiveTripGlance(context),

          // Quick Action Hub
          _buildQuickActionHub(context),
          const SizedBox(height: AppSpacing.lg),

          // Featured Central Vietnam Tours (SRS #63, #64)
          _buildFeaturedToursSection(context),
          const SizedBox(height: AppSpacing.lg),

          // Top Destinations / POIs (SRS #50)
          _buildFeaturedPoisSection(context),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildGreetingHeader(BuildContext context, String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xin chào, $name 👋',
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
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primarySoft,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'T',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // Search bar launcher
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push(AppRoutes.tourSearch),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppColors.muted, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Tìm tour, điểm đến, ẩm thực miền Trung...',
                    style: TextStyle(color: AppColors.muted, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Tour & POI',
                    style: TextStyle(
                      fontSize: 10,
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
          colors: [Color(0xFF00152A), Color(0xFF004D40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: Color(0xFF6DF5E1),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'AI TRIP PLANNER',
                      style: TextStyle(
                        color: Color(0xFF6DF5E1),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Lên lịch trình thông minh\nchỉ trong 30 giây',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tự động tối ưu hóa điểm tham quan, tuyến đường và chi phí cho chuyến du lịch Đà Nẵng - Hội An - Huế.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton.icon(
            onPressed: () => context.push(AppRoutes.createItinerary),
            icon: const Icon(Icons.rocket_launch, size: 16),
            label: const Text('Bắt đầu lên lịch trình'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006B5F),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
      _QuickActionItem(
        icon: Icons.tour_outlined,
        label: 'Search Tours',
        route: AppRoutes.tourSearch,
        color: const Color(0xFF0284C7),
      ),
      _QuickActionItem(
        icon: Icons.recommend_outlined,
        label: 'Tour Recommendations',
        route: AppRoutes.tourRecommendations,
        color: const Color(0xFF0D9488),
      ),
      _QuickActionItem(
        icon: Icons.group_add_outlined,
        label: 'Vào nhóm',
        route: AppRoutes.joinTravelGroup,
        color: const Color(0xFF7C3AED),
      ),
      _QuickActionItem(
        icon: Icons.download_for_offline_outlined,
        label: 'Bản đồ Offline',
        route: AppRoutes.offlinePackage(1),
        color: const Color(0xFFD97706),
      ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: actions
          .map(
            (action) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.push(action.route),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: action.color.withValues(alpha: 0.12),
                          child: Icon(
                            action.icon,
                            size: 20,
                            color: action.color,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          action.label,
                          style: const TextStyle(
                            fontSize: 11,
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
            ),
          )
          .toList(),
    );
  }

  Widget _buildFeaturedToursSection(BuildContext context) {
    // Curated tours showcase
    final sampleTours = [
      _TourCardData(
        id: '1',
        title: 'Khám phá Cố đô Huế & Ca Huế sông Hương',
        duration: '1 Ngày',
        rating: 4.9,
        price: 850000,
        tag: 'Bán chạy',
      ),
      _TourCardData(
        id: '2',
        title: 'Bà Nà Hills & Cầu Vàng trọn gói',
        duration: '1 Ngày',
        rating: 4.8,
        price: 1250000,
        tag: 'Nổi bật',
      ),
      _TourCardData(
        id: '3',
        title: 'Hội An phố cổ & Rừng dừa Bảy Mẫu',
        duration: 'Nửa ngày',
        rating: 4.9,
        price: 650000,
        tag: 'Ưu đãi',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tour nổi bật miền Trung',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            TextButton(
              onPressed: () => context.push(AppRoutes.tourSearch),
              child: const Text('Xem tất cả'),
            ),
          ],
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: sampleTours.length,
            itemBuilder: (context, index) {
              final tour = sampleTours[index];
              return Container(
                width: 240,
                margin: const EdgeInsets.only(right: AppSpacing.sm),
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  onTap: () => context.push(AppRoutes.tourDetail(tour.id)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tour.tag,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                size: 14,
                                color: Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${tour.rating}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          tour.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 13,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            tour.duration,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        TripFormatters.formatCurrencyVnd(tour.price),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedPoisSection(BuildContext context) {
    final pois = [
      {'name': 'Cầu Rồng Đà Nẵng', 'cat': 'Danh lam', 'city': 'Đà Nẵng'},
      {'name': 'Phố cổ Hội An', 'cat': 'Di sản', 'city': 'Quảng Nam'},
      {'name': 'Đại nội Huế', 'cat': 'Lịch sử', 'city': 'Huế'},
      {'name': 'Ngũ Hành Sơn', 'cat': 'Tâm linh', 'city': 'Đà Nẵng'},
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
              onPressed: () => context.push(AppRoutes.explore),
              child: const Text('Khám phá'),
            ),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            childAspectRatio: 2.2,
          ),
          itemCount: pois.length,
          itemBuilder: (context, index) {
            final poi = pois[index];
            return AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              onTap: () => context.push(AppRoutes.explore),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    poi['name']!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${poi['cat']} · ${poi['city']}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  ),
                ],
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

class _TourCardData {
  const _TourCardData({
    required this.id,
    required this.title,
    required this.duration,
    required this.rating,
    required this.price,
    required this.tag,
  });

  final String id;
  final String title;
  final String duration;
  final double rating;
  final int price;
  final String tag;
}
