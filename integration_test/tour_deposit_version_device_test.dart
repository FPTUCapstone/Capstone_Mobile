import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/operator_tours/data/datasources/operator_tour_remote_data_source.dart';
import 'package:trip_mate_mobile/features/operator_tours/data/repositories/operator_tour_repository_impl.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_detail.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_draft.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_options.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/usecases/create_tour_package_use_case.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/usecases/load_tour_package_options_use_case.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/usecases/tour_package_use_cases.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/cubit/create_tour_package_cubit.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/cubit/operator_tours_cubit.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/pages/create_tour_package_page.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/pages/edit_tour_package_page.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/pages/operator_tours_page.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/services/tour_image_picker.dart';
import 'package:trip_mate_mobile/features/poi/data/datasources/poi_remote_data_source.dart';
import 'package:trip_mate_mobile/features/poi/data/repositories/poi_repository_impl.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_location.dart';
import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_location_service.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/get_poi_detail_use_case.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/get_poi_location_use_case.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/get_pois_use_case.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_list_cubit.dart';
import 'package:trip_mate_mobile/features/tour_detail/data/datasources/dio_tour_detail_remote_data_source.dart';
import 'package:trip_mate_mobile/features/tour_detail/data/repositories/tour_detail_repository_impl.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/usecases/get_tour_detail.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/pages/tour_detail_page.dart';
import 'package:uuid/uuid.dart';

const _api = String.fromEnvironment('TOUR_E2E_API');
const _mediaSeedUrl = String.fromEnvironment('TOUR_E2E_MEDIA_SEED_URL');
const _password = String.fromEnvironment(
  'TOUR_E2E_PASSWORD',
  defaultValue: 'TourAudit!2026',
);
const _operatorEmail = String.fromEnvironment(
  'TOUR_E2E_OPERATOR_EMAIL',
  defaultValue: 'operator-a@e2e.local',
);
const _staffEmail = String.fromEnvironment(
  'TOUR_E2E_STAFF_EMAIL',
  defaultValue: 'staff@e2e.local',
);
const _travelerEmail = String.fromEnvironment(
  'TOUR_E2E_TRAVELER_EMAIL',
  defaultValue: 'traveler@e2e.local',
);

