import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/guest/presentation/widgets/guest_hero_banner.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_summary.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_list_cubit.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_list_state.dart';
import 'package:trip_mate_mobile/features/poi/presentation/pages/explore_poi_page.dart';
import 'package:trip_mate_mobile/features/poi/presentation/widgets/poi_image.dart';
import 'package:trip_mate_mobile/features/poi/presentation/widgets/poi_status_and_rating.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/cubit/tour_search_cubit.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/cubit/tour_search_state.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/pages/tour_search_page.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_shimmer.dart';
import 'package:trip_mate_mobile/shared/widgets/app_sliding_bottom_nav.dart';

/// Premium Mobile-First Guest Homepage implementing SRS Screen #35.
///
/// Provides unauthenticated travelers with a welcoming, high-conversion discovery
/// interface featuring primary search, category taxonomy chips, featured POIs,
/// trending Central Vietnam tours, an AI smart itinerary planning CTA, and
/// a thumb-friendly 4-destination bottom navigation bar.
class GuestLandingPage extends StatefulWidget {
  const GuestLandingPage({super.key});

  @override
  State<GuestLandingPage> createState() => _GuestLandingPageState();
}

class _GuestLandingPageState extends State<GuestLandingPage> {
  PoiListCubit? _poiCubit;
  TourSearchCubit? _tourCubit;
  int _selectedCategoryIndex = 0;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    if (serviceLocator.isRegistered<PoiListCubit>()) {
      _poiCubit = serviceLocator<PoiListCubit>();
      _poiCubit!.loadInitial();
    }
    if (serviceLocator.isRegistered<TourSearchCubit>()) {
      _tourCubit = serviceLocator<TourSearchCubit>();
      _tourCubit!.loadInitial();
    }
  }

  @override
  void dispose() {
    _poiCubit?.close();
    _tourCubit?.close();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    await Future.wait([
      if (_poiCubit != null) _poiCubit!.refresh(),
      if (_tourCubit != null) _tourCubit!.refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    PreferredSizeWidget? appBar;
    if (_currentTabIndex == 0) {
      appBar = _buildAppBar(context);
    } else if (_currentTabIndex == 3) {
      appBar = _buildGuestAccountAppBar(context);
    }

    Widget content = Scaffold(
      backgroundColor: AppColors.surface,
      appBar: appBar,
      body: switch (_currentTabIndex) {
        0 => _buildHomeFeed(context),
        1 =>
          _poiCubit != null
              ? const ExplorePoiPage(isTraveler: false)
              : const SizedBox.shrink(),
        2 =>
          _tourCubit != null
              ? const TourSearchPage(isTraveler: false)
              : const SizedBox.shrink(),
        3 => _buildGuestAccountView(context),
        _ => _buildHomeFeed(context),
      },
      bottomNavigationBar: _buildBottomNavigation(context),
    );

    if (_poiCubit != null && _tourCubit != null) {
      return MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _poiCubit!),
          BlocProvider.value(value: _tourCubit!),
        ],
        child: content,
      );
    } else if (_poiCubit != null) {
      return BlocProvider.value(value: _poiCubit!, child: content);
    } else if (_tourCubit != null) {
      return BlocProvider.value(value: _tourCubit!, child: content);
    }

    return content;
  }

  Widget _buildHomeFeed(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.secondary,
      onRefresh: _handleRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.xs),
            // Section A: Compact Welcome & Tagline
            _buildWelcomeSubheader(context),
            const SizedBox(height: AppSpacing.sm),

            // Visual Hero Rotating Banner Area
            const GuestHeroBanner(),
            const SizedBox(height: AppSpacing.md),

            // Section B: Primary Search Bar
            _buildPrimarySearchBar(context),
            const SizedBox(height: AppSpacing.md),

            // Section C: Quick Discovery Categories
            _buildDiscoveryCategories(context),
            const SizedBox(height: AppSpacing.lg),

            // Section D: Featured Destinations / POIs
            _buildFeaturedPoisSection(context),
            const SizedBox(height: AppSpacing.lg),

            // Section E: Trending Tours
            _buildTrendingToursSection(context),
            const SizedBox(height: AppSpacing.lg),

            // Section F: Smart Itinerary Call-to-Action
            _buildSmartItineraryCta(context),
            const SizedBox(height: AppSpacing.lg),

            // Section H: Why Choose TripMate
            _buildWhyTripMateSection(context),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/logo/tripmate_logo_full_512.png',
            height: 28,
            fit: BoxFit.contain,
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () => context.push(AppRoutes.travelerRegistration),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            side: const BorderSide(color: AppColors.line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Đăng ký',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        TextButton(
          onPressed: () => context.push(AppRoutes.login),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            backgroundColor: AppColors.secondary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Đăng nhập',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
      ],
    );
  }

  Widget _buildWelcomeSubheader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hành trình trọn vẹn,\ntrải nghiệm thông minh',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
            height: 1.25,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Khám phá danh lam, ẩm thực và tour du lịch miền Trung cùng AI.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.muted, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildPrimarySearchBar(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Tìm kiếm tour và điểm đến du lịch miền Trung',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _currentTabIndex = 2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0C00152A),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.search,
                    size: 20,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Bạn muốn khám phá nơi nào?',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tìm tour Đà Nẵng, Hội An, Huế...',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.tune,
                    size: 18,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiscoveryCategories(BuildContext context) {
    final categories = <_CategoryItem>[
      const _CategoryItem(
        label: 'Tất cả',
        icon: Icons.travel_explore_outlined,
        categoryId: null,
      ),
      const _CategoryItem(
        label: 'Di sản & Văn hóa',
        icon: Icons.account_balance_outlined,
        categoryId: 1,
      ),
      const _CategoryItem(
        label: 'Bãi biển',
        icon: Icons.beach_access_outlined,
        categoryId: 2,
      ),
      const _CategoryItem(
        label: 'Thiên nhiên',
        icon: Icons.forest_outlined,
        categoryId: 3,
      ),
      const _CategoryItem(
        label: 'Bảo tàng',
        icon: Icons.museum_outlined,
        categoryId: 4,
      ),
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = categories[index];
          final isSelected = _selectedCategoryIndex == index;

          return ChoiceChip(
            showCheckmark: false,
            avatar: Icon(
              item.icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.secondary,
            ),
            label: Text(item.label),
            selected: isSelected,
            onSelected: (_) {
              setState(() => _selectedCategoryIndex = index);
              if (item.categoryId != null) {
                _poiCubit?.selectCategory(item.categoryId);
              } else {
                _poiCubit?.selectCategory(null);
              }
            },
            materialTapTargetSize: MaterialTapTargetSize.padded,
            selectedColor: AppColors.secondary,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: isSelected ? AppColors.secondary : AppColors.line,
            ),
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.ink,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedPoisSection(BuildContext context) {
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
                  'Danh lam thắng cảnh nổi tiếng',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  'Điểm đến biểu tượng không thể bỏ qua tại miền Trung',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () => setState(() => _currentTabIndex = 1),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward, size: 14),
              label: const Text('Khám phá'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_poiCubit != null)
          BlocBuilder<PoiListCubit, PoiListState>(
            builder: (context, state) {
              Widget body;
              if (state.status == PoiListStatus.loading &&
                  state.items.isEmpty) {
                body = _buildPoiSkeletonList();
              } else if (state.items.isNotEmpty) {
                body = _buildDynamicPoiList(state.items);
              } else {
                body = _buildCuratedPoiList(context);
              }
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: body,
              );
            },
          )
        else
          _buildCuratedPoiList(context),
      ],
    );
  }

  Widget _buildDynamicPoiList(List<PoiSummary> pois) {
    final displayPois = pois.take(6).toList(growable: false);

    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: displayPois.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final poi = displayPois[index];
          return Container(
            width: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A00152A),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.push(AppRoutes.poiDetail(poi.id)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 105,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          PoiImage(
                            url: poi.thumbnailUrl,
                            semanticLabel: 'Ảnh ${poi.name}',
                          ),
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                poi.categoryName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          if (poi.averageRating != null)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      color: Color(0xFFF59E0B),
                                      size: 13,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      poi.averageRating!.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            poi.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.place_outlined,
                                size: 12,
                                color: AppColors.muted,
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  poi.address ?? 'Miền Trung, Việt Nam',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ),
                              if (poi.distanceKm != null)
                                Text(
                                  '${poi.distanceKm!.toStringAsFixed(1)} km',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          PoiOpenStatus(isOpen: poi.isOpenNow),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCuratedPoiList(BuildContext context) {
    final curatedPois = [
      {
        'id': 1,
        'name': 'Cầu Rồng Đà Nẵng',
        'category': 'Biểu tượng',
        'location': 'Hải Châu, Đà Nẵng',
        'rating': '4.8',
        'imageUrl':
            'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=600',
      },
      {
        'id': 2,
        'name': 'Phố cổ Hội An',
        'category': 'Di sản UNESCO',
        'location': 'Hội An, Quảng Nam',
        'rating': '4.9',
        'imageUrl':
            'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=600',
      },
      {
        'id': 3,
        'name': 'Đại nội Huế',
        'category': 'Di tích Lịch sử',
        'location': 'Thành phố Huế',
        'rating': '4.8',
        'imageUrl':
            'https://images.unsplash.com/photo-1583417319070-4a69db38a482?w=600',
      },
      {
        'id': 4,
        'name': 'Ngũ Hành Sơn',
        'category': 'Danh thắng Kỳ vĩ',
        'location': 'Ngũ Hành Sơn, Đà Nẵng',
        'rating': '4.7',
        'imageUrl':
            'https://images.unsplash.com/photo-1528127269322-539801943592?w=600',
      },
    ];

    return SizedBox(
      height: 195,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: curatedPois.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final p = curatedPois[index];
          return Container(
            width: 190,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A00152A),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _currentTabIndex = 1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 105,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          PoiImage(
                            url: p['imageUrl'] as String?,
                            semanticLabel: 'Ảnh ${p['name']}',
                          ),
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                p['category'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star,
                                    size: 11,
                                    color: Color(0xFFF59E0B),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    p['rating'] as String,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['name'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.place_outlined,
                                size: 12,
                                color: AppColors.muted,
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  p['location'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.muted,
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildPoiSkeletonList() {
    return AppShimmer(
      child: SizedBox(
        height: 195,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 3,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (_, _) => Container(
            width: 190,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              children: [
                Container(
                  height: 105,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: 120,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 10,
                        width: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrendingToursSection(BuildContext context) {
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
                  'Tour du lịch thịnh hành',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  'Gói tour trọn gói, hướng dẫn viên bản địa',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () => setState(() => _currentTabIndex = 2),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward, size: 14),
              label: const Text('Xem tất cả'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_tourCubit != null)
          BlocBuilder<TourSearchCubit, TourSearchState>(
            builder: (context, state) {
              Widget body;
              if (state.status == TourSearchStatus.loading &&
                  state.items.isEmpty) {
                body = _buildTourSkeletonList();
              } else if (state.items.isNotEmpty) {
                body = _buildDynamicTourList(state.items);
              } else if (state.status == TourSearchStatus.failure) {
                body = _buildTourRetryState(context);
              } else {
                body = _buildCuratedTourList(context);
              }
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: body,
              );
            },
          )
        else
          _buildCuratedTourList(context),
      ],
    );
  }

  Widget _buildDynamicTourList(List<TourSummary> tours) {
    final displayTours = tours.take(5).toList(growable: false);

    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: displayTours.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final tour = displayTours[index];
          return Container(
            width: 230,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A00152A),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.push(
                  AppRoutes.tourDetail(tour.tourId),
                  extra: tour,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 105,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          PoiImage(
                            url: tour.thumbnailUrl,
                            semanticLabel: 'Ảnh tour ${tour.title}',
                          ),
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${tour.durationDays} ngày',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: _buildAvailabilityChip(
                              tour.availabilityStatus,
                              tour.remainingSlots,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tour.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Giá trọn gói',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                  Text(
                                    TripFormatters.formatCurrencyVnd(
                                      tour.basePrice,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                ],
                              ),
                              if (tour.destinations.isNotEmpty)
                                Flexible(
                                  child: Text(
                                    tour.destinations.first,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w500,
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvailabilityChip(
    AvailabilityStatus status,
    int? remainingSlots,
  ) {
    final (label, color) = switch (status) {
      AvailabilityStatus.available => (
        remainingSlots != null ? 'Còn $remainingSlots chỗ' : 'Có chỗ',
        AppColors.success,
      ),
      AvailabilityStatus.soldOut => ('Hết chỗ', AppColors.error),
      AvailabilityStatus.noUpcomingSchedule => ('Chưa mở bán', AppColors.muted),
      AvailabilityStatus.unknown => ('Chi tiết', AppColors.muted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTourRetryState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: AppColors.muted,
            size: 32,
          ),
          const SizedBox(height: 6),
          const Text(
            'Không thể tải danh sách tour du lịch mới nhất',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Kiểm tra kết nối mạng và thử lại, hoặc khám phá danh mục tour.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _tourCubit?.loadInitial(),
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Thử lại', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => context.push(AppRoutes.tourSearch),
                icon: const Icon(Icons.travel_explore, size: 14),
                label: const Text(
                  'Khám phá tour',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCuratedTourList(BuildContext context) {
    final tours = [
      {
        'id': '1',
        'title': 'Khám phá Cố đô Huế & Ca Huế Sông Hương',
        'duration': '1 Ngày',
        'price': 850000,
        'rating': '4.9',
        'imageUrl':
            'https://images.unsplash.com/photo-1583417319070-4a69db38a482?w=600',
      },
      {
        'id': '2',
        'title': 'Bà Nà Hills & Cầu Vàng Trọn Gói',
        'duration': '1 Ngày',
        'price': 1250000,
        'rating': '4.8',
        'imageUrl':
            'https://images.unsplash.com/photo-1528127269322-539801943592?w=600',
      },
      {
        'id': '3',
        'title': 'Tour Hội An Phố Cổ & Rừng Dừa Bảy Mẫu',
        'duration': 'Nửa ngày',
        'price': 650000,
        'rating': '4.9',
        'imageUrl':
            'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=600',
      },
    ];

    return SizedBox(
      height: 215,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tours.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final t = tours[index];
          return Container(
            width: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A00152A),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.push(AppRoutes.tourSearch),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 105,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          PoiImage(
                            url: t['imageUrl'] as String?,
                            semanticLabel: 'Ảnh ${t['title']}',
                          ),
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                t['duration'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star,
                                    size: 11,
                                    color: Color(0xFFF59E0B),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    t['rating'] as String,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t['title'] as String,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                TripFormatters.formatCurrencyVnd(
                                  t['price'] as int,
                                ),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.secondary,
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 12,
                                color: AppColors.muted,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTourSkeletonList() {
    return AppShimmer(
      child: SizedBox(
        height: 215,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 3,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (_, _) => Container(
            width: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              children: [
                Container(
                  height: 105,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: 140,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 12,
                        width: 70,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmartItineraryCta(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00152A), Color(0xFF004D40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF6DF5E1).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 13, color: Color(0xFF6DF5E1)),
                SizedBox(width: 4),
                Text(
                  'TỐI ƯU BỞI AI',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6DF5E1),
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Khám phá nhiều hơn,\nlên lịch trình thông minh hơn',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tự động tối ưu thứ tự tham quan, tránh tắc đường và cá nhân hóa chuyến đi theo sở thích của bạn.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton.icon(
            onPressed: () => context.push(
              Uri(
                path: AppRoutes.login,
                queryParameters: {'from': AppRoutes.createItinerary},
              ).toString(),
            ),
            icon: const Icon(Icons.rocket_launch, size: 16),
            label: const Text('Lên lịch trình cùng AI'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhyTripMateSection(BuildContext context) {
    final benefits = [
      {
        'icon': Icons.alt_route,
        'title': 'Tối ưu lộ trình AI',
        'desc':
            'Sắp xếp thứ tự tham quan thông minh tránh tắc đường và tiết kiệm thời gian.',
      },
      {
        'icon': Icons.offline_pin_outlined,
        'title': 'Hoạt động Offline',
        'desc':
            'Tải trọn bộ bản đồ và lịch trình ngoại tuyến khi không có kết nối 4G/Wifi.',
      },
      {
        'icon': Icons.group_work_outlined,
        'title': 'Đi chung & Định vị nhóm',
        'desc': 'Tạo nhóm du lịch gia đình/bạn bè và chia sẻ vị trí an toàn.',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tại sao chọn TripMate?',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final item in benefits)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              borderRadius: 14,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      size: 22,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['desc'] as String,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  static const _guestDestinations = <AppNavDestination>[
    AppNavDestination(
      label: 'Trang chủ',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    AppNavDestination(
      label: 'Khám phá',
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore,
    ),
    AppNavDestination(
      label: 'Tour',
      icon: Icons.tour_outlined,
      selectedIcon: Icons.tour,
    ),
    AppNavDestination(
      label: 'Tài khoản',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
    ),
  ];

  Widget _buildBottomNavigation(BuildContext context) {
    return AppSlidingBottomNav(
      selectedIndex: _currentTabIndex,
      onDestinationSelected: (index) {
        setState(() => _currentTabIndex = index);
      },
      destinations: _guestDestinations,
    );
  }

  PreferredSizeWidget _buildGuestAccountAppBar(BuildContext context) {
    return AppBar(
      title: const Text(
        'Tài khoản',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: AppColors.primary,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildGuestAccountView(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Profile card
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            borderRadius: 20,
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 38,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Khách du lịch',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Khám phá TripMate không cần tài khoản. Đăng nhập để đồng bộ lịch trình AI và đặt tour.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            context.push(AppRoutes.travelerRegistration),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          side: const BorderSide(color: AppColors.secondary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Tạo tài khoản',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => context.push(AppRoutes.login),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Đăng nhập ngay',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Features card
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            borderRadius: 16,
            child: Column(
              children: [
                _buildSettingsTile(
                  icon: Icons.bookmark_border_rounded,
                  title: 'Tour & Điểm đến đã lưu',
                  subtitle: 'Yêu cầu đăng nhập để đồng bộ',
                  onTap: () => context.push(AppRoutes.login),
                ),
                const Divider(height: 1, indent: 56, color: AppColors.line),
                _buildSettingsTile(
                  icon: Icons.qr_code_scanner_rounded,
                  title: 'Vé tour QR & Đặt chỗ',
                  subtitle: 'Xem vé điện tử và lịch sử chuyến đi',
                  onTap: () => context.push(AppRoutes.login),
                ),
                const Divider(height: 1, indent: 56, color: AppColors.line),
                _buildSettingsTile(
                  icon: Icons.language_rounded,
                  title: 'Ngôn ngữ',
                  subtitle: 'Tiếng Việt (VN)',
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 56, color: AppColors.line),
                _buildSettingsTile(
                  icon: Icons.help_outline_rounded,
                  title: 'Hỗ trợ & Trợ giúp',
                  subtitle: 'FAQ và liên hệ đội ngũ TripMate',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 12,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: AppColors.secondary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryItem {
  const _CategoryItem({
    required this.label,
    required this.icon,
    this.categoryId,
  });

  final String label;
  final IconData icon;
  final int? categoryId;
}
