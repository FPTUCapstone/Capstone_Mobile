import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/network/network_info.dart';
import 'package:trip_mate_mobile/features/e_ticket/domain/entities/e_ticket_failure.dart';
import 'package:trip_mate_mobile/features/e_ticket/domain/usecases/get_e_ticket_use_case.dart';
import 'package:trip_mate_mobile/features/e_ticket/domain/usecases/refresh_e_ticket_qr_use_case.dart';
import 'package:trip_mate_mobile/features/e_ticket/presentation/cubit/e_ticket_state.dart';

/// UC-29 e-ticket screen state. Nothing is persisted; the last ticket stays in
/// memory so the QR can still be shown when the connection drops.
final class ETicketCubit extends Cubit<ETicketState> {
  ETicketCubit({
    required ETicketKey key,
    required GetETicketUseCase getTicket,
    required RefreshETicketQrUseCase refreshQr,
    required NetworkInfo networkInfo,
  }) : _key = key,
       _getTicket = getTicket,
       _refreshQr = refreshQr,
       _networkInfo = networkInfo,
       super(const ETicketState());

  final ETicketKey _key;
  final GetETicketUseCase _getTicket;
  final RefreshETicketQrUseCase _refreshQr;
  final NetworkInfo _networkInfo;
  StreamSubscription<bool>? _connectivity;

  /// Loads the ticket at once; connectivity only gates [refresh], and a failed
  /// connectivity check is treated as online rather than blocking the ticket.
  Future<void> start() async {
    _connectivity ??= _networkInfo.onConnectivityChanged.listen((online) {
      if (!isClosed) emit(state.copyWith(online: online));
    }, onError: (Object _) {});
    await Future.wait([load(), _checkConnectivity()]);
  }

  Future<void> _checkConnectivity() async {
    try {
      final online = await _networkInfo.isConnected;
      if (!isClosed) emit(state.copyWith(online: online));
    } on Object {
      // Keep the default (online): the Backend answer decides what works.
    }
  }

  Future<void> load() async {
    emit(state.copyWith(phase: ETicketPhase.loading, clearFailure: true));
    try {
      final ticket = await _getTicket(_key);
      if (!isClosed) {
        emit(
          state.copyWith(
            phase: ETicketPhase.ready,
            ticket: ticket,
            staleQr: false,
          ),
        );
      }
    } on ETicketFailure catch (failure) {
      if (!isClosed) {
        emit(
          ETicketState(
            phase: ETicketPhase.failure,
            failure: failure.kind,
            online: state.online,
          ),
        );
      }
    }
  }

  /// Revokes the QR and shows the new one. On any failure the ticket is re-read,
  /// because the old QR may already be revoked on the server.
  Future<void> refresh() async {
    final current = state.ticket;
    if (!state.canRefresh || current == null) return;
    emit(state.copyWith(refreshing: true));
    try {
      final ticket = await _refreshQr(current.ticketId);
      if (!isClosed) {
        emit(state.copyWith(ticket: ticket, refreshing: false, staleQr: false));
      }
    } on ETicketFailure {
      try {
        final ticket = await _getTicket(ETicketKey.ticket(current.ticketId));
        if (!isClosed) {
          emit(
            state.copyWith(ticket: ticket, refreshing: false, staleQr: false),
          );
        }
      } on ETicketFailure {
        if (!isClosed) {
          emit(state.copyWith(refreshing: false, staleQr: true));
        }
      }
    }
  }

  @override
  Future<void> close() async {
    await _connectivity?.cancel();
    return super.close();
  }
}
