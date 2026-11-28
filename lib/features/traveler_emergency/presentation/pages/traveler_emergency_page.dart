import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/features/emergency_tour/domain/entities/emergency_action.dart';
import 'package:trip_mate_mobile/features/emergency_tour/resources/emergency_copy_vi.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/domain/entities/traveler_emergency_status.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/presentation/cubit/traveler_emergency_cubit.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/presentation/cubit/traveler_emergency_state.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/resources/traveler_emergency_vi.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_coastal_app_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/app_empty_state.dart';
import 'package:trip_mate_mobile/shared/widgets/app_section_card.dart';
import 'package:trip_mate_mobile/shared/widgets/error_view.dart';
import 'package:trip_mate_mobile/shared/widgets/loading_indicator.dart';
import 'package:url_launcher/url_launcher.dart';

typedef _Strings = TravelerEmergencyStringsVi;

class TravelerEmergencyPage extends StatefulWidget {
  const TravelerEmergencyPage({
    this.dial = launchUrl,
    this.onAcknowledged,
    super.key,
  });

  /// Starts the device's dialler for a `tel:` link.
  final Future<bool> Function(Uri uri) dial;

  /// The notice is no longer unread, so the shared banner should refresh.
  final VoidCallback? onAcknowledged;

  @override
  State<TravelerEmergencyPage> createState() => _TravelerEmergencyPageState();
}

