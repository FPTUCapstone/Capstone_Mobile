import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/tripmate_visual_tokens.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/shared/widgets/anchored_action_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';
import 'package:trip_mate_mobile/shared/widgets/section_card.dart';

/// UC-08 Traveler Profile (Screen #45).
///
/// Only the Backend-issued identity carried by the authenticated session
/// (`fullName`, `email`) is real data here. The Backend does not yet expose a
/// profile read/update contract, so the profile is presented read-only: every
/// other value is shown as not provided, and nothing can be changed or "saved".
class TravelerProfilePage extends StatelessWidget {
  const TravelerProfilePage({super.key});

  static const _notProvided = 'Not provided';

  @override
  Widget build(BuildContext context) {
    final fullName = context.select((AuthSessionCubit c) => c.state.fullName);
    final email = context.select((AuthSessionCubit c) => c.state.email);

    return TripMateVisualTheme(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          actions: const [
            TextButton(onPressed: null, child: Text('Save')),
            SizedBox(width: AppSpacing.xxs),
          ],
        ),
        bottomNavigationBar: const AnchoredActionBar(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CapabilityNote(
                message: "Profile editing isn't available in the app yet.",
              ),
              SizedBox(height: AppSpacing.xs),
              AppButton(label: 'Save changes', onPressed: null),
            ],
          ),
        ),
        body: AppPageScaffold(
          showAppBar: false,
          content: [
            const SizedBox(height: AppSpacing.sm),
            _ProfileHeader(fullName: fullName),
            const SizedBox(height: AppSpacing.lg),
            const FieldLabel('Full name'),
            ReadOnlyField(
              icon: Icons.person_outline,
              value: fullName,
              placeholder: 'Name not available',
            ),
            const SizedBox(height: AppSpacing.md),
            const FieldLabel('Phone number'),
            const ReadOnlyField(
              icon: Icons.phone_outlined,
              placeholder: _notProvided,
            ),
            const SizedBox(height: AppSpacing.md),
            const FieldLabel('Email address', trailing: _ReadOnlyChip()),
            ReadOnlyField(
              icon: Icons.mail_outline,
              value: email,
              placeholder: 'Email not available',
              tinted: true,
              helper: 'Your email identifies your account.',
            ),
            const SizedBox(height: AppSpacing.md),
            const FieldLabel('Address'),
            const ReadOnlyField(
              icon: Icons.location_on_outlined,
              placeholder: _notProvided,
            ),
            const SizedBox(height: AppSpacing.md),
            const FieldLabel('Date of birth'),
            const ReadOnlyField(
              icon: Icons.calendar_today_outlined,
              placeholder: _notProvided,
            ),
            const SizedBox(height: AppSpacing.md),
            const FieldLabel('Gender'),
            const ReadOnlyField(icon: Icons.wc, placeholder: _notProvided),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.fullName});

  final String? fullName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        Semantics(
          label: 'No profile photo available',
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: TripMateVisualTokens.cardShadow,
            ),
            child: CircleAvatar(
              radius: 46,
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.primary,
              child: const Icon(Icons.person_outline, size: 46),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          fullName ?? 'Name not available',
          style: theme.textTheme.titleLarge?.copyWith(
            color: scheme.secondary,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        const _TravelerPill(),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.photo_camera_outlined, size: 18),
          label: const Text('Change avatar'),
        ),
      ],
    );
  }
}

/// The role badge from the Stitch profile header (navy pill).
class _TravelerPill extends StatelessWidget {
  const _TravelerPill();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: TripMateVisualTokens.navy,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.luggage_outlined,
              size: 14,
              color: TripMateVisualTokens.tealLight,
            ),
            SizedBox(width: 6),
            Text(
              'TRAVELER',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Marks the email as read-only where Stitch places its status chip.
class _ReadOnlyChip extends StatelessWidget {
  const _ReadOnlyChip();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              'Read only',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
