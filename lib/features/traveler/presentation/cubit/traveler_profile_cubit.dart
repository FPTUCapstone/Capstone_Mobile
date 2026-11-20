import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/traveler_profile_repository.dart';

class TravelerProfileState {
  const TravelerProfileState({
    this.profile,
    this.busy = false,
    this.error,
    this.saved = false,
  });
  final TravelerProfile? profile;
  final bool busy;
  final String? error;
  final bool saved;
}

class TravelerProfileCubit extends Cubit<TravelerProfileState> {
  TravelerProfileCubit(this.repository) : super(const TravelerProfileState());
  final TravelerProfileRepository repository;
  int _loadGeneration = 0;
  Future<void> load() async {
    if (isClosed) return;
    final generation = ++_loadGeneration;
    emit(const TravelerProfileState(busy: true));
    try {
      final profile = await repository.load();
      if (!isClosed && generation == _loadGeneration) {
        emit(TravelerProfileState(profile: profile));
      }
    } catch (_) {
      if (!isClosed && generation == _loadGeneration) {
        emit(
          const TravelerProfileState(
            error: 'Unable to load your profile. Please retry.',
          ),
        );
      }
    }
  }

  Future<void> save({
    required String fullName,
    required String phoneNumber,
    String? dateOfBirth,
    Uint8List? avatar,
    String? avatarName,
    String? avatarMime,
  }) async {
    if (state.busy) return;
    final previous = state.profile;
    emit(TravelerProfileState(profile: previous, busy: true));
    try {
      final profile = await repository.save(
        fullName: fullName,
        phoneNumber: phoneNumber,
        dateOfBirth: dateOfBirth,
        avatar: avatar,
        avatarName: avatarName,
        avatarMime: avatarMime,
      );
      if (!isClosed) emit(TravelerProfileState(profile: profile, saved: true));
    } catch (_) {
      if (!isClosed) {
        emit(
          TravelerProfileState(
            profile: previous,
            error: 'Unable to save your profile. Please try again.',
          ),
        );
      }
    }
  }
}
