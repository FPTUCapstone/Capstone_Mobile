import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_booking_request.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_capability.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_category.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_list_item.dart';
import 'package:trip_mate_mobile/features/commercial_services/resources/commercial_service_en.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_detail.dart';

/// Deterministic Demo scenarios for UC-30 (`View Commercial Service`) in Debug
/// Demo mode (`kDebugMode && ?demo=true`).
enum DemoCommercialServiceScenario {
  availableHotel(poiId: 901, label: 'Available Hotel'),
  availableVehicleRental(poiId: 902, label: 'Available Vehicle Rental'),
  availableRestaurant(poiId: 903, label: 'Available Restaurant'),
  inactivePoi(poiId: 904, label: 'Inactive POI'),
  unsupportedCategory(poiId: 905, label: 'Unsupported Category (No Book CTA)'),
  availabilityUnavailable(
    poiId: 906,
    label: 'Availability Missing (Book Disabled)',
  ),
  closedForBooking(poiId: 907, label: 'Closed for Booking'),
  systemFailure(poiId: 908, label: 'System Failure');

  const DemoCommercialServiceScenario({
    required this.poiId,
    required this.label,
  });

  final int poiId;
  final String label;

  static DemoCommercialServiceScenario fromPoiId(int poiId) {
    for (final scenario in DemoCommercialServiceScenario.values) {
      if (scenario.poiId == poiId) return scenario;
    }
    return DemoCommercialServiceScenario.availableHotel;
  }
}

/// Isolated, in-memory Demo store for UC-30 and UC-31 (`kDebugMode && ?demo=true`
/// only).
///
/// Never used in Production, never persists to disk or `shared_preferences`,
/// and provides `reset()` for deterministic unit/widget test isolation.
final class DemoCommercialServiceStore {
  DemoCommercialServiceStore._();

  static final DemoCommercialServiceStore instance =
      DemoCommercialServiceStore._();

  static const String defaultIntendedDateIso = '2026-10-15';
  static const String unavailableDemoDateIso = '2026-10-20';
  static const String unavailableDemoTimeSlot = '23:30';

  final Map<String, CommercialServiceBookingRequest> _requestsById = {};
  int _nextSequence = 1001;

  /// Resets all in-memory Demo state for test isolation.
  void reset() {
    _requestsById.clear();
    _nextSequence = 1001;
  }

  List<CommercialServiceBookingRequest> get allRequests =>
      List.unmodifiable(_requestsById.values);

  CommercialServiceBookingRequest? getRequest(String requestId) =>
      _requestsById[requestId];

  /// Returns catalog items for Screen #71 (`Commercial Services Search & List`)
  /// in Demo mode (`kDebugMode && ?demo=true`).
  ///
  /// Supports multi-criteria filtering: category, keyword, date, and price range.
  List<CommercialServiceListItem> getDemoCatalogItems({
    String? keyword,
    CommercialServiceCategory? category,
    String? dateIso,
    int? maxPriceVnd,
  }) {
    final effectiveDate = (dateIso != null && dateIso.trim().isNotEmpty)
        ? dateIso.trim()
        : defaultIntendedDateIso;
    final scenarios = [
      DemoCommercialServiceScenario.availableHotel,
      DemoCommercialServiceScenario.availableVehicleRental,
      DemoCommercialServiceScenario.availableRestaurant,
      DemoCommercialServiceScenario.closedForBooking,
      DemoCommercialServiceScenario.availabilityUnavailable,
    ];

    final results = <CommercialServiceListItem>[];
    for (final s in scenarios) {
      final composite = resolveComposite(
        scenario: s,
        intendedDateIso: effectiveDate,
      );
      if (!composite.isActivePoi || !composite.isCommercialPoi) {
        continue;
      }
      if (category != null && composite.commercialCategory != category) {
        continue;
      }
      if (keyword != null && keyword.trim().isNotEmpty) {
        final query = keyword.trim().toLowerCase();
        final nameMatch = composite.poi.name.toLowerCase().contains(query);
        final addrMatch =
            composite.poi.address?.toLowerCase().contains(query) ?? false;
        if (!nameMatch && !addrMatch) {
          continue;
        }
      }
      final item = CommercialServiceListItem.fromComposite(composite);
      if (maxPriceVnd != null &&
          item.startingPriceVnd != null &&
          item.startingPriceVnd! > maxPriceVnd) {
        continue;
      }
      results.add(item);
    }
    return results;
  }

