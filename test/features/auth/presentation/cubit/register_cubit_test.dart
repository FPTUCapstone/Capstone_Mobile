import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/exceptions.dart';
import 'package:trip_mate_mobile/features/auth/data/models/login_request.dart';
import 'package:trip_mate_mobile/features/auth/data/models/register_traveler_request.dart';
import 'package:trip_mate_mobile/features/auth/data/models/register_traveler_response.dart';
import 'package:trip_mate_mobile/features/auth/data/models/session_response_dto.dart';
import 'package:trip_mate_mobile/features/auth/data/services/firebase_auth_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/register_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/register_state.dart';

class MockAuthRepository implements AuthRepository {
  RegisterTravelerResponse? responseToReturn;
  Object? exceptionToThrow;
  RegisterTravelerRequest? lastRequest;

  @override
  Future<RegisterTravelerResponse> registerTraveler(
    RegisterTravelerRequest request,
    String firebaseIdToken,
  ) async {
    lastRequest = request;
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return responseToReturn!;
  }

  @override
  Future<SessionResponseDto> googleAuth(String firebaseIdToken) {
    throw UnimplementedError();
  }

  @override
  Future<SessionResponseDto> login(
    LoginRequest request, [
    String? firebaseIdToken,
  ]) {
    throw UnimplementedError();
  }

  @override
  Future<SessionResponseDto> verifyEmail(String firebaseIdToken) {
    throw UnimplementedError();
  }
}

class MockFirebaseAuthService implements FirebaseAuthService {
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
  Future<String> signInWithEmail({
    required String email,
    required String password,
  }) async => 'firebase-token';

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

    final testResponse = const RegisterTravelerResponse(
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
          registerError: FirebaseAuthException(code: 'email-already-in-use'),
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
          registerError: FirebaseAuthException(code: 'network-request-failed'),
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
