import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/core/utils/calendar_date_format.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_member.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_members.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_group_members_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_group_members_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/helpers/session_identity_helper.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/remove_group_member_dialog.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/travel_group_coastal_header.dart';
import 'package:trip_mate_mobile/features/traveler/resources/travel_group_vi.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/error_view.dart';

/// Active group member list and UC-20 Host removal flow (Screen #59).
///
/// Production Security Rule (P2): Host authority is determined STRICTLY by
/// verifying that the authenticated user ID from the session matches the
/// authoritative Host returned by the Backend. If session identity is absent
/// or does not match, host authority fails closed (never relying on route extra).
final class TravelGroupMembersPage extends StatefulWidget {
  const TravelGroupMembersPage({
    super.key,
    required this.groupId,
    this.isHost = false,
    this.currentUserId,
    this.storage,
  });

  final int groupId;
  final bool isHost;
  final int? currentUserId;
  final SecureStorageService? storage;

  @override
  State<TravelGroupMembersPage> createState() => _TravelGroupMembersPageState();
}

final class _TravelGroupMembersPageState extends State<TravelGroupMembersPage> {
  int? _resolvedUserId;
  int? _pendingRemovalMemberId;

  @override
  void initState() {
    super.initState();
    _resolvedUserId = widget.currentUserId;
    if (_resolvedUserId == null) {
      _resolveUserId();
    }
  }

  Future<void> _resolveUserId() async {
    final userId = await SessionIdentityHelper.getCurrentUserId(widget.storage);
    if (!mounted) return;
    if (userId != null && userId != _resolvedUserId) {
      setState(() {
        _resolvedUserId = userId;
      });
    }
  }

