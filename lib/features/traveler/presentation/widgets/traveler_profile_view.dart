import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/traveler_profile_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';

/// Dedicated Traveler Profile view embedded in the Traveler Shell (SRS #45, #46).
class TravelerProfileView extends StatelessWidget {
  const TravelerProfileView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => serviceLocator<TravelerProfileCubit>()..load(),
    child: BlocBuilder<TravelerProfileCubit, TravelerProfileState>(
      builder: (context, profileState) => _buildProfile(context, profileState),
    ),
  );

  Widget _buildProfile(
    BuildContext context,
    TravelerProfileState profileState,
  ) {
    final session = context.watch<AuthSessionCubit>();
    final state = session.state;
    final email = profileState.profile?.email ?? '';
    final name = profileState.profile?.fullName ?? '';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'T';

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hồ sơ du khách',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.tripHistory),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.history_outlined, size: 15),
                label: const Text(
                  TripHistoryStringsEn.tripHistoryTitle,
                  style: TextStyle(fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
        // Compact Horizontal Profile Summary Card
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundImage: profileState.profile?.avatarUrl == null
                    ? null
                    : NetworkImage(profileState.profile!.avatarUrl!),
                backgroundColor: AppColors.primarySoft,
                child: profileState.profile?.avatarUrl != null
                    ? null
                    : Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondary,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Du khách TripMate' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Thành viên TripMate',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Section: Personal & Travel Preferences (SRS #46)
        Text(
          'Du lịch & Cá nhân',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _ProfileTile(
                icon: Icons.person_outline,
                title: 'Hồ sơ người dùng',
                subtitle: 'Cập nhật thông tin cá nhân',
                onTap: () async {
                  final profileCubit = context.read<TravelerProfileCubit>();
                  await context.push(AppRoutes.travelerProfile);
                  if (!profileCubit.isClosed) await profileCubit.load();
                },
              ),
              const Divider(height: 1, indent: 56),
              _ProfileTile(
                icon: Icons.tune,
                title: 'Sở thích du lịch',
                subtitle: 'Tùy chỉnh phong cách & lịch trình AI',
                onTap: () => context.push(AppRoutes.travelerPreferences),
              ),
              const Divider(height: 1, indent: 56),
              _ProfileTile(
                icon: Icons.download_for_offline_outlined,
                title: 'Dữ liệu ngoại tuyến',
                subtitle: 'Quản lý gói lịch trình ngoại tuyến',
                onTap: () => context.push(AppRoutes.offlinePackages),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Section: Account & Security
        Text(
          'Tài khoản & Bảo mật',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _ProfileTile(
                icon: Icons.settings_outlined,
                title: 'Cài đặt tài khoản',
                subtitle: 'Tùy chọn thông báo và giao diện',
                onTap: () => context.push(AppRoutes.travelerSettings),
              ),
              const Divider(height: 1, indent: 56),
              _ProfileTile(
                icon: Icons.lock_outline,
                title: 'Đổi mật khẩu',
                subtitle: 'Cập nhật mật khẩu đăng nhập',
                onTap: () => context.push(AppRoutes.travelerChangePassword),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Sign Out Button
        OutlinedButton.icon(
          key: const Key('traveler-profile-sign-out-button'),
          onPressed: state.operation == AuthSessionOperation.signOut
              ? null
              : () => _confirmSignOut(context, session),
          icon: const Icon(Icons.logout, size: 18, color: AppColors.error),
          label: const Text(
            'Đăng xuất',
            style: TextStyle(color: AppColors.error),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFFCA5A5)),
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Text(
            'TripMate Mobile · Phiên bản 1.0.0',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.muted,
              fontSize: 11.5,
            ),
          ),
        ),
      ],
    );
  }

  void _confirmSignOut(BuildContext context, AuthSessionCubit session) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận đăng xuất'),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản TripMate không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.of(ctx).pop();
              session.signOut();
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppColors.secondary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
