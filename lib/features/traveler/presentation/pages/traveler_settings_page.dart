import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';

class TravelerSettingsPage extends StatefulWidget {
  const TravelerSettingsPage({super.key});

  @override
  State<TravelerSettingsPage> createState() => _TravelerSettingsPageState();
}

class _TravelerSettingsPageState extends State<TravelerSettingsPage> {
  var _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Settings',
      content: [
        Card(
          child: Column(
            children: [
              _SettingsRow(
                icon: Icons.person_outline,
                label: 'Profile information',
                onTap: () => context.push(AppRoutes.travelerProfile),
              ),
              const Divider(height: 1),
              _SettingsRow(
                icon: Icons.tune,
                label: 'Travel preferences',
                onTap: () => context.push(AppRoutes.travelerPreferences),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_none),
                title: const Text('Notifications'),
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() => _notificationsEnabled = value);
                },
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.cloud_download_outlined),
                title: Text('Offline downloads'),
                trailing: Text('248 MB  ›'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Card(
          child: ListTile(title: Text('App version'), trailing: Text('1.0.0')),
        ),
      ],
      footer: OutlinedButton.icon(
        onPressed: _confirmSignOut,
        icon: const Icon(Icons.logout),
        label: const Text('Sign out'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error),
          minimumSize: const Size.fromHeight(52),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.logout, color: AppColors.error),
        title: const Text('Sign out of TripMate?'),
        content: const Text(
          'Your session on this device will end. Downloaded offline trips stay on the device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          AppButton(
            label: 'Sign out',
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AuthSessionCubit>().clearSession();
    }
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