const _samplePngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAUAAAADICAYAAACZBDirAAACqklEQVR4nO3UIQEAIBDAwG9BJ+ifB2IgduL81GadfQGK5ncAwC8GCGQZIJBlgECWAQJZBghkGSCQZYBAlgECWQYIZBkgkGWAQJYBAlkGCGQZIJBlgECWAQJZBghkGSCQZYBAlgECWQYIZBkgkGWAQJYBAlkGCGQZIJBlgECWAQJZBghkGSCQZYBAlgECWQYIZBkgkGWAQJYBAlkGCGQZIJBlgECWAQJZBghkGSCQZYBAlgECWQYIZBkgkGWAQJYBAlkGCGQZIJBlgECWAQJZBghkGSCQZYBAlgECWQYIZBkgkGWAQJYBAlkGCGQZIJBlgECWAQJZBghkGSCQZYBAlgECWQYIZBkgkGWAQJYBAlkGCGQZIJBlgECWAQJZBghkGSCQZYBAlgECWQYIZBkgkGWAQJYBAlkGCGQZIJBlgECWAQJZBghkGSCQZYBAlgECWQYIZBkgkGWAQJYBAlkGCGQZIJBlgECWAQJZBghkGSCQZYBAlgECWQYIZBkgkGWAQJYBAlkGCGQZIJBlgECWAQJZBghkGSCQZYBAlgECWQYIZBkgkGWAQJYBAlkGCGQZIJBlgECWAQJZBghkGSCQZYBAlgECWQYIZBkgkGWAQJYBAlkGCGQZIJBlgECWAQJZBghkGSCQZYBAlgECWQYIZBkgkGWAQJYBAlkGCGQZIJBlgECWAQJZBghkGSCQZYBAlgECWQYIZBkgkGWAQJYBAlkGCGQZIJBlgECWAQJZBghkGSCQZYBAlgECWQYIZBkgkGWAQJYBAlkGCGQZIJBlgECWAQJZBghkGSCQZYBAlgECWQYIZBkgkGWAQJYBAlkGCGQZIJBlgECWAQJZBghkGSCQZYBAlgECWQYIZBkgkGWAQJYBAlkGCGQZIJBlgECWAQJZBghkGSCQ9QCbWBZw6NRNsAAAAABJRU5ErkJggg==';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final skip = _api.isEmpty ? 'Set TOUR_E2E_API dart-define to run.' : null;

  late DioClient operatorClient;
  late DioClient staffClient;
  late DioClient travelerClient;
  late OperatorTourRepositoryImpl operatorRepo;

  setUpAll(() async {
    if (skip != null) return;
    operatorClient = await _signIn(_operatorEmail);
    staffClient = await _signIn(
      _staffEmail,
      loginPath: '/api/v1/auth/web/admin/login',
    );
    travelerClient = await _signIn(_travelerEmail);
    operatorRepo = OperatorTourRepositoryImpl(
      _E2eOperatorTourRemoteDataSource(
        DioOperatorTourRemoteDataSource(operatorClient),
      ),
    );
    await _registerTestDependencies(operatorClient, operatorRepo);
  });

  tearDownAll(() async {
    if (skip != null) return;
    await serviceLocator.reset();
  });

  testWidgets(
    'Mobile E2E: Create deposit tour v1, submit, approve, view traveler detail, reopen departure, clone v2, version history, delete draft',
    (tester) async {
      final listCubit = OperatorToursCubit(
        listTours: ListTourPackagesUseCase(operatorRepo),
      );
      addTearDown(listCubit.close);
      await listCubit.load();

      final router = _buildRouter(
        listCubit: listCubit,
        travelerClient: travelerClient,
      );
      await tester.pumpWidget(
        BlocProvider<AuthSessionCubit>(
          create: (_) => AuthSessionCubit(),
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Open CreateTourPackagePage from OperatorToursPage
      await _tapVisible(tester, find.text('Create tour package'));
      await _until(tester, find.widgetWithText(FilterChip, 'Sports shoes'));

      final titleV1 =
          'Mobile E2E Deposit v1 ${DateTime.now().millisecondsSinceEpoch}';
      await _enterVisible(
        tester,
        find.widgetWithText(TextFormField, 'Tour title'),
        titleV1,
      );
      await _enterVisible(
        tester,
        find.widgetWithText(TextFormField, 'Description'),
        'Real Android E2E test verifying deposit setup, packing tags, reopen departure, and version history.',
      );
      await _enterVisible(
        tester,
        find.widgetWithText(TextFormField, 'Base price (VND)'),
        '3000000',
      );
      await _enterVisible(
        tester,
        find.widgetWithText(TextFormField, 'Duration (days)'),
        '1',
      );
      await _enterVisible(
        tester,
        find.widgetWithText(TextFormField, 'Highlights (optional)'),
        'Dragon Bridge evening walk',
      );

      // Quick packing checklist tags
      await _tapVisible(
        tester,
        find.widgetWithText(FilterChip, 'Sports shoes'),
      );
      await _tapVisible(
        tester,
        find.widgetWithText(FilterChip, 'ID card / Passport'),
      );
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(
                TextFormField,
                'Traveller requirements (optional)',
              ),
            )
            .controller!
            .text,
        '- Sports shoes\n- ID card / Passport',
      );

      // Destinations + Cancellation Policy + Category
      await _tapVisible(tester, find.widgetWithText(FilterChip, 'Đà Nẵng'));
      await _tapVisible(tester, find.byType(DropdownButtonFormField<int>));
      await _until(tester, find.text('Standard scheduled departure'));
      final policyItems = find.text('Standard scheduled departure');
      await tester.ensureVisible(policyItems.last);
      await tester.pumpAndSettle();
      await tester.tap(policyItems.last);
      await tester.pumpAndSettle();

      // Enable Deposit Setup (30% · Domestic / 7 days)
      await _tapVisible(tester, find.text('Allow deposit'));
      await tester.pumpAndSettle();
      await _tapVisible(
        tester,
        find.widgetWithText(ChoiceChip, '30% · Domestic'),
      );
      await _tapVisible(tester, find.widgetWithText(ChoiceChip, '7 days'));
      await tester.pumpAndSettle();
      expect(find.textContaining('900.000 VND'), findsOneWidget);
      expect(find.textContaining('2.100.000 VND'), findsOneWidget);

      // Step 0 -> Step 1 (Itinerary)
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Continue'));
      await _tapVisible(tester, find.text('Add point of interest'));
      await _tapVisible(tester, find.text('Cầu Rồng Đà Nẵng'));
      await _until(tester, find.textContaining('Day 1'));

      // Step 1 -> Step 2 (Schedules) -> Step 3 (Photos) -> Step 4 (Preview & save)
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Continue'));
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Continue'));
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Continue'));
      await _scrollToText(
        tester,
        'Deposit 30% at booking · Balance due 7 days before departure',
      );

      // Save v1 Draft -> navigates to EditTourPackagePage
      await _tapVisible(tester, find.text('Save draft'));
      await _until(tester, find.text('Delete draft'));
      final v1Detail = (await operatorRepo.listTours()).items.firstWhere(
        (item) => item.title == titleV1,
      );
      final v1Id = v1Detail.id;
      debugPrint('MOBILE_E2E created v1Id=$v1Id');

      // Upload Cover Photo & Submit v1 for Review
      await _tapVisible(tester, find.text('Photos'));
      await _tapVisible(tester, find.text('Add photo'));
      await _until(tester, find.text('Cover photo'));
      await _tapVisible(tester, find.text('Preview & save'));
      await _tapVisible(tester, find.text('Submit for review'));
      await _until(tester, find.text('Submit for review?'));
      await _enterVisible(
        tester,
        find.widgetWithText(TextFormField, 'Submission note (optional)'),
        'Mobile E2E v1 submit',
      );
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Submit'));
      await _until(tester, find.text('Create tour package'));

      // Staff Approve & Publish v1 via real HTTP
      await _approveAndPublishTour(staffClient, v1Id);

      // Refresh OperatorToursPage -> verify v1 shows "v1 · Published"
      await listCubit.refresh();
      await tester.pumpAndSettle();
      await _until(tester, find.text(titleV1));
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, titleV1),
          matching: find.textContaining('v1 · Published'),
        ),
        findsOneWidget,
      );

      // Traveler TourDetailPage -> verify v1 Deposit Policy, Highlights & Packing Requirements
      router.go('/traveler/tours/$v1Id');
      await _until(tester, find.byKey(const Key('tour-detail-deposit-policy')));
      await _scrollToText(tester, '30% Deposit Option Available');
      await _scrollToText(tester, 'Dragon Bridge evening walk');
      await _scrollToText(tester, 'Sports shoes');
      expect(
        find.text('30% deposit · Balance due 7 days prior'),
        findsOneWidget,
      );

      // Back to Operator EditTourPackagePage(v1Id) -> Reopen/Add Departure
      router.go(AppRoutes.editTourPackagePath(v1Id));
      await _until(tester, find.text('Open new departure'));
      await _tapVisible(tester, find.text('Open new departure'));
      await _until(tester, find.text('Publish departure'));
      await _tapVisible(tester, find.text('Publish departure'));
      await _scrollToText(tester, 'Schedules (2)');

      // Clone v1 -> Create v2 Draft (50% deposit, 14 days due)
      await _tapVisible(tester, find.text('Create v2 draft'));
      await _until(tester, find.textContaining('Creating draft v2 from v1'));
      final titleV2 =
          'Mobile E2E Deposit v2 ${DateTime.now().millisecondsSinceEpoch}';
      await _enterVisible(
        tester,
        find.widgetWithText(TextFormField, 'Tour title'),
        titleV2,
      );
      await _tapVisible(
        tester,
        find.widgetWithText(ChoiceChip, '50% · Holiday / Flight'),
      );
      await _tapVisible(tester, find.widgetWithText(ChoiceChip, '14 days'));
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Continue'));
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Continue'));
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Continue'));
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Continue'));
      await _tapVisible(tester, find.text('Save draft'));
      await _until(tester, find.text('Delete draft'));
      final v2Id = (await operatorRepo.listTours()).items
          .firstWhere((item) => item.title == titleV2)
          .id;
      debugPrint('MOBILE_E2E created v2Id=$v2Id');

      // Upload photo & Submit v2, then Staff Approves & Publishes v2
      await _tapVisible(tester, find.text('Photos'));
      await _tapVisible(tester, find.text('Add photo'));
      await _until(tester, find.text('Cover photo'));
      await _tapVisible(tester, find.text('Preview & save'));
      await _tapVisible(tester, find.text('Submit for review'));
      await _until(tester, find.text('Submit for review?'));
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Submit'));
      await _until(tester, find.text('Open new departure'));
      await _approveAndPublishTour(staffClient, v2Id);

      // Open v2 -> Version History shows both v1 (Inactive) & v2 (Published), clickable View jumps to v1
      router.go(AppRoutes.editTourPackagePath(v2Id));
      await _until(tester, find.text('Create v3 draft'));
      await _tapVisible(tester, find.text('Preview & save'));
      await _scrollToText(tester, 'Version History');
      expect(find.textContaining('v1 · Inactive'), findsOneWidget);
      expect(find.textContaining('v2 · Published'), findsWidgets);

      await _tapVisible(tester, find.widgetWithText(TextButton, 'View'));
      await _until(
        tester,
        find.textContaining('This package (v1) is inactive'),
      );

      // Traveler TourDetailPage(v2) reflects updated 50% / 14 days deposit policy
      router.go('/traveler/tours/$v2Id');
      await _until(tester, find.byKey(const Key('tour-detail-deposit-policy')));
      await _scrollToText(tester, '50% Deposit Option Available');
      expect(
        find.text('50% deposit · Balance due 14 days prior'),
        findsOneWidget,
      );

      // Delete throwaway Draft via EditTourPackagePage UI
      final seeded = await operatorRepo.getTour(v2Id);
      final tempDraftId = await operatorRepo.createDraft(
        TourPackageDraft(
          title: 'Temp Delete Draft ${DateTime.now().millisecondsSinceEpoch}',
          description: 'Throwaway draft to verify delete button.',
          basePrice: 1500000,
          durationDays: 1,
          destinationIds: seeded.destinationIds,
          cancellationPolicyTemplateId: seeded.cancellationPolicyTemplateId!,
          itineraryItems: const [
            TourItineraryStopDraft(
              poiId: 1,
              dayNo: 1,
              sequenceNo: 1,
              stayDurationMinutes: 60,
            ),
          ],
          schedules: [
            TourScheduleDraft(
              startAtUtc: DateTime.now().toUtc().add(const Duration(days: 14)),
              endAtUtc: DateTime.now().toUtc().add(
                const Duration(days: 14, hours: 8),
              ),
              totalCapacity: 10,
              adultPrice: 1500000,
            ),
          ],
        ),
        const Uuid().v4(),
      );
      router.go(AppRoutes.operatorTours);
      await _until(tester, find.text('Create tour package'));
      unawaited(router.push(AppRoutes.editTourPackagePath(tempDraftId)));
      await _until(tester, find.text('Delete draft'));
      await _tapVisible(tester, find.text('Delete draft'));
      await _until(tester, find.text('Delete draft tour?'));
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Delete'));
      await _until(tester, find.text('Create tour package'));
      expect(
        (await operatorRepo.listTours()).items.any(
          (item) => item.id == tempDraftId,
        ),
        isFalse,
      );
    },
    skip: skip != null,
  );
}

