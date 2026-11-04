import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/emergency_tour/domain/entities/emergency_action.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/domain/entities/traveler_emergency_status.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/resources/traveler_emergency_en.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';

/// Stays until the notice is acknowledged, so a dismissed push cannot hide it.
class TravelerEmergencyBanner extends StatelessWidget {
  const TravelerEmergencyBanner({
    required this.unread,
    required this.onOpen,
    super.key,
  });

  final List<TravelerEmergencyNotice> unread;

  /// The booking to open, or null when several notices need the list.
  final ValueChanged<int?> onOpen;

  @override
  Widget build(BuildContext context) {
    if (unread.isEmpty) return const SizedBox.shrink();
    final single = unread.length == 1 ? unread.single : null;
    final message = switch (single?.action) {
      null => TravelerEmergencyStringsEn.bannerSeveral(unread.length),
      EmergencyAction.emergencyStop => TravelerEmergencyStringsEn.bannerStopped,
      _ => TravelerEmergencyStringsEn.bannerUpdate,
    };
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Semantics(
        button: true,
        child: InkWell(
          key: const Key('emergency-banner'),
          onTap: () => onOpen(single?.bookingId),
          child: AppAlert(message: message, type: AppAlertType.warning),
        ),
      ),
    );
  }
}
