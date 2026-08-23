import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Choose a mobile experience',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'These buttons only preview role-based routing. No credentials '
              'are collected or sent.',
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Preview Traveler shell',
              onPressed: () =>
                  context.read<AuthSessionCubit>().previewAs(UserRole.traveler),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Preview Tour Operator shell',
              onPressed: () => context.read<AuthSessionCubit>().previewAs(
                UserRole.tourOperator,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            TextButton(
              onPressed: () => context.go(AppRoutes.travelerRegistration),
              child: const Text('Traveler registration placeholder'),
            ),
            TextButton(
              onPressed: () => context.go(AppRoutes.operatorRegistration),
              child: const Text('Tour Operator onboarding placeholder'),
            ),
          ],
        ),
      ),
    );
  }
}
