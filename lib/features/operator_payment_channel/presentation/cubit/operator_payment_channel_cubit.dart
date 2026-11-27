import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/operator_payment_channel/domain/entities/payment_channel_status.dart';
import 'package:trip_mate_mobile/features/operator_payment_channel/domain/usecases/operator_payment_channel_usecases.dart';
import 'package:trip_mate_mobile/features/operator_payment_channel/presentation/cubit/operator_payment_channel_state.dart';

final class OperatorPaymentChannelCubit
    extends Cubit<OperatorPaymentChannelState> {
  OperatorPaymentChannelCubit({
    required GetPaymentChannelUseCase getChannel,
    required SubmitPaymentChannelCredentialsUseCase submitCredentials,
    required VerifyPaymentChannelUseCase verify,
  }) : _getChannel = getChannel,
       _submitCredentials = submitCredentials,
       _verify = verify,
       super(const OperatorPaymentChannelState());

  final GetPaymentChannelUseCase _getChannel;
  final SubmitPaymentChannelCredentialsUseCase _submitCredentials;
  final VerifyPaymentChannelUseCase _verify;

  Future<void> load() async {
    emit(state.copyWith(loadStatus: PaymentChannelLoadStatus.loading));
    try {
      final channel = await _getChannel();
      emit(
        state.copyWith(
          loadStatus: PaymentChannelLoadStatus.success,
          channel: channel,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          loadStatus: PaymentChannelLoadStatus.failure,
          loadError: e.toString(),
        ),
      );
    }
  }

  Future<void> submitCredentials(SubmitCredentialsRequest request) async {
    emit(
      state.copyWith(
        actionStatus: PaymentChannelActionStatus.submitting,
        clearActionError: true,
      ),
    );
    try {
      final channel = await _submitCredentials(request);
      emit(
        state.copyWith(
          actionStatus: PaymentChannelActionStatus.success,
          channel: channel,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          actionStatus: PaymentChannelActionStatus.failure,
          actionError: _errorMessage(e),
        ),
      );
    }
  }

  Future<void> verify() async {
    emit(
      state.copyWith(
        actionStatus: PaymentChannelActionStatus.verifying,
        clearActionError: true,
      ),
    );
    try {
      final channel = await _verify();
      emit(
        state.copyWith(
          actionStatus: PaymentChannelActionStatus.success,
          channel: channel,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          actionStatus: PaymentChannelActionStatus.failure,
          actionError: _errorMessage(e),
        ),
      );
    }
  }

  static String _errorMessage(Object e) {
    final msg = e.toString();
    if (msg.contains('400') || msg.contains('422')) {
      return 'Thông tin không hợp lệ. Vui lòng kiểm tra lại.';
    }
    if (msg.contains('409')) {
      return 'Yêu cầu xung đột. Vui lòng tải lại trang.';
    }
    return 'Đã xảy ra lỗi. Vui lòng thử lại.';
  }
}