  /// Returns a deterministic [CommercialServiceDetailComposite] for the given
  /// [scenario] and [intendedDateIso].
  ///
  /// Availability is computed at display time (`BR-55`) and is never treated as
  /// a reservation or slot hold.
  CommercialServiceDetailComposite resolveComposite({
    required DemoCommercialServiceScenario scenario,
    String intendedDateIso = defaultIntendedDateIso,
  }) {
    final nowUtc = DateTime.utc(2026, 10, 7, 2, 0);
    return switch (scenario) {
      DemoCommercialServiceScenario.availableHotel => _buildHotelComposite(
        poiId: 901,
        status: 'Active',
        isOpenForBooking: true,
        includeAvailability: true,
        intendedDateIso: intendedDateIso,
        nowUtc: nowUtc,
      ),
      DemoCommercialServiceScenario.availableVehicleRental =>
        _buildVehicleRentalComposite(
          poiId: 902,
          intendedDateIso: intendedDateIso,
          nowUtc: nowUtc,
        ),
      DemoCommercialServiceScenario.availableRestaurant =>
        _buildRestaurantComposite(
          poiId: 903,
          isOpenForBooking: true,
          intendedDateIso: intendedDateIso,
          nowUtc: nowUtc,
        ),
      DemoCommercialServiceScenario.inactivePoi => _buildHotelComposite(
        poiId: 904,
        status: 'Inactive',
        isOpenForBooking: false,
        includeAvailability: false,
        intendedDateIso: intendedDateIso,
        nowUtc: nowUtc,
      ),
      DemoCommercialServiceScenario.unsupportedCategory =>
        _buildUnsupportedCategoryComposite(poiId: 905, nowUtc: nowUtc),
      DemoCommercialServiceScenario.availabilityUnavailable =>
        _buildHotelComposite(
          poiId: 906,
          status: 'Active',
          isOpenForBooking: true,
          includeAvailability: false,
          intendedDateIso: intendedDateIso,
          nowUtc: nowUtc,
        ),
      DemoCommercialServiceScenario.closedForBooking =>
        _buildRestaurantComposite(
          poiId: 907,
          isOpenForBooking: false,
          intendedDateIso: intendedDateIso,
          nowUtc: nowUtc,
        ),
      DemoCommercialServiceScenario.systemFailure => _buildHotelComposite(
        poiId: 908,
        status: 'Active',
        isOpenForBooking: true,
        includeAvailability: true,
        intendedDateIso: intendedDateIso,
        nowUtc: nowUtc,
      ),
    };
  }

  /// Checks whether `(requestedDateIso, requestedTime)` is available in Demo
  /// mode (`BR-88`).
  bool isDateTimeAvailable({
    required String requestedDateIso,
    required String requestedTime,
    required CommercialAvailabilityInfo? availability,
  }) {
    if (requestedDateIso.trim() == unavailableDemoDateIso) {
      return false;
    }
    if (requestedTime.trim() == unavailableDemoTimeSlot) {
      return false;
    }
    if (availability == null ||
        !availability.isRetrieved ||
        !availability.isAvailableForDate) {
      return false;
    }
    if (availability.availableTimeSlots.isNotEmpty &&
        !availability.availableTimeSlots.contains(requestedTime.trim())) {
      return false;
    }
    return true;
  }

