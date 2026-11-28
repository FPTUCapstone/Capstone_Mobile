import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/entities/post_trip_complaint.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/entities/selected_evidence.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/usecases/post_trip_complaint_use_cases.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/validation/post_trip_complaint_validation.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/presentation/cubit/post_trip_complaint_state.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/resources/post_trip_complaint_strings.dart';
import 'package:uuid/uuid.dart';

final class PostTripComplaintCubit extends Cubit<PostTripComplaintState> {
  PostTripComplaintCubit({
    required int bookingId,
    required GetPostTripComplaintContext getContext,
    required SubmitPostTripComplaint submit,
    required AmendPostTripComplaintEvidence amend,
    required DownloadPostTripComplaintEvidence download,
  }) : _bookingId = bookingId,
       _getContext = getContext,
       _submit = submit,
       _amend = amend,
       _download = download,
       super(const PostTripComplaintState());
  final int _bookingId;
  final GetPostTripComplaintContext _getContext;
  final SubmitPostTripComplaint _submit;
  final AmendPostTripComplaintEvidence _amend;
  final DownloadPostTripComplaintEvidence _download;
  String? _submitKey;
  String? _amendKey;
  String? _amendFingerprint;

  Future<void> load() async {
    if (isClosed || state.isBusy) return;
    emit(
      state.copyWith(phase: PostTripComplaintPhase.loading, clearMessage: true),
    );
    try {
      final context = await _getContext(_bookingId);
      if (isClosed) return;
      emit(state.copyWith(context: context, phase: _phase(context)));
    } on Object catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            phase: PostTripComplaintPhase.failure,
            message: _message(error),
          ),
        );
      }
    }
  }

  void setCategory(PostTripComplaintReasonCategory? category) {
    if (isClosed || state.isBusy) return;
    _submitKey = null;
    emit(state.copyWith(category: category, clearCategory: category == null));
  }

  void setDetail(String detail) {
    if (isClosed || state.isBusy) return;
    _submitKey = null;
    emit(state.copyWith(detail: detail));
  }

  void setEvidence(List<SelectedEvidence> evidence) {
    if (isClosed || state.isBusy) return;
    final issue = PostTripComplaintValidation.validateEvidence(
      evidence,
      requireData: true,
    );
    if (issue != null) {
      emit(
        state.copyWith(
          message: PostTripComplaintStrings.validationMessage(issue),
        ),
      );
      return;
    }
    _submitKey = null;
    emit(
      state.copyWith(evidence: List.unmodifiable(evidence), clearMessage: true),
    );
  }

  Future<void> submit() async {
    if (isClosed || state.isBusy) return;
    final context = state.context;
    final category = state.category;
    final detailIssue = PostTripComplaintValidation.validateDetail(
      state.detail,
    );
    final evidenceIssue = PostTripComplaintValidation.validateEvidence(
      state.evidence,
      requireData: true,
    );
    if (context == null ||
        !context.canSubmit ||
        category == null ||
        detailIssue != null ||
        evidenceIssue != null ||
        state.isBusy) {
      if (!state.isBusy) {
        emit(
          state.copyWith(
            message: context == null || !context.canSubmit
                ? PostTripComplaintStrings.windowClosed
                : category == null
                ? 'Vui lòng chọn danh mục lý do.'
                : detailIssue != null
                ? PostTripComplaintStrings.validationMessage(detailIssue)
                : PostTripComplaintStrings.validationMessage(evidenceIssue!),
          ),
        );
      }
      return;
    }
    emit(
      state.copyWith(
        phase: PostTripComplaintPhase.submitting,
        clearMessage: true,
      ),
    );
    try {
      _submitKey ??= const Uuid().v4();
      await _submit(
        bookingId: _bookingId,
        idempotencyKey: _submitKey!,
        category: category,
        detail: state.detail.trim(),
        evidence: state.evidence,
      );
      await _loadFresh();
      _submitKey = null;
    } on Object catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            phase: PostTripComplaintPhase.eligible,
            message: _message(error),
          ),
        );
      }
    }
  }

  Future<void> amend(List<SelectedEvidence> evidence) async {
    if (isClosed || state.isBusy) return;
    final context = state.context;
    final existing = context?.complaint?.evidence ?? const [];
    final issue = PostTripComplaintValidation.validateEvidence(
      evidence,
      existingCount: existing.length,
      existingBytes: existing.fold(0, (sum, item) => sum + item.sizeBytes),
      requireData: true,
    );
    if (context == null ||
        !context.canAmendEvidence ||
        evidence.isEmpty ||
        issue != null ||
        state.isBusy) {
      if (!state.isBusy) {
        emit(
          state.copyWith(
            message: issue != null
                ? PostTripComplaintStrings.validationMessage(issue)
                : 'Vui lòng chọn tệp minh chứng trước khi gửi.',
          ),
        );
      }
      return;
    }
    emit(
      state.copyWith(
        phase: PostTripComplaintPhase.amending,
        clearMessage: true,
      ),
    );
    try {
      // Reuse a key only while the retry payload is exactly the same. A
      // changed evidence selection must receive a fresh key or the server
      // correctly rejects it as an idempotency payload mismatch.
      final fingerprint = _evidenceFingerprint(evidence);
      if (_amendFingerprint != fingerprint) {
        _amendFingerprint = fingerprint;
        _amendKey = const Uuid().v4();
      }
      await _amend(
        bookingId: _bookingId,
        idempotencyKey: _amendKey!,
        evidence: evidence,
      );
      await _loadFresh(PostTripComplaintStrings.evidenceAdded);
      _amendKey = null;
      _amendFingerprint = null;
    } on Object catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            phase: PostTripComplaintPhase.existing,
            message: _message(error),
          ),
        );
      }
    }
  }

  Future<ComplaintEvidenceDownload?> downloadEvidence(int evidenceId) async {
    try {
      return await _download(bookingId: _bookingId, evidenceId: evidenceId);
    } on Object catch (error) {
      if (!isClosed) emit(state.copyWith(message: _message(error)));
      return null;
    }
  }

  Future<void> _loadFresh([
    String message = PostTripComplaintStrings.submitted,
  ]) async {
    final context = await _getContext(_bookingId);
    if (!isClosed) {
      emit(
        PostTripComplaintState(
          context: context,
          phase: _phase(context),
          message: message,
        ),
      );
    }
  }

  static PostTripComplaintPhase _phase(PostTripComplaintContext context) =>
      context.complaint != null
      ? PostTripComplaintPhase.existing
      : context.canSubmit
      ? PostTripComplaintPhase.eligible
      : PostTripComplaintPhase.ineligible;

  static String _evidenceFingerprint(
    List<SelectedEvidence> evidence,
  ) => evidence
      .map(
        (item) =>
            '${item.name}\u0000${item.sizeBytes}\u0000${item.contentType}\u0000${Object.hashAll(item.bytes ?? const <int>[])}',
      )
      .join('\u0001');
  static String _message(Object error) => switch (error) {
    AuthenticationFailure() =>
      'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
    PermissionFailure() => 'Bạn không có quyền truy cập khiếu nại này.',
    NetworkFailure() => 'Vui lòng kiểm tra kết nối mạng và thử lại.',
    RateLimitFailure() =>
      'Bạn thao tác quá nhiều lần. Vui lòng đợi một chút rồi thử lại.',
    ValidationFailure() =>
      'Không thể xác thực khiếu nại. Vui lòng kiểm tra lý do và giới hạn tệp minh chứng rồi thử lại.',
    NotFoundFailure() => 'Không tìm thấy đơn đặt tour này.',
    ConflictFailure() => PostTripComplaintStrings.existing,
    _ => PostTripComplaintStrings.systemError,
  };
}
