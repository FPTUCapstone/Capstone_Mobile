import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/e_ticket/domain/entities/e_ticket.dart';
import 'package:trip_mate_mobile/features/e_ticket/domain/entities/e_ticket_failure.dart';

enum ETicketPhase { loading, ready, failure }

final class ETicketState extends Equatable {
  const ETicketState({
    this.phase = ETicketPhase.loading,
    this.ticket,
    this.failure,
    this.online = true,
    this.refreshing = false,
    this.staleQr = false,
  });

  final ETicketPhase phase;

  /// The last ticket read successfully; kept in memory only, so the QR stays on
  /// screen when the connection drops.
  final ETicket? ticket;
  final ETicketFailureKind? failure;
  final bool online;
  final bool refreshing;

  /// Both the refresh and the re-read failed: the QR on screen may already be revoked.
  final bool staleQr;

  bool get canRefresh =>
      phase == ETicketPhase.ready &&
      (ticket?.status.showsQr ?? false) &&
      online &&
      !refreshing;

  ETicketState copyWith({
    ETicketPhase? phase,
    ETicket? ticket,
    ETicketFailureKind? failure,
    bool clearFailure = false,
    bool? online,
    bool? refreshing,
    bool? staleQr,
  }) => ETicketState(
    phase: phase ?? this.phase,
    ticket: ticket ?? this.ticket,
    failure: clearFailure ? null : (failure ?? this.failure),
    online: online ?? this.online,
    refreshing: refreshing ?? this.refreshing,
    staleQr: staleQr ?? this.staleQr,
  );

  @override
  List<Object?> get props => [
    phase,
    ticket,
    failure,
    online,
    refreshing,
    staleQr,
  ];
}
