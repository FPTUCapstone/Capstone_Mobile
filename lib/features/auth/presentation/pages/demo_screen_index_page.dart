import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';

class DemoScreenIndexPage extends StatelessWidget {
  const DemoScreenIndexPage({super.key});

  static const _screens = [
    ('UC-01', 'Register Traveler Account', AppRoutes.demoUc01),
    ('UC-02', 'Register Tour Operator Account', AppRoutes.demoUc02),
    ('UC-03', 'Resubmit Operator Application', AppRoutes.demoUc03),
    ('UC-04', 'Sign In', AppRoutes.demoUc04),
    ('UC-05', 'Sign Out / Settings', AppRoutes.demoUc05),
    ('UC-06', 'Reset Password', AppRoutes.demoUc06),
    ('UC-07', 'Change Password', AppRoutes.demoUc07),
    ('UC-08', 'Update Traveler Profile', AppRoutes.demoUc08),
    ('UC-09', 'Travel Preferences', AppRoutes.demoUc09),
  ];

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Demo Screens',
      content: [
        const AppAlert(
          title: 'Development only',
          message:
              'This index is available only in debug builds and is not a production TripMate feature.',
          type: AppAlertType.warning,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Account & Authentication',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Column(
            children: _screens
                .map(
                  (screen) => ListTile(
                    leading: CircleAvatar(child: Text(screen.$1.substring(3))),
                    title: Text(screen.$1),
                    subtitle: Text(screen.$2),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(screen.$3),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}
