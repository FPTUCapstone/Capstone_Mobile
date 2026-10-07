import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/commercial_services/resources/commercial_service_en.dart';

void main() {
  group('CR-09 Centralized Resources Architecture Test', () {
    test('CommercialServiceEn exposes all required resource namespaces', () {
      expect(CommercialServiceEn.search, isNotNull);
      expect(CommercialServiceEn.detail, isNotNull);
      expect(CommercialServiceEn.booking, isNotNull);
      expect(CommercialServiceEn.messages, isNotNull);
      expect(CommercialServiceEn.demo, isNotNull);
      expect(CommercialServiceEn.accessibility, isNotNull);

      // Verify specific canonical strings
      expect(CommercialServiceEn.search.title, equals('Commercial Services'));
      expect(
        CommercialServiceEn.booking.title,
        equals('Commercial Service Booking'),
      );
      expect(
        CommercialServiceEn.messages.requestCancelled,
        contains('If a payment had been collected'),
      );
    });

    test(
      'Commercial presentation pages contain zero hardcoded user-facing string literals in UI widgets',
      () {
        final presentationDir = Directory(
          'lib/features/commercial_services/presentation/pages',
        );
        expect(
          presentationDir.existsSync(),
          isTrue,
          reason: 'presentation/pages directory must exist',
        );

        final dartFiles = presentationDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList();

        expect(dartFiles, isNotEmpty);

        final violations = <String>[];

        // Regex patterns detecting raw user-visible string literals inside widgets
        // Disallows raw words (2+ letters) directly passed to UI string parameters
        final textPattern = RegExp(
          r'''Text\(\s*['"]([a-zA-Z\u00C0-\u024F\u1E00-\u1EFF]{2,}[^'"]*)['"]''',
        );
        final labelTextPattern = RegExp(
          r'''labelText:\s*['"]([a-zA-Z\u00C0-\u024F\u1E00-\u1EFF]{2,}[^'"]*)['"]''',
        );
        final hintTextPattern = RegExp(
          r'''hintText:\s*['"]([a-zA-Z\u00C0-\u024F\u1E00-\u1EFF]{2,}[^'"]*)['"]''',
        );
        final tooltipPattern = RegExp(
          r'''tooltip:\s*['"]([a-zA-Z\u00C0-\u024F\u1E00-\u1EFF]{2,}[^'"]*)['"]''',
        );
        final semanticsLabelPattern = RegExp(
          r'''Semantics\([^)]*label:\s*['"]([a-zA-Z\u00C0-\u024F\u1E00-\u1EFF]{2,}[^'"]*)['"]''',
        );

        for (final file in dartFiles) {
          final lines = file.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            final trimmed = line.trim();

            // Skip comments
            if (trimmed.startsWith('//') ||
                trimmed.startsWith('/*') ||
                trimmed.startsWith('*')) {
              continue;
            }

            // Exclude ValueKey, Key, debugPrint, route paths
            if (line.contains("Key('") ||
                line.contains('Key("') ||
                line.contains('AppRoutes.') ||
                line.contains("path: '")) {
              continue;
            }

            if (textPattern.hasMatch(line)) {
              final match = textPattern.firstMatch(line)!.group(1);
              violations.add(
                '${file.path}:${i + 1} - Raw Text literal: "$match"',
              );
            }
            if (labelTextPattern.hasMatch(line)) {
              final match = labelTextPattern.firstMatch(line)!.group(1);
              violations.add(
                '${file.path}:${i + 1} - Raw labelText literal: "$match"',
              );
            }
            if (hintTextPattern.hasMatch(line)) {
              final match = hintTextPattern.firstMatch(line)!.group(1);
              violations.add(
                '${file.path}:${i + 1} - Raw hintText literal: "$match"',
              );
            }
            if (tooltipPattern.hasMatch(line)) {
              final match = tooltipPattern.firstMatch(line)!.group(1);
              violations.add(
                '${file.path}:${i + 1} - Raw tooltip literal: "$match"',
              );
            }
            if (semanticsLabelPattern.hasMatch(line)) {
              final match = semanticsLabelPattern.firstMatch(line)!.group(1);
              violations.add(
                '${file.path}:${i + 1} - Raw Semantics label literal: "$match"',
              );
            }
          }
        }

        expect(
          violations,
          isEmpty,
          reason:
              'CR-09 VIOLATION: Hardcoded string literals found in commercial presentation pages:\n'
              '${violations.join('\n')}\n'
              'All user-visible UI text MUST be centralized in CommercialServiceEn.',
        );
      },
    );

    test(
      'Commercial entry points in traveler_shell_page.dart use CommercialServiceEn (PR #32 commercial scope)',
      () {
        final shellFile = File(
          'lib/features/traveler/presentation/pages/traveler_shell_page.dart',
        );
        expect(shellFile.existsSync(), isTrue);

        final content = shellFile.readAsStringSync();

        // Check imports
        expect(
          content,
          contains(
            "import 'package:trip_mate_mobile/features/commercial_services/resources/commercial_service_en.dart';",
          ),
          reason: 'traveler_shell_page.dart must import CommercialServiceEn',
        );

        // Verify that commercial entry buttons do NOT use raw strings
        expect(
          content,
          contains(
            'key: const Key(\'traveler_home_commercial_services_button\')',
          ),
          reason: 'Home commercial button must exist with expected test key',
        );
        expect(
          content,
          contains(
            'key: const Key(\'traveler_bookings_commercial_services_button\')',
          ),
          reason:
              'Bookings commercial button must exist with expected test key',
        );

        // Verify both button labels use CommercialServiceEn.search.title
        final lines = content.split('\n');
        var verifiedButtons = 0;
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains('traveler_home_commercial_services_button') ||
              lines[i].contains(
                'traveler_bookings_commercial_services_button',
              )) {
            // Check subsequent lines for CommercialServiceEn.search.title
            final window = lines
                .sublist(i, (i + 7).clamp(0, lines.length))
                .join('\n');
            if (window.contains('CommercialServiceEn.search.title')) {
              verifiedButtons++;
            }
          }
        }

        expect(
          verifiedButtons,
          equals(2),
          reason:
              'Both commercial entry points in traveler_shell_page must use CommercialServiceEn.search.title',
        );
      },
    );
  });
}
