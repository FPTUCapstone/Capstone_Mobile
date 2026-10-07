import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_capability.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_category.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_messages.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/cubit/commercial_service_detail_cubit.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/cubit/commercial_service_detail_state.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/demo/demo_commercial_service_store.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_detail.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_summary.dart';
import 'package:trip_mate_mobile/features/poi/presentation/theme/poi_palette.dart';
import 'package:trip_mate_mobile/features/poi/presentation/widgets/poi_image.dart';
import 'package:trip_mate_mobile/features/poi/presentation/widgets/poi_map_projection.dart';
import 'package:trip_mate_mobile/features/poi/presentation/widgets/poi_status_and_rating.dart';

class CommercialServiceDetailPage extends StatelessWidget {
  const CommercialServiceDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<
      CommercialServiceDetailCubit,
      CommercialServiceDetailState
    >(
      builder: (context, state) {
        return switch (state.status) {
          CommercialServiceDetailStatus.initial ||
          CommercialServiceDetailStatus.loading => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          CommercialServiceDetailStatus.inactiveOrNotFound =>
            _CommercialStatusMessagePage(
              key: const Key('commercial_service_msg34_view'),
              icon: Icons.location_off_outlined,
              title: 'Point of Interest Unavailable',
              message: state.errorMessage ?? CommercialServiceMessages.msg34,
              isDemoMode: state.isDemoMode,
              demoScenario: state.demoScenario,
              onSelectDemoScenario: context
                  .read<CommercialServiceDetailCubit>()
                  .selectDemoScenario,
              onBack: () => _handleBack(context),
            ),
          CommercialServiceDetailStatus.failure => _CommercialStatusMessagePage(
            key: const Key('commercial_service_msg127_view'),
            icon: Icons.cloud_off_outlined,
            title: 'Unable to Load Commercial Service',
            message: state.errorMessage ?? CommercialServiceMessages.msg127,
            isDemoMode: state.isDemoMode,
            demoScenario: state.demoScenario,
            onSelectDemoScenario: context
                .read<CommercialServiceDetailCubit>()
                .selectDemoScenario,
            onBack: () => _handleBack(context),
            onRetry: context.read<CommercialServiceDetailCubit>().retry,
          ),
          CommercialServiceDetailStatus.loaded => _CommercialServiceLoadedBody(
            state: state,
            onBack: () => _handleBack(context),
          ),
        };
      },
    );
  }

  static void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.commercialServicesSearch);
    }
  }
}

class _CommercialServiceLoadedBody extends StatelessWidget {
  const _CommercialServiceLoadedBody({
    required this.state,
    required this.onBack,
  });

  final CommercialServiceDetailState state;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final composite = state.composite!;
    final poi = composite.poi;
    final cubit = context.read<CommercialServiceDetailCubit>();

