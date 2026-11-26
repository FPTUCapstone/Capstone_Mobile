import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';
import 'package:trip_mate_mobile/features/tour_operator/domain/entities/operator_profile.dart';
import 'package:trip_mate_mobile/features/tour_operator/presentation/cubit/operator_profile_cubit.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';

/// Tour Operator Profile view implementing UC-34 (SRS #76).
class OperatorProfileView extends StatefulWidget {
  const OperatorProfileView({this.isDemoMode = false, this.cubit, super.key});

  final bool isDemoMode;
  final OperatorProfileCubit? cubit;

  @override
  State<OperatorProfileView> createState() => _OperatorProfileViewState();
}

class _OperatorProfileViewState extends State<OperatorProfileView> {
  OperatorProfileCubit? _cubit;
  var _ownsCubit = false;

  @override
  void initState() {
    super.initState();
    if (widget.cubit != null) {
      _cubit = widget.cubit;
      _ownsCubit = false;
    } else if (serviceLocator.isRegistered<OperatorProfileCubit>()) {
      _cubit = serviceLocator<OperatorProfileCubit>(param1: widget.isDemoMode);
      _ownsCubit = true;
    }
    if (_cubit != null &&
        _cubit!.state.status == OperatorProfileLoadStatus.initial) {
      unawaited(_cubit!.load());
    }
  }

  @override
  void dispose() {
    if (_ownsCubit && _cubit != null) {
      unawaited(_cubit!.close());
    }
    super.dispose();
  }

