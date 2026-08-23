import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';

class RegistrationPage extends StatelessWidget {
  const RegistrationPage({required this.role, super.key});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final isTraveler = role == UserRole.traveler;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isTraveler ? 'Traveler registration' : 'Business onboarding',
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isTraveler ? Icons.person_add_outlined : Icons.store_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '${role.label} flow placeholder',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'The production registration flow will be implemented in a '
                'dedicated feature task.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
