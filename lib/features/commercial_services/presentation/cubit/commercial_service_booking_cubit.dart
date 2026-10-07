import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_booking_request.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_capability.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_messages.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/cubit/commercial_service_booking_state.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/demo/demo_commercial_service_store.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/get_poi_detail_use_case.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';

final class CommercialServiceBookingCubit
    extends Cubit<CommercialServiceBookingState> {
  CommercialServiceBookingCubit({
    GetPoiDetailUseCase? getPoiDetail,
    bool isDemoMode = false,
    DemoCommercialServiceStore? demoStore,
    DateTime Function()? nowUtcProvider,
  }) : _getPoiDetail = getPoiDetail,
       _demoStore = demoStore ?? DemoCommercialServiceStore.instance,
       _nowUtcProvider = nowUtcProvider ?? (() => DateTime.now().toUtc()),
       super(CommercialServiceBookingState(isDemoMode: isDemoMode));

  final GetPoiDetailUseCase? _getPoiDetail;
  final DemoCommercialServiceStore _demoStore;
  final DateTime Function() _nowUtcProvider;

  Future<void> load({
    required int poiId,
    CommercialServiceDetailComposite? initialComposite,
    String? initialOptionId,
    String? initialDateIso,
    String? prefillFullName,
    String? prefillPhoneNumber,
    String? prefillEmail,
  }) async {
    if (!state.isDemoMode) {
      // Production: UC-31 has NO_BACKEND. Never create fake bookings or fake
      // authoritative amounts. Optionally load real POI summary if available.
      CommercialServiceDetailComposite? prodComposite = initialComposite;
      if (prodComposite == null && _getPoiDetail != null && poiId > 0) {
        try {
          final poi = await _getPoiDetail(poiId);
          if (poi.status.trim().toLowerCase() == 'active') {
            prodComposite = CommercialServiceDetailComposite.fromProductionPoi(
              poi,
            );
          }
        } on Object {
          // Keep prodComposite null if real POI fetch fails; screen remains
          // truthfully in pendingIntegration state.
        }
      }
      emit(
        state.copyWith(
          status: CommercialServiceBookingStatus.pendingIntegration,
          poiId: poiId,
          composite: prodComposite,
          contactFullName: prefillFullName ?? '',
          contactPhoneNumber: prefillPhoneNumber ?? '',
          contactEmail: prefillEmail ?? '',
          clearActiveRequest: true,
          clearValidation: true,
          clearStatusMessage: true,
          clearError: true,
        ),
      );
      return;
    }

    final scenario = DemoCommercialServiceScenario.fromPoiId(poiId);
    final effectiveDateIso =
        (initialDateIso != null && initialDateIso.trim().isNotEmpty)
        ? initialDateIso.trim()
        : DemoCommercialServiceStore.defaultIntendedDateIso;
    final composite =
        initialComposite ??
        _demoStore.resolveComposite(
          scenario: scenario,
          intendedDateIso: effectiveDateIso,
        );

    final defaultOptionId =
        (initialOptionId != null &&
            composite.options.any((o) => o.optionId == initialOptionId))
        ? initialOptionId
        : (composite.options.isNotEmpty
              ? composite.options.first.optionId
              : '');
    final defaultTime =
        (composite.availability?.availableTimeSlots.isNotEmpty ?? false)
        ? composite.availability!.availableTimeSlots.first
        : '14:00';

    emit(
      state.copyWith(
        status: CommercialServiceBookingStatus.ready,
        poiId: poiId,
        composite: composite,
        selectedOptionId: defaultOptionId,
        requestedDateIso: effectiveDateIso,
        requestedTime: defaultTime,
        quantity: 1,
        contactFullName: prefillFullName ?? 'Nguyen Minh Phuc',
        contactPhoneNumber: prefillPhoneNumber ?? '0905123456',
        contactEmail: prefillEmail ?? 'traveler.demo@tripmate.vn',
        fieldErrors: const {},
        clearActiveRequest: true,
        clearValidation: true,
        clearStatusMessage: true,
        clearError: true,
      ),
    );
  }

  void selectOption(String optionId) {
    if (!state.isDemoMode) return;
    emit(
      state.copyWith(
        selectedOptionId: optionId,
        clearValidation: true,
        clearError: true,
      ),
    );
  }

  void updateRequestedDate(String dateIso) {
    if (!state.isDemoMode) return;
    emit(
      state.copyWith(
        requestedDateIso: dateIso,
        clearValidation: true,
        clearError: true,
      ),
    );
  }

  void updateRequestedTime(String time) {
    if (!state.isDemoMode) return;
    emit(
      state.copyWith(
        requestedTime: time,
        clearValidation: true,
        clearError: true,
      ),
    );
  }

  void updateQuantity(int quantity) {
    if (!state.isDemoMode) return;
    final clamped = quantity < 1 ? 1 : quantity;
    emit(
      state.copyWith(
        quantity: clamped,
        clearValidation: true,
        clearError: true,
      ),
    );
  }

  void updateSpecialRequest(String value) {
    if (!state.isDemoMode) return;
    emit(state.copyWith(specialRequest: value));
  }

  void updateContactFullName(String value) {
    if (!state.isDemoMode) return;
    emit(state.copyWith(contactFullName: value, clearValidation: true));
  }

  void updateContactPhoneNumber(String value) {
    if (!state.isDemoMode) return;
    emit(state.copyWith(contactPhoneNumber: value, clearValidation: true));
  }

  void updateContactEmail(String value) {
    if (!state.isDemoMode) return;
    emit(state.copyWith(contactEmail: value, clearValidation: true));
  }

  void toggleSimulateServiceClosed(bool value) {
    if (!state.isDemoMode) return;
    emit(
      state.copyWith(
        simulateServiceClosed: value,
        clearValidation: true,
        clearError: true,
      ),
    );
  }

  void toggleSimulateDateTimeUnavailable(bool value) {
    if (!state.isDemoMode) return;
    emit(
      state.copyWith(
        simulateDateTimeUnavailable: value,
        clearValidation: true,
        clearError: true,
      ),
    );
  }

  void toggleSimulateSystemFailure(bool value) {
    if (!state.isDemoMode) return;
    emit(
      state.copyWith(
        simulateSystemFailure: value,
        clearValidation: true,
        clearError: true,
      ),
    );
  }

  /// Submits the commercial service booking request after `CR-05` dialog
  /// confirmation (`Report 3 SRS Section 3.6.2`).
  void submitRequest() {
    if (!state.isDemoMode) {
      // Production guard: never create a fake booking or fake booking ID.
      emit(
        state.copyWith(
          status: CommercialServiceBookingStatus.pendingIntegration,
          clearActiveRequest: true,
        ),
      );
      return;
    }

    final composite = state.composite;
    if (composite == null || !composite.isCommercialPoi) {
      emit(
        state.copyWith(
          validationMessage: CommercialServiceMessages.msg75,
          clearActiveRequest: true,
        ),
      );
      return;
    }

    // 1. Required fields validation -> MSG01 (Abnormal Case 3.a1).
    final fieldErrors = <String, String>{};
    if (state.selectedOptionId.trim().isEmpty || state.selectedOption == null) {
      fieldErrors['selectedOption'] = CommercialServiceMessages.msg01;
    }
    if (state.requestedDateIso.trim().isEmpty) {
      fieldErrors['requestedDate'] = CommercialServiceMessages.msg01;
    }
    if (state.requestedTime.trim().isEmpty) {
      fieldErrors['requestedTime'] = CommercialServiceMessages.msg01;
    }
    if (state.contactFullName.trim().isEmpty) {
      fieldErrors['contactFullName'] = CommercialServiceMessages.msg01;
    }
    if (state.contactPhoneNumber.trim().isEmpty) {
      fieldErrors['contactPhoneNumber'] = CommercialServiceMessages.msg01;
    }
    if (state.contactEmail.trim().isEmpty) {
      fieldErrors['contactEmail'] = CommercialServiceMessages.msg01;
    }
    if (state.quantity <= 0) {
      fieldErrors['quantity'] = CommercialServiceMessages.msg01;
    }

    if (fieldErrors.isNotEmpty) {
      emit(
        state.copyWith(
          fieldErrors: fieldErrors,
          validationMessage: CommercialServiceMessages.msg01,
          clearStatusMessage: true,
          clearError: true,
        ),
      );
      return;
    }

    // 2. Requested date in the past -> MSG76 (Abnormal Case 2.a1).
    // Uses canonical Vietnam planning wall-clock date (UTC+7) to avoid naive
    // UTC boundary string comparisons.
    final parsedDate = _tryParseIsoDate(state.requestedDateIso.trim());
    if (parsedDate == null) {
      emit(
        state.copyWith(
          fieldErrors: const {'requestedDate': CommercialServiceMessages.msg01},
          validationMessage: CommercialServiceMessages.msg01,
          clearStatusMessage: true,
          clearError: true,
        ),
      );
      return;
    }
    final vietnamNow = planningWallClockNow(_nowUtcProvider());
    final todayDateUtc = DateTime.utc(
      vietnamNow.year,
      vietnamNow.month,
      vietnamNow.day,
    );
    if (parsedDate.isBefore(todayDateUtc)) {
      emit(
        state.copyWith(
          fieldErrors: const {'requestedDate': CommercialServiceMessages.msg76},
          validationMessage: CommercialServiceMessages.msg76,
          clearStatusMessage: true,
          clearError: true,
        ),
      );
      return;
    }

    // 3. Service no longer open for booking -> MSG75 (Abnormal Case 7.a3, BR-88).
    if (state.simulateServiceClosed || composite.isOpenForBooking != true) {
      emit(
        state.copyWith(
          fieldErrors: const {},
          validationMessage: CommercialServiceMessages.msg75,
          clearStatusMessage: true,
          clearError: true,
        ),
      );
      return;
    }

    // 4. Requested date or requested time not available -> MSG70 (Abnormal Case 7.a1, BR-88).
    final refreshedComposite = _demoStore.resolveComposite(
      scenario: DemoCommercialServiceScenario.fromPoiId(state.poiId),
      intendedDateIso: state.requestedDateIso.trim(),
    );
    final isDateTimeAvailable =
        !state.simulateDateTimeUnavailable &&
        _demoStore.isDateTimeAvailable(
          requestedDateIso: state.requestedDateIso.trim(),
          requestedTime: state.requestedTime.trim(),
          availability: refreshedComposite.availability,
        );
    if (!isDateTimeAvailable) {
      emit(
        state.copyWith(
          composite: refreshedComposite,
          fieldErrors: const {'availability': CommercialServiceMessages.msg70},
          validationMessage: CommercialServiceMessages.msg70,
          clearStatusMessage: true,
          clearError: true,
        ),
      );
      return;
    }

    // 5. Requested quantity exceeds available quantity -> MSG71 (Abnormal Case 7.a2, BR-88).
    final selectedOption = state.selectedOption!;
    if (state.quantity > selectedOption.availableQuantity) {
      emit(
        state.copyWith(
          fieldErrors: const {'quantity': CommercialServiceMessages.msg71},
          validationMessage: CommercialServiceMessages.msg71,
          clearStatusMessage: true,
          clearError: true,
        ),
      );
      return;
    }

    // 6. System or network failure -> MSG127 (Abnormal Case 8.a1).
    if (state.simulateSystemFailure) {
      emit(
        state.copyWith(
          status: CommercialServiceBookingStatus.failure,
          fieldErrors: const {},
          errorMessage: CommercialServiceMessages.msg127,
          clearValidation: true,
          clearStatusMessage: true,
        ),
      );
      return;
    }

    // 7. Create request with status Pending Confirmation -> MSG69 (BR-89).
    final request = _demoStore.createPendingRequest(
      poiId: composite.poi.id,
      serviceName: composite.poi.name,
      category: composite.commercialCategory!,
      address: composite.poi.address,
      selectedOption: selectedOption,
      requestedDateIso: state.requestedDateIso.trim(),
      requestedTime: state.requestedTime.trim(),
      quantity: state.quantity,
      specialRequest: state.specialRequest,
      contactInfo: CommercialBookingContactInfo(
        fullName: state.contactFullName.trim(),
        phoneNumber: state.contactPhoneNumber.trim(),
        email: state.contactEmail.trim(),
      ),
      nowUtc: _nowUtcProvider(),
    );

    emit(
      state.copyWith(
        status: CommercialServiceBookingStatus.requestActive,
        activeRequest: request,
        fieldErrors: const {},
        statusMessage: CommercialServiceMessages.msg69,
        clearValidation: true,
        clearError: true,
      ),
    );
  }

  /// Simulates the commercial service provider confirming the pending request
  /// (`BR-89` -> `Confirmed`, `MSG72`).
  void simulateProviderConfirm() {
    if (!state.isDemoMode) return;
    final active = state.activeRequest;
    if (active == null ||
        active.status != CommercialBookingStatus.pendingConfirmation) {
      return;
    }
    final updated = _demoStore.confirmRequest(
      active.requestId,
      nowUtc: _nowUtcProvider(),
    );
    if (updated == null) return;
    emit(
      state.copyWith(
        status: CommercialServiceBookingStatus.requestActive,
        activeRequest: updated,
        statusMessage: CommercialServiceMessages.msg72,
        clearValidation: true,
        clearError: true,
      ),
    );
  }

  /// Simulates the commercial service provider rejecting the pending request
  /// (`BR-89` -> `Rejected`, `MSG73`).
  void simulateProviderReject() {
    if (!state.isDemoMode) return;
    final active = state.activeRequest;
    if (active == null ||
        active.status != CommercialBookingStatus.pendingConfirmation) {
      return;
    }
    final updated = _demoStore.rejectRequest(
      active.requestId,
      nowUtc: _nowUtcProvider(),
    );
    if (updated == null) return;
    emit(
      state.copyWith(
        status: CommercialServiceBookingStatus.requestActive,
        activeRequest: updated,
        statusMessage: CommercialServiceMessages.msg73,
        clearValidation: true,
        clearError: true,
      ),
    );
  }

  /// Cancels a `Pending Confirmation` request after `CR-05` confirmation dialog
  /// (`Alternative Flow` -> `Cancelled`, `MSG74`, `BR-76`).
  void cancelPendingRequest() {
    if (!state.isDemoMode) return;
    final active = state.activeRequest;
    if (active == null ||
        active.status != CommercialBookingStatus.pendingConfirmation) {
      return;
    }
    final updated = _demoStore.cancelPendingRequest(
      active.requestId,
      nowUtc: _nowUtcProvider(),
    );
    if (updated == null) return;
    emit(
      state.copyWith(
        status: CommercialServiceBookingStatus.requestActive,
        activeRequest: updated,
        statusMessage: CommercialServiceMessages.msg74,
        clearValidation: true,
        clearError: true,
      ),
    );
  }

  /// Allows the Traveler to start a new booking request after a rejection or
  /// cancellation (`Alternative Flow step 4`).
  void startNewRequest() {
    if (!state.isDemoMode) return;
    emit(
      state.copyWith(
        status: CommercialServiceBookingStatus.ready,
        fieldErrors: const {},
        clearActiveRequest: true,
        clearValidation: true,
        clearStatusMessage: true,
        clearError: true,
      ),
    );
  }

  static DateTime? _tryParseIsoDate(String raw) {
    final parts = raw.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime.utc(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }
}