class _TravelerEmergencyPageState extends State<TravelerEmergencyPage>
    with WidgetsBindingObserver {
  bool _callFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(context.read<TravelerEmergencyCubit>().load());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _call(String number) async {
    var started = false;
    try {
      started = await widget.dial(Uri(scheme: 'tel', path: number));
    } on Object {
      // No dialler on this device: the contact stays visible as text.
    }
    if (mounted) setState(() => _callFailed = !started);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return Scaffold(
      backgroundColor: c.canvas,
      appBar: const AppCoastalAppBar(title: _Strings.pageTitle),
      body: BlocConsumer<TravelerEmergencyCubit, TravelerEmergencyState>(
        listenWhen: (previous, current) =>
            previous.isAcknowledging && !current.isAcknowledging,
        listener: (_, state) {
          if (state.actionFailure == null) widget.onAcknowledged?.call();
        },
        builder: (context, state) => switch (state.status) {
          TravelerEmergencyLoadStatus.loading => const LoadingIndicator(),
          TravelerEmergencyLoadStatus.notFound => const AppEmptyState(
            title: _Strings.notFoundTitle,
            message: _Strings.notFoundMessage,
            icon: Icons.search_off_rounded,
          ),
          TravelerEmergencyLoadStatus.failure => ErrorView(
            retryLabel: _Strings.retry,
            message: state.failure?.viMessage ?? _Strings.loadFailed,
            onRetry: context.read<TravelerEmergencyCubit>().load,
          ),
          TravelerEmergencyLoadStatus.ready => _content(context, state),
        },
      ),
    );
  }

  Widget _content(BuildContext context, TravelerEmergencyState state) {
    final c = context.tmColors;
    final emergency = state.emergency!;
    final title = switch (emergency.action) {
      EmergencyAction.emergencyStop => _Strings.stoppedTitle,
      EmergencyAction.cancelBeforeDeparture => _Strings.cancelledTitle,
      EmergencyAction.unknown => _Strings.unknownTitle,
    };
    final reason = _Section(
      icon: Icons.info_outline_rounded,
      title: _Strings.reason,
      child: Text(
        emergency.reasonDetails,
        style: TextStyle(color: c.textPrimary, height: 1.45),
      ),
    );
    final contact = _contactCard(context, emergency);
    return SafeArea(
      key: const Key('emergency-notice-loaded'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: c.errorContainer,
                borderRadius: BorderRadius.circular(TripMateRadius.xl),
                border: Border.all(color: c.error.withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c.error.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      emergency.isStopped
                          ? Icons.warning_amber_rounded
                          : Icons.event_busy_outlined,
                      color: c.error,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            title,
                            style: TextStyle(
                              fontFamily: AppTypography.displayFont,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: c.error,
                              height: 1.25,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_Strings.committedAt}: ${TripFormatters.formatVietnamDateTime(emergency.committedAtUtc)}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (state.isStale)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppAlert(
                  message: _Strings.staleNotice,
                  type: AppAlertType.warning,
                ),
              ),
            // Safety comes first for a stopped tour; a cancelled departure has
            // no one in the field, so the reason leads instead.
            if (emergency.isStopped) ...[
              if (emergency.immediateInstructions case final instructions?)
                _Section(
                  icon: Icons.health_and_safety_outlined,
                  title: _Strings.instructions,
                  highlightWarning: true,
                  child: Text(
                    instructions,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                ),
              contact,
              reason,
            ] else ...[
              reason,
              if (emergency.immediateInstructions case final instructions?)
                _Section(
                  icon: Icons.health_and_safety_outlined,
                  title: _Strings.instructions,
                  highlightWarning: true,
                  child: Text(
                    instructions,
                    style: TextStyle(color: c.textPrimary, height: 1.45),
                  ),
                ),
              if (emergency.emergencyContact != null) contact,
            ],
            _Section(
              icon: Icons.confirmation_number_outlined,
              title: _Strings.booking,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_Strings.bookingStatus}: ${bookingStatusLabel(emergency.bookingStatus)}',
                    style: TextStyle(color: c.textPrimary, height: 1.4),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_Strings.scheduleStatus}: ${departureStatusLabel(emergency.scheduleStatus)}',
                    style: TextStyle(color: c.textPrimary, height: 1.4),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_Strings.tickets}: ${_Strings.ticketSummary(emergency.totalTicketCount, emergency.cancelledTicketCount, emergency.usedTicketCount)}',
                    style: TextStyle(color: c.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
            _refundStatus(context, emergency),
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppAlert(message: _Strings.companionReminder),
            ),
            if (state.actionFailure case final failure?)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppAlert(
                  message: failure.viMessage,
                  type: AppAlertType.error,
                ),
              ),
            _acknowledgement(context, state, emergency),
          ],
        ),
      ),
    );
  }

  /// The refund line and the existing refund-progress screen when a refund
  /// request exists.
  Widget _refundStatus(
    BuildContext context,
    TravelerEmergencyStatus emergency,
  ) {
    final c = context.tmColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _Strings.refundHandling(
                emergency.refundHandling,
                emergency.action,
              ),
              style: TextStyle(color: c.textPrimary, height: 1.4),
            ),
            if (emergency.hasRefundRequest) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                key: const Key('emergency-refund-progress'),
                onPressed: () => context.push(
                  AppRoutes.bookingRefund('${emergency.bookingId}'),
                ),
                icon: const Icon(Icons.currency_exchange_rounded),
                label: const Text(_Strings.viewRefundProgress),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _contactCard(BuildContext context, TravelerEmergencyStatus emergency) {
    final c = context.tmColors;
    final number = emergency.dialableContact;
    return _Section(
      icon: Icons.support_agent_rounded,
      title: _Strings.contact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            emergency.emergencyContact ?? _Strings.noContact,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          if (number != null) ...[
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              key: const Key('emergency-call'),
              onPressed: () => _call(number),
              style: FilledButton.styleFrom(
                backgroundColor: c.error,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.call_rounded),
              label: const Text(_Strings.call),
            ),
          ],
          if (_callFailed) ...[
            const SizedBox(height: AppSpacing.sm),
            const AppAlert(
              message: _Strings.callFailed,
              type: AppAlertType.warning,
            ),
          ],
        ],
      ),
    );
  }

  Widget _acknowledgement(
    BuildContext context,
    TravelerEmergencyState state,
    TravelerEmergencyStatus emergency,
  ) {
    final c = context.tmColors;
    final acknowledgedAt = emergency.acknowledgedAtUtc;
    if (acknowledgedAt != null) {
      return AppAlert(
        message: _Strings.acknowledgedAt(
          TripFormatters.formatVietnamDateTime(acknowledgedAt),
        ),
        type: AppAlertType.success,
      );
    }
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _Strings.acknowledgeExplanation,
            style: TextStyle(color: c.textSecondary, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            key: const Key('emergency-ack'),
            onPressed: state.isAcknowledging
                ? null
                : context.read<TravelerEmergencyCubit>().acknowledgeNotice,
            icon: const Icon(Icons.done_rounded),
            label: const Text(_Strings.acknowledge),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
    this.highlightWarning = false,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final bool highlightWarning;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    if (highlightWarning) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: c.warningContainer,
            borderRadius: BorderRadius.circular(TripMateRadius.lg),
            border: Border.all(color: c.warning.withValues(alpha: 0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: c.warning),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: c.warning,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              child,
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppSectionCard(title: title, icon: icon, child: child),
    );
  }
}
