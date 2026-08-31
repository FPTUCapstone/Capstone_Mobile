import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum OperatorApplicationStatus { draft, rejected, submitting, pending }

final class OperatorApplicationState extends Equatable {
  const OperatorApplicationState({required this.status, this.licenceFileName});

  final String? licenceFileName;
  final OperatorApplicationStatus status;

  bool get hasLicence => licenceFileName != null;
  bool get isSubmitting => status == OperatorApplicationStatus.submitting;

  OperatorApplicationState copyWith({
    String? licenceFileName,
    OperatorApplicationStatus? status,
  }) {
    return OperatorApplicationState(
      licenceFileName: licenceFileName ?? this.licenceFileName,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [status, licenceFileName];
}

final class OperatorApplicationCubit extends Cubit<OperatorApplicationState> {
  OperatorApplicationCubit({
    OperatorApplicationStatus initialStatus =
        OperatorApplicationStatus.rejected,
  }) : super(
         OperatorApplicationState(
           status: initialStatus,
           licenceFileName: initialStatus == OperatorApplicationStatus.rejected
               ? 'licence-2026-renewed.pdf'
               : null,
         ),
       );

  void selectDemoLicence() {
    emit(state.copyWith(licenceFileName: 'licence-0401998877.pdf'));
  }

  Future<void> submit({bool isResubmission = false}) async {
    emit(state.copyWith(status: OperatorApplicationStatus.submitting));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    emit(
      state.copyWith(
        licenceFileName: isResubmission
            ? 'licence-2026-renewed.pdf'
            : state.licenceFileName,
        status: OperatorApplicationStatus.pending,
      ),
    );
  }
}
