import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/in_app_notification_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/in_app_inbox_state.dart';

final class InAppInboxCubit extends Cubit<InAppInboxState> {
  InAppInboxCubit(this._repository) : super(const InAppInboxState());

  final InAppNotificationRepository _repository;
  int _loadGeneration = 0;

  Future<void> load() async {
    final generation = ++_loadGeneration;
    final unreadOnly = state.unreadOnly;
    emit(
      InAppInboxState(status: InAppInboxStatus.loading, unreadOnly: unreadOnly),
    );
    try {
      final page = await _repository.getInbox(unreadOnly: unreadOnly);
      if (isClosed || generation != _loadGeneration) return;
      emit(
        InAppInboxState(
          status: InAppInboxStatus.ready,
          items: page.items,
          unreadOnly: unreadOnly,
          nextBeforeId: page.nextBeforeId,
        ),
      );
    } catch (error) {
      if (isClosed || generation != _loadGeneration) return;
      emit(
        InAppInboxState(
          status: InAppInboxStatus.error,
          unreadOnly: unreadOnly,
          errorMessage: _message(error),
        ),
      );
    }
  }

  Future<void> setUnreadOnly(bool unreadOnly) async {
    if (state.unreadOnly == unreadOnly &&
        state.status != InAppInboxStatus.initial) {
      return;
    }
    emit(InAppInboxState(unreadOnly: unreadOnly));
    await load();
  }

  Future<void> loadMore() async {
    final current = state;
    if (current.status != InAppInboxStatus.ready ||
        current.isLoadingMore ||
        current.nextBeforeId == null) {
      return;
    }
    final generation = _loadGeneration;
    emit(
      InAppInboxState(
        status: InAppInboxStatus.ready,
        items: current.items,
        unreadOnly: current.unreadOnly,
        nextBeforeId: current.nextBeforeId,
        isLoadingMore: true,
        markingReadIds: current.markingReadIds,
      ),
    );
    try {
      final page = await _repository.getInbox(
        unreadOnly: current.unreadOnly,
        beforeId: current.nextBeforeId,
      );
      if (isClosed || generation != _loadGeneration) return;
      final existingIds = state.items.map((item) => item.id).toSet();
      emit(
        InAppInboxState(
          status: InAppInboxStatus.ready,
          items: [
            ...state.items,
            ...page.items.where((item) => !existingIds.contains(item.id)),
          ],
          unreadOnly: current.unreadOnly,
          nextBeforeId: page.nextBeforeId,
          markingReadIds: state.markingReadIds,
        ),
      );
    } catch (error) {
      if (isClosed || generation != _loadGeneration) return;
      emit(
        InAppInboxState(
          status: InAppInboxStatus.ready,
          items: state.items,
          unreadOnly: current.unreadOnly,
          nextBeforeId: current.nextBeforeId,
          markingReadIds: state.markingReadIds,
          pageError: _message(error),
        ),
      );
    }
  }

  Future<void> markRead(int notificationId) async {
    if (state.markingReadIds.contains(notificationId) ||
        !state.items.any((item) => item.id == notificationId && !item.isRead)) {
      return;
    }
    final generation = _loadGeneration;
    _emitWithReadStatus(notificationId, true);
    try {
      await _repository.markRead(notificationId);
      if (isClosed || generation != _loadGeneration) return;
      final current = state;
      emit(
        InAppInboxState(
          status: current.status,
          items: current.unreadOnly
              ? current.items
                    .where((item) => item.id != notificationId)
                    .toList()
              : current.items
                    .map(
                      (item) =>
                          item.id == notificationId ? item.markedRead() : item,
                    )
                    .toList(),
          unreadOnly: current.unreadOnly,
          nextBeforeId: current.nextBeforeId,
          isLoadingMore: current.isLoadingMore,
          markingReadIds: {...current.markingReadIds}..remove(notificationId),
          pageError: current.pageError,
        ),
      );
    } catch (error) {
      if (isClosed || generation != _loadGeneration) return;
      _emitWithReadStatus(notificationId, false, actionError: _message(error));
    }
  }

  Future<void> retry() => state.pageError != null ? loadMore() : load();

  void _emitWithReadStatus(int id, bool pending, {String? actionError}) {
    final current = state;
    final ids = {...current.markingReadIds};
    pending ? ids.add(id) : ids.remove(id);
    emit(
      InAppInboxState(
        status: current.status,
        items: current.items,
        unreadOnly: current.unreadOnly,
        nextBeforeId: current.nextBeforeId,
        isLoadingMore: current.isLoadingMore,
        markingReadIds: ids,
        pageError: current.pageError,
        actionError: actionError,
      ),
    );
  }

  String _message(Object error) => error is Failure
      ? error.message
      : 'Something went wrong. Please try again later.';
}
