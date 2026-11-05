import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/emergency_tour/domain/entities/emergency_action.dart';
import 'package:trip_mate_mobile/features/emergency_tour/resources/emergency_copy_vi.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/domain/entities/traveler_emergency_status.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/presentation/cubit/traveler_emergency_cubit.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/presentation/cubit/traveler_emergency_state.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/resources/traveler_emergency_vi.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_empty_state.dart';
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(_Strings.pageTitle)),
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

  Widget _content(BuildContext context, TravelerEmergencyState state) {
    final emergency = state.emergency!;
    final title = switch (emergency.action) {
      EmergencyAction.emergencyStop => _Strings.stoppedTitle,
      EmergencyAction.cancelBeforeDeparture => _Strings.cancelledTitle,
      EmergencyAction.unknown => _Strings.unknownTitle,
    };
    final reason = _Section(
      title: _Strings.reason,
      child: Text(emergency.reasonDetails),
    );
    final contact = _contactCard(emergency);
    return SafeArea(
      key: const Key('emergency-notice-loaded'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Row(
                children: [
                  Icon(
                    emergency.isStopped
                        ? Icons.warning_amber_rounded
                        : Icons.event_busy_outlined,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${_Strings.committedAt}: ${TripFormatters.formatVietnamDateTime(emergency.committedAtUtc)}',
              style: const TextStyle(color: AppColors.muted),
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
                  title: _Strings.instructions,
                  child: Text(instructions),
                ),
              contact,
              reason,
            ] else ...[
              reason,
              if (emergency.immediateInstructions case final instructions?)
                _Section(
                  title: _Strings.instructions,
                  child: Text(instructions),
                ),
              if (emergency.emergencyContact != null) contact,
            ],
            _Section(
              title: _Strings.booking,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_Strings.bookingStatus}: ${bookingStatusLabel(emergency.bookingStatus)}',
                  ),
                  Text(
                    '${_Strings.scheduleStatus}: ${departureStatusLabel(emergency.scheduleStatus)}',
                  ),
                  Text(
                    '${_Strings.tickets}: ${_Strings.ticketSummary(emergency.totalTicketCount, emergency.cancelledTicketCount, emergency.usedTicketCount)}',
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(_Strings.paymentHandlingNotice),
            ),
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

  Widget _contactCard(TravelerEmergencyStatus emergency) {
    final number = emergency.dialableContact;
    return _Section(
      title: _Strings.contact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(emergency.emergencyContact ?? _Strings.noContact),
          if (number != null) ...[
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              key: const Key('emergency-call'),
              onPressed: () => _call(number),
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
    final acknowledgedAt = emergency.acknowledgedAtUtc;
    if (acknowledgedAt != null) {
      return AppAlert(
        message: _Strings.acknowledgedAt(
          TripFormatters.formatVietnamDateTime(acknowledgedAt),
        ),
        type: AppAlertType.success,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(_Strings.acknowledgeExplanation),
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
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: AppCard(
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            child,
          ],
        ),
      ),
    ),
  );
}
