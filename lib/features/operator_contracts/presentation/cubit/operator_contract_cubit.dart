import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/operator_contracts/domain/entities/operator_contract.dart';
import 'package:trip_mate_mobile/features/operator_contracts/domain/repositories/operator_contract_repository.dart';
import 'package:uuid/uuid.dart';

const _unchanged = Object();

final class OperatorContractState {
  const OperatorContractState({
    this.contract,
    this.loading = false,
    this.busy = false,
    this.documentLoading = false,
    this.documentReviewed = false,
    this.consent = false,
    this.document,
    this.signature,
    this.challenge,
    this.error,
    this.notice,
    this.drawingRevision = 0,
    this.sessionRenewed = false,
    this.pollPaused = false,
    this.challengeExhausted = false,
  });
  final OperatorContract? contract;
  final bool loading,
      busy,
      documentLoading,
      documentReviewed,
      consent,
      sessionRenewed,
      pollPaused,
      challengeExhausted;
  final Uint8List? document, signature;
  final ContractSigningChallenge? challenge;
  final String? error, notice;
  final int drawingRevision;
  OperatorContractState copyWith({
    Object? contract = _unchanged,
    bool? loading,
    bool? busy,
    bool? documentLoading,
    bool? documentReviewed,
    bool? consent,
    Object? document = _unchanged,
    Object? signature = _unchanged,
    Object? challenge = _unchanged,
    Object? error = _unchanged,
    Object? notice = _unchanged,
    int? drawingRevision,
    bool? sessionRenewed,
    bool? pollPaused,
    bool? challengeExhausted,
  }) => OperatorContractState(
    contract: identical(contract, _unchanged)
        ? this.contract
        : contract as OperatorContract?,
    loading: loading ?? this.loading,
    busy: busy ?? this.busy,
    documentLoading: documentLoading ?? this.documentLoading,
    documentReviewed: documentReviewed ?? this.documentReviewed,
    consent: consent ?? this.consent,
    document: identical(document, _unchanged)
        ? this.document
        : document as Uint8List?,
    signature: identical(signature, _unchanged)
        ? this.signature
        : signature as Uint8List?,
    challenge: identical(challenge, _unchanged)
        ? this.challenge
        : challenge as ContractSigningChallenge?,
    error: identical(error, _unchanged) ? this.error : error as String?,
    notice: identical(notice, _unchanged) ? this.notice : notice as String?,
    drawingRevision: drawingRevision ?? this.drawingRevision,
    sessionRenewed: sessionRenewed ?? this.sessionRenewed,
    pollPaused: pollPaused ?? this.pollPaused,
    challengeExhausted: challengeExhausted ?? this.challengeExhausted,
  );
}

