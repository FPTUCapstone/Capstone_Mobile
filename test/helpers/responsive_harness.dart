import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/theme/app_theme.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/tour_operator_application_status.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';

typedef ReviewViewport = ({String name, Size size});

/// Logical viewports required for Batch 1 review (device pixel ratio 1.0, so
/// physical size equals logical size).
const reviewViewports = <ReviewViewport>[
  (name: '360x800', size: Size(360, 800)),
  (name: '390x844', size: Size(390, 844)),
  (name: '412x915', size: Size(412, 915)),
];

const reviewTextScales = <double>[1.0, 2.0];

/// In-memory [SecureStorageService] for tests; no keystore, no network.
final class InMemorySecureStorage implements SecureStorageService {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

/// Builds the REAL [AuthSessionCubit] in an authenticated state by restoring a
/// persisted session through its production restore path. No Backend, no
/// network: it only lets a page be rendered against a known session snapshot.
/// Pass `authenticated: false` for the unauthenticated state.
Future<AuthSessionCubit> buildSessionCubit({
  bool authenticated = true,
  UserRole role = UserRole.traveler,
  TourOperatorApplicationStatus? applicationStatus,
  String? fullName,
  String? email,
  InMemorySecureStorage? storage,
}) async {
  final store = storage ?? InMemorySecureStorage();
  if (authenticated) {
    store.values
      ..[AppConstants.keepSignedInKey] = 'true'
      ..[AppConstants.accessTokenKey] = 'test-access'
      ..[AppConstants.refreshTokenKey] = 'test-refresh'
      ..[AppConstants.sessionRoleKey] = role.name;
    if (applicationStatus != null) {
      store.values[AppConstants.sessionApplicationStatusKey] =
          applicationStatus.name;
    }
    if (fullName != null) {
      store.values[AppConstants.sessionFullNameKey] = fullName;
    }
    if (email != null) {
      store.values[AppConstants.sessionEmailKey] = email;
    }
  }
  final cubit = AuthSessionCubit(null, store);
  addTearDown(cubit.close);
  await cubit.restoreSession();
  return cubit;
}

/// Wraps [home] in the real TripMate theme, an optional session provider and a
/// forced text scale.
Widget harnessApp({
  required Widget home,
  AuthSessionCubit? session,
  double textScale = 1.0,
}) {
  final Widget content = session == null
      ? home
      : BlocProvider<AuthSessionCubit>.value(value: session, child: home);
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: content,
  );
}

/// Renders [app] at [size] with optional keyboard ([viewInsets]) and system bar
/// ([safeArea]) insets. The test view is reset automatically.
Future<void> pumpAtViewport(
  WidgetTester tester,
  Widget app, {
  Size size = const Size(390, 844),
  EdgeInsets viewInsets = EdgeInsets.zero,
  EdgeInsets safeArea = EdgeInsets.zero,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.view.viewInsets = FakeViewPadding(
    left: viewInsets.left,
    top: viewInsets.top,
    right: viewInsets.right,
    bottom: viewInsets.bottom,
  );
  tester.view.padding = FakeViewPadding(
    left: safeArea.left,
    top: safeArea.top,
    right: safeArea.right,
    bottom: safeArea.bottom,
  );
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pump();
}

/// Scrolls the page's primary scrollable (from the top) until [finder] is
/// visible. Lazy lists only build near the viewport, so this starts at the top
/// to make the result independent of earlier scrolling.
Future<void> scrollIntoView(WidgetTester tester, Finder finder) async {
  final scrollable = find.byType(Scrollable).first;
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pump();
  await tester.scrollUntilVisible(finder, 250, scrollable: scrollable);
  await tester.pump();
}

/// Fails when Flutter reported any exception (including RenderFlex overflow).
void expectNoFlutterException(WidgetTester tester) {
  expect(tester.takeException(), isNull);
}

/// Touch targets >= 48x48 and every tappable node labelled.
Future<void> expectAccessibleTapTargets(WidgetTester tester) async {
  final handle = tester.ensureSemantics();
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  handle.dispose();
}

/// Runs [body] for every required viewport and text scale.
void forEachViewportAndScale(
  String description,
  Future<void> Function(
    WidgetTester tester,
    ReviewViewport viewport,
    double textScale,
  )
  body,
) {
  for (final viewport in reviewViewports) {
    for (final textScale in reviewTextScales) {
      testWidgets('$description @ ${viewport.name} x$textScale', (
        tester,
      ) async {
        await body(tester, viewport, textScale);
      });
    }
  }
}
