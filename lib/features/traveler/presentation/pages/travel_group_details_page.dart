import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/leave_travel_group_result.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_member.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/leave_travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/helpers/session_identity_helper.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/leave_travel_group_dialog.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/travel_group_coastal_header.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';

/// Screen for viewing travel group details, inviting members, opening members
/// list, and initiating the UC-21 Leave Travel Group flow (Screen #60).
final class TravelGroupDetailsPage extends StatefulWidget {
  const TravelGroupDetailsPage({
    super.key,
    required this.groupId,
    this.group,
    this.isHost = false,
    this.currentUserId,
    this.members,
    this.repository,
    this.leaveRepository,
    this.storage,
  });

  final int groupId;
  final TravelGroup? group;
  final bool isHost;
  final int? currentUserId;
  final List<TravelGroupMember>? members;
  final TravelGroupRepository? repository;
  final LeaveTravelGroupRepository? leaveRepository;
  final SecureStorageService? storage;

  @override
  State<TravelGroupDetailsPage> createState() => _TravelGroupDetailsPageState();
}

final class _TravelGroupDetailsPageState extends State<TravelGroupDetailsPage> {
  int? _resolvedUserId;
  bool? _authoritativeIsHost;
  TravelGroup? _resolvedGroup;
  List<TravelGroupMember>? _resolvedMembers;
  bool _membershipCheckFailed = false;

  @override
  void initState() {
    super.initState();
    _resolvedUserId = widget.currentUserId;
    _resolvedGroup = widget.repository == null ? widget.group : null;
    _resolvedMembers = widget.members;
    if (_resolvedUserId == null) {
      _resolveUserId();
    } else {
      _refreshGroupMembership();
    }
  }

  Future<void> _resolveUserId() async {
    final userId = await SessionIdentityHelper.getCurrentUserId(widget.storage);
    if (!mounted) return;
    if (userId == null) {
      setState(() => _membershipCheckFailed = true);
      return;
    }
    if (userId != _resolvedUserId) {
      setState(() {
        _resolvedUserId = userId;
      });
      await _refreshGroupMembership();
    }
  }

  Future<void> _refreshGroupMembership() async {
    final repository = widget.repository;
    final userId = _resolvedUserId;
    if (repository == null || userId == null) return;
    setState(() => _membershipCheckFailed = false);
    try {
      final details = await repository.getTravelGroupMembers(
        groupId: widget.groupId,
      );
      if (!mounted) return;
      setState(() {
        _authoritativeIsHost = details.members.any(
          (member) => member.memberId == userId && member.isHost,
        );
        _resolvedMembers = details.members;
        _resolvedGroup = TravelGroup(
          id: details.groupId,
          name: details.groupName,
          itineraryId: details.itineraryId,
          inviteCode: widget.group?.inviteCode,
        );
      });
    } on Failure catch (failure) {
      if (!mounted) return;
      if (failure is PermissionFailure ||
          failure is NotFoundFailure ||
          failure is ConflictFailure) {
        context.go(AppRoutes.traveler);
        return;
      }
      setState(() => _membershipCheckFailed = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _membershipCheckFailed = true);
    }
  }

  bool get _isHost =>
      widget.repository == null ? widget.isHost : _authoritativeIsHost == true;