Future<void> _registerTestDependencies(
  DioClient operatorClient,
  OperatorTourRepositoryImpl operatorRepo,
) async {
  await serviceLocator.reset();
  final poiRepo = PoiRepositoryImpl(DioPoiRemoteDataSource(operatorClient));
  serviceLocator
    ..registerFactory<PoiListCubit>(
      () => PoiListCubit(
        getPois: GetPoisUseCase(poiRepo),
        getLocation: GetPoiLocationUseCase(const _FixedPoiLocationService()),
      ),
    )
    ..registerFactory<CreateTourPackageCubit>(
      () => CreateTourPackageCubit(
        createTour: CreateTourPackageUseCase(operatorRepo),
        loadOptions: LoadTourPackageOptionsUseCase(operatorRepo),
        getTour: GetTourPackageUseCase(operatorRepo),
        updateTour: UpdateTourPackageUseCase(operatorRepo),
        deleteTour: DeleteTourPackageUseCase(operatorRepo),
        addDeparture: AddTourDepartureUseCase(operatorRepo),
        submitForReview: SubmitTourForReviewUseCase(operatorRepo),
        media: ManageTourMediaUseCase(operatorRepo),
        getPoiDetail: GetPoiDetailUseCase(poiRepo),
        imagePicker: _EmbeddedPngPicker(),
      ),
    );
}