  Future<void> _openEdit(OperatorProfile profile) async {
    final updated = await context.push<OperatorProfile>(
      AppRoutes.operatorProfileEditPath(isDemo: widget.isDemoMode),
      extra: profile,
    );
    if (updated != null && mounted) {
      _cubit?.applyUpdatedProfile(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSessionCubit>();
    final authState = session.state;

    final cubit = _cubit;
    if (cubit == null) {
      return _buildContent(
        context: context,
        session: session,
        authState: authState,
        profile: null,
      );
    }

    return BlocBuilder<OperatorProfileCubit, OperatorProfileState>(
      bloc: cubit,
      builder: (context, state) {
        if (state.status == OperatorProfileLoadStatus.loading &&
            state.profile == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.status == OperatorProfileLoadStatus.error &&
            state.profile == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppAlert(
                    message:
                        state.loadError ??
                        OperatorProfileMessages.systemFailure,
                    type: AppAlertType.error,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: cubit.load,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          );
        }

        final profile = state.profile;
        if (profile == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: cubit.load,
          child: _buildContent(
            context: context,
            session: session,
            authState: authState,
            profile: profile,
          ),
        );
      },
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required AuthSessionCubit session,
    required AuthSessionState authState,
    required OperatorProfile? profile,
  }) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (widget.isDemoMode) ...[
          const AppAlert(
            message: 'Bản xem trước DEMO · Dữ liệu hồ sơ mẫu',
            type: AppAlertType.warning,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (profile != null) ...[
          // Business Header Card (compact horizontal layout)
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _HeaderLogo(profile: profile),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.businessName.isNotEmpty
                                ? profile.businessName
                                : 'Chưa cập nhật tên doanh nghiệp',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            profile.contactEmail.isNotEmpty
                                ? profile.contactEmail
                                : profile.accountEmail,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.muted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.verified,
                                  size: 13,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  profile.approvalStatus == 'Approved'
                                      ? 'Đối tác đã xác minh'
                                      : profile.approvalStatus,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('operator_profile_edit_button'),
                  onPressed: () => _openEdit(profile),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('Chỉnh sửa hồ sơ doanh nghiệp'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(40),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        AppCard(
          padding: EdgeInsets.zero,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(
                Icons.description_outlined,
                color: AppColors.primary,
              ),
              title: const Text(
                'Hợp đồng đối tác',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Xem và tải bản hợp đồng của doanh nghiệp',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
              onTap: () => context.push(AppRoutes.operatorContract),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Security & Account Settings
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
              InkWell(
                onTap: () => context.push(AppRoutes.operatorChangePassword),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.lock_outline,
                          size: 19,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Đổi mật khẩu',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.ink,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Cập nhật mật khẩu tài khoản đối tác',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: AppColors.muted,
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, indent: 56),
              InkWell(
                onTap: () => _showPartnerPolicySheet(context),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.description_outlined,
                          size: 19,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quy chế & Chính sách đối tác',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.ink,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Quy định chiết khấu và nghĩa vụ tour',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: AppColors.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Business & Legal Details
        if (profile != null) ...[
          Text(
            'Thông tin pháp lý & Liên hệ',
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
                _InfoTile(
                  icon: Icons.badge_outlined,
                  title: 'Giấy phép kinh doanh',
                  value: _displayOrPlaceholder(profile.businessLicenceNumber),
                ),
                const Divider(height: 1, indent: 56),
                _InfoTile(
                  icon: Icons.receipt_long_outlined,
                  title: 'Mã số thuế',
                  value: _displayOrPlaceholder(profile.taxCode),
                ),
                const Divider(height: 1, indent: 56),
                _InfoTile(
                  icon: Icons.alternate_email,
                  title: 'Email tài khoản đăng nhập',
                  value: _displayOrPlaceholder(profile.accountEmail),
                ),
                const Divider(height: 1, indent: 56),
                _InfoTile(
                  icon: Icons.phone_outlined,
                  title: 'Số điện thoại liên hệ',
                  value: _displayOrPlaceholder(profile.contactPhone),
                ),
                const Divider(height: 1, indent: 56),
                _InfoTile(
                  icon: Icons.mail_outline,
                  title: 'Email liên hệ doanh nghiệp',
                  value: _displayOrPlaceholder(profile.contactEmail),
                ),
                const Divider(height: 1, indent: 56),
                _InfoTile(
                  icon: Icons.location_on_outlined,
                  title: 'Trụ sở chính',
                  value: _displayOrPlaceholder(profile.businessAddress),
                ),
                const Divider(height: 1, indent: 56),
                _InfoTile(
                  icon: Icons.language_outlined,
                  title: 'Website chính thức',
                  value: _displayOrPlaceholder(profile.website ?? ''),
                ),
                const Divider(height: 1, indent: 56),
                _InfoTile(
                  icon: Icons.info_outline,
                  title: 'Mô tả doanh nghiệp',
                  value: _displayOrPlaceholder(profile.businessDescription),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        // Sign Out Button
        OutlinedButton.icon(
          key: const Key('operator-profile-sign-out-button'),
          onPressed: authState.operation == AuthSessionOperation.signOut
              ? null
              : session.signOut,
          icon: const Icon(Icons.logout, size: 18, color: AppColors.error),
          label: const Text(
            'Đăng xuất đối tác',
            style: TextStyle(color: AppColors.error),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppColors.error.withValues(alpha: 0.45)),
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Text(
            'TripMate Partner · Phiên bản 1.0',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.muted,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  String _displayOrPlaceholder(String value) =>
      value.trim().isNotEmpty ? value.trim() : 'Chưa cập nhật';

  void _showPartnerPolicySheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quy chế & Chính sách đối tác',
              style: Theme.of(
                sheetContext,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Gói tour cần có lịch trình, chính sách hủy và giá minh bạch trước khi gửi duyệt.\n'
              '• Đối soát quyết toán được cập nhật tự động sau khi hoàn tất chuyến đi và hết thời hạn hoàn tiền.\n'
              '• Mọi sự cố thời tiết cần được xử lý qua mục Cảnh báo an toàn.',
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.muted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Đã hiểu'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderLogo extends StatelessWidget {
  const _HeaderLogo({required this.profile});

  final OperatorProfile profile;

  @override
  Widget build(BuildContext context) {
    if (profile.localLogoBytes != null) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.memory(profile.localLogoBytes!, fit: BoxFit.contain),
      );
    }
    if (profile.logoUrl != null && profile.logoUrl!.isNotEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          profile.logoUrl!,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _fallbackBadge(),
        ),
      );
    }
    return _fallbackBadge();
  }

  Widget _fallbackBadge() => Container(
    width: 56,
    height: 56,
    decoration: BoxDecoration(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Icon(
      Icons.business_center_outlined,
      color: Colors.white,
      size: 26,
    ),
  );
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