  /// Creates a new [CommercialServiceBookingRequest] in Demo mode with status
  /// `Pending Confirmation` (`BR-89`).
  CommercialServiceBookingRequest createPendingRequest({
    required int poiId,
    required String serviceName,
    required CommercialServiceCategory category,
    required String? address,
    required CommercialServiceOption selectedOption,
    required String requestedDateIso,
    required String requestedTime,
    required int quantity,
    required String? specialRequest,
    required CommercialBookingContactInfo contactInfo,
    DateTime? nowUtc,
  }) {
    final timestamp = nowUtc ?? DateTime.now().toUtc();
    final requestId = 'CSB-DEMO-${_nextSequence++}';
    // BR-63: Estimated amount is computed by TripMate from the service price.
    final estimatedAmountVnd = selectedOption.unitPriceVnd * quantity;
    final request = CommercialServiceBookingRequest(
      requestId: requestId,
      poiId: poiId,
      serviceName: serviceName,
      category: category,
      address: address,
      selectedOption: selectedOption,
      requestedDateIso: requestedDateIso,
      requestedTime: requestedTime,
      quantity: quantity,
      specialRequest: (specialRequest == null || specialRequest.trim().isEmpty)
          ? null
          : specialRequest.trim(),
      contactInfo: contactInfo,
      estimatedAmountVnd: estimatedAmountVnd,
      // BR-89: Always created with Pending Confirmation.
      status: CommercialBookingStatus.pendingConfirmation,
      createdAtUtc: timestamp,
      updatedAtUtc: timestamp,
    );
    _requestsById[requestId] = request;
    return request;
  }

  /// Simulates the commercial service provider confirming a pending request
  /// (`BR-89` -> `Confirmed`, `MSG72`, `PC-03`).
  CommercialServiceBookingRequest? confirmRequest(
    String requestId, {
    DateTime? nowUtc,
  }) {
    final current = _requestsById[requestId];
    if (current == null ||
        current.status != CommercialBookingStatus.pendingConfirmation) {
      return current;
    }
    final updated = current.copyWith(
      status: CommercialBookingStatus.confirmed,
      updatedAtUtc: nowUtc ?? DateTime.now().toUtc(),
      associatedItinerarySummary:
          'Reflected in Associated Itinerary: ${current.serviceName} (${current.selectedOption.name} × ${current.quantity}) on ${current.requestedDateIso} at ${current.requestedTime}.',
    );
    _requestsById[requestId] = updated;
    return updated;
  }

  /// Simulates the commercial service provider rejecting a pending request
  /// (`BR-89` -> `Rejected`, `MSG73`).
  CommercialServiceBookingRequest? rejectRequest(
    String requestId, {
    DateTime? nowUtc,
  }) {
    final current = _requestsById[requestId];
    if (current == null ||
        current.status != CommercialBookingStatus.pendingConfirmation) {
      return current;
    }
    final updated = current.copyWith(
      status: CommercialBookingStatus.rejected,
      updatedAtUtc: nowUtc ?? DateTime.now().toUtc(),
    );
    _requestsById[requestId] = updated;
    return updated;
  }

  /// Simulates the Traveler cancelling a `Pending Confirmation` request
  /// (`Alternative Flow` -> `Cancelled`, `MSG74`, `BR-76`).
  CommercialServiceBookingRequest? cancelPendingRequest(
    String requestId, {
    DateTime? nowUtc,
  }) {
    final current = _requestsById[requestId];
    if (current == null ||
        current.status != CommercialBookingStatus.pendingConfirmation) {
      return current;
    }
    final updated = current.copyWith(
      status: CommercialBookingStatus.cancelled,
      updatedAtUtc: nowUtc ?? DateTime.now().toUtc(),
      refundChannelNotice: CommercialServiceEn.booking.cancelSuccessNotice,
    );
    _requestsById[requestId] = updated;
    return updated;
  }

