import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
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
    final c = context.tmColors;
    final session = context.watch<AuthSessionCubit>();
    final state = session.state;
    // Only the approved local-cleanup notice is surfaced here; unrelated auth
    // errors are not this screen's concern.
    final localCleanupFailure =
        state.status == AuthSessionStatus.authenticated &&
        state.errorMessage ==
            AuthSessionCubit.signOutLocalCleanupFailureMessage;

    return AppPageScaffold(
      title: 'Cài đặt',
      content: [
        if (localCleanupFailure) ...[
          AppAlert(message: state.errorMessage!, type: AppAlertType.error),
          const SizedBox(height: AppSpacing.md),
        ],
        AppCard(
          padding: EdgeInsets.zero,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(TripMateRadius.lg),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.person_outline,
                  label: 'Thông tin cá nhân',
                  onTap: () => context.push(AppRoutes.travelerProfile),
                ),
                Divider(height: 1, indent: 60, color: c.borderSubtle),
                _SettingsRow(
                  icon: Icons.tune,
                  label: 'Sở thích du lịch',
                  onTap: () => context.push(AppRoutes.travelerPreferences),
                ),
                Divider(height: 1, indent: 60, color: c.borderSubtle),
                _SettingsRow(
                  icon: Icons.lock_outline,
                  label: 'Đổi mật khẩu',
                  onTap: () => context.push(AppRoutes.travelerChangePassword),
                ),
                Divider(height: 1, indent: 60, color: c.borderSubtle),
                SwitchListTile(
                  secondary: _SettingsIconBadge(icon: Icons.notifications_none),
                  title: Text(
                    'Thông báo',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                  activeThumbColor: c.brandTeal,
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() => _notificationsEnabled = value);
                  },
                ),
                Divider(height: 1, indent: 60, color: c.borderSubtle),
                ListTile(
                  leading: const _SettingsIconBadge(
                    icon: Icons.cloud_download_outlined,
                  ),
                  title: Text(
                    'Dữ liệu tải ngoại tuyến',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Quản lý gói ngoại tuyến trong chi tiết lịch trình',
                    style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                  ),
                  trailing: Text(
                    'Theo chuyến  ›',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: c.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: EdgeInsets.zero,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(TripMateRadius.lg),
            child: ListTile(
              leading: const _SettingsIconBadge(icon: Icons.info_outline),
              title: Text(
                'Phiên bản ứng dụng',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
              trailing: Text(
                '1.0.0',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: c.textMuted,
                ),
              ),
            ),
          ),
        ),
      ],
      footer: OutlinedButton.icon(
        onPressed: state.operation == AuthSessionOperation.signOut
            ? null
            : _confirmSignOut,
        icon: const Icon(Icons.logout),
        label: const Text('Đăng xuất'),
        style: _signOutButtonStyle(c),
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final c = context.tmColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.logout, color: c.error),
        title: const Text('Đăng xuất khỏi TripMate?'),
        content: const Text(
          'Phiên đăng nhập trên thiết bị này sẽ kết thúc. Các lịch trình đã tải ngoại tuyến vẫn được giữ lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          AppButton(
            label: 'Đăng xuất',
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AuthSessionCubit>().signOut();
    }
  }

  ButtonStyle _signOutButtonStyle(TripMateColors c) => OutlinedButton.styleFrom(
    foregroundColor: c.error,
    side: BorderSide(color: c.error.withValues(alpha: 0.55)),
    minimumSize: const Size.fromHeight(52),
  );
}

class _SettingsIconBadge extends StatelessWidget {
  const _SettingsIconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: c.tealSoftContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 19, color: c.brandTeal),
    );
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
    final c = context.tmColors;
    return ListTile(
      leading: _SettingsIconBadge(icon: icon),
      title: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w600, color: c.textPrimary),
      ),
      trailing: Icon(Icons.chevron_right, color: c.textMuted),
      onTap: onTap,
    );
  }
}