final class OperatorContractCubit extends Cubit<OperatorContractState> {
  OperatorContractCubit(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(const OperatorContractState());
  final OperatorContractRepository _repository;
  final DateTime Function() _now;
  Timer? _poll;
  int _generation = 0, _pollCount = 0;
  String? _attemptId, _attemptFingerprint;
  bool _refreshing = false;
  int _failedOtpAttempts = 0;

  Future<void> load({bool reconcileSignedSession = false}) async {
    if (isClosed || state.busy) return;
    _poll?.cancel();
    final generation = ++_generation;
    emit(state.copyWith(loading: true, error: null, pollPaused: false));
    try {
      final value = await _repository.current();
      if (!_current(generation)) return;
      _apply(value);
      emit(state.copyWith(loading: false));
      if (reconcileSignedSession && value?.isSigned == true) {
        await renewSignedSession();
      }
      _schedulePoll();
    } on OperatorContractFailure catch (error) {
      if (_current(generation)) {
        emit(state.copyWith(loading: false, error: error.message));
      }
    } catch (_) {
      if (_current(generation)) {
        emit(
          state.copyWith(
            loading: false,
            error: 'Chưa thể tải hợp đồng. Vui lòng thử lại.',
          ),
        );
      }
    }
  }

  bool _current(int generation) => !isClosed && generation == _generation;
  void _apply(OperatorContract? value, {bool reset = false}) {
    final changed =
        reset ||
        value?.id != state.contract?.id ||
        value?.acceptedContentSha256 != state.contract?.acceptedContentSha256 ||
        value?.isSigned == true ||
        value?.status == OperatorContractStatus.voided;
    if (changed) {
      _failedOtpAttempts = 0;
      _attemptId = null;
      _attemptFingerprint = null;
      emit(
        OperatorContractState(
          contract: value,
          drawingRevision: state.drawingRevision + 1,
        ),
      );
    } else {
      emit(state.copyWith(contract: value, error: null));
    }
  }

  void _schedulePoll() {
    if (isClosed ||
        state.contract?.documentState !=
            OperatorContractDocumentState.processing) {
      return;
    }
    if (++_pollCount > 30) {
      emit(state.copyWith(pollPaused: true));
      return;
    }
    _poll = Timer(const Duration(seconds: 2), load);
  }

  Future<void> retryProcessing() async {
    _pollCount = 0;
    await load();
  }

  Future<void> prepare({
    required String signerName,
    required String signerTitle,
    required String signerCapacity,
  }) async {
    final contract = state.contract;
    if (state.busy || contract == null || !contract.canPrepare) return;
    if ([
      signerName,
      signerTitle,
      signerCapacity,
    ].any((value) => value.trim().isEmpty)) {
      emit(
        state.copyWith(
          error: 'Hãy điền họ tên, chức vụ và tư cách đại diện của người ký.',
        ),
      );
      return;
    }
    final generation = ++_generation;
    _poll?.cancel();
    emit(state.copyWith(busy: true, error: null));
    try {
      final value = await _repository.prepare(
        contract,
        signerName: signerName.trim(),
        signerTitle: signerTitle.trim(),
        signerCapacity: signerCapacity.trim(),
      );
      if (!_current(generation)) return;
      _apply(value, reset: true);
      _pollCount = 0;
      _schedulePoll();
    } on OperatorContractFailure catch (error) {
      if (_current(generation)) {
        if (error.statusCode == 409) {
          await _recoverConflict(error);
        } else {
          emit(state.copyWith(error: error.message));
        }
      }
    } catch (_) {
      if (_current(generation)) {
        emit(state.copyWith(error: 'Chưa thể tạo hợp đồng. Vui lòng thử lại.'));
      }
    } finally {
      if (_current(generation)) emit(state.copyWith(busy: false));
    }
  }

  Future<void> openDocument() async {
    final contract = state.contract;
    if (contract == null ||
        state.documentLoading ||
        state.busy ||
        (!contract.isSigned &&
            contract.documentState != OperatorContractDocumentState.ready)) {
      return;
    }
    final generation = _generation;
    emit(state.copyWith(documentLoading: true, error: null));
    try {
      final bytes = await _repository.document(contract);
      if (!_current(generation) || state.contract?.id != contract.id) return;
      emit(
        state.copyWith(
          document: bytes,
          documentLoading: false,
          documentReviewed: false,
        ),
      );
    } on OperatorContractFailure catch (error) {
      if (_current(generation)) {
        emit(state.copyWith(documentLoading: false, error: error.message));
      }
    } catch (_) {
      if (_current(generation)) {
        emit(
          state.copyWith(
            documentLoading: false,
            error: 'Chưa thể mở PDF. Vui lòng thử lại.',
          ),
        );
      }
    }
  }

  void markDocumentReviewed() {
    if (state.document != null && !state.documentLoading && !state.busy) {
      emit(state.copyWith(documentReviewed: true));
    }
  }

  void documentViewFailed() {
    if (!isClosed) {
      emit(
        state.copyWith(
          documentReviewed: false,
          consent: false,
          error:
              'Không thể hiển thị PDF. Hãy thử tải lại; bạn chưa thể ký khi chưa xem được hợp đồng.',
        ),
      );
    }
  }

  void setConsent(bool value) {
    if (!state.busy) {
      emit(
        state.copyWith(consent: value && state.documentReviewed, error: null),
      );
    }
  }

  void setSignature(Uint8List? bytes) {
    if (state.busy || state.contract?.canSign != true) return;
    final valid =
        bytes != null &&
        bytes.length <= 512 * 1024 &&
        bytes.length >= 8 &&
        _pngHeader.asMap().entries.every(
          (entry) => bytes[entry.key] == entry.value,
        );
    emit(
      state.copyWith(
        signature: valid
            ? Uint8List.fromList(bytes).asUnmodifiableView()
            : null,
        error: bytes != null && !valid
            ? 'Ảnh chữ ký chưa hợp lệ. Vui lòng vẽ lại.'
            : null,
      ),
    );
  }

  static const _pngHeader = [137, 80, 78, 71, 13, 10, 26, 10];
  bool get _ready =>
      state.contract?.canSign == true &&
      state.documentReviewed &&
      state.consent &&
      state.signature != null;
  bool get canRequestOtp =>
      _ready &&
      !state.busy &&
      (state.challenge == null ||
          !_now().toUtc().isBefore(state.challenge!.resendAtUtc));
  Future<void> requestOtp() async {
    if (state.busy) return;
    if (!_ready) {
      emit(
        state.copyWith(
          error:
              'Hãy mở PDF, xác nhận đã đọc và vẽ chữ ký trước khi lấy mã xác nhận.',
        ),
      );
      return;
    }
    if (!canRequestOtp) {
      emit(state.copyWith(error: 'Vui lòng đợi hết thời gian gửi lại mã.'));
      return;
    }
    final generation = _generation;
    final contract = state.contract!;
    emit(state.copyWith(busy: true, error: null, notice: null));
    try {
      final challenge = await _repository.requestChallenge(contract);
      if (!_current(generation)) return;
      _failedOtpAttempts = 0;
      _attemptId = null;
      _attemptFingerprint = null;
      emit(
        state.copyWith(
          contract: contract.withRowVersion(challenge.rowVersion),
          challenge: challenge,
          challengeExhausted: false,
          notice: 'Mã xác nhận đã được gửi đến ${challenge.maskedEmail}.',
        ),
      );
    } on OperatorContractFailure catch (error) {
      if (_current(generation)) {
        if (error.statusCode == 409) {
          await _recoverConflict(error);
        } else {
          emit(state.copyWith(error: error.message));
        }
      }
    } catch (_) {
      if (_current(generation)) {
        emit(
          state.copyWith(error: 'Chưa thể gửi mã xác nhận. Vui lòng thử lại.'),
        );
      }
    } finally {
      if (_current(generation)) emit(state.copyWith(busy: false));
    }
  }

  Future<void> submit(String otp) async {
    if (state.busy) return;
    if (state.challengeExhausted) {
      emit(
        state.copyWith(
          error:
              'Mã xác nhận đã hết lượt thử. Hãy yêu cầu mã mới khi hết thời gian chờ.',
        ),
      );
      return;
    }
    final challenge = state.challenge, contract = state.contract;
    if (!_ready ||
        challenge == null ||
        contract == null ||
        !RegExp(r'^\d{6}$').hasMatch(otp.trim())) {
      emit(
        state.copyWith(
          error: 'Hãy kiểm tra chữ ký, xác nhận đồng ý và mã gồm 6 chữ số.',
        ),
      );
      return;
    }
    if (!_now().toUtc().isBefore(challenge.expiresAtUtc)) {
      emit(
        state.copyWith(
          challenge: null,
          error: 'Mã xác nhận đã hết hạn. Hãy yêu cầu mã mới.',
        ),
      );
      return;
    }
    final generation = _generation;
    final signature = state.signature!;
    final fingerprint = sha256
        .convert(
          utf8.encode(
            jsonEncode([
              contract.id,
              contract.acceptedContentSha256,
              contract.rowVersion,
              contract.signerName,
              contract.otpPolicy.consentVersion,
              challenge.id,
              otp.trim(),
              sha256.convert(signature).toString(),
            ]),
          ),
        )
        .toString();
    if (_attemptFingerprint != fingerprint) {
      _attemptFingerprint = fingerprint;
      _attemptId = const Uuid().v4();
    }
    emit(state.copyWith(busy: true, error: null, notice: null));
    try {
      final result = await _repository.sign(
        contract,
        ContractSignatureSubmission(
          expectedContentSha256: contract.acceptedContentSha256!,
          rowVersion: contract.rowVersion,
          signerName: contract.signerName,
          acceptedTerms: true,
          consentVersion: contract.otpPolicy.consentVersion,
          challengeId: challenge.id,
          otp: otp.trim(),
          idempotencyKey: _attemptId!,
          signature: signature,
        ),
      );
      if (!_current(generation)) return;
      if (!result.isSigned) {
        throw const OperatorContractFailure('unconfirmed_signature');
      }
      _apply(result, reset: true);
      await renewSignedSession();
    } on OperatorContractFailure catch (error) {
      if (!_current(generation)) return;
      if (error.statusCode == 409) {
        await _recoverConflict(error);
      } else {
        // A lost response is not a failed signature. Read the server's durable
        // outcome before offering a retry with the original idempotency key.
        OperatorContract? latest;
        if (error.statusCode == null || (error.statusCode ?? 0) >= 500) {
          try {
            latest = await _repository.current();
          } catch (_) {}
        }
        if (!_current(generation)) return;
        if (latest?.isSigned == true && latest!.id == contract.id) {
          _apply(latest, reset: true);
          await renewSignedSession();
        } else {
          if (error.code == 'contract.otp_invalid') _failedOtpAttempts++;
          final exhausted =
              _failedOtpAttempts >= contract.otpPolicy.maxFailedAttempts;
          emit(
            state.copyWith(
              challengeExhausted: exhausted,
              error: exhausted
                  ? 'Mã xác nhận đã hết lượt thử. Hãy yêu cầu mã mới khi hết thời gian chờ.'
                  : error.message,
            ),
          );
        }
      }
    } catch (_) {
      if (_current(generation)) {
        emit(
          state.copyWith(
            error:
                'Chưa xác nhận được kết quả ký. Hãy tải lại để kiểm tra trước khi thử lại.',
          ),
        );
      }
    } finally {
      if (_current(generation)) emit(state.copyWith(busy: false));
    }
  }

  Future<void> _recoverConflict(OperatorContractFailure failure) async {
    try {
      final latest = await _repository.current();
      if (isClosed) return;
      _apply(latest, reset: true);
      emit(state.copyWith(error: failure.message));
    } catch (_) {
      if (!isClosed) {
        emit(
          OperatorContractState(
            contract: state.contract,
            error: failure.message,
            drawingRevision: state.drawingRevision + 1,
          ),
        );
      }
    }
  }

  Future<void> renewSignedSession() async {
    if (state.contract?.isSigned != true || _refreshing) return;
    _refreshing = true;
    try {
      await _repository.renewSession();
      if (!isClosed) {
        emit(
          state.copyWith(
            sessionRenewed: true,
            notice: 'Hợp đồng đã được ký và lưu thành công.',
            error: null,
          ),
        );
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          state.copyWith(
            sessionRenewed: false,
            notice:
                'Hợp đồng đã ký được lưu. Chưa thể cập nhật phiên đăng nhập; hãy thử lại bước cập nhật phiên.',
          ),
        );
      }
    } finally {
      _refreshing = false;
    }
  }

  @override
  Future<void> close() {
    _generation++;
    _poll?.cancel();
    return super.close();
  }
}
