import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';

enum DemoAccountType { traveler, operator, rejectedOperator }

final class DemoAccount {
  const DemoAccount({
    required this.email,
    required this.role,
    required this.type,
  });

  final String email;
  final UserRole role;
  final DemoAccountType type;
}

abstract final class AuthDemoData {
  static const password = 'password123';
  static const verificationCode = '123456';

  static const traveler = DemoAccount(
    email: 'traveler@tripmate.demo',
    role: UserRole.traveler,
    type: DemoAccountType.traveler,
  );
  static const operator = DemoAccount(
    email: 'operator@tripmate.demo',
    role: UserRole.tourOperator,
    type: DemoAccountType.operator,
  );
  static const rejectedOperator = DemoAccount(
    email: 'rejected@tripmate.demo',
    role: UserRole.tourOperator,
    type: DemoAccountType.rejectedOperator,
  );

  static const accounts = [traveler, operator, rejectedOperator];

  static DemoAccount? authenticate(String email, String candidatePassword) {
    if (candidatePassword != password) {
      return null;
    }
    final normalizedEmail = email.trim().toLowerCase();
    for (final account in accounts) {
      if (account.email == normalizedEmail) {
        return account;
      }
    }
    return null;
  }
}
