import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/exceptions.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_credentials.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/traveler_registration.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:trip_mate_mobile/features/auth/domain/services/auth_identity_service.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/register_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/register_state.dart';

class MockAuthRepository implements AuthRepository {
  TravelerRegistrationResult? responseToReturn;
  Object? exceptionToThrow;
  TravelerRegistration? lastRequest;

  @override
  Future<TravelerRegistrationResult> registerTraveler(
    TravelerRegistration request,
    String firebaseIdToken,
  ) async {
    lastRequest = request;
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return responseToReturn!;
  }

  @override
  Future<AuthSession> googleAuth(String firebaseIdToken) {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> login(
    AuthCredentials request, [
    String? firebaseIdToken,
  ]) {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> verifyEmail(String firebaseIdToken) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout(String? refreshToken) {
    throw UnimplementedError();
  }
}

class MockFirebaseAuthService implements AuthIdentityService {
  MockFirebaseAuthService({this.registerError});

  final Object? registerError;

  @override
  Future<String?> get currentUserEmail async => null;

  @override
  Future<String> registerWithEmail({
    required String email,
    required String password,
  }) async {
    if (registerError != null) throw registerError!;
    return 'firebase-token';
  }

  @override
  Future<String?> refreshIdToken() async => 'firebase-token';

  @override
  Future<String> signInWithGoogle() async => 'firebase-token';

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<bool> get isEmailVerified async => false;
}

void main() {
  group('RegisterCubit', () {
    late MockAuthRepository mockRepository;

    setUp(() {
      mockRepository = MockAuthRepository();
    });

    test('initial state is RegisterInitial', () {
      final cubit = RegisterCubit(mockRepository, MockFirebaseAuthService());
      addTearDown(cubit.close);
      expect(cubit.state, const RegisterInitial());
    });

    final testResponse = const TravelerRegistrationResult(
      userId: 1,
      email: 'traveler@example.com',
      fullName: 'Nguyen Van A',
      role: 'Traveler',
      status: 'PendingEmailVerification',
      emailSent: true,
      messageCode: 'MSG07',
    );

    blocTest<RegisterCubit, RegisterState>(
      'emits [RegisterLoading, RegisterSuccess] on successful registration',
      build: () {
        mockRepository.responseToReturn = testResponse;
        return RegisterCubit(mockRepository, MockFirebaseAuthService());
      },
      act: (cubit) => cubit.registerTraveler(
        fullName: '  Nguyen Van A  ',
        email: '  TRAVELER@EXAMPLE.COM  ',
        password: 'Password123!',
        confirmPassword: 'Password123!',
        acceptedTerms: true,
        phone: '  0912345678  ',
      ),
      expect: () => [const RegisterLoading(), RegisterSuccess(testResponse)],
      verify: (_) {
        expect(mockRepository.lastRequest?.email, 'traveler@example.com');
        expect(mockRepository.lastRequest?.fullName, 'Nguyen Van A');
        expect(mockRepository.lastRequest?.phoneNumber, '0912345678');
        expect(mockRepository.lastRequest?.password, 'Password123!');
        expect(mockRepository.lastRequest?.acceptedTerms, isTrue);
      },
    );

    blocTest<RegisterCubit, RegisterState>(
      'emits [RegisterLoading, RegisterFailure] on ServerException failure',
      build: () {
        mockRepository.exceptionToThrow = const ServerException(
          'An account with this email address already exists.',
        );
        return RegisterCubit(mockRepository, MockFirebaseAuthService());
      },
      act: (cubit) => cubit.registerTraveler(
        fullName: 'Nguyen Van A',
        email: 'existing@example.com',
        password: 'Password123!',
        confirmPassword: 'Password123!',
        acceptedTerms: true,
      ),
      expect: () => const [
        RegisterLoading(),
        RegisterFailure('An account with this email address already exists.'),
      ],
    );

    blocTest<RegisterCubit, RegisterState>(
      'maps an existing Firebase email to the duplicate-account message',
      build: () => RegisterCubit(
        mockRepository,
        MockFirebaseAuthService(
          registerError: const AuthIdentityException(
            AuthIdentityFailure.emailAlreadyInUse,
          ),
        ),
      ),
      act: (cubit) => cubit.registerTraveler(
        fullName: 'Nguyen Van A',
        email: 'existing@example.com',
        password: 'Password123!',
        confirmPassword: 'Password123!',
        acceptedTerms: true,
      ),
      expect: () => const [
        RegisterLoading(),
        RegisterFailure(
          'An account with this email already exists. Please sign in or use another email.',
        ),
      ],
      verify: (_) => expect(mockRepository.lastRequest, isNull),
    );

    blocTest<RegisterCubit, RegisterState>(
      'maps a Firebase network failure to the connection message',
      build: () => RegisterCubit(
        mockRepository,
        MockFirebaseAuthService(
          registerError: const AuthIdentityException(
            AuthIdentityFailure.network,
          ),
        ),
      ),
      act: (cubit) => cubit.registerTraveler(
        fullName: 'Nguyen Van A',
        email: 'new@example.com',
        password: 'Password123!',
        confirmPassword: 'Password123!',
        acceptedTerms: true,
      ),
      expect: () => const [
        RegisterLoading(),
        RegisterFailure(
          'TripMate is temporarily unable to process your request. Please check your connection and try again.',
        ),
      ],
      verify: (_) => expect(mockRepository.lastRequest, isNull),
    );
  });
}
