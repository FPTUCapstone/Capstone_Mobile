import 'package:equatable/equatable.dart';

enum ChangePasswordStatus { idle, submitting, success, failure }

final class ChangePasswordState extends Equatable {
  const ChangePasswordState({
    this.status = ChangePasswordStatus.idle,
    this.errorMessage,
    this.fieldErrors = const <String, List<String>>{},
  });

  final ChangePasswordStatus status;
  final String? errorMessage;
  final Map<String, List<String>> fieldErrors;

  bool get isSubmitting => status == ChangePasswordStatus.submitting;

  @override
  List<Object?> get props => [status, errorMessage, fieldErrors];
}
