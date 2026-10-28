import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/leave_travel_group_result.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_member.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/leave_travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/helpers/session_identity_helper.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/leave_travel_group_dialog.dart';

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
  bool _membershipCheckFailed = false;

  @override
  void initState() {
    super.initState();
    _resolvedUserId = widget.currentUserId;
    _resolvedGroup = widget.repository == null ? widget.group : null;
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
        groupName: _resolvedGroup?.name ?? 'Travel Group #${widget.groupId}',
        isHost: _isHost,
        currentUserId: _resolvedUserId,
        members: widget.members,
        repository: widget.repository,
        leaveRepository: widget.leaveRepository,
        onAccessLost: () => accessLost = true,
      ),
    );
    if (!mounted) return;
    if (accessLost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You no longer have access to this group.'),
        ),
      );
      context.go(AppRoutes.traveler);
      return;
    }
    if (result == null) return;
    final message = result.groupClosed
        ? 'You left and the group is now closed.'
        : result.newHostUserId != null
        ? 'You left the group. Host privileges were transferred.'
        : 'You left the travel group.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    // Replace the route stack so group-only pages cannot be reopened by Back.
    context.go(AppRoutes.traveler);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.repository != null && _authoritativeIsHost == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Travel Group')),
        body: Center(
          child: _membershipCheckFailed
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Could not confirm group membership.'),
                    TextButton(
                      onPressed: _resolvedUserId == null
                          ? _resolveUserId
                          : _refreshGroupMembership,
                      child: const Text('Retry'),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Travel Group')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            currentGroup?.name ?? 'Travel Group #${widget.groupId}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          if (currentGroup != null)
            Text(
              _isHost ? 'You are the Group Host.' : 'You are a Group Member.',
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.pushNamed(
              AppRouteNames.travelGroupMembers,
              pathParameters: {'groupId': widget.groupId.toString()},
              extra: _isHost,
            ),
            icon: const Icon(Icons.group_outlined),
            label: const Text('View members'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('location_sharing_button'),
            onPressed: () => context.pushNamed(
              AppRouteNames.groupLocationSharing,
              pathParameters: {'groupId': widget.groupId.toString()},
              extra: currentGroup?.name,
            ),
            icon: const Icon(Icons.share_location_outlined),
            label: const Text('Location Sharing'),
          ),
          if (currentGroup != null && _isHost) ...[
            if (currentGroup.inviteCode?.isNotEmpty ?? false) ...[
              const SizedBox(height: 24),
              SelectableText('Invite code: ${currentGroup.inviteCode}'),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.pushNamed(
                AppRouteNames.inviteGroupMembers,
                pathParameters: {'groupId': widget.groupId.toString()},
              ),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Invite Members'),
            ),
          ],
          const SizedBox(height: 32),
          // Danger Zone / Group actions: UC-21 Leave Group
          OutlinedButton.icon(
            key: const Key('leave_group_button'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
              minimumSize: const Size(48, 48),
            ),
            onPressed: _openLeaveDialog,
            icon: const Icon(Icons.exit_to_app_outlined),
            label: const Text('Leave Group'),
          ),
        ],
      ),
    );
  }
}
