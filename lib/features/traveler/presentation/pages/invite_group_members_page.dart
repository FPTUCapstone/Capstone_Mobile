import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
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
  const InviteGroupMembersPage({super.key, required this.groupId});

  final int groupId;

  @override
  State<InviteGroupMembersPage> createState() => _InviteGroupMembersPageState();
}

class _InviteGroupMembersPageState extends State<InviteGroupMembersPage> {
  @override
  void initState() {
    super.initState();
    context.read<InviteGroupMembersCubit>().loadInvitation(widget.groupId);
  }

  Future<void> _copyInviteCode(String code) async {
    final copyOperation = Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invite code "$code" copied to clipboard.'),
        duration: Duration(seconds: 2),
      ),
    );
    try {
      await copyOperation;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'TripMate is temporarily unable to process your request. Please check your connection and try again.',
          ),
        ),
      );
    }
  }

  Future<void> _shareInvitation(String deepLink) {
    return SharePlus.instance.share(ShareParams(text: deepLink));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InviteGroupMembersCubit, InviteGroupMembersState>(
      builder: (context, state) {
        if (state.status == InviteGroupMembersStatus.loading ||
            state.status == InviteGroupMembersStatus.initial) {
          return const AppPageScaffold(
            title: 'Invite Members',
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

        if (state.status == InviteGroupMembersStatus.failure) {
          return AppPageScaffold(
            title: 'Invite Members',
            content: [
              AppAlert(
                message:
                    state.errorMessage ??
                    'TripMate is temporarily unable to process your request.',
                type: AppAlertType.error,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Retry',
                onPressed: () => context
                    .read<InviteGroupMembersCubit>()
                    .loadInvitation(widget.groupId),
              ),
            ],
          );
        }

        final invitation = state.invitation!;
        return AppPageScaffold(
          title: 'Invite Members',
          content: [
            // Group Header Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
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
                      size: 26,
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
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const StatusBadge(
                          label: 'GROUP HOST',
                          type: StatusBadgeType.info,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // QR Code Section
            Center(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    QrImageView(
                      data: invitation.qrData,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Scan QR to join group',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Invite Code Container
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Text(
                    'INVITATION CODE',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.muted,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
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
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                              color: AppColors.primary,
                            ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded),
                        tooltip: 'Copy Code',
                        onPressed: () => _copyInviteCode(invitation.inviteCode),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Expiration text
            Center(
              child: Text(
                'Valid until: ${invitation.expiresAt.day.toString().padLeft(2, '0')}/${invitation.expiresAt.month.toString().padLeft(2, '0')}/${invitation.expiresAt.year}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Action Button
            AppButton(
              label: 'Share Invitation',
              onPressed: () => _shareInvitation(invitation.qrData),
            ),
          ],
        );
      },
    );
  }
}
