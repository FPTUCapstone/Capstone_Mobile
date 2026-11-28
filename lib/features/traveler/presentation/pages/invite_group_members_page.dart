import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/invite_group_members_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/invite_group_members_state.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

/// [UC-18] Page for inviting group members via QR code and invite code.
class InviteGroupMembersPage extends StatefulWidget {
  const InviteGroupMembersPage({
    super.key,
    required this.groupId,
    this.shareOperation,
  });

  final int groupId;
  final Future<void> Function(String payload, Rect? shareOrigin)?
  shareOperation;

  @override
  State<InviteGroupMembersPage> createState() => _InviteGroupMembersPageState();
}

class _InviteGroupMembersPageState extends State<InviteGroupMembersPage> {
  final _shareButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    context.read<InviteGroupMembersCubit>().loadInvitation(widget.groupId);
  }

  void _close() {
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      Navigator.of(context).maybePop();
    } else if (router.canPop()) {
      router.pop();
    } else {
      router.go(AppRoutes.traveler);
    }
  }

  List<Widget> get _closeAction => [
    TextButton(onPressed: _close, child: const Text('Đóng')),
  ];

  Future<void> _copyInviteCode(String code) async {
    try {
      await Clipboard.setData(ClipboardData(text: code));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã sao chép mã mời "$code".'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'TripMate tạm thời không thể xử lý yêu cầu của bạn. Vui lòng kiểm tra kết nối mạng và thử lại.',
          ),
        ),
      );
    }
  }

  Future<void> _shareInvitation(String deepLink) async {
    try {
      final renderBox =
          _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
      final shareOrigin = renderBox == null
          ? null
          : renderBox.localToGlobal(Offset.zero) & renderBox.size;
      final operation = widget.shareOperation;
      if (operation != null) {
        await operation(deepLink, shareOrigin);
      } else {
        await SharePlus.instance.share(
          ShareParams(text: deepLink, sharePositionOrigin: shareOrigin),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'TripMate tạm thời không thể xử lý yêu cầu của bạn. Vui lòng kiểm tra kết nối mạng và thử lại.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmRegenerateInvitation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tạo lại lời mời?'),
        content: const Text('Mã mời hiện tại sẽ ngừng hoạt động ngay lập tức.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Tạo lại'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      unawaited(
        context.read<InviteGroupMembersCubit>().regenerateInvitation(
          widget.groupId,
        ),
      );
    }
  }

  String _formatExpiry(DateTime expiresAt) {
    final hoChiMinhTime = expiresAt.toUtc().add(const Duration(hours: 7));
    return '${hoChiMinhTime.day.toString().padLeft(2, '0')}/'
        '${hoChiMinhTime.month.toString().padLeft(2, '0')}/'
        '${hoChiMinhTime.year} '
        '${hoChiMinhTime.hour.toString().padLeft(2, '0')}:'
        '${hoChiMinhTime.minute.toString().padLeft(2, '0')} (GMT+7)';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InviteGroupMembersCubit, InviteGroupMembersState>(
      builder: (context, state) {
        if (state.status == InviteGroupMembersStatus.loading ||
            state.status == InviteGroupMembersStatus.initial ||
            (state.status == InviteGroupMembersStatus.regenerating &&
                state.invitation == null)) {
          return AppPageScaffold(
            title: 'Mời thành viên',
            actions: _closeAction,
            content: [
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: CircularProgressIndicator(),
                ),
              ),
            ],
          );
        }

        if (state.status == InviteGroupMembersStatus.regenerationUncertain) {
          return AppPageScaffold(
            title: 'Mời thành viên',
            actions: _closeAction,
            content: [
              AppAlert(
                message:
                    state.errorMessage ??
                    'Lời mời có thể đã thay đổi. Vui lòng thử lại để xác nhận mã hiện tại.',
                type: AppAlertType.error,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Thử lại',
                onPressed: () => context
                    .read<InviteGroupMembersCubit>()
                    .regenerateInvitation(widget.groupId),
              ),
            ],
          );
        }

        if (state.status == InviteGroupMembersStatus.failure &&
            state.invitation == null) {
          return AppPageScaffold(
            title: 'Mời thành viên',
            actions: _closeAction,
            content: [
              AppAlert(
                message:
                    state.errorMessage ??
                    'TripMate tạm thời không thể xử lý yêu cầu của bạn.',
                type: AppAlertType.error,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Thử lại',
                onPressed: () => context
                    .read<InviteGroupMembersCubit>()
                    .loadInvitation(widget.groupId),
              ),
            ],
          );
        }

        final invitation = state.invitation!;
        final isRegenerating =
            state.status == InviteGroupMembersStatus.regenerating;
        return AppPageScaffold(
          title: 'Mời thành viên',
          actions: _closeAction,
          content: [
            if (state.status == InviteGroupMembersStatus.failure) ...[
              AppAlert(
                message:
                    state.errorMessage ??
                    'TripMate tạm thời không thể xử lý yêu cầu của bạn.',
                type: AppAlertType.error,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            // Group Header Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.groups_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invitation.groupName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        const StatusBadge(
                          label: 'TRƯỞNG NHÓM',
                          type: StatusBadgeType.info,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // QR Code Section
            Center(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  children: [
                    QrImageView(
                      data: invitation.qrData,
                      version: QrVersions.auto,
                      size: 184,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Quét mã QR để tham gia nhóm',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Invite Code Container
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                children: [
                  Text(
                    'MÃ MỜI',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.muted,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        invitation.inviteCode,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3.5,
                              color: AppColors.primary,
                            ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      IconButton(
                        icon: const Icon(
                          Icons.copy_rounded,
                          color: AppColors.primary,
                        ),
                        tooltip: 'Sao chép mã',
                        onPressed: isRegenerating
                            ? null
                            : () => _copyInviteCode(invitation.inviteCode),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // Expiration text
            Center(
              child: Text(
                'Hiệu lực đến: ${_formatExpiry(invitation.expiresAt)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Action buttons
            AppButton(
              key: _shareButtonKey,
              label: 'Chia sẻ lời mời',
              onPressed: isRegenerating
                  ? null
                  : () => _shareInvitation(invitation.qrData),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: isRegenerating ? null : _confirmRegenerateInvitation,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                isRegenerating ? 'Đang tạo lại lời mời...' : 'Tạo lại lời mời',
              ),
            ),
          ],
        );
      },
    );
  }
}