    return Scaffold(
      backgroundColor: PoiPalette.background,
      appBar: AppBar(
        backgroundColor: PoiPalette.navy,
        foregroundColor: Colors.white,
        leading: IconButton(
          key: const Key('commercial_service_back_button'),
          onPressed: onBack,
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          composite.isCommercialPoi
              ? 'Commercial Service Detail'
              : 'Point of Interest Detail',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (kDebugMode && state.isDemoMode) ...[
                    _DemoScenarioBanner(
                      activeScenario: state.demoScenario,
                      intendedDateIso: state.intendedDateIso,
                      onSelectScenario: cubit.selectDemoScenario,
                      onSelectDate: cubit.updateIntendedDate,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _CommercialPhotoGallery(
                    photos: poi.photos,
                    poiName: poi.name,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _CategoryBadge(label: poi.categoryName, emphasized: true),
                      if (composite.commercialCategory != null)
                        const _CategoryBadge(
                          label: 'Commercial Service (BR-87)',
                        ),
                      if (!composite.isCommercialPoi)
                        const _CategoryBadge(
                          label: 'Ordinary POI (Non-Commercial)',
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    poi.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: PoiPalette.navy,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 14,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      PoiRating(
                        rating: poi.averageRating,
                        reviewCount: poi.reviewCount,
                      ),
                      PoiOpenStatus(isOpen: poi.isOpenNow),
                    ],
                  ),
                  if (!composite.isCommercialDataBackedByServer &&
                      composite.isCommercialPoi) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      container: true,
                      label:
                          'Production Partial Backend Notice: Base POI details are live from Backend, while commercial options, pricing, and display-time availability are pending server integration.',
                      child: Container(
                        key: const Key(
                          'commercial_service_production_partial_banner',
                        ),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFFB300)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, color: Color(0xFFE65100)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Base POI information is loaded from the live TripMate server. Commercial service options, pricing, and display-time availability are pending server integration (BR-88).',
                                style: TextStyle(
                                  color: Color(0xFF4E342E),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (state.noticeMessage != null) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      label: state.noticeMessage,
                      child: Container(
                        key: const Key('commercial_service_msg75_banner'),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE53935)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.block_outlined,
                              color: Color(0xFFC62828),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                state.noticeMessage!,
                                style: const TextStyle(
                                  color: Color(0xFFB71C1C),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _SectionBox(
                    title: 'Service Information',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoRow(
                          icon: Icons.category_outlined,
                          label: 'Category',
                          value: poi.categoryName,
                        ),
                        const Divider(height: 20),
                        _InfoRow(
                          icon: Icons.place_outlined,
                          label: 'Address',
                          value: poi.address ?? 'Address not provided',
                        ),
                        const Divider(height: 20),
                        _InfoRow(
                          icon: Icons.my_location_outlined,
                          label: 'Coordinates',
                          value:
                              '${poi.latitude.toStringAsFixed(4)}, ${poi.longitude.toStringAsFixed(4)}',
                        ),
                        if (composite.isCommercialPoi) ...[
                          const Divider(height: 20),
                          _InfoRow(
                            icon: Icons.phone_outlined,
                            label: 'Contact Information',
                            value:
                                composite.contactInfo ??
                                'Pending Server Integration (Not returned by POI endpoint)',
                          ),
                          const Divider(height: 20),
                          _InfoRow(
                            icon: Icons.payments_outlined,
                            label: 'Price Range',
                            value:
                                composite.priceRangeLabel ??
                                'Pending Server Integration (Not returned by POI endpoint)',
                          ),
                        ],
                        if (poi.description != null &&
                            poi.description!.trim().isNotEmpty) ...[
                          const Divider(height: 20),
                          Text(
                            poi.description!,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(height: 1.5),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (composite.isCommercialPoi) ...[
                    const SizedBox(height: 16),
                    _CategorySpecificSection(
                      composite: composite,
                      selectedOptionId: state.selectedOptionId,
                      onSelectOption: cubit.selectOption,
                    ),
                    const SizedBox(height: 16),
                    _AvailabilitySection(
                      composite: composite,
                      intendedDateIso: state.intendedDateIso,
                    ),
                  ],
                  const SizedBox(height: 16),
                  _SectionBox(
                    title: 'Opening Hours',
                    child: _OpeningHoursList(hours: poi.openingHours),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton.icon(
                        key: const Key('commercial_service_view_map_button'),
                        onPressed: () => _showMapSheet(context, poi),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('View on Map'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(140, 48),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(110, 48),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      // BR-87: A point of interest of any other category never exposes a
      // commercial booking action.
      bottomNavigationBar: composite.isCommercialPoi
          ? SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: PoiPalette.line)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      button: true,
                      enabled: composite.canBookService,
                      label: composite.canBookService
                          ? 'Book Service for ${poi.name}'
                          : 'Book Service disabled for ${poi.name}',
                      child: FilledButton.icon(
                        key: const Key('commercial_service_book_button'),
                        onPressed: composite.canBookService
                            ? () => context.push(
                                AppRoutes.commercialServiceBooking(
                                  poi.id,
                                  optionId: state.selectedOptionId,
                                  intendedDate: state.intendedDateIso,
                                  demo: state.isDemoMode,
                                ),
                                extra: composite,
                              )
                            : null,
                        icon: const Icon(Icons.event_available_outlined),
                        label: const Text('Book Service'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: PoiPalette.teal,
                        ),
                      ),
                    ),
                    if (!composite.canBookService) ...[
                      const SizedBox(height: 6),
                      Text(
                        !composite.isCommercialDataBackedByServer
                            ? 'Book Service is unavailable until commercial options and display-time availability are integrated (BR-88).'
                            : (composite.isOpenForBooking == false
                                  ? CommercialServiceMessages.msg75
                                  : 'Book Service requires verified display-time availability for the selected date (BR-88).'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: PoiPalette.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : null,
    );
  }

  static void _showMapSheet(BuildContext context, PoiDetail poi) {
    final summary = PoiSummary(
      id: poi.id,
      name: poi.name,
      categoryId: poi.categoryId,
      categoryName: poi.categoryName,
      latitude: poi.latitude,
      longitude: poi.longitude,
      address: poi.address,
      indoorOutdoor: poi.indoorOutdoor,
      averageVisitDurationMinutes: poi.averageVisitDurationMinutes,
      hasShelter: poi.hasShelter,
      averageRating: poi.averageRating,
      reviewCount: poi.reviewCount,
      thumbnailUrl: poi.photos.isNotEmpty ? poi.photos.first.url : null,
      isOpenNow: poi.isOpenNow,
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _CommercialPoiMapSheet(poi: summary),
    );
  }
}

class _CategorySpecificSection extends StatelessWidget {
  const _CategorySpecificSection({
    required this.composite,
    required this.selectedOptionId,
    required this.onSelectOption,
  });

  final CommercialServiceDetailComposite composite;
  final String? selectedOptionId;
  final ValueChanged<String> onSelectOption;

  @override
  Widget build(BuildContext context) {
    final category = composite.commercialCategory!;
    return _SectionBox(
      title: '${category.specificSectionTitle} (${category.canonicalName})',
      child: !composite.isCommercialDataBackedByServer
          ? Text(
              'Pending Server Integration — ${category.specificSectionTitle} and bookable service options are not returned by GET /api/v1/pois/{id}. No fake ${category.unitLabel} are displayed in Production.',
              key: const Key('commercial_options_pending_notice'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: PoiPalette.muted,
                fontStyle: FontStyle.italic,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (category == CommercialServiceCategory.restaurant &&
                    composite.restaurantInfo != null) ...[
                  Text(
                    'Table Capacity: ${composite.restaurantInfo!.totalTableCapacity} seats',
                    key: const Key('restaurant_table_capacity_text'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: PoiPalette.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Menu Highlights:',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: PoiPalette.teal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final dish
                      in composite.restaurantInfo!.menuHighlights) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.restaurant_menu,
                            size: 16,
                            color: PoiPalette.teal,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(dish)),
                        ],
                      ),
                    ),
                  ],
                  const Divider(height: 24),
                ],
                for (final option in composite.options) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OptionCard(
                      option: option,
                      selected:
                          (selectedOptionId ??
                              composite.options.first.optionId) ==
                          option.optionId,
                      onTap: () => onSelectOption(option.optionId),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final CommercialServiceOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${option.name}, ${_formatVnd(option.unitPriceVnd)} ${option.priceUnitLabel}, ${option.availableQuantity} available',
      child: Material(
        key: Key('commercial_option_${option.optionId}'),
        color: selected ? PoiPalette.tealSoft : PoiPalette.background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? PoiPalette.teal : PoiPalette.line,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: selected ? PoiPalette.teal : PoiPalette.muted,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        option.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: PoiPalette.navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  option.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    Text(
                      '${_formatVnd(option.unitPriceVnd)} / ${option.priceUnitLabel}',
                      style: const TextStyle(
                        color: PoiPalette.teal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (option.capacityLabel != null)
                      Text(
                        '· ${option.capacityLabel}',
                        style: const TextStyle(color: PoiPalette.muted),
                      ),
                    Text(
                      '· ${option.availableQuantity} available',
                      style: const TextStyle(
                        color: PoiPalette.navy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvailabilitySection extends StatelessWidget {
  const _AvailabilitySection({
    required this.composite,
    required this.intendedDateIso,
  });

  final CommercialServiceDetailComposite composite;
  final String intendedDateIso;

  @override
  Widget build(BuildContext context) {
    final availability = composite.availability;
    return _SectionBox(
      title: 'Display-Time Availability (BR-55)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Intended Service Date: $intendedDateIso',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (!composite.isCommercialDataBackedByServer)
            Text(
              'Pending Server Integration — Commercial availability for the intended date cannot be retrieved yet. Book Service remains disabled (BR-88).',
              key: const Key('commercial_availability_pending_notice'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: PoiPalette.muted,
                fontStyle: FontStyle.italic,
              ),
            )
          else if (availability == null || !availability.isRetrieved)
            Text(
              'Commercial availability could not be retrieved at display time (BR-88). Booking is disabled.',
              key: const Key('commercial_availability_missing_notice'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: PoiPalette.muted,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Semantics(
              container: true,
              label: availability.isAvailableForDate
                  ? 'Available on ${availability.intendedDateIso} with ${availability.totalAvailableUnits} units'
                  : 'Unavailable on ${availability.intendedDateIso}',
              child: Container(
                key: const Key('commercial_service_availability_indicator'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: availability.isAvailableForDate
                      ? PoiPalette.tealSoft
                      : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          availability.isAvailableForDate
                              ? Icons.check_circle_outline
                              : Icons.cancel_outlined,
                          color: availability.isAvailableForDate
                              ? PoiPalette.teal
                              : const Color(0xFFC62828),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            availability.isAvailableForDate
                                ? 'Available on ${availability.intendedDateIso} (${availability.totalAvailableUnits} units open)'
                                : 'No availability on ${availability.intendedDateIso}',
                            style: TextStyle(
                              color: availability.isAvailableForDate
                                  ? PoiPalette.navy
                                  : const Color(0xFFB71C1C),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (availability.availableTimeSlots.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Time slots: ${availability.availableTimeSlots.join(', ')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'BR-55: Retrieved at display time only. This indicator is not a reservation or slot hold.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: PoiPalette.muted),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CommercialPoiMapSheet extends StatelessWidget {
  const _CommercialPoiMapSheet({required this.poi});

  final PoiSummary poi;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.map_outlined, color: PoiPalette.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bản đồ minh họa vị trí · ${poi.name}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: PoiPalette.navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('commercial_map_sheet_close_button'),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close map',
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final projected = PoiMapProjection.project([
                    poi,
                  ], Size(constraints.maxWidth, constraints.maxHeight));
                  final point =
                      projected[poi.id] ??
                      Offset(
                        constraints.maxWidth / 2,
                        constraints.maxHeight / 2,
                      );
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ColoredBox(color: PoiPalette.land),
                        ),
                        Positioned(
                          left: point.dx - 24,
                          top: point.dy - 24,
                          child: Semantics(
                            label: 'Map marker for ${poi.name}',
                            child: const CircleAvatar(
                              radius: 24,
                              backgroundColor: PoiPalette.teal,
                              child: Icon(Icons.place, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Coordinates: ${poi.latitude.toStringAsFixed(4)}, ${poi.longitude.toStringAsFixed(4)}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (poi.address != null) ...[
              const SizedBox(height: 4),
              Text(poi.address!),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Return to Commercial Service Detail'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: PoiPalette.teal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoScenarioBanner extends StatelessWidget {
  const _DemoScenarioBanner({
    required this.activeScenario,
    required this.intendedDateIso,
    required this.onSelectScenario,
    required this.onSelectDate,
  });

  final DemoCommercialServiceScenario activeScenario;
  final String intendedDateIso;
  final ValueChanged<DemoCommercialServiceScenario> onSelectScenario;
  final ValueChanged<String> onSelectDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('commercial_service_demo_banner'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PoiPalette.teal),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.science_outlined, color: PoiPalette.teal, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'DEMO MODE (kDebugMode && ?demo=true) — UC-30 Scenarios',
                  style: TextStyle(
                    color: PoiPalette.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final scenario in DemoCommercialServiceScenario.values)
                ChoiceChip(
                  key: Key('demo_scenario_${scenario.name}'),
                  label: Text(scenario.label),
                  selected: activeScenario == scenario,
                  onSelected: (_) => onSelectScenario(scenario),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ActionChip(
                key: const Key('demo_date_available_chip'),
                label: const Text('Date: 2026-10-15 (Available)'),
                onPressed: () => onSelectDate(
                  DemoCommercialServiceStore.defaultIntendedDateIso,
                ),
              ),
              ActionChip(
                key: const Key('demo_date_unavailable_chip'),
                label: const Text('Date: 2026-10-20 (Unavailable)'),
                onPressed: () => onSelectDate(
                  DemoCommercialServiceStore.unavailableDemoDateIso,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommercialPhotoGallery extends StatelessWidget {
  const _CommercialPhotoGallery({required this.photos, required this.poiName});

  final List<PoiPhoto> photos;
  final String poiName;

  @override
  Widget build(BuildContext context) {
    final primaryUrl = photos.isNotEmpty ? photos.first.url : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 200,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PoiImage(
              url: primaryUrl,
              semanticLabel: 'Gallery photo for $poiName',
            ),
            if (photos.isNotEmpty)
              Positioned(
                right: 12,
                bottom: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      '${photos.length} photo(s)',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionBox extends StatelessWidget {
  const _SectionBox({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PoiPalette.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: PoiPalette.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: PoiPalette.teal),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: PoiPalette.muted),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.label, this.emphasized = false});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: emphasized ? PoiPalette.tealSoft : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PoiPalette.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: emphasized ? PoiPalette.teal : PoiPalette.navy,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _OpeningHoursList extends StatelessWidget {
  const _OpeningHoursList({required this.hours});

  final List<PoiOpeningHour> hours;

  static const _days = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  @override
  Widget build(BuildContext context) {
    final byDay = {for (final hour in hours) hour.dayOfWeek: hour};
    return Column(
      children: [
        for (var day = 0; day < 7; day++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(child: Text(_days[day])),
                Flexible(
                  child: Text(
                    _formatHour(byDay[day]),
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: PoiPalette.teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (day < 6) const Divider(height: 1),
        ],
      ],
    );
  }

  static String _formatHour(PoiOpeningHour? hour) {
    if (hour == null ||
        hour.isClosed ||
        hour.openTime == null ||
        hour.closeTime == null) {
      return 'Closed';
    }
    final open = hour.openTime!.length >= 5
        ? hour.openTime!.substring(0, 5)
        : hour.openTime!;
    final close = hour.closeTime!.length >= 5
        ? hour.closeTime!.substring(0, 5)
        : hour.closeTime!;
    return '$open – $close';
  }
}

class _CommercialStatusMessagePage extends StatelessWidget {
  const _CommercialStatusMessagePage({
    required this.icon,
    required this.title,
    required this.message,
    required this.isDemoMode,
    required this.demoScenario,
    required this.onSelectDemoScenario,
    required this.onBack,
    this.onRetry,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool isDemoMode;
  final DemoCommercialServiceScenario demoScenario;
  final ValueChanged<DemoCommercialServiceScenario> onSelectDemoScenario;
  final VoidCallback onBack;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: PoiPalette.navy,
        foregroundColor: Colors.white,
        leading: IconButton(
          key: const Key('commercial_service_status_back_button'),
          onPressed: onBack,
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Commercial Service'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (kDebugMode && isDemoMode) ...[
                    _DemoScenarioBanner(
                      activeScenario: demoScenario,
                      intendedDateIso:
                          DemoCommercialServiceStore.defaultIntendedDateIso,
                      onSelectScenario: onSelectDemoScenario,
                      onSelectDate: (_) {},
                    ),
                    const SizedBox(height: 24),
                  ],
                  Icon(icon, size: 60, color: PoiPalette.teal),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: PoiPalette.navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (onRetry != null) ...[
                    FilledButton.icon(
                      key: const Key('commercial_service_retry_button'),
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(160, 48),
                        backgroundColor: PoiPalette.teal,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  OutlinedButton.icon(
                    key: const Key('commercial_service_inactive_back_button'),
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(160, 48),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatVnd(int amount) {
  final s = amount.toString();
  final buffer = StringBuffer('₫');
  final offset = s.length % 3;
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (i - offset) % 3 == 0) buffer.write(',');
    buffer.write(s[i]);
  }
  return buffer.toString();
}
