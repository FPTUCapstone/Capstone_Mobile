import 'dart:convert';
import 'dart:io';

import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/router/notification_destinations.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/notifications/data/repositories/in_app_notification_repository_impl.dart';
import 'package:trip_mate_mobile/features/notifications/presentation/cubit/in_app_inbox_cubit.dart';
import 'package:trip_mate_mobile/features/notifications/presentation/pages/in_app_inbox_page.dart';

void main() {
  final fixtureJson =
      Platform.environment['TRIPMATE_NOTIFICATION_MOBILE_FIXTURE'];
  final fixture = fixtureJson == null
      ? null
      : jsonDecode(fixtureJson) as Map<String, dynamic>;

  for (final role in ['Traveler', 'TourOperator']) {
    testWidgets(
      '$role reads only its own SQL-backed notification in Flutter inbox',
      skip: fixture == null,
      (tester) async {
        final origin = Uri.parse(fixture!['origin'] as String);
        expect(origin.host, anyOf('127.0.0.1', 'localhost'));
        final actors = (fixture['actors'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        final actor = actors.singleWhere((user) => user['role'] == role);
        final foreignActor = actors.singleWhere((user) => user['role'] != role);
        final isOperator = role == 'TourOperator';
        final client = DioClient(
          config: AppConfig(
            environment: Environment.production,
            apiBaseUrl: origin,
          ),
          secureStorage: _TokenStorage(actor['token'] as String),
        );
        client.dio.httpClientAdapter = IOHttpClientAdapter(
          createHttpClient: () => _RealHttpOverrides().createHttpClient(null),
        );
        addTearDown(() => client.dio.close(force: true));
        final repository = InAppNotificationRepositoryImpl(dioClient: client);
        final cubit = InAppInboxCubit(repository);
        addTearDown(cubit.close);
        await tester.runAsync(cubit.load);

        final id = actor['noticeId'] as int;
        final foreignId = foreignActor['noticeId'] as int;
        final title = actor['title'] as String;
        expect(
          cubit.state.items.map((item) => item.id),
          isNot(contains(foreignId)),
        );
        await tester.runAsync(
          () => expectLater(
            repository.markRead(foreignId),
            throwsA(isA<NotFoundFailure>()),
          ),
        );
        final item = cubit.state.items.singleWhere((item) => item.id == id);
        expect(item.isRead, isFalse);
        final inbox = isOperator
            ? AppRoutes.operatorInbox
            : AppRoutes.inAppInbox;
        final router = GoRouter(
          initialLocation: inbox,
          routes: [
            GoRoute(
              path: inbox,
              builder: (_, _) => BlocProvider.value(
                value: cubit,
                child: InAppInboxPage(
                  destinationFor: isOperator
                      ? operatorNotificationDestination
                      : travelerNotificationDestination,
                ),
              ),
            ),
            GoRoute(
              path: AppRoutes.editTourPackage,
              builder: (_, state) => Scaffold(
                body: Text('Tour ${state.pathParameters['tourId']}'),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        final tile = find.ancestor(
          of: find.text(title),
          matching: find.byType(Card),
        );
        expect(
          find.descendant(of: tile, matching: find.text('Unread')),
          findsOneWidget,
        );
        await tester.runAsync(() async {
          final read = cubit.stream.firstWhere(
            (state) => state.items.any((item) => item.id == id && item.isRead),
          );
          await tester.tap(
            find.descendant(
              of: tile,
              matching: find.text(isOperator ? 'Open' : 'Mark as read'),
            ),
          );
          await read.timeout(const Duration(seconds: 15));
          final persisted = await repository.getInbox();
          expect(
            persisted.items.singleWhere((item) => item.id == id).isRead,
            isTrue,
          );
        });
        await tester.pumpAndSettle();
        if (isOperator) {
          expect(find.text('Tour ${item.relatedEntityId}'), findsOneWidget);
        } else {
          expect(
            find.descendant(of: tile, matching: find.text('Unread')),
            findsNothing,
          );
        }
      },
    );
  }
}

final class _RealHttpOverrides extends HttpOverrides {}

final class _TokenStorage implements SecureStorageService {
  const _TokenStorage(this._token);
  final String _token;

  @override
  Future<String?> read(String key) async =>
      key == AppConstants.accessTokenKey ? _token : null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> deleteAll() async {}
}
