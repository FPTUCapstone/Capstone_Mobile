import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/in_app_notification.dart';

enum InAppInboxStatus { initial, loading, ready, error }

final class InAppInboxState extends Equatable {
  const InAppInboxState({
    this.status = InAppInboxStatus.initial,
    this.items = const [],
    this.unreadOnly = false,
    this.nextBeforeId,
    this.isLoadingMore = false,
    this.markingReadIds = const {},
    this.errorMessage,
    this.pageError,
    this.actionError,
  });

  final InAppInboxStatus status;
  final List<InAppNotification> items;
  final bool unreadOnly;
  final int? nextBeforeId;
  final bool isLoadingMore;
  final Set<int> markingReadIds;
  final String? errorMessage;
  final String? pageError;
  final String? actionError;

  bool get hasMore => nextBeforeId != null;

  @override
  List<Object?> get props => [
    status,
    items,
    unreadOnly,
    nextBeforeId,
    isLoadingMore,
    markingReadIds,
    errorMessage,
    pageError,
    actionError,
  ];
}
