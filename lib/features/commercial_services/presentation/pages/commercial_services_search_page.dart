import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_category.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_list_item.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_messages.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/cubit/commercial_services_search_cubit.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/cubit/commercial_services_search_state.dart';
import 'package:trip_mate_mobile/features/poi/presentation/theme/poi_palette.dart';
import 'package:trip_mate_mobile/features/poi/presentation/widgets/poi_image.dart';
import 'package:trip_mate_mobile/features/poi/presentation/widgets/poi_status_and_rating.dart';

/// Screen #71: `Commercial Services Search & List`
///
/// Implements UC-30 search and browse requirements under Report 3 V2 Section 3.6.1.
///
/// Multi-criteria search supports:
/// - Category filtering: `Hotel`, `Vehicle Rental`, `Restaurant` (`BR-87`)
/// - Keyword search (`REAL_BACKEND` on `GET /api/v1/pois`)
/// - Intended date availability (`NO_BACKEND` in Production; interactive in Demo)
/// - Commercial price range (`NO_BACKEND` in Production; interactive in Demo)
///
/// Tapping an item navigates to Screen #72 detail portion (`/traveler/services/:poiId`).
class CommercialServicesSearchPage extends StatefulWidget {
  const CommercialServicesSearchPage({super.key});

  @override
  State<CommercialServicesSearchPage> createState() =>
      _CommercialServicesSearchPageState();
}

