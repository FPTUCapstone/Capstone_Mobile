import 'package:trip_mate_mobile/core/error/failures.dart';

final class InvalidResetCredentialFailure extends Failure {
  const InvalidResetCredentialFailure([
    super.message =
        'The reset code is invalid or no longer usable. Request a new code and try again.',
  ]);
}
