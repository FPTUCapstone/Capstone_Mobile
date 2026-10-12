import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/group_invitation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_members.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/join_travel_group_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/join_travel_group_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/join_travel_group_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/qr_scanner_dialog.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_text_field.dart';

final class _MockTravelGroupRepository implements TravelGroupRepository {
  String? lastCode;
  String? lastKey;

  @override
  Future<TravelGroup> createTravelGroup({
    required String name,
    required int itineraryId,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<GroupInvitation> getOrCreateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<GroupInvitation> regenerateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<TravelGroup> joinTravelGroup({
    required String invitationCode,
    required String idempotencyKey,
  }) async {
    lastCode = invitationCode;
    lastKey = idempotencyKey;
    return const TravelGroup(id: 42, name: 'Joined Group', itineraryId: 10);
  }

  @override
  Future<TravelGroupMembers> getTravelGroupMembers({required int groupId}) =>
      throw UnimplementedError();
}

void main() {
  late _MockTravelGroupRepository repository;
  late JoinTravelGroupCubit cubit;

  setUp(() {
    repository = _MockTravelGroupRepository();
    cubit = JoinTravelGroupCubit(repository: repository);
  });

  tearDown(() {
    cubit.close();
  });

  Widget buildSubject() {
    return MaterialApp(
      home: BlocProvider<JoinTravelGroupCubit>.value(
        value: cubit,
        child: const JoinTravelGroupPage(),
      ),
    );
  }

  testWidgets('renders all required components and buttons', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Join Shared Group Trip'), findsOneWidget);
    expect(find.byType(AppTextField), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Join Group'), findsOneWidget);
    expect(find.text('Scan QR Invitation'), findsOneWidget);
  });

  testWidgets(
    'submitting empty code shows inline MSG01 without calling repository',
    (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(AppButton, 'Join Group'));
      await tester.pumpAndSettle();

      expect(find.text('This field is required.'), findsOneWidget);
      expect(repository.lastCode, isNull);
    },
  );

  testWidgets('submitting valid code calls repository and succeeds', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(AppTextField), 'A7K4P2QX');
    await tester.tap(find.widgetWithText(AppButton, 'Join Group'));
    await tester.pumpAndSettle();

    expect(repository.lastCode, 'A7K4P2QX');
    expect(repository.lastKey, isNotNull);
  });

  testWidgets(
    'typing lowercase characters converts them to uppercase and limits to 8',
    (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(AppTextField), 'hoian8kpxyz');
      await tester.pumpAndSettle();

      expect(find.text('HOIAN8KP'), findsOneWidget);
    },
  );

  testWidgets('tapping paste button populates code from clipboard', (
    tester,
  ) async {
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
          if (methodCall.method == 'Clipboard.getData') {
            return {'text': 'tripmate://groups/join?code=B2M4X7Q9'};
          }
          return null;
        });

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.content_paste_rounded));
    await tester.pumpAndSettle();

    expect(find.text('B2M4X7Q9'), findsOneWidget);
  });

  testWidgets('failure with existingGroupId shows MSG57 snackbar', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    cubit.emit(
      const JoinTravelGroupState.failure(
        'You are already a member of this travel group.',
        42,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('You are already a member of this travel group.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'camera permission granted -> QR decoded -> join request submitted',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<JoinTravelGroupCubit>.value(
            value: cubit,
            child: JoinTravelGroupPage(
              scannerLauncher: (context) async => 'QRJOIN99',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan QR Invitation'));
      await tester.pumpAndSettle();

      expect(repository.lastCode, 'QRJOIN99');
      expect(repository.lastKey, isNotNull);
    },
  );

  testWidgets('rapid taps launch only one scanner', (tester) async {
    int scanLaunchCount = 0;
    final scanResult = Completer<String?>();

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<JoinTravelGroupCubit>.value(
          value: cubit,
          child: JoinTravelGroupPage(
            scannerLauncher: (context) async {
              scanLaunchCount++;
              return scanResult.future;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan QR Invitation'));
    await tester.pump();
    await tester.tap(find.text('Scan QR Invitation'), warnIfMissed: false);
    await tester.pump();

    expect(scanLaunchCount, 1);
    expect(repository.lastCode, isNull);

    scanResult.complete('CODE1111');
    await tester.pumpAndSettle();
    expect(repository.lastCode, 'CODE1111');
  });

  testWidgets('scan action is disabled while submitting', (tester) async {
    int scanLaunchCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<JoinTravelGroupCubit>.value(
          value: cubit,
          child: JoinTravelGroupPage(
            scannerLauncher: (context) async {
              scanLaunchCount++;
              return 'CODE1111';
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    cubit.emit(const JoinTravelGroupState.submitting());
    await tester.pump();
    await tester.tap(find.text('Scan QR Invitation'), warnIfMissed: false);
    await tester.pump();

    expect(scanLaunchCount, 0);
    expect(repository.lastCode, isNull);
  });

  testWidgets(
    'successful join navigates to travel group details page with extra preserved',
    (tester) async {
      TravelGroup? capturedExtra;
      final router = GoRouter(
        initialLocation: '/join',
        routes: [
          GoRoute(
            path: '/join',
            builder: (_, _) => BlocProvider<JoinTravelGroupCubit>.value(
              value: cubit,
              child: const JoinTravelGroupPage(),
            ),
          ),
          GoRoute(
            path: '${AppRoutes.travelerTravelGroups}/:groupId',
            builder: (_, state) {
              capturedExtra = state.extra as TravelGroup?;
              return Scaffold(
                body: Text(
                  'Group details for ${state.pathParameters['groupId']}',
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(AppTextField), 'A7K4P2QX');
      await tester.tap(find.widgetWithText(AppButton, 'Join Group'));
      await tester.pumpAndSettle();

      expect(find.text('Group details for 42'), findsOneWidget);
      expect(capturedExtra, isNotNull);
      expect(capturedExtra!.id, 42);
      expect(capturedExtra!.name, 'Joined Group');
      expect(capturedExtra!.itineraryId, 10);
    },
  );

  group('Cancel Button Navigation', () {
    testWidgets('tapping cancel button pops when canPop is true', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: ElevatedButton(
                onPressed: () => context.push('/join'),
                child: const Text('Go to Join'),
              ),
            ),
          ),
          GoRoute(
            path: '/join',
            builder: (_, _) => BlocProvider<JoinTravelGroupCubit>.value(
              value: cubit,
              child: const JoinTravelGroupPage(),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Go to Join'));
      await tester.pumpAndSettle();
      expect(find.text('Join Shared Group Trip'), findsOneWidget);

      await tester.tap(find.byKey(const Key('cancel_button')));
      await tester.pumpAndSettle();
      expect(find.text('Go to Join'), findsOneWidget);
    });

    testWidgets(
      'tapping cancel button navigates to traveler home when canPop is false',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/join',
          routes: [
            GoRoute(
              path: '/join',
              builder: (_, _) => BlocProvider<JoinTravelGroupCubit>.value(
                value: cubit,
                child: const JoinTravelGroupPage(),
              ),
            ),
            GoRoute(
              path: AppRoutes.traveler,
              builder: (_, _) => const Text('Traveler Home Page'),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('cancel_button')));
        await tester.pumpAndSettle();
        expect(find.text('Traveler Home Page'), findsOneWidget);
      },
    );
  });

  group('QrScannerDialog permission handling', () {
    testWidgets(
      'shows MSG46 and Open App Settings button when camera is denied',
      (tester) async {
        bool openedSettings = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: QrScannerDialog(
                initialPermission: CameraPermissionState.denied,
                onScanned: (_) {},
                onOpenAppSettings: () async {
                  openedSettings = true;
                  return true;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('camera_permission_denied_view')),
          findsOneWidget,
        );
        expect(find.text(QrScannerDialog.msg46), findsOneWidget);
        expect(
          find.byKey(const Key('open_app_settings_button')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('open_app_settings_button')));
        await tester.pumpAndSettle();
        expect(openedSettings, isTrue);
      },
    );

    testWidgets(
      'shows MSG46 and Open App Settings button when permanently denied',
      (tester) async {
        bool openedSettings = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: QrScannerDialog(
                initialPermission: CameraPermissionState.permanentlyDenied,
                onScanned: (_) {},
                onOpenAppSettings: () async {
                  openedSettings = true;
                  return true;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('camera_permission_denied_view')),
          findsOneWidget,
        );
        expect(find.text(QrScannerDialog.msg46), findsOneWidget);
        expect(
          find.byKey(const Key('open_app_settings_button')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('open_app_settings_button')));
        await tester.pumpAndSettle();
        expect(openedSettings, isTrue);
      },
    );
  });

  group('Demo Mode Controls in JoinTravelGroupPage', () {
    testWidgets('toggles demo controls panel and simulates chips', (
      tester,
    ) async {
      final demoCubit = JoinTravelGroupCubit(
        repository: repository,
        isDemoMode: true,
      );
      addTearDown(demoCubit.close);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<JoinTravelGroupCubit>.value(
            value: demoCubit,
            child: const JoinTravelGroupPage(isDemoMode: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('demo_controls_toggle_button')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('demo_controls_panel')), findsNothing);

      await tester.tap(find.byKey(const Key('demo_controls_toggle_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('demo_controls_panel')), findsOneWidget);
      expect(find.text('DEMO_ONLY Test Controls'), findsOneWidget);

      await tester.tap(find.text('Simulate Valid (HOIAN8KP)'));
      await tester.pumpAndSettle();
      expect(find.text('HOIAN8KP'), findsOneWidget);

      await tester.tap(find.text('Simulate Expired (EXPIRED8)'));
      await tester.pumpAndSettle();
      expect(find.text('EXPIRED8'), findsOneWidget);

      await tester.tap(find.text('Simulate Already Member (ALREADY8)'));
      await tester.pumpAndSettle();
      expect(find.text('ALREADY8'), findsOneWidget);

      await tester.tap(find.text('Simulate Server Error (SERVER12)'));
      await tester.pumpAndSettle();
      expect(find.text('SERVER12'), findsOneWidget);

      await tester.tap(find.byKey(const Key('demo_controls_toggle_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('demo_controls_panel')), findsNothing);
    });
  });

  group('Responsive Layout and Accessibility', () {
    for (final size in [
      const Size(360, 640),
      const Size(390, 844),
      const Size(412, 915),
    ]) {
      testWidgets('renders cleanly on ${size.width}x${size.height}', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text('Join Shared Group Trip'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('renders without overflow at 200% font scale', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: BlocProvider<JoinTravelGroupCubit>.value(
              value: cubit,
              child: const JoinTravelGroupPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Join Shared Group Trip'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
