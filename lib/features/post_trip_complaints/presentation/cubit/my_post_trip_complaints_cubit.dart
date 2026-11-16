import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/entities/post_trip_complaint.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/usecases/post_trip_complaint_use_cases.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/resources/post_trip_complaint_strings.dart';

enum MyPostTripComplaintsPhase { loading, ready, failure }

final class MyPostTripComplaintsState {
  const MyPostTripComplaintsState({
    this.phase = MyPostTripComplaintsPhase.loading,
    this.items = const [],
    this.message,
  });
  final MyPostTripComplaintsPhase phase;
  final List<MyPostTripComplaint> items;
  final String? message;
}

final class MyPostTripComplaintsCubit extends Cubit<MyPostTripComplaintsState> {
  MyPostTripComplaintsCubit(this._list)
    : super(const MyPostTripComplaintsState());
  final ListMyPostTripComplaints _list;
  Future<void> load() async {
    emit(const MyPostTripComplaintsState());
    try {
      final items = await _list();
      if (!isClosed) {
        emit(
          MyPostTripComplaintsState(
            phase: MyPostTripComplaintsPhase.ready,
            items: items,
          ),
        );
      }
    } on Object {
      if (!isClosed) {
        emit(
          const MyPostTripComplaintsState(
            phase: MyPostTripComplaintsPhase.failure,
            message: PostTripComplaintStrings.systemError,
          ),
        );
      }
    }
  }
}
