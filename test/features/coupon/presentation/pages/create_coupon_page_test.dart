import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/coupon/domain/entities/coupon_draft.dart';
import 'package:trip_mate_mobile/features/coupon/domain/entities/eligible_coupon_tour.dart';
import 'package:trip_mate_mobile/features/coupon/domain/repositories/coupon_repository.dart';
import 'package:trip_mate_mobile/features/coupon/presentation/cubit/create_coupon_cubit.dart';
import 'package:trip_mate_mobile/features/coupon/presentation/cubit/create_coupon_state.dart';
import 'package:trip_mate_mobile/features/coupon/presentation/pages/create_coupon_page.dart';

void main() {
  Widget page(CouponRepository repository) => MaterialApp(
    home: BlocProvider(
      create: (_) => CreateCouponCubit(repository: repository),
      child: const CreateCouponPage(),
    ),
  );

  testWidgets('Create another keeps the selected tours for the next coupon', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(page(_CouponRepository()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mã ưu đãi'),
      'TRIP10',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mức giảm (%)'),
      '10',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mức giảm tối đa (VND)'),
      '100000',
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Tạo mã giảm giá'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Tạo mã khác'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isTrue,
    );
  });

  testWidgets(
    'Create another resets monetary and usage fields but keeps tours',
    (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(page(_CouponRepository()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mã ưu đãi'),
        'TRIP10',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mức giảm (%)'),
        '10',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mức giảm tối đa (VND)'),
        '100000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Đơn hàng tối thiểu (VND)'),
        '200000',
      );
      await tester.tap(find.text('Giới hạn lượt sử dụng (tùy chọn)'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tổng số lượt dùng'),
        '10',
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.tap(find.widgetWithText(FilledButton, 'Tạo mã giảm giá'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Tạo mã khác'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Đơn hàng tối thiểu (VND)'),
            )
            .controller!
            .text,
        '0',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Tổng số lượt dùng'),
            )
            .controller!
            .text,
        isEmpty,
      );
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
    },
  );

  testWidgets('keeps tour selection visible when coupon creation fails', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      page(
        _CouponRepository(
          createFailure: const ConflictFailure('Mã giảm giá này đã tồn tại.'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mã ưu đãi'),
      'TRIP10',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mức giảm (%)'),
      '10',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mức giảm tối đa (VND)'),
      '100000',
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.tap(find.widgetWithText(FilledButton, 'Tạo mã giảm giá'));
    await tester.pumpAndSettle();

    expect(find.text('Mã giảm giá này đã tồn tại.'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsOneWidget);
    expect(
      find.textContaining('Không thể tải danh sách tour đã duyệt'),
      findsNothing,
    );
  });

  testWidgets('updates the customer preview as discount fields change', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(page(_CouponRepository()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mức giảm (%)'),
      '15',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mức giảm tối đa (VND)'),
      '100000',
    );
    await tester.pump();

    expect(find.textContaining('Giảm 15%, tối đa ₫100,000'), findsOneWidget);
  });

  testWidgets('offers a retry action when eligible tours cannot be loaded', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cubit = CreateCouponCubit(
      repository: _CouponRepository(failure: const NetworkFailure()),
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<CreateCouponCubit>.value(
          value: cubit,
          child: const CreateCouponPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(cubit.state.status, CreateCouponStatus.tourLoadFailure);

    expect(find.text('Thử lại'), findsOneWidget);
  });
}

final class _CouponRepository implements CouponRepository {
  _CouponRepository({this.failure, this.createFailure});

  final Failure? failure;
  final Failure? createFailure;

  @override
  Future<String> createCoupon(CouponDraft draft) async {
    if (createFailure != null) throw createFailure!;
    return 'TRIP10';
  }

  @override
  Future<List<EligibleCouponTour>> getEligibleTours() async {
    if (failure != null) throw failure!;
    return const [
      EligibleCouponTour(
        id: 1,
        title: 'Da Nang Highlights',
        destination: 'Da Nang',
        basePrice: 500000,
      ),
    ];
  }
}
