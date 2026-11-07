import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/core/push/emergency_push_hint.dart';

/// The foreground surface. A SnackBar with an action stays until dismissed unless
/// told otherwise, and this one must not outlive the moment it announces.
SnackBar emergencyUpdateSnackBar({required VoidCallback onOpen}) => SnackBar(
  content: const Text('TripMate has an important update for you.'),
  persist: false,
  duration: const Duration(seconds: 6),
  action: SnackBarAction(label: 'Open', onPressed: onOpen),
);

/// Turns a UC-70 hint into a REST refresh plus either the guarded route (tapped)
/// or one in-app surface (foreground). Nothing from the payload is ever shown.
final class EmergencyPushHandler {
  const EmergencyPushHandler({
    required this.open,
    required this.refresh,
    required this.surface,
    this.dismissSurface,
  });

  final void Function(String location) open;
  final Future<void> Function(EmergencyPushHint hint) refresh;
  final void Function(String location) surface;

  /// Removes an earlier in-app surface so it cannot outlive what it announced.
  final void Function()? dismissSurface;

  Future<void> handle(EmergencyPushHint hint) async {
    try {
      await refresh(hint);
    } on Object {
      // The hint still leads to the guarded route, which reads REST itself.
    }
    final location = switch (hint) {
      OperatorReviewHint(:final reviewId) => AppRoutes.operatorSafetyReviewPath(
        reviewId,
      ),
      TravelerBookingHint(:final bookingId) => AppRoutes.travelerEmergency(
        bookingId,
      ),
    };
    if (hint.opened) {
      dismissSurface?.call();
      open(location);
    } else {
      surface(location);
    }
  }
}
