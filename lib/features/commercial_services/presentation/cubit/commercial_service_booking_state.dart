import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_booking_request.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_capability.dart';

enum CommercialServiceBookingStatus {
  initial,
  loading,
  pendingIntegration,
  ready,
  submitting,
  requestActive,
  failure,
}

final class CommercialServiceBookingState extends Equatable {
  const CommercialServiceBookingState({
    this.status = CommercialServiceBookingStatus.initial,
    this.poiId = 0,
    this.isDemoMode = false,
    this.composite,
    this.selectedOptionId = '',
    this.requestedDateIso = '',
    this.requestedTime = '',
    this.quantity = 1,
    this.specialRequest = '',
    this.contactFullName = '',
    this.contactPhoneNumber = '',
    this.contactEmail = '',
    this.activeRequest,
    this.fieldErrors = const {},
    this.validationMessage,
    this.statusMessage,
    this.errorMessage,
    this.simulateServiceClosed = false,
    this.simulateDateTimeUnavailable = false,
    this.simulateSystemFailure = false,
  });

  final CommercialServiceBookingStatus status;
  final int poiId;
  final bool isDemoMode;
  final CommercialServiceDetailComposite? composite;
  final String selectedOptionId;
  final String requestedDateIso;
  final String requestedTime;
  final int quantity;
  final String specialRequest;
  final String contactFullName;
  final String contactPhoneNumber;
  final String contactEmail;
  final CommercialServiceBookingRequest? activeRequest;
  final Map<String, String> fieldErrors;
  final String? validationMessage;
  final String? statusMessage;
  final String? errorMessage;

  // Demo simulation toggles (active only when isDemoMode == true).
  final bool simulateServiceClosed;
  final bool simulateDateTimeUnavailable;
  final bool simulateSystemFailure;

  CommercialServiceOption? get selectedOption {
    final options = composite?.options ?? const [];
    for (final option in options) {
      if (option.optionId == selectedOptionId) return option;
    }
    return options.isNotEmpty ? options.first : null;
  }

  /// `BR-63`: In Production (`!isDemoMode`), client arithmetic is never
  /// treated as authoritative (`returns null`). In Demo mode, returns the
  /// deterministic Demo preview amount (`unitPriceVnd * quantity`).
  int? get demoPreviewEstimatedAmountVnd {
    if (!isDemoMode) return null;
    final option = selectedOption;
    if (option == null || quantity <= 0) return null;
    return option.unitPriceVnd * quantity;
  }

  CommercialServiceBookingState copyWith({
    CommercialServiceBookingStatus? status,
    int? poiId,
    bool? isDemoMode,
    CommercialServiceDetailComposite? composite,
    String? selectedOptionId,
    String? requestedDateIso,
    String? requestedTime,
    int? quantity,
    String? specialRequest,
    String? contactFullName,
    String? contactPhoneNumber,
    String? contactEmail,
    CommercialServiceBookingRequest? activeRequest,
    Map<String, String>? fieldErrors,
    String? validationMessage,
    String? statusMessage,
    String? errorMessage,
    bool? simulateServiceClosed,
    bool? simulateDateTimeUnavailable,
    bool? simulateSystemFailure,
    bool clearActiveRequest = false,
    bool clearValidation = false,
    bool clearStatusMessage = false,
    bool clearError = false,
  }) {
    return CommercialServiceBookingState(
      status: status ?? this.status,
      poiId: poiId ?? this.poiId,
      isDemoMode: isDemoMode ?? this.isDemoMode,
      composite: composite ?? this.composite,
      selectedOptionId: selectedOptionId ?? this.selectedOptionId,
      requestedDateIso: requestedDateIso ?? this.requestedDateIso,
      requestedTime: requestedTime ?? this.requestedTime,
      quantity: quantity ?? this.quantity,
      specialRequest: specialRequest ?? this.specialRequest,
      contactFullName: contactFullName ?? this.contactFullName,
      contactPhoneNumber: contactPhoneNumber ?? this.contactPhoneNumber,
      contactEmail: contactEmail ?? this.contactEmail,
      activeRequest: clearActiveRequest
          ? null
          : (activeRequest ?? this.activeRequest),
      fieldErrors: fieldErrors ?? this.fieldErrors,
      validationMessage: clearValidation
          ? null
          : (validationMessage ?? this.validationMessage),
      statusMessage: clearStatusMessage
          ? null
          : (statusMessage ?? this.statusMessage),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      simulateServiceClosed:
          simulateServiceClosed ?? this.simulateServiceClosed,
      simulateDateTimeUnavailable:
          simulateDateTimeUnavailable ?? this.simulateDateTimeUnavailable,
      simulateSystemFailure:
          simulateSystemFailure ?? this.simulateSystemFailure,
    );
  }

  @override
  List<Object?> get props => [
    status,
    poiId,
    isDemoMode,
    composite,
    selectedOptionId,
    requestedDateIso,
    requestedTime,
    quantity,
    specialRequest,
    contactFullName,
    contactPhoneNumber,
    contactEmail,
    activeRequest,
    fieldErrors,
    validationMessage,
    statusMessage,
    errorMessage,
    simulateServiceClosed,
    simulateDateTimeUnavailable,
    simulateSystemFailure,
  ];
}
