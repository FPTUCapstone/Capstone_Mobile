import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/location/device_location_service.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/group_location_sharing_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/group_location_sharing_state.dart';

/// Screen #61: Group Location Sharing Settings (UC-22).
///
/// Implements consent configuration and OS permission verification for
/// sharing live GPS location with active travel group members.
///
/// Canonical invariant:
/// effectiveSharing = activeMembership AND storedOptIn AND devicePermissionGranted
final class GroupLocationSharingPage extends StatefulWidget {
  const GroupLocationSharingPage({
    super.key,
    required this.groupId,
    this.groupName,
    this.cubit,
    this.travelGroupRepository,
    this.locationService,
    this.secureStorage,
    this.isDemoMode = false,
  });

  final int groupId;
  final String? groupName;
  final GroupLocationSharingCubit? cubit;
  final TravelGroupRepository? travelGroupRepository;
  final DeviceLocationService? locationService;
  final SecureStorageService? secureStorage;
  final bool isDemoMode;

  @override
  State<GroupLocationSharingPage> createState() =>
      _GroupLocationSharingPageState();
}

class _GroupLocationSharingPageState extends State<GroupLocationSharingPage>
    with WidgetsBindingObserver {
  late final GroupLocationSharingCubit _cubit;
  late final bool _isLocalCubit;
  bool _showDemoControls = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.cubit != null) {
      _cubit = widget.cubit!;
      _isLocalCubit = false;
    } else {
      _cubit = GroupLocationSharingCubit(
        groupId: widget.groupId,
        groupName: widget.groupName,
        travelGroupRepository: widget.travelGroupRepository,
        locationService: widget.locationService,
        secureStorage: widget.secureStorage,
        isDemoMode: widget.isDemoMode,
      )..initialize();
      _isLocalCubit = true;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_isLocalCubit) {
      _cubit.close();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cubit.checkDevicePermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<GroupLocationSharingCubit, GroupLocationSharingState>(
        listener: (context, state) {
          if (state.noticeMessage != null) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.noticeMessage!),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ),
            );
            _cubit.clearMessages();
          } else if (state.errorMessage != null &&
              state.errorMessage !=
                  GroupLocationSharingCubit.pendingBeIntegrationMessage) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
              ),
            );
            _cubit.clearMessages();
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Location Sharing'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              actions: [
                if (state.isDemoMode)
                  IconButton(
                    icon: Icon(
                      _showDemoControls
                          ? Icons.bug_report
                          : Icons.bug_report_outlined,
                      color: AppColors.warning,
                    ),
                    tooltip: 'Toggle Demo Controls',
                    onPressed: () {
                      setState(() {
                        _showDemoControls = !_showDemoControls;
                      });
                    },
                  ),
              ],
            ),
            body: state.status == GroupLocationSharingStatus.loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () async {
                      await _cubit.checkDevicePermission();
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Pending Backend Integration Banner (Production Mode)
                          if (state.pendingBeIntegration) ...[
                            _buildPendingIntegrationBanner(),
                            const SizedBox(height: AppSpacing.md),
                          ],

                          // 2. Active Sharing Status Hero Card
                          _buildStatusHeroCard(state),
                          const SizedBox(height: AppSpacing.md),

                          // 3. Primary Toggle Card (Consent Opt-In)
                          _buildPrimarySettingCard(state),
                          const SizedBox(height: AppSpacing.md),

                          // 4. Audience Card
                          _buildAudienceCard(state),
                          const SizedBox(height: AppSpacing.md),

                          // 5. Device Permission State & Settings Card
                          _buildPermissionCard(state),
                          const SizedBox(height: AppSpacing.md),

                          // 6. Privacy & Retention Explanation
                          _buildPrivacyNoticeCard(),

                          // 7. Demo Controls (Only in demo mode)
                          if (state.isDemoMode && _showDemoControls) ...[
                            const SizedBox(height: AppSpacing.lg),
                            _buildDemoControlsPanel(state),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                        ],
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildPendingIntegrationBanner() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.warning, size: 24),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pending Server Integration',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  GroupLocationSharingCubit.pendingBeIntegrationMessage,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.ink,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHeroCard(GroupLocationSharingState state) {
    final IconData icon;
    final Color color;
    final String title;
    final String subtitle;

    if (state.effectiveSharing) {
      icon = Icons.location_on;
      color = AppColors.success;
      title = 'Sharing is Active';
      subtitle = state.groupName != null
          ? 'Your location is shared with members of ${state.groupName}.'
          : 'Your location is shared with active members of this group.';
    } else if (state.storedOptIn && !state.devicePermissionGranted) {
      icon = Icons.location_off;
      color = AppColors.warning;
      title = 'Location Sharing Paused';
      subtitle = !state.isLocationServiceEnabled
          ? 'Device location services are disabled. Turn on GPS to broadcast your position.'
          : 'Device location permission is required. Enable permission in Settings.';
    } else if (!state.isActiveMember) {
      icon = Icons.person_off_outlined;
      color = AppColors.muted;
      title = 'Membership Inactive';
      subtitle = 'Only active members of this group can share location.';
    } else {
      icon = Icons.location_off_outlined;
      color = AppColors.muted;
      title = 'Location Sharing Off';
      subtitle = 'Your position is not being shared with this travel group.';
    }

    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withValues(alpha: 0.18),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.ink,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimarySettingCard(GroupLocationSharingState state) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: SwitchListTile.adaptive(
          title: const Text(
            'Share my live location',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.ink,
            ),
          ),
          subtitle: const Text(
            'With members of this group only',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          value: state.storedOptIn,
          activeThumbColor: AppColors.primary,
          onChanged: (value) {
            _cubit.toggleLocationSharing(value);
          },
        ),
      ),
    );
  }

  Widget _buildAudienceCard(GroupLocationSharingState state) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Who can see my location',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(
                  Icons.people_outline,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.groupName != null
                            ? 'Members of ${state.groupName}'
                            : 'All group members',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Visible only to confirmed active travelers in this group',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard(GroupLocationSharingState state) {
    final String permissionLabel;
    final IconData permissionIcon;
    final Color permissionColor;

    if (!state.isLocationServiceEnabled) {
      permissionLabel = 'Location Services Disabled';
      permissionIcon = Icons.location_disabled;
      permissionColor = AppColors.error;
    } else if (state.devicePermissionGranted) {
      permissionLabel = 'Permission Granted';
      permissionIcon = Icons.check_circle_outline;
      permissionColor = AppColors.success;
    } else if (state.isPermissionPermanentlyDenied) {
      permissionLabel = 'Permanently Denied';
      permissionIcon = Icons.block;
      permissionColor = AppColors.error;
    } else {
      permissionLabel = 'Permission Denied';
      permissionIcon = Icons.warning_amber_rounded;
      permissionColor = AppColors.warning;
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Device Location Permission',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(permissionIcon, color: permissionColor, size: 20),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    permissionLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: permissionColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'TripMate requires operating system permission to access GPS position.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (!state.isLocationServiceEnabled)
              OutlinedButton.icon(
                onPressed: () => _cubit.openLocationSettings(),
                icon: const Icon(Icons.settings_suggest_outlined, size: 18),
                label: const Text('Open Location Settings'),
              )
            else if (state.isPermissionPermanentlyDenied)
              OutlinedButton.icon(
                onPressed: () => _cubit.openAppSettings(),
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('Open Device Settings'),
              )
            else if (!state.devicePermissionGranted)
              FilledButton.tonalIcon(
                onPressed: () => _cubit.requestDevicePermission(),
                icon: const Icon(Icons.near_me_outlined, size: 18),
                label: const Text('Request Permission'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyNoticeCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, size: 20, color: AppColors.muted),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Text(
              'Your location is shared only with active members of this travel group '
              'while sharing is enabled, and stops immediately when you leave the group '
              'or turn this setting off.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoControlsPanel(GroupLocationSharingState state) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.build_circle_outlined,
                color: Colors.amber.shade800,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'DEMO_ONLY Test Controls',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.amber.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              FilterChip(
                label: const Text('Grant Permission'),
                selected:
                    state.devicePermission == LocationPermission.whileInUse,
                onSelected: (_) =>
                    _cubit.setDemoPermission(LocationPermission.whileInUse),
              ),
              FilterChip(
                label: const Text('Deny Permission'),
                selected: state.devicePermission == LocationPermission.denied,
                onSelected: (_) =>
                    _cubit.setDemoPermission(LocationPermission.denied),
              ),
              FilterChip(
                label: const Text('Deny Forever'),
                selected:
                    state.devicePermission == LocationPermission.deniedForever,
                onSelected: (_) =>
                    _cubit.setDemoPermission(LocationPermission.deniedForever),
              ),
              FilterChip(
                label: Text(
                  state.isLocationServiceEnabled ? 'Disable GPS' : 'Enable GPS',
                ),
                selected: !state.isLocationServiceEnabled,
                onSelected: (_) => _cubit.setDemoPermission(
                  state.devicePermission,
                  isServiceEnabled: !state.isLocationServiceEnabled,
                ),
              ),
              FilterChip(
                label: Text(
                  state.isActiveMember
                      ? 'Simulate Inactive Member'
                      : 'Simulate Active Member',
                ),
                selected: !state.isActiveMember,
                onSelected: (_) =>
                    _cubit.setDemoActiveMembership(!state.isActiveMember),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