  static List<PoiOpeningHour> _standardOpeningHours({
    String open = '07:00:00',
    String close = '22:00:00',
  }) => [
    for (var day = 0; day < 7; day++)
      PoiOpeningHour(
        dayOfWeek: day,
        openTime: open,
        closeTime: close,
        isClosed: false,
      ),
  ];

  static CommercialServiceDetailComposite _buildHotelComposite({
    required int poiId,
    required String status,
    required bool isOpenForBooking,
    required bool includeAvailability,
    required String intendedDateIso,
    required DateTime nowUtc,
  }) {
    final isDateAvailable = intendedDateIso.trim() != unavailableDemoDateIso;
    final poi = PoiDetail(
      id: poiId,
      name: 'Sala Danang Beach Hotel (Demo)',
      description:
          'Oceanfront 4-star hotel overlooking My Khe Beach with rooftop infinity pool and airport transfer support.',
      status: status,
      categoryId: 10,
      categoryName: 'Hotel',
      latitude: 16.0618,
      longitude: 108.2462,
      address: '36-38 Lam Hoanh, Phuoc My, Son Tra, Da Nang',
      indoorOutdoor: 'Indoor',
      averageVisitDurationMinutes: 720,
      hasShelter: true,
      scenicScore: 4.7,
      photoRating: 4.8,
      averageRating: 4.8,
      reviewCount: 342,
      isOpenNow: true,
      openingHours: _standardOpeningHours(open: '00:00:00', close: '23:59:00'),
      photos: const [
        PoiPhoto(
          id: 1,
          url: 'https://images.unsplash.com/photo-1566073771259-6a8506099945',
          caption: 'Oceanfront facade & pool deck',
          sortOrder: 1,
        ),
        PoiPhoto(
          id: 2,
          url: 'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b',
          caption: 'Deluxe Ocean View King Room',
          sortOrder: 2,
        ),
      ],
      tags: const [
        PoiTag(id: 1, name: 'Beachfront'),
        PoiTag(id: 2, name: 'Breakfast Included'),
      ],
      createdAtUtc: nowUtc,
      updatedAtUtc: nowUtc,
    );

    const options = [
      CommercialServiceOption(
        optionId: 'hotel-deluxe-ocean',
        name: 'Deluxe Ocean View Room',
        description:
            'King bed · 32m² · Balcony facing My Khe Beach · Breakfast',
        unitPriceVnd: 1450000,
        priceUnitLabel: 'per night',
        availableQuantity: 4,
        capacityLabel: '2 Adults',
      ),
      CommercialServiceOption(
        optionId: 'hotel-family-suite',
        name: 'Premier Family Suite',
        description: '2 Queen beds · 54m² · Living area & sea view',
        unitPriceVnd: 2350000,
        priceUnitLabel: 'per night',
        availableQuantity: 2,
        capacityLabel: '4 Adults',
      ),
    ];

    return CommercialServiceDetailComposite(
      poi: poi,
      commercialCategory: CommercialServiceCategory.hotel,
      isCommercialDataBackedByServer: true,
      contactInfo: '+84 236 3658 555 · reservations@saladanang.demo.vn',
      priceRangeLabel: '₫1,450,000 – ₫2,350,000 / night (Demo)',
      isOpenForBooking: isOpenForBooking,
      options: options,
      availability: includeAvailability
          ? CommercialAvailabilityInfo(
              intendedDateIso: intendedDateIso,
              isRetrieved: true,
              isAvailableForDate: isDateAvailable,
              totalAvailableUnits: isDateAvailable ? 6 : 0,
              availableTimeSlots: isDateAvailable
                  ? const ['14:00', '15:00', '18:00']
                  : const [],
              retrievedAtUtc: nowUtc,
            )
          : null,
    );
  }