  Future<void> _openLeaveDialog() async {
    var accessLost = false;
    final result = await showDialog<LeaveTravelGroupResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LeaveTravelGroupDialog(
        groupId: widget.groupId,
        groupName: _resolvedGroup?.name ?? 'Nhóm du lịch #${widget.groupId}',
        isHost: _isHost,
        currentUserId: _resolvedUserId,
        members: _resolvedMembers ?? widget.members,
        repository: widget.repository,
        leaveRepository: widget.leaveRepository,
        onAccessLost: () => accessLost = true,
      ),
    );
    if (!mounted) return;
    if (accessLost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn không còn quyền truy cập nhóm này.')),
      );
      context.go(AppRoutes.traveler);
      return;
    }
    if (result == null) return;
    final message = result.groupClosed
        ? 'Bạn đã rời khỏi nhóm và nhóm đã được đóng.'
        : result.newHostUserId != null
        ? 'Bạn đã rời khỏi nhóm. Quyền Trưởng nhóm đã được chuyển giao.'
        : 'Bạn đã rời khỏi nhóm du lịch.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    // Replace the route stack so group-only pages cannot be reopened by Back.
    context.go(AppRoutes.traveler);
  }

  void _copyInviteCode(String inviteCode) {
    Clipboard.setData(ClipboardData(text: inviteCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép mã mời "$inviteCode"'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openMembers() async {
    await context.pushNamed(
      AppRouteNames.travelGroupMembers,
      pathParameters: {'groupId': widget.groupId.toString()},
      extra: _isHost,
    );
    if (!mounted) return;
    await _refreshGroupMembership();
  }

  Future<void> _openLocationSharing(TravelGroup? currentGroup) async {
    await context.pushNamed(
      AppRouteNames.groupLocationSharing,
      pathParameters: {'groupId': widget.groupId.toString()},
      extra: currentGroup?.name,
    );
    if (!mounted) return;
    await _refreshGroupMembership();
  }

  String _membersSummary(List<TravelGroupMember> members) {
    if (members.isEmpty) {
      return 'Xem và quản lý danh sách thành viên trong nhóm.';
    }
    if (members.length == 1) {
      return members.first.displayName;
    }
    if (members.length == 2) {
      return '${members[0].displayName} và ${members[1].displayName}';
    }
    final remaining = members.length - 2;
    return '${members[0].displayName}, ${members[1].displayName} '
        'và $remaining bạn đồng hành khác';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.repository != null && _authoritativeIsHost == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: const Text('Nhóm du lịch'),
          backgroundColor: AppColors.cardBackground,
          surfaceTintColor: Colors.transparent,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, thickness: 1, color: AppColors.line),
          ),
        ),
        body: Center(
          child: _membershipCheckFailed
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Không thể xác nhận tư cách thành viên nhóm.'),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: _resolvedUserId == null
                          ? _resolveUserId
                          : _refreshGroupMembership,
                      child: const Text('Thử lại'),
                    ),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      );
    }

    final currentGroup = _resolvedGroup?.id == widget.groupId
        ? _resolvedGroup
        : null;
    final groupName = currentGroup?.name ?? 'Nhóm du lịch #${widget.groupId}';
    final loadedMembers = _resolvedMembers ?? const <TravelGroupMember>[];
    final showInviteCode =
        currentGroup != null &&
        _isHost &&
        (currentGroup.inviteCode?.isNotEmpty ?? false);
    final sharingCount = loadedMembers
        .where((member) => member.locationSharingEnabled)
        .length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Nhóm du lịch'),
        backgroundColor: AppColors.cardBackground,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppColors.line),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Coastal Boarding-Pass Group Card
            AppCard(
              padding: EdgeInsets.zero,
              borderRadius: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CoastalRoutePassHeader(
                    borderRadius: showInviteCode
                        ? const BorderRadius.vertical(top: Radius.circular(17))
                        : BorderRadius.circular(17),
                    padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.explore_outlined,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'NHÓM CHUYẾN ĐI',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: Colors.white.withValues(alpha: 0.82),
                              ),
                            ),
                            const Spacer(),
                            if (currentGroup != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.18),
                                  ),
                                ),
                                child: Text(
                                  _isHost ? 'Trưởng nhóm' : 'Thành viên',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          groupName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 19,
                                color: Colors.white,
                                height: 1.2,
                              ),
                        ),
                        if (currentGroup?.itineraryId != null ||
                            loadedMembers.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (currentGroup?.itineraryId != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.map_outlined,
                                      size: 13.5,
                                      color: Colors.white.withValues(
                                        alpha: 0.86,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Lịch trình #${currentGroup!.itineraryId}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withValues(
                                          alpha: 0.88,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              if (currentGroup?.itineraryId != null &&
                                  loadedMembers.isNotEmpty)
                                Text(
                                  '·',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              if (loadedMembers.isNotEmpty)
                                Text(
                                  '${loadedMembers.length} thành viên',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.88),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (showInviteCode) ...[
                    const CoastalPassDivider(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 11),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'MÃ MỜI THAM GIA NHÓM',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: AppColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                SelectableText(
                                  currentGroup.inviteCode!,
                                  style: const TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.6,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () =>
                                _copyInviteCode(currentGroup.inviteCode!),
                            style: TextButton.styleFrom(
                              backgroundColor: AppColors.primarySoft,
                              foregroundColor: AppColors.primary,
                              minimumSize: const Size(0, 36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.copy_rounded, size: 14),
                            label: const Text(
                              'Sao chép',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Members Card — direct entry into UC-20
            AppCard(
              key: const Key('view_members_button'),
              borderRadius: 16,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              onTap: _openMembers,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Thành viên trong nhóm',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      Text(
                        loadedMembers.isEmpty
                            ? 'Xem'
                            : '${loadedMembers.length} người',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  if (loadedMembers.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _OverlappingAvatars(members: loadedMembers),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _membersSummary(loadedMembers),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFECEEEB),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isHost ? 'Quản lý thành viên' : 'Xem thành viên',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 15,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Trip Workspace List Card
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'TIỆN ÍCH NHÓM',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                  color: AppColors.muted,
                ),
              ),
            ),
            const SizedBox(height: 6),
            AppCard(
              padding: EdgeInsets.zero,
              borderRadius: 16,
              child: Column(
                children: [
                  _WorkspaceRow(
                    key: const Key('open_group_chat_button'),
                    icon: Icons.forum_outlined,
                    iconColor: AppColors.primary,
                    title: 'Trò chuyện nhóm',
                    subtitle: 'Nhắn tin, chia tiền & bình chọn',
                    onTap: () => context.pushNamed(
                      AppRouteNames.travelGroupChat,
                      pathParameters: {'groupId': widget.groupId.toString()},
                      extra: currentGroup,
                    ),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFECEEEB),
                  ),
                  _WorkspaceRow(
                    key: const Key('location_sharing_button'),
                    icon: Icons.share_location_outlined,
                    iconColor: AppColors.primary,
                    title: 'Chia sẻ vị trí',
                    subtitle: loadedMembers.isEmpty
                        ? 'Cài đặt chia sẻ vị trí với nhóm'
                        : '$sharingCount thành viên đang bật vị trí',
                    subtitleColor: sharingCount > 0
                        ? const Color(0xFF0E7A56)
                        : AppColors.muted,
                    onTap: () => _openLocationSharing(currentGroup),
                  ),
                  if (currentGroup != null && _isHost) ...[
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFECEEEB),
                    ),
                    _WorkspaceRow(
                      key: const Key('invite_members_button'),
                      icon: Icons.person_add_alt_1_outlined,
                      iconColor: const Color(0xFF995436),
                      title: 'Mời thành viên',
                      subtitle: 'Chia sẻ mã mời hoặc mã QR',
                      onTap: () => context.pushNamed(
                        AppRouteNames.inviteGroupMembers,
                        pathParameters: {'groupId': widget.groupId.toString()},
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Danger Zone: UC-21 Leave Group
            OutlinedButton.icon(
              key: const Key('leave_group_button'),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.cardBackground,
                foregroundColor: AppColors.error,
                side: const BorderSide(color: Color(0xFFF2C6CE)),
                minimumSize: const Size(48, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _openLeaveDialog,
              icon: const Icon(Icons.exit_to_app_outlined, size: 18),
              label: const Text(
                'Rời khỏi nhóm du lịch',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _OverlappingAvatars extends StatelessWidget {
  const _OverlappingAvatars({required this.members});

  final List<TravelGroupMember> members;

  @override
  Widget build(BuildContext context) {
    final visible = members.take(4).toList(growable: false);
    final width = 36 + (visible.length - 1) * 24.0;
    return SizedBox(
      width: width,
      height: 36,
      child: Stack(
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: i * 24.0,
              child: GroupMemberAvatar(
                displayName: visible[i].displayName,
                avatarUrl: visible[i].avatarUrl,
                isHost: visible[i].isHost,
                radius: 16,
                borderColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

final class _WorkspaceRow extends StatelessWidget {
  const _WorkspaceRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.subtitleColor = AppColors.muted,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color subtitleColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 19, color: iconColor),
            const SizedBox(width: 12),
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
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: subtitleColor == AppColors.muted
                          ? FontWeight.w400
                          : FontWeight.w600,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Color(0xFF8CA09A),
            ),
          ],
        ),
      ),
    );
  }
}