  Future<void> _confirmRemoval(TravelGroupMember member) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RemoveGroupMemberDialog(
        groupId: widget.groupId,
        memberId: member.memberId,
        memberName: member.displayName,
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _pendingRemovalMemberId = member.memberId);
    await context.read<TravelGroupMembersCubit>().removeMember(
      groupId: widget.groupId,
      memberUserId: member.memberId,
    );
    if (mounted) {
      setState(() => _pendingRemovalMemberId = null);
    }
  }

  void _openItinerary(BuildContext context, int itineraryId) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.push(AppRoutes.itineraryDetailPath(itineraryId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TravelGroupMembersCubit, TravelGroupMembersState>(
      listenWhen: (previous, current) =>
          (current is TravelGroupMembersPermissionDenied &&
              previous is! TravelGroupMembersPermissionDenied) ||
          (current is TravelGroupMembersAuthenticationRequired &&
              previous is! TravelGroupMembersAuthenticationRequired),
      listener: (context, state) {
        final router = GoRouter.maybeOf(context);
        if (router != null) {
          router.go(
            state is TravelGroupMembersAuthenticationRequired
                ? AppRoutes.login
                : AppRoutes.traveler,
          );
        }
      },
      child: BlocBuilder<TravelGroupMembersCubit, TravelGroupMembersState>(
        builder: (context, state) {
          final loadedMembers = switch (state) {
            TravelGroupMembersSuccess(:final members) => members,
            TravelGroupMembersRemoving(:final members) => members,
            TravelGroupMembersRemovalRetryable(:final members) => members,
            TravelGroupMembersRemovalIssue(:final members) => members,
            _ => null,
          };

          return Scaffold(
            backgroundColor: AppColors.surface,
            appBar: AppBar(
              title: const Text(TravelGroupStringsVi.membersTitle),
              backgroundColor: AppColors.cardBackground,
              surfaceTintColor: Colors.transparent,
              actions: [
                if (loadedMembers != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextButton(
                      onPressed: () =>
                          _openItinerary(context, loadedMembers.itineraryId),
                      child: const Text(
                        TravelGroupStringsVi.itineraryAction,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
              ],
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(1),
                child: Divider(height: 1, thickness: 1, color: AppColors.line),
              ),
            ),
            body: switch (state) {
              TravelGroupMembersInitial() || TravelGroupMembersLoading() =>
                const Center(child: CircularProgressIndicator()),
              TravelGroupMembersSuccess(:final members) => _MembersContent(
                members: members,
                currentUserId: _resolvedUserId,
                onRemove: _confirmRemoval,
                onOpenItinerary: () =>
                    _openItinerary(context, members.itineraryId),
                banner: state.removedMemberName == null
                    ? null
                    : _RemovalBannerData(
                        tone: _BannerTone.success,
                        message: TravelGroupStringsVi.msg60(
                          state.removedMemberName!,
                        ),
                      ),
              ),
              TravelGroupMembersRemoving(:final members) => _MembersContent(
                members: members,
                currentUserId: _resolvedUserId,
                pendingRemovalMemberId: _pendingRemovalMemberId,
                onOpenItinerary: () =>
                    _openItinerary(context, members.itineraryId),
                banner: const _RemovalBannerData(
                  tone: _BannerTone.removing,
                  message: TravelGroupStringsVi.removingProgress,
                ),
              ),
              TravelGroupMembersRemovalRetryable(:final members) =>
                _MembersContent(
                  members: members,
                  currentUserId: _resolvedUserId,
                  onOpenItinerary: () =>
                      _openItinerary(context, members.itineraryId),
                  banner: _RemovalBannerData(
                    tone: _BannerTone.warning,
                    message: TravelGroupStringsVi.msg127,
                    actionLabel: TravelGroupStringsVi.retry,
                    onAction: () =>
                        context.read<TravelGroupMembersCubit>().retryRemoval(),
                  ),
                ),
              TravelGroupMembersRemovalIssue(:final members, :final message) =>
                _MembersContent(
                  members: members,
                  currentUserId: _resolvedUserId,
                  onOpenItinerary: () =>
                      _openItinerary(context, members.itineraryId),
                  banner: _RemovalBannerData(
                    tone: _BannerTone.error,
                    message: message,
                    actionLabel: TravelGroupStringsVi.refresh,
                    onAction: () => context
                        .read<TravelGroupMembersCubit>()
                        .load(groupId: widget.groupId),
                  ),
                ),
              TravelGroupMembersPermissionDenied() => _PermissionDeniedView(
                onGoHome: () =>
                    GoRouter.maybeOf(context)?.go(AppRoutes.traveler),
              ),
              TravelGroupMembersAuthenticationRequired() => const ErrorView(
                message: TravelGroupStringsVi.msg125,
              ),
              TravelGroupMembersNotFound() => const ErrorView(
                message: TravelGroupStringsVi.groupNotFound,
              ),
              TravelGroupMembersFailure() => ErrorView(
                message: TravelGroupStringsVi.loadMembersFailed,
                onRetry: () => context.read<TravelGroupMembersCubit>().load(
                  groupId: widget.groupId,
                ),
              ),
            },
          );
        },
      ),
    );
  }
}

enum _BannerTone { removing, success, warning, error }

final class _RemovalBannerData {
  const _RemovalBannerData({
    required this.tone,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final _BannerTone tone;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
}

final class _MembersContent extends StatelessWidget {
  const _MembersContent({
    required this.members,
    this.currentUserId,
    this.onRemove,
    this.onOpenItinerary,
    this.pendingRemovalMemberId,
    this.banner,
  });

  final TravelGroupMembers members;
  final int? currentUserId;
  final void Function(TravelGroupMember)? onRemove;
  final VoidCallback? onOpenItinerary;
  final int? pendingRemovalMemberId;
  final _RemovalBannerData? banner;

  @override
  Widget build(BuildContext context) {
    if (members.members.isEmpty) {
      return const Center(
        child: Text(
          'Chưa có thành viên nào trong nhóm.',
          style: TextStyle(color: AppColors.muted, fontSize: 14),
        ),
      );
    }

    // Host authority audit (P2): Authoritative loaded group members define the true Host.
    // If current authenticated user ID is unavailable or does not match loaded Host,
    // FAIL CLOSED (effectiveViewerIsHost = false). Never rely on GoRouter.extra or route flags.
    final hosts = members.members
        .where((m) => m.isHost)
        .toList(growable: false);
    final bool effectiveViewerIsHost =
        currentUserId != null &&
        hosts.length == 1 &&
        hosts.single.memberId == currentUserId;

    final otherMembers = members.members
        .where((m) => !m.isHost)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _MembersHeader(members: members, onOpenItinerary: onOpenItinerary),
        if (banner != null) ...[
          const SizedBox(height: 12),
          _StatusBanner(data: banner!),
        ],
        if (hosts.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _SectionCaption('TRƯỞNG NHÓM'),
          const SizedBox(height: 6),
          AppCard(
            padding: EdgeInsets.zero,
            borderRadius: 16,
            child: Column(
              children: [
                for (var i = 0; i < hosts.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFECEEEB),
                    ),
                  _MemberRow(
                    member: hosts[i],
                    isViewerHost: effectiveViewerIsHost,
                    currentUserId: currentUserId,
                    isPendingRemoval: false,
                    onRemove: null,
                  ),
                ],
              ],
            ),
          ),
        ],
        if (otherMembers.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionCaption(
            TravelGroupStringsVi.otherMembersSection(otherMembers.length),
          ),
          const SizedBox(height: 6),
          AppCard(
            padding: EdgeInsets.zero,
            borderRadius: 16,
            child: Column(
              children: [
                for (var i = 0; i < otherMembers.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFECEEEB),
                    ),
                  _MemberRow(
                    member: otherMembers[i],
                    isViewerHost: effectiveViewerIsHost,
                    currentUserId: currentUserId,
                    isPendingRemoval:
                        pendingRemovalMemberId == otherMembers[i].memberId,
                    onRemove: onRemove,
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

final class _SectionCaption extends StatelessWidget {
  const _SectionCaption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
          color: AppColors.muted,
        ),
      ),
    );
  }
}

final class _MembersHeader extends StatelessWidget {
  const _MembersHeader({required this.members, this.onOpenItinerary});

  final TravelGroupMembers members;
  final VoidCallback? onOpenItinerary;

  @override
  Widget build(BuildContext context) {
    return CoastalRoutePassHeader(
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  members.groupName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 16.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${members.memberCount} thành viên trong nhóm',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.86),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: onOpenItinerary,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.map_outlined, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    '#${members.itineraryId}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.data});

  final _RemovalBannerData data;

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg, btnBg) = switch (data.tone) {
      _BannerTone.removing => (
        AppColors.primarySoft,
        const Color(0xFFC6DAD2),
        AppColors.primary,
        AppColors.primary,
      ),
      _BannerTone.success => (
        const Color(0xFFE7F6F0),
        const Color(0xFFBBE5D3),
        const Color(0xFF0B6E4C),
        const Color(0xFF0E9F6E),
      ),
      _BannerTone.warning => (
        const Color(0xFFFEF3E2),
        const Color(0xFFF3DCA9),
        const Color(0xFF9A4809),
        AppColors.warning,
      ),
      _BannerTone.error => (
        const Color(0xFFFDECEF),
        const Color(0xFFF4C2CC),
        const Color(0xFFB31B38),
        AppColors.error,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          if (data.tone == _BannerTone.removing)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: fg),
            )
          else if (data.tone == _BannerTone.success)
            Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 13, color: Colors.white),
            )
          else
            Icon(
              data.tone == _BannerTone.warning
                  ? Icons.warning_amber_rounded
                  : Icons.error_outline,
              size: 19,
              color: fg,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              data.message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
                height: 1.35,
              ),
            ),
          ),
          if (data.actionLabel != null && data.onAction != null) ...[
            const SizedBox(width: 8),
            FilledButton(
              onPressed: data.onAction,
              style: FilledButton.styleFrom(
                backgroundColor: btnBg,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                data.actionLabel!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

final class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isViewerHost,
    required this.isPendingRemoval,
    this.currentUserId,
    this.onRemove,
  });

  final TravelGroupMember member;
  final bool isViewerHost;
  final bool isPendingRemoval;
  final int? currentUserId;
  final void Function(TravelGroupMember)? onRemove;

  @override
  Widget build(BuildContext context) {
    final isSelf = currentUserId != null && member.memberId == currentUserId;
    // BR-45: Only Group Host may remove members. Group Host cannot remove itself.
    final showRemoveAction = isViewerHost && !member.isHost && !isSelf;
    final joinedText = formatCalendarDate(member.joinedAtUtc.toLocal());

    return Opacity(
      opacity: isPendingRemoval ? 0.45 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            GroupMemberAvatar(
              displayName: member.displayName,
              avatarUrl: member.avatarUrl,
              isHost: member.isHost,
              radius: member.isHost ? 21 : 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: member.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: AppColors.ink,
                      ),
                      children: [
                        if (isSelf && !member.isHost)
                          const TextSpan(
                            text: ' (Bạn)',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: AppColors.muted,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Tham gia $joinedText',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: member.locationSharingEnabled
                              ? AppColors.success
                              : const Color(0xFFA9B6B1),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          member.locationSharingEnabled
                              ? 'Đang chia sẻ vị trí'
                              : 'Tắt chia sẻ vị trí',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: member.locationSharingEnabled
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: member.locationSharingEnabled
                                ? const Color(0xFF0E7A56)
                                : AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (member.isHost) ...[
              const SizedBox(width: 8),
              const Text(
                'Trưởng nhóm',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF995436),
                ),
              ),
            ] else if (showRemoveAction) ...[
              const SizedBox(width: 4),
              TextButton(
                key: Key('remove_member_button_${member.memberId}'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  disabledForegroundColor: const Color(0xFFB4BEBA),
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: onRemove == null ? null : () => onRemove!(member),
                child: const Text(
                  'Xóa',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _PermissionDeniedView extends StatelessWidget {
  const _PermissionDeniedView({required this.onGoHome});

  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: AppCard(
          padding: EdgeInsets.zero,
          borderRadius: 18,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CoastalRoutePassHeader(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(17),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NHÓM CHUYẾN ĐI',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Quyền truy cập nhóm',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Đã kết thúc',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      TravelGroupStringsVi.msg126,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: onGoHome,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(TravelGroupStringsVi.backToHome),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
