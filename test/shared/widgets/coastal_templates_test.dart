import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_theme.dart';
import 'package:trip_mate_mobile/shared/widgets/app_bottom_sheet_scaffold.dart';
import 'package:trip_mate_mobile/shared/widgets/app_coastal_app_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/app_filter_chip_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/app_section_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_sticky_action_bar.dart';

Widget _app({
  required ThemeData theme,
  required Widget home,
  double textScale = 1.0,
}) {
  return MaterialApp(
    theme: theme,
    themeAnimationDuration: Duration.zero,
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: home,
    ),
  );
}

void main() {
  group('Canonical Coastal Heritage Templates (T2–T5)', () {
    testWidgets(
      'AppCoastalAppBar renders title, optional subtitle, and hairline divider in Light & Dark',
      (tester) async {
        await tester.pumpWidget(
          _app(
            theme: AppTheme.dark,
            home: const Scaffold(
              appBar: AppCoastalAppBar(
                title: 'Tour Details',
                subtitle: 'Central Vietnam',
              ),
              body: SizedBox.shrink(),
            ),
          ),
        );

        expect(find.text('Tour Details'), findsOneWidget);
        expect(find.text('Central Vietnam'), findsOneWidget);
        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.backgroundColor, TripMateColors.dark.surfaceCard);
        expect(appBar.elevation, 0);
        expect(find.byType(Divider), findsOneWidget);
      },
    );

    testWidgets(
      'AppStickyActionBar renders summary + primary CTA cleanly at 320x568 and 200% text scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        var tapped = false;
        await tester.pumpWidget(
          _app(
            theme: AppTheme.light,
            textScale: 2.0,
            home: Scaffold(
              body: const SizedBox.expand(),
              bottomNavigationBar: AppStickyActionBar(
                summary: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text('From'), Text('1.500.000₫')],
                ),
                primaryAction: FilledButton(
                  onPressed: () => tapped = true,
                  child: const Text('Book Now'),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('1.500.000₫'), findsOneWidget);
        await tester.tap(find.text('Book Now'));
        expect(tapped, isTrue);
      },
    );

    testWidgets(
      'AppStickyActionBar lays out dual secondary + primary actions evenly',
      (tester) async {
        var declined = false;
        var accepted = false;
        await tester.pumpWidget(
          _app(
            theme: AppTheme.dark,
            home: Scaffold(
              body: const SizedBox.expand(),
              bottomNavigationBar: AppStickyActionBar(
                secondaryAction: OutlinedButton(
                  onPressed: () => declined = true,
                  child: const Text('Decline'),
                ),
                primaryAction: FilledButton(
                  onPressed: () => accepted = true,
                  child: const Text('Accept'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Decline'));
        await tester.tap(find.text('Accept'));
        expect(declined, isTrue);
        expect(accepted, isTrue);
      },
    );

    testWidgets(
      'AppFilterChipBar uses ChoiceChips with accessible targets and updates selection',
      (tester) async {
        String? selected;
        await tester.pumpWidget(
          _app(
            theme: AppTheme.light,
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: AppFilterChipBar<String?>(
                  selectedValue: selected,
                  onSelected: (value) => setState(() => selected = value),
                  options: const [
                    AppFilterOption(value: null, label: 'All'),
                    AppFilterOption(value: 'draft', label: 'Draft', count: 2),
                    AppFilterOption(value: 'live', label: 'Published'),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.byType(ChoiceChip), findsNWidgets(3));
        expect(find.text('Draft (2)'), findsOneWidget);

        // Tap target meets mobile touch ergonomics (>= 44dp height)
        final chipSize = tester.getSize(
          find.widgetWithText(ChoiceChip, 'Published'),
        );
        expect(chipSize.height, greaterThanOrEqualTo(44));

        await tester.tap(find.widgetWithText(ChoiceChip, 'Published'));
        await tester.pumpAndSettle();
        expect(selected, 'live');
      },
    );

    testWidgets(
      'showAppModalBottomSheet presents AppBottomSheetScaffold and closes via 44dp close button',
      (tester) async {
        await tester.pumpWidget(
          _app(
            theme: AppTheme.dark,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => showAppModalBottomSheet<void>(
                      context: context,
                      title: 'Bank Payment Guide',
                      subtitle: 'Scan VietQR inside your banking app',
                      builder: (_) => const Text('Sheet instructions body'),
                    ),
                    child: const Text('Open sheet'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open sheet'));
        await tester.pumpAndSettle();

        expect(find.byType(AppBottomSheetScaffold), findsOneWidget);
        expect(find.text('Bank Payment Guide'), findsOneWidget);
        expect(
          find.text('Scan VietQR inside your banking app'),
          findsOneWidget,
        );
        expect(find.text('Sheet instructions body'), findsOneWidget);

        final closeBtn = find.byTooltip('Đóng');
        expect(closeBtn, findsOneWidget);
        expect(tester.getSize(closeBtn).height, greaterThanOrEqualTo(44));

        await tester.tap(closeBtn);
        await tester.pumpAndSettle();
        expect(find.byType(AppBottomSheetScaffold), findsNothing);
      },
    );

    testWidgets(
      'AppSectionCard and AppKeyValueRow render structured info without overflow at 200% text scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _app(
            theme: AppTheme.dark,
            textScale: 2.0,
            home: const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: AppSectionCard(
                  title: 'Price Breakdown',
                  subtitle: 'Live server quote',
                  icon: Icons.receipt_long_outlined,
                  child: Column(
                    children: [
                      AppKeyValueRow(
                        label: 'Adults (2)',
                        value: '1.500.000₫',
                        isPrice: true,
                      ),
                      AppKeyValueRow(
                        label: 'Total Amount',
                        value: '1.500.000₫',
                        isPrice: true,
                        isProminent: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Price Breakdown'), findsOneWidget);
        expect(find.text('Live server quote'), findsOneWidget);
        expect(find.text('1.500.000₫'), findsNWidgets(2));
      },
    );
  });
}
