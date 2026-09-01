import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum PreferredTransport { motorbike, car, walking, publicBus }

enum TravelPace { relaxed, balanced, packed }

enum TravelInterest { beach, heritage, museum, localFood, nature, nightlife }

enum FoodPreference { noRestriction, vegetarian, halal, noSeafood }

enum RiskTolerance { low, medium, high }

final class TravelPreferencesState extends Equatable {
  const TravelPreferencesState({
    required this.autoApply,
    required this.food,
    required this.interests,
    required this.pace,
    required this.risk,
    required this.transport,
  });

  const TravelPreferencesState.defaults()
    : this(
        autoApply: true,
        food: FoodPreference.noRestriction,
        interests: const {
          TravelInterest.beach,
          TravelInterest.heritage,
          TravelInterest.localFood,
        },
        pace: TravelPace.balanced,
        risk: RiskTolerance.medium,
        transport: PreferredTransport.motorbike,
      );

  final bool autoApply;
  final FoodPreference food;
  final Set<TravelInterest> interests;
  final TravelPace pace;
  final RiskTolerance risk;
  final PreferredTransport transport;

  TravelPreferencesState copyWith({
    bool? autoApply,
    FoodPreference? food,
    Set<TravelInterest>? interests,
    TravelPace? pace,
    RiskTolerance? risk,
    PreferredTransport? transport,
  }) {
    return TravelPreferencesState(
      autoApply: autoApply ?? this.autoApply,
      food: food ?? this.food,
      interests: Set.unmodifiable(interests ?? this.interests),
      pace: pace ?? this.pace,
      risk: risk ?? this.risk,
      transport: transport ?? this.transport,
    );
  }

  @override
  List<Object?> get props => [
    autoApply,
    food,
    ...interests.toList()..sort((a, b) => a.index.compareTo(b.index)),
    pace,
    risk,
    transport,
  ];
}

final class TravelPreferencesCubit extends Cubit<TravelPreferencesState> {
  TravelPreferencesCubit() : super(const TravelPreferencesState.defaults());

  void reset() => emit(const TravelPreferencesState.defaults());

  void setAutoApply({required bool value}) {
    emit(state.copyWith(autoApply: value));
  }

  void setFood(FoodPreference value) => emit(state.copyWith(food: value));

  void setPace(TravelPace value) => emit(state.copyWith(pace: value));

  void setRisk(RiskTolerance value) => emit(state.copyWith(risk: value));

  void setTransport(PreferredTransport value) {
    emit(state.copyWith(transport: value));
  }

  void toggleInterest(TravelInterest value) {
    final interests = Set<TravelInterest>.of(state.interests);
    if (!interests.remove(value)) {
      interests.add(value);
    }
    emit(state.copyWith(interests: interests));
  }
}