GoRouter _buildRouter({
  required OperatorToursCubit listCubit,
  required DioClient travelerClient,
}) => GoRouter(
  initialLocation: AppRoutes.operatorTours,
  routes: [
    GoRoute(
      path: AppRoutes.operatorTours,
      builder: (_, _) => BlocProvider.value(
        value: listCubit,
        child: const OperatorToursPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.createTourPackage,
      builder: (_, state) => BlocProvider(
        create: (_) => serviceLocator<CreateTourPackageCubit>()..loadOptions(),
        child: CreateTourPackagePage(
          cloneFrom: state.extra is TourPackageDetail
              ? state.extra as TourPackageDetail
              : null,
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.editTourPackage,
      builder: (_, state) => BlocProvider(
        key: ValueKey('edit-tour-${state.pathParameters['tourId']}'),
        create: (_) => serviceLocator<CreateTourPackageCubit>(),
        child: EditTourPackagePage(
          tourId: int.tryParse(state.pathParameters['tourId'] ?? ''),
        ),
      ),
    ),
    GoRoute(
      path: '/traveler/tours/:tourId',
      builder: (_, state) => TourDetailPage(
        key: ValueKey('traveler-tour-${state.pathParameters['tourId']}'),
        tourId: state.pathParameters['tourId'] ?? '',
        getTourDetail: GetTourDetail(
          TourDetailRepositoryImpl(
            DioTourDetailRemoteDataSource(travelerClient),
          ),
        ),
      ),
    ),
  ],
);

Future<void> _approveAndPublishTour(DioClient staffClient, int tourId) async {
  await staffClient.dio.post<Object?>(
    '/api/v1/admin/tours/$tourId/approve',
    data: {
      'checklist': {
        'contentCompleteness': true,
        'imageAppropriateness': true,
        'pricePlausibility': true,
        'policyCompliance': true,
        'itineraryFeasibility': true,
      },
      'note': 'Mobile E2E Approved',
    },
  );
  await staffClient.dio.post<Object?>('/api/v1/admin/tours/$tourId/publish');
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await _scrollToFinder(tester, finder);
  await _until(tester, finder);
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

Finder _verticalScrollables() => find.byWidgetPredicate(
  (widget) =>
      widget is Scrollable &&
      widget.restorationId != 'editable' &&
      (widget.axisDirection == AxisDirection.down ||
          widget.axisDirection == AxisDirection.up),
);

Future<void> _scrollToFinder(WidgetTester tester, Finder finder) async {
  for (var w = 0; w < 20 && finder.evaluate().isEmpty; w++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }
  for (var i = 0; i < 12 && finder.evaluate().isEmpty; i++) {
    final scrollable = _verticalScrollables();
    if (scrollable.evaluate().isEmpty) break;
    await tester.drag(scrollable.last, const Offset(0, -320));
    await tester.pumpAndSettle();
  }
  for (var i = 0; i < 14 && finder.evaluate().isEmpty; i++) {
    final scrollable = _verticalScrollables();
    if (scrollable.evaluate().isEmpty) break;
    await tester.drag(scrollable.last, const Offset(0, 320));
    await tester.pumpAndSettle();
  }
}

Future<void> _scrollToText(WidgetTester tester, String text) async {
  final finder = find.textContaining(text);
  await _scrollToFinder(tester, finder);
  await _until(tester, finder);
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
}

Future<void> _enterVisible(
  WidgetTester tester,
  Finder finder,
  String text,
) async {
  await _scrollToFinder(tester, finder);
  await _until(tester, finder);
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.enterText(finder.first, text);
  await tester.pumpAndSettle();
}

Future<void> _until(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 200; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    if (finder.evaluate().isNotEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  throw TestFailure('Timed out waiting for $finder');
}

Future<DioClient> _signIn(
  String email, {
  String loginPath = '/api/v1/auth/login',
}) async {
  final response = await Dio(BaseOptions(baseUrl: _api))
      .post<Map<String, dynamic>>(
        loginPath,
        data: {'email': email, 'password': _password},
      );
  final data = response.data!['data'] as Map<String, dynamic>;
  final token = data['accessToken'] as String;
  return DioClient(
    config: AppConfig(
      environment: Environment.development,
      apiBaseUrl: Uri.parse(_api),
    ),
    secureStorage: _MemoryStorage(token),
  );
}

final class _MemoryStorage implements SecureStorageService {
  _MemoryStorage(this._token);
  final String _token;

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  Future<String?> read(String key) async =>
      key == AppConstants.accessTokenKey ? _token : null;

  @override
  Future<void> write(String key, String value) async {}
}

final class _FixedPoiLocationService implements PoiLocationService {
  const _FixedPoiLocationService();

  @override
  Future<PoiLocation> requestCurrentLocation() async =>
      const PoiLocation(latitude: 16.0611, longitude: 108.2278);
}

final class _EmbeddedPngPicker implements TourImagePicker {
  @override
  Future<TourImageUpload?> pickImage() async => TourImageUpload(
    fileName: 'mobile-e2e-cover.png',
    contentType: 'image/png',
    bytes: base64Decode(_samplePngBase64),
  );
}

/// Delegates every operation to [DioOperatorTourRemoteDataSource]. Only when an
/// external media provider returns 503 (e.g. local offline/clock-skewed E2E)
/// and `TOUR_E2E_MEDIA_SEED_URL` is configured, seeds the DB media row after
/// exercising the real multipart + SkiaSharp inspection endpoint.
final class _E2eOperatorTourRemoteDataSource
    implements OperatorTourRemoteDataSource {
  _E2eOperatorTourRemoteDataSource(this._inner);
  final OperatorTourRemoteDataSource _inner;

  @override
  Future<int> createDraft(TourPackageDraft draft, String idempotencyKey) =>
      _inner.createDraft(draft, idempotencyKey);

  @override
  Future<void> updateDraft(int tourId, TourPackageDraft draft) =>
      _inner.updateDraft(tourId, draft);

  @override
  Future<void> deleteTour(int tourId) => _inner.deleteTour(tourId);

  @override
  Future<TourDepartureDetail> addDeparture(
    int tourId,
    TourScheduleDraft departure,
    String idempotencyKey,
  ) => _inner.addDeparture(tourId, departure, idempotencyKey);

  @override
  Future<TourPackageOptions> loadOptions() => _inner.loadOptions();

  @override
  Future<TourPackageDetail> getTour(int tourId) => _inner.getTour(tourId);

  @override
  Future<TourPackagePage> listTours({
    String? status,
    int page = 1,
    int pageSize = 20,
  }) => _inner.listTours(status: status, page: page, pageSize: pageSize);

  @override
  Future<TourReviewSubmission> submitForReview(
    int tourId, {
    String? submissionNote,
  }) => _inner.submitForReview(tourId, submissionNote: submissionNote);

  @override
  Future<List<TourMediaItem>> listMedia(int tourId) => _inner.listMedia(tourId);

  @override
  Future<void> uploadMedia(
    int tourId,
    TourImageUpload image, {
    required String altText,
    required bool makePrimary,
    required String idempotencyKey,
  }) async {
    try {
      await _inner.uploadMedia(
        tourId,
        image,
        altText: altText,
        makePrimary: makePrimary,
        idempotencyKey: idempotencyKey,
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 503 && _mediaSeedUrl.isNotEmpty) {
        await Dio().post<Object?>(
          _mediaSeedUrl,
          queryParameters: {'tourId': tourId, 'isPrimary': makePrimary},
        );
        return;
      }
      rethrow;
    }
  }

  @override
  Future<void> setPrimaryMedia(int tourId, int mediaId) =>
      _inner.setPrimaryMedia(tourId, mediaId);

  @override
  Future<void> deleteMedia(int tourId, int mediaId) =>
      _inner.deleteMedia(tourId, mediaId);
}