class _CommercialServicesSearchPageState
    extends State<CommercialServicesSearchPage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    final initialQuery = context
        .read<CommercialServicesSearchCubit>()
        .state
        .searchQuery;
    _searchController = TextEditingController(text: initialQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchSubmitted(String value) {
    context.read<CommercialServicesSearchCubit>().submitSearch(value);
  }

  static String _formatVnd(int amount) {
    final s = amount.toString();
    final buffer = StringBuffer('₫');
    final offset = s.length % 3;
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (i - offset) % 3 == 0) buffer.write(',');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<
      CommercialServicesSearchCubit,
      CommercialServicesSearchState
    >(
      builder: (context, state) {
        final cubit = context.read<CommercialServicesSearchCubit>();

        return Scaffold(
          backgroundColor: PoiPalette.background,
          appBar: AppBar(
            backgroundColor: PoiPalette.navy,
            foregroundColor: Colors.white,
            leading: IconButton(
              key: const Key('commercial_search_back_button'),
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.traveler);
                }
              },
            ),
            title: const Text(
              'Commercial Services (Screen #71)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Top Search & Filter Bar
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Column(
                    children: [
                      // Keyword Search Field
                      TextField(
                        key: const Key('commercial_search_input'),
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: _onSearchSubmitted,
                        decoration: InputDecoration(
                          hintText: 'Search hotels, rentals, restaurants...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  key: const Key(
                                    'commercial_search_clear_button',
                                  ),
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchSubmitted('');
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: PoiPalette.line),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // BR-87 Canonical Category Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              key: const Key('commercial_category_chip_all'),
                              label: const Text('All'),
                              selected: state.selectedCategory == null,
                              onSelected: (_) => cubit.selectCategory(null),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              key: const Key('commercial_category_chip_hotel'),
                              label: const Text('Hotel'),
                              selected:
                                  state.selectedCategory ==
                                  CommercialServiceCategory.hotel,
                              onSelected: (selected) => cubit.selectCategory(
                                selected
                                    ? CommercialServiceCategory.hotel
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              key: const Key(
                                'commercial_category_chip_vehicle',
                              ),
                              label: const Text('Vehicle Rental'),
                              selected:
                                  state.selectedCategory ==
                                  CommercialServiceCategory.vehicleRental,
                              onSelected: (selected) => cubit.selectCategory(
                                selected
                                    ? CommercialServiceCategory.vehicleRental
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              key: const Key(
                                'commercial_category_chip_restaurant',
                              ),
                              label: const Text('Restaurant'),
                              selected:
                                  state.selectedCategory ==
                                  CommercialServiceCategory.restaurant,
                              onSelected: (selected) => cubit.selectCategory(
                                selected
                                    ? CommercialServiceCategory.restaurant
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Mode Banner: Production Truthfulness vs Demo Controls
                if (!state.isDemoMode)
                  Container(
                    key: const Key('commercial_search_production_banner'),
                    width: double.infinity,
                    color: const Color(0xFFFFF8E1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Color(0xFFE65100),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Live catalog from Backend (GET /api/v1/pois). Commercial date availability & price filters are Pending Server Integration.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF4E342E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    key: const Key('commercial_search_demo_banner'),
                    width: double.infinity,
                    color: const Color(0xFFE0F2F1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.bug_report_outlined,
                          size: 18,
                          color: Color(0xFF00796B),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Demo Mode active: Multi-criteria filtering (category, date ${state.selectedDateIso.isNotEmpty ? state.selectedDateIso : '2026-10-15'}, price) enabled with deterministic fixtures.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF004D40),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Main Content
                Expanded(
                  child: switch (state.status) {
                    CommercialServicesSearchStatus.initial ||
                    CommercialServicesSearchStatus.loading => const Center(
                      child: CircularProgressIndicator(
                        key: Key('commercial_search_loading'),
                      ),
                    ),
                    CommercialServicesSearchStatus.failure => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.cloud_off_outlined,
                              size: 48,
                              color: Color(0xFFC62828),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              state.errorMessage ??
                                  CommercialServiceMessages.msg127,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFB71C1C),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              key: const Key('commercial_search_retry_button'),
                              onPressed: cubit.retry,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    CommercialServicesSearchStatus.empty => Center(
                      key: const Key('commercial_search_empty_view'),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.storefront_outlined,
                              size: 48,
                              color: PoiPalette.muted,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No commercial services found matching your criteria.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: PoiPalette.navy,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              key: const Key('commercial_search_reset_button'),
                              onPressed: cubit.resetFilters,
                              child: const Text('Reset filters'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    CommercialServicesSearchStatus.success =>
                      ListView.separated(
                        key: const Key('commercial_search_list'),
                        padding: const EdgeInsets.all(16),
                        itemCount: state.items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = state.items[index];
                          return _CommercialServiceCard(
                            item: item,
                            selectedDateIso: state.selectedDateIso,
                            isDemoMode: state.isDemoMode,
                            formatVnd: _formatVnd,
                          );
                        },
                      ),
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CommercialServiceCard extends StatelessWidget {
  const _CommercialServiceCard({
    required this.item,
    required this.selectedDateIso,
    required this.isDemoMode,
    required this.formatVnd,
  });

  final CommercialServiceListItem item;
  final String selectedDateIso;
  final bool isDemoMode;
  final String Function(int) formatVnd;

  @override
  Widget build(BuildContext context) {
    final targetPath = AppRoutes.commercialServiceDetail(
      item.id,
      intendedDate: selectedDateIso.isNotEmpty ? selectedDateIso : null,
      demo: isDemoMode,
    );

    return InkWell(
      key: Key('commercial_service_card_${item.id}'),
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(targetPath),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PoiPalette.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail / Image
            if (item.thumbnailUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: PoiImage(
                    url: item.thumbnailUrl,
                    semanticLabel: item.name,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2F2EF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.category?.canonicalName ?? item.categoryName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: PoiPalette.navy,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (item.availabilityStatusLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: item.isAvailableForDate == true
                                ? PoiPalette.tealSoft
                                : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.availabilityStatusLabel!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: item.isAvailableForDate == true
                                  ? PoiPalette.teal
                                  : PoiPalette.muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Name
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: PoiPalette.navy,
                    ),
                  ),

                  // Address
                  if (item.address != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.address!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: PoiPalette.muted),
                    ),
                  ],
                  const SizedBox(height: 8),

                  // Rating & Reviews
                  Row(
                    children: [
                      PoiRating(
                        rating: item.rating,
                        reviewCount: item.reviewCount,
                      ),
                      const Spacer(),
                      if (item.startingPriceVnd != null)
                        Text(
                          'From ${formatVnd(item.startingPriceVnd!)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: PoiPalette.teal,
                          ),
                        )
                      else if (item.priceRangeLabel != null)
                        Text(
                          item.priceRangeLabel!,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: PoiPalette.muted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // CTA Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      key: Key('commercial_service_view_details_${item.id}'),
                      onPressed: () => context.push(targetPath),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: PoiPalette.teal,
                        side: const BorderSide(color: PoiPalette.teal),
                      ),
                      child: const Text('View Commercial Details'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
