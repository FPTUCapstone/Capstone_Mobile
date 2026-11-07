import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/network_info.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/domain/entities/traveler_emergency_status.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/domain/usecases/traveler_emergency_use_cases.dart';

final class TravelerEmergencyNoticesState extends Equatable {
  const TravelerEmergencyNoticesState({this.notices = const []});

  final List<TravelerEmergencyNotice> notices;

  List<TravelerEmergencyNotice> get unread =>
      notices.where((notice) => notice.requiresAcknowledgement).toList();

  bool hasNoticeFor(int bookingId) =>
      notices.any((notice) => notice.bookingId == bookingId);

  @override
  List<Object?> get props => [notices];
}

/// The Traveler's server-backed notices, shared by the banner and Trip History,
/// so a denied or missed push still leads to the decision.
final class TravelerEmergencyNoticesCubit
    extends Cubit<TravelerEmergencyNoticesState> {
  TravelerEmergencyNoticesCubit({
    required GetTravelerEmergencyNoticesUseCase getNotices,
    required NetworkInfo networkInfo,
  }) : _getNotices = getNotices,
       _networkInfo = networkInfo,
       super(const TravelerEmergencyNoticesState()) {
    _connectivity = _networkInfo.onConnectivityChanged.listen((connected) {
      if (connected) unawaited(refresh());
    });
  }

  final GetTravelerEmergencyNoticesUseCase _getNotices;
  final NetworkInfo _networkInfo;
  late final StreamSubscription<bool> _connectivity;

  /// Bumped by [reset] so a late response cannot restore another account's data.
  int _generation = 0;

  Future<void> refresh() async {
    final generation = _generation;
    if (!await _networkInfo.isConnected) return;
    try {
      final notices = await _getNotices();
      if (!isClosed && generation == _generation) {
        emit(TravelerEmergencyNoticesState(notices: notices));
      }
    } on Failure {
      // Discovery is best effort: what is known stays, and the next resume retries.
    }
  }

  void reset() {
    _generation++;
    emit(const TravelerEmergencyNoticesState());
  }

  @override
  Future<void> close() async {
    await _connectivity.cancel();
    return super.close();
  }
}