  static CommercialServiceDetailComposite _buildVehicleRentalComposite({
    required int poiId,
    required String intendedDateIso,
    required DateTime nowUtc,
  }) {
    final isDateAvailable = intendedDateIso.trim() != unavailableDemoDateIso;
    final poi = PoiDetail(
      id: poiId,
      name: 'Central Coast Mobility Rental (Demo)',
      description:
          'Daily motorbike and self-drive/chauffeured SUV rental service covering Da Nang, Hoi An, and Hai Van Pass.',
      status: 'Active',
      categoryId: 11,
      categoryName: 'Vehicle Rental',
      latitude: 16.0544,
      longitude: 108.2022,
      address: '112 Nguyen Van Linh, Hai Chau, Da Nang',
      indoorOutdoor: 'Mixed',
      averageVisitDurationMinutes: 45,
      hasShelter: true,
      scenicScore: 4.2,
      photoRating: 4.3,
      averageRating: 4.6,
      reviewCount: 198,
      isOpenNow: true,
      openingHours: _standardOpeningHours(open: '06:30:00', close: '21:00:00'),
      photos: const [
        PoiPhoto(
          id: 10,
          url: 'https://images.unsplash.com/photo-1549317661-bd32c8ce0db2',
          caption: 'Fleet of 7-seat touring SUVs & scooters',
          sortOrder: 1,
        ),
      ],
      tags: const [
        PoiTag(id: 3, name: 'Helmet Included'),
        PoiTag(id: 4, name: 'Hotel Delivery'),
      ],
      createdAtUtc: nowUtc,
      updatedAtUtc: nowUtc,
    );

    const options = [
      CommercialServiceOption(
        optionId: 'vehicle-scooter-125',
        name: 'Honda AirBlade 125cc Automatic',
        description: 'Automatic transmission · 2 helmets · Raincoat included',
        unitPriceVnd: 180000,
        priceUnitLabel: 'per day',
        availableQuantity: 5,
        capacityLabel: '2 Riders',
      ),
      CommercialServiceOption(
        optionId: 'vehicle-suv-7seat',
        name: '7-Seat Touring SUV (Automatic)',
        description: 'Automatic transmission · 4 large suitcases · A/C',
        unitPriceVnd: 1200000,
        priceUnitLabel: 'per day',
        availableQuantity: 3,
        capacityLabel: '7 Seats',
      ),
    ];

    return CommercialServiceDetailComposite(
      poi: poi,
      commercialCategory: CommercialServiceCategory.vehicleRental,
      isCommercialDataBackedByServer: true,
      contactInfo: '+84 905 888 222 · fleet@centralcoastrental.demo.vn',
      priceRangeLabel: '₫180,000 – ₫1,200,000 / day (Demo)',
      isOpenForBooking: true,
      options: options,
      availability: CommercialAvailabilityInfo(
        intendedDateIso: intendedDateIso,
        isRetrieved: true,
        isAvailableForDate: isDateAvailable,
        totalAvailableUnits: isDateAvailable ? 8 : 0,
        availableTimeSlots: isDateAvailable
            ? const ['08:00', '09:00', '14:00', '18:00']
            : const [],
        retrievedAtUtc: nowUtc,
      ),
    );
  }

