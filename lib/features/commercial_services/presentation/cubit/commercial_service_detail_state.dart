import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_capability.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/demo/demo_commercial_service_store.dart';

enum CommercialServiceDetailStatus {
  initial,
  loading,
  loaded,
  inactiveOrNotFound,
  failure,
}

final class CommercialServiceDetailState extends Equatable {
  const CommercialServiceDetailState({
    this.status = CommercialServiceDetailStatus.initial,
    this.rawPoiId = '',
    this.intendedDateIso = DemoCommercialServiceStore.defaultIntendedDateIso,
    this.isDemoMode = false,
    this.demoScenario = DemoCommercialServiceScenario.availableHotel,
    this.composite,
    this.selectedOptionId,
    this.noticeMessage,
    this.errorMessage,
  });

  final CommercialServiceDetailStatus status;
  final String rawPoiId;
  final String intendedDateIso;
  final bool isDemoMode;
  final DemoCommercialServiceScenario demoScenario;
  final CommercialServiceDetailComposite? composite;
  final String? selectedOptionId;
  final String? noticeMessage;
  final String? errorMessage;

  CommercialServiceDetailState copyWith({
    CommercialServiceDetailStatus? status,
    String? rawPoiId,
    String? intendedDateIso,
    bool? isDemoMode,
    DemoCommercialServiceScenario? demoScenario,
    CommercialServiceDetailComposite? composite,
    String? selectedOptionId,
    String? noticeMessage,
    String? errorMessage,
    bool clearComposite = false,
    bool clearNotice = false,
    bool clearError = false,
  }) {
    return CommercialServiceDetailState(
      status: status ?? this.status,
      rawPoiId: rawPoiId ?? this.rawPoiId,
      intendedDateIso: intendedDateIso ?? this.intendedDateIso,
      isDemoMode: isDemoMode ?? this.isDemoMode,
      demoScenario: demoScenario ?? this.demoScenario,
      composite: clearComposite ? null : (composite ?? this.composite),
      selectedOptionId: selectedOptionId ?? this.selectedOptionId,
      noticeMessage: clearNotice ? null : (noticeMessage ?? this.noticeMessage),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    status,
    rawPoiId,
    intendedDateIso,
    isDemoMode,
    demoScenario,
    composite,
    selectedOptionId,
    noticeMessage,
    errorMessage,
  ];
}
