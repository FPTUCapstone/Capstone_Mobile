import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/create_itinerary_state.dart';

final class CreateItineraryCubit extends Cubit<CreateItineraryState> {
  CreateItineraryCubit({
    required ItineraryRepository repository,
    String Function()? operationKeyFactory,
  }) : _repository = repository,
       _operationKeyFactory = operationKeyFactory ?? _createUuidV4,
       super(const CreateItineraryState.initial());

  final ItineraryRepository _repository;
  final String Function() _operationKeyFactory;
  String? _operationKey;
  ItineraryGenerationRequest? _lastAttemptRequest;

  Future<void> generate(ItineraryGenerationRequest request) async {
    if (_lastAttemptRequest != null && _lastAttemptRequest != request) {
      _operationKey = null;
    }

    final key = _operationKey ??= _operationKeyFactory();
    _lastAttemptRequest = request;
    emit(const CreateItineraryState.generating());
    try {
      final result = await _repository.generate(
        request: request,
        idempotencyKey: key,
      );
      _operationKey = null;
      _lastAttemptRequest = null;
      emit(CreateItineraryState.success(result));
    } catch (error) {
      final message = switch (error) {
        AuthenticationFailure() =>
          'Your session has expired. Please sign in again to continue.',
        PermissionFailure() =>
          'You do not have permission to create an itinerary.',
        ConflictFailure() => _handleConflict(),
        RoutingProviderFailure failure => failure.message,
        ConstraintFailure failure => failure.message,
        ValidationFailure failure => failure.message,
        _ =>
          'TripMate is temporarily unable to generate your itinerary. Please try again.',
      };
      emit(CreateItineraryState.failure(message));
    }
  }

  String _handleConflict() {
    _operationKey = null;
    _lastAttemptRequest = null;
    return 'This request was already used with different details. Start a new itinerary request.';
  }

  static String _createUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