  static CommercialServiceDetailComposite _buildRestaurantComposite({
    required int poiId,
    required bool isOpenForBooking,
    required String intendedDateIso,
    required DateTime nowUtc,
  }) {
    final isDateAvailable = intendedDateIso.trim() != unavailableDemoDateIso;
    final poi = PoiDetail(
      id: poiId,
      name: 'Madame Lan Riverside Dining (Demo)',
      description:
          'Heritage Central Vietnamese garden restaurant along the Han River featuring Hoi An and Hue specialties.',
      status: 'Active',
      categoryId: 12,
      categoryName: 'Restaurant',
      latitude: 16.0772,
      longitude: 108.2240,
      address: '04 Bach Dang, Thach Thang, Hai Chau, Da Nang',
      indoorOutdoor: 'Mixed',
      averageVisitDurationMinutes: 90,
      hasShelter: true,
      scenicScore: 4.6,
      photoRating: 4.7,
      averageRating: 4.7,
      reviewCount: 512,
      isOpenNow: true,
      openingHours: _standardOpeningHours(open: '06:30:00', close: '22:00:00'),
      photos: const [
        PoiPhoto(
          id: 20,
          url: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4',
          caption: 'Lantern-lit riverside courtyard dining',
          sortOrder: 1,
        ),
      ],
      tags: const [
        PoiTag(id: 5, name: 'Vietnamese Cuisine'),
        PoiTag(id: 6, name: 'River View'),
      ],
      createdAtUtc: nowUtc,
      updatedAtUtc: nowUtc,
    );

    const options = [
      CommercialServiceOption(
        optionId: 'rest-garden-table-4',
        name: 'Garden Courtyard Table (4 Guests)',
        description: 'Open-air lantern garden seating · Set menu deposit',
        unitPriceVnd: 600000,
        priceUnitLabel: 'per table',
        availableQuantity: 6,
        capacityLabel: 'Up to 4 Guests',
      ),
      CommercialServiceOption(
        optionId: 'rest-vip-room-10',
        name: 'Private Heritage Dining Room (10 Guests)',
        description: 'Air-conditioned private room overlooking Han River',
        unitPriceVnd: 1800000,
        priceUnitLabel: 'per room',
        availableQuantity: 2,
        capacityLabel: 'Up to 10 Guests',
      ),
    ];

    return CommercialServiceDetailComposite(
      poi: poi,
      commercialCategory: CommercialServiceCategory.restaurant,
      isCommercialDataBackedByServer: true,
      contactInfo: '+84 236 3616 226 · booking@madamelan.demo.vn',
      priceRangeLabel: '₫600,000 – ₫1,800,000 / table (Demo)',
      isOpenForBooking: isOpenForBooking,
      options: options,
      restaurantInfo: const RestaurantSpecificInfo(
        menuHighlights: [
          'Mi Quang Tom Thit (Quang-style Turmeric Noodles)',
          'Banh Xeo Miền Trung (Crispy Vietnamese Pancakes)',
          'Grilled Lemongrass Pork Skewers (Nem Lui)',
          'Steamed Sea Bass with Ginger & Soy',
        ],
        totalTableCapacity: 120,
      ),
      availability: CommercialAvailabilityInfo(
        intendedDateIso: intendedDateIso,
        isRetrieved: true,
        isAvailableForDate: isDateAvailable,
        totalAvailableUnits: isDateAvailable ? 8 : 0,
        availableTimeSlots: isDateAvailable
            ? const ['11:30', '12:30', '18:00', '19:30']
            : const [],
        retrievedAtUtc: nowUtc,
      ),
    );
  }

  static CommercialServiceDetailComposite _buildUnsupportedCategoryComposite({
    required int poiId,
    required DateTime nowUtc,
  }) {
    final poi = PoiDetail(
      id: poiId,
      name: 'Dragon Bridge Heritage Point (Demo)',
      description:
          'Iconic bridge landmark spanning the Han River. Non-commercial POI category that never exposes a booking action.',
      status: 'Active',
      categoryId: 1,
      categoryName: 'Attraction',
      latitude: 16.0611,
      longitude: 108.2275,
      address: 'Nguyen Van Linh, Phuoc Ninh, Hai Chau, Da Nang',
      indoorOutdoor: 'Outdoor',
      averageVisitDurationMinutes: 45,
      hasShelter: false,
      scenicScore: 4.9,
      photoRating: 4.9,
      averageRating: 4.9,
      reviewCount: 1024,
      isOpenNow: true,
      openingHours: _standardOpeningHours(open: '00:00:00', close: '23:59:00'),
      photos: const [],
      tags: const [PoiTag(id: 7, name: 'Landmark')],
      createdAtUtc: nowUtc,
      updatedAtUtc: nowUtc,
    );

    return CommercialServiceDetailComposite.fromProductionPoi(poi);
  }
}
