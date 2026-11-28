import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/canonical_trip_review.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/reviewable_record_ref.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/canonical_trip_review_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/usecases/canonical_trip_review_use_case.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';

enum CanonicalReviewOutcome { none, created, updated }

final class CanonicalTripReviewState extends Equatable {
  const CanonicalTripReviewState({
    this.context,
    this.busy = false,
    this.message,
    this.outcome = CanonicalReviewOutcome.none,
  });
  final CanonicalReviewContext? context;
  final bool busy;
  final String? message;
  final CanonicalReviewOutcome outcome;

  @override
  List<Object?> get props => [context, busy, message, outcome];
}

final class CanonicalTripReviewCubit extends Cubit<CanonicalTripReviewState> {
  CanonicalTripReviewCubit({required this.reference, required this.useCase})
    : super(const CanonicalTripReviewState());
  final ReviewableRecordRef reference;
  final CanonicalTripReviewUseCase useCase;

  Future<void> load({String? message}) async {
    emit(CanonicalTripReviewState(context: state.context, busy: true));
    try {
      emit(
        CanonicalTripReviewState(
          context: await useCase.load(reference),
          message: message,
        ),
      );
    } on Failure catch (failure) {
      emit(
        CanonicalTripReviewState(
          context: state.context,
          message: _message(failure),
        ),
      );
    } catch (_) {
      emit(
        CanonicalTripReviewState(
          context: state.context,
          message: _message(const ServerFailure()),
        ),
      );
    }
  }

  Future<void> submit({
    required int rating,
    required String title,
    required String content,
    required bool publishDisplayName,
    required List<ReviewPhotoUpload> photos,
  }) async {
    final existing = state.context?.review;
    emit(CanonicalTripReviewState(context: state.context, busy: true));
    try {
      if (existing == null) {
        await useCase.create(
          reference,
          rating: rating,
          title: title,
          content: content,
          publishDisplayName: publishDisplayName,
          photos: photos,
        );
        emit(
          CanonicalTripReviewState(
            context: state.context,
            message: TripHistoryStringsEn.reviewSubmitSuccess,
            outcome: CanonicalReviewOutcome.created,
          ),
        );
      } else {
        await useCase.update(
          reference,
          rating: rating,
          title: title,
          content: content,
          publishDisplayName: publishDisplayName,
          version: existing.version,
        );
        await load(message: TripHistoryStringsEn.reviewUpdateSuccess);
        emit(
          CanonicalTripReviewState(
            context: state.context,
            message: state.message,
            outcome: CanonicalReviewOutcome.updated,
          ),
        );
      }
    } on ConflictFailure catch (failure) {
      if (failure.message == 'trip_review.duplicate') {
        await load(message: _message(failure));
      } else {
        emit(
          CanonicalTripReviewState(
            context: state.context,
            message: _message(failure),
          ),
        );
      }
    } on Failure catch (failure) {
      emit(
        CanonicalTripReviewState(
          context: state.context,
          message: _message(failure),
        ),
      );
    } catch (_) {
      emit(
        CanonicalTripReviewState(
          context: state.context,
          message: _message(const ServerFailure()),
        ),
      );
    }
  }

  static String _message(Failure failure) => switch (failure.message) {
    'trip_review.invalid_input' =>
      'Vui lòng kiểm tra lại thông tin đánh giá và thử lại.',
    'trip_review.not_found' => 'Không tìm thấy đơn đặt tour này.',
    'trip_review.forbidden' =>
      'Bạn chỉ có thể đánh giá đơn đặt tour của chính mình.',
    'trip_review.booking_not_completed' =>
      'Chỉ có thể gửi đánh giá sau khi chuyến đi đã hoàn thành.',
    'trip_review.duplicate' =>
      'Đánh giá đã tồn tại. Nội dung đánh giá hiện có được hiển thị bên dưới.',
    'trip_review.edit_expired' =>
      'Đã hết thời hạn 7 ngày chỉnh sửa. Đánh giá này hiện chỉ có thể xem.',
    'trip_review.stale_version' =>
      'Đánh giá này vừa được thay đổi ở nơi khác. Vui lòng tải lại trước khi lưu.',
    'trip_review.policy_rejected' =>
      'Đánh giá bị từ chối do vi phạm chính sách nội dung.',
    'trip_review.policy_unavailable' =>
      'Hệ thống kiểm duyệt nội dung tạm thời gián đoạn. Vui lòng thử lại.',
    'trip_review.unsupported_subject' =>
      'Đơn đặt này không hỗ trợ gửi đánh giá.',
    'trip_review.unsupported_media_type' =>
      'Chỉ hỗ trợ ảnh định dạng JPEG, PNG hoặc WebP.',
    'trip_review.body_too_large' => 'Ảnh đã chọn có dung lượng quá lớn.',
    'trip_review.invalid_response' =>
      'Dịch vụ đánh giá trả về phản hồi không hợp lệ.',
    _ when failure is NetworkFailure => 'Vui lòng kiểm tra kết nối mạng.',
    _ when failure is AuthenticationFailure =>
      'Vui lòng đăng nhập để tiếp tục.',
    _ when failure is PermissionFailure =>
      'Bạn chỉ có thể đánh giá đơn đặt tour của chính mình.',
    _ when failure is NotFoundFailure => 'Không tìm thấy đơn đặt tour này.',
    _ => 'Dịch vụ đánh giá hiện không khả dụng. Vui lòng thử lại.',
  };
}
