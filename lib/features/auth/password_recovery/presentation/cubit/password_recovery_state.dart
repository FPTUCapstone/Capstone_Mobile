import 'package:equatable/equatable.dart';

enum PasswordRecoveryStatus {
  idle,
  requesting,
  requestAccepted,
  confirming,
  resending,
  cooldown,
  success,
  failure,
}

final class PasswordRecoveryState extends Equatable {
  const PasswordRecoveryState({
    this.status = PasswordRecoveryStatus.idle,
    this.normalizedEmail,
    this.feedbackMessage,
    this.errorMessage,
    this.fieldErrors = const <String, List<String>>{},
    this.cooldownSeconds = 0,
    this.cooldownEmail,
    this.isEditingEmail = false,
  });

  final PasswordRecoveryStatus status;
  final String? normalizedEmail;
  final String? feedbackMessage;
  final String? errorMessage;
  final Map<String, List<String>> fieldErrors;
  final int cooldownSeconds;
  final String? cooldownEmail;
  final bool isEditingEmail;

  bool get isBusy =>
      status == PasswordRecoveryStatus.requesting ||
      status == PasswordRecoveryStatus.confirming ||
      status == PasswordRecoveryStatus.resending;

  bool get hasAcceptedRequest =>
      normalizedEmail != null &&
      !isEditingEmail &&
      status != PasswordRecoveryStatus.requesting;

  bool hasActiveCooldownFor(String rawEmail) {
    if (cooldownSeconds <= 0 || cooldownEmail == null) return false;
    return rawEmail.trim().toLowerCase() == cooldownEmail;
  }

  @override
  List<Object?> get props => [
    status,
    normalizedEmail,
    feedbackMessage,
    errorMessage,
    fieldErrors,
    cooldownSeconds,
    cooldownEmail,
    isEditingEmail,
  ];
}
