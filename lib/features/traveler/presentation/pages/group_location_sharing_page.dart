import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/core/location/device_location_service.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/group_location_sharing_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/group_location_sharing_state.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_coastal_app_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/app_section_card.dart';

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
          final c = context.tmColors;
          if (state.noticeMessage != null) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.noticeMessage!),
                backgroundColor: c.success,
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
                backgroundColor: c.error,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
              ),
            );
            _cubit.clearMessages();
          }
        },
        builder: (context, state) {
          final c = context.tmColors;
          return Scaffold(
            backgroundColor: c.canvas,
            appBar: AppCoastalAppBar(
              title: 'Chia sẻ vị trí',
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Đóng',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              actions: [
                if (state.isDemoMode)
                  IconButton(
                    icon: Icon(
                      _showDemoControls
                          ? Icons.bug_report
                          : Icons.bug_report_outlined,
                      color: c.warning,
                    ),
                    tooltip: 'Bật/tắt điều khiển demo',
                    onPressed: () {
                      setState(() {
                        _showDemoControls = !_showDemoControls;
                      });
                    },
                  ),
              ],
            ),
            body: state.status == GroupLocationSharingStatus.loading
                ? Center(child: CircularProgressIndicator(color: c.brandTeal))
                : RefreshIndicator(
                    color: c.brandTeal,
                    onRefresh: () async {
                      await _cubit.checkDevicePermission();
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (state.pendingBeIntegration) ...[
                            _buildPendingIntegrationBanner(context),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          _buildStatusHeroCard(context, state),
                          const SizedBox(height: AppSpacing.md),
                          _buildPrimarySettingCard(context, state),
                          const SizedBox(height: AppSpacing.md),
                          _buildAudienceCard(context, state),
                          const SizedBox(height: AppSpacing.md),
                          _buildPermissionCard(context, state),
                          const SizedBox(height: AppSpacing.md),
                          _buildPrivacyNoticeCard(context),
                          if (state.isDemoMode && _showDemoControls) ...[
                            const SizedBox(height: AppSpacing.lg),
                            _buildDemoControlsPanel(context, state),
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

  Widget _buildPendingIntegrationBanner(BuildContext context) {
    final c = context.tmColors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.warningContainer,
        borderRadius: BorderRadius.circular(TripMateRadius.lg),
        border: Border.all(color: c.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: c.warning, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đang chờ tích hợp máy chủ',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  GroupLocationSharingCubit.pendingBeIntegrationMessage,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: c.textSecondary,
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

  Widget _buildStatusHeroCard(
    BuildContext context,
    GroupLocationSharingState state,
  ) {
    final c = context.tmColors;
    final IconData icon;
    final Color accent;
    final Color surfaceTint;
    final String title;
    final String subtitle;

    if (state.isActivelySharing) {
      icon = Icons.location_on;
      accent = c.success;
      surfaceTint = c.successContainer;
      title = 'Bản xem thử: Đang chia sẻ vị trí';
      subtitle = state.groupName != null
          ? 'Chế độ mô phỏng: Vị trí của bạn đang được chia sẻ với thành viên của ${state.groupName}.'
          : 'Chế độ mô phỏng: Vị trí của bạn đang được chia sẻ với các thành viên đang hoạt động của nhóm này.';
    } else if (state.sharingPrerequisitesSatisfied) {
      icon = Icons.pause_circle_outline;
      accent = c.warning;
      surfaceTint = c.warningContainer;
      title = 'Chia sẻ vị trí tạm chưa khả dụng';
      subtitle =
          'Bạn đã đồng ý chia sẻ và cấp quyền vị trí trên thiết bị. '
          'Tính năng phát vị trí trực tiếp đang tạm dừng do chờ tích hợp máy chủ.';
    } else if (state.storedOptIn && !state.devicePermissionGranted) {
      icon = Icons.location_off;
      accent = c.warning;
      surfaceTint = c.warningContainer;
      title = 'Chia sẻ vị trí đang tạm dừng';
      subtitle = !state.isLocationServiceEnabled
          ? 'Dịch vụ định vị trên thiết bị đang tắt. Vui lòng bật GPS để phát vị trí của bạn.'
          : 'Cần cấp quyền truy cập vị trí trên thiết bị. Vui lòng bật quyền trong Cài đặt.';
    } else if (!state.isActiveMember) {
      icon = Icons.person_off_outlined;
      accent = c.textMuted;
      surfaceTint = c.surfaceElevated;
      title = 'Không còn là thành viên hoạt động';
      subtitle =
          'Chỉ thành viên đang hoạt động của nhóm này mới có thể cấu hình chia sẻ vị trí.';
    } else {
      icon = Icons.location_off_outlined;
      accent = c.textMuted;
      surfaceTint = c.surfaceCard;
      title = 'Chia sẻ vị trí đang tắt';
      subtitle = 'Vị trí của bạn hiện không được chia sẻ với nhóm du lịch này.';
    }

    return Container(
      decoration: BoxDecoration(
        color: surfaceTint,
        borderRadius: BorderRadius.circular(TripMateRadius.xl),
        border: Border.all(
          color: accent == c.textMuted
              ? c.borderSubtle
              : accent.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 28),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTypography.displayFont,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: accent == c.textMuted ? c.textPrimary : accent,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: c.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimarySettingCard(
    BuildContext context,
    GroupLocationSharingState state,
  ) {
    final c = context.tmColors;
    final bool canChangePreference =
        state.isDemoMode && state.isActiveMember && !state.pendingBeIntegration;

    final String subtitleText;
    if (state.pendingBeIntegration) {
      subtitleText = state.storedOptIn
          ? 'Chỉ với thành viên của nhóm này (Đã đồng ý — tạm khóa chỉnh sửa do chờ tích hợp máy chủ)'
          : 'Chỉ với thành viên của nhóm này (Tạm khóa chỉnh sửa do chờ tích hợp máy chủ)';
    } else if (!state.isActiveMember) {
      subtitleText =
          'Chỉ với thành viên của nhóm này (Chỉ thành viên đang hoạt động mới có thể cấu hình)';
    } else {
      subtitleText = 'Chỉ với thành viên của nhóm này';
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(TripMateRadius.lg),
        child: SwitchListTile.adaptive(
          title: Text(
            'Chia sẻ vị trí trực tiếp của tôi',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: c.textPrimary,
            ),
          ),
          subtitle: Text(
            subtitleText,
            style: TextStyle(fontSize: 12.5, color: c.textSecondary),
          ),
          value: state.storedOptIn,
          activeThumbColor: c.brandTeal,
          onChanged: canChangePreference
              ? (value) {
                  _cubit.toggleLocationSharing(value);
                }
              : null,
        ),
      ),
    );
  }

  Widget _buildAudienceCard(
    BuildContext context,
    GroupLocationSharingState state,
  ) {
    final c = context.tmColors;
    return AppSectionCard(
      title: 'Ai có thể xem vị trí của tôi',
      icon: Icons.people_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.groupName != null
                ? 'Thành viên của ${state.groupName}'
                : 'Tất cả thành viên nhóm',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Chỉ hiển thị với các thành viên đang hoạt động đã xác nhận trong nhóm này khi tính năng chia sẻ được bật',
            style: TextStyle(
              fontSize: 12.5,
              color: c.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard(
    BuildContext context,
    GroupLocationSharingState state,
  ) {
    final c = context.tmColors;
    final String permissionLabel;
    final IconData permissionIcon;
    final Color permissionColor;

    if (!state.isLocationServiceEnabled) {
      permissionLabel = 'Dịch vụ định vị đang tắt';
      permissionIcon = Icons.location_disabled;
      permissionColor = c.error;
    } else if (state.devicePermissionGranted) {
      permissionLabel = 'Đã cấp quyền vị trí';
      permissionIcon = Icons.check_circle_outline;
      permissionColor = c.success;
    } else if (state.isPermissionPermanentlyDenied) {
      permissionLabel = 'Bị từ chối vĩnh viễn';
      permissionIcon = Icons.block;
      permissionColor = c.error;
    } else {
      permissionLabel = 'Chưa cấp quyền vị trí';
      permissionIcon = Icons.warning_amber_rounded;
      permissionColor = c.warning;
    }

    return AppSectionCard(
      title: 'Quyền vị trí thiết bị',
      icon: Icons.gps_fixed_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(permissionIcon, color: permissionColor, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  permissionLabel,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: permissionColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'TripMate cần quyền từ hệ điều hành để truy cập vị trí GPS.',
            style: TextStyle(
              fontSize: 12.5,
              color: c.textSecondary,
              height: 1.4,
            ),
          ),
          if (!state.isLocationServiceEnabled ||
              state.isPermissionPermanentlyDenied ||
              !state.devicePermissionGranted) ...[
            const SizedBox(height: AppSpacing.sm),
            if (!state.isLocationServiceEnabled)
              OutlinedButton.icon(
                onPressed: () => _cubit.openLocationSettings(),
                icon: const Icon(Icons.settings_suggest_outlined, size: 18),
                label: const Text('Mở cài đặt định vị'),
              )
            else if (state.isPermissionPermanentlyDenied)
              OutlinedButton.icon(
                onPressed: () => _cubit.openAppSettings(),
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('Mở cài đặt thiết bị'),
              )
            else
              FilledButton.tonalIcon(
                onPressed: () => _cubit.requestDevicePermission(),
                icon: const Icon(Icons.near_me_outlined, size: 18),
                label: const Text('Yêu cầu quyền'),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrivacyNoticeCard(BuildContext context) {
    final c = context.tmColors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(TripMateRadius.lg),
        border: Border.all(color: c.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 19, color: c.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Vị trí của bạn chỉ được chia sẻ với các thành viên đang hoạt động trong nhóm du lịch này '
              'khi tính năng được bật, và sẽ dừng ngay lập tức khi bạn rời nhóm '
              'hoặc tắt cài đặt này.',
              style: TextStyle(
                fontSize: 12.5,
                color: c.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoControlsPanel(
    BuildContext context,
    GroupLocationSharingState state,
  ) {
    final c = context.tmColors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.warningContainer,
        borderRadius: BorderRadius.circular(TripMateRadius.lg),
        border: Border.all(color: c.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.build_circle_outlined, color: c.warning, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Điều khiển thử nghiệm (Demo)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: c.warning,
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
                label: const Text('Cấp quyền vị trí'),
                selected:
                    state.devicePermission == LocationPermission.whileInUse,
                onSelected: (_) =>
                    _cubit.setDemoPermission(LocationPermission.whileInUse),
              ),
              FilterChip(
                label: const Text('Từ chối quyền'),
                selected: state.devicePermission == LocationPermission.denied,
                onSelected: (_) =>
                    _cubit.setDemoPermission(LocationPermission.denied),
              ),
              FilterChip(
                label: const Text('Từ chối vĩnh viễn'),
                selected:
                    state.devicePermission == LocationPermission.deniedForever,
                onSelected: (_) =>
                    _cubit.setDemoPermission(LocationPermission.deniedForever),
              ),
              FilterChip(
                label: Text(
                  state.isLocationServiceEnabled ? 'Tắt GPS' : 'Bật GPS',
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
                      ? 'Giả lập ngừng hoạt động'
                      : 'Giả lập thành viên hoạt động',
                ),
                selected: !state.isActiveMember,
                onSelected: (_) =>
                    _cubit.setDemoActiveMembership(!state.isActiveMember),
              ),
              FilterChip(
                label: Text(
                  state.liveLocationDeliveryConfirmed
                      ? 'Giả lập tắt phát vị trí'
                      : 'Giả lập bật phát vị trí',
                ),
                selected: state.liveLocationDeliveryConfirmed,
                onSelected: (_) => _cubit.setDemoDeliveryConfirmed(
                  !state.liveLocationDeliveryConfirmed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
