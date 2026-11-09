import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/emergency_tour/resources/emergency_copy_vi.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/emergency_decision.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/weather_safety_review.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/operator_safety_review_detail_cubit.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/operator_safety_review_detail_state.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/widgets/safety_review_status_badge.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/resources/operator_weather_safety_vi.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_empty_state.dart';
import 'package:trip_mate_mobile/shared/widgets/error_view.dart';
import 'package:trip_mate_mobile/shared/widgets/loading_indicator.dart';

typedef _Strings = OperatorWeatherSafetyStringsVi;

class OperatorSafetyReviewDetailPage extends StatefulWidget {
  const OperatorSafetyReviewDetailPage({this.onChanged, super.key});

  /// The server state changed here, so the shared inbox should refresh.
  final VoidCallback? onChanged;

  @override
  State<OperatorSafetyReviewDetailPage> createState() =>
      _OperatorSafetyReviewDetailPageState();
}

class _OperatorSafetyReviewDetailPageState
    extends State<OperatorSafetyReviewDetailPage>
    with WidgetsBindingObserver {
  final _instructions = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(context.read<OperatorSafetyReviewDetailCubit>().load());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _openDecision(WeatherSafetyReview review) async {
    final cubit = context.read<OperatorSafetyReviewDetailCubit>();
    await context.push(
      AppRoutes.operatorEmergencyDecisionPath(
        tourId: review.tourId,
        scheduleId: review.tourScheduleId,
      ),
    );
    if (!mounted) return;
    await cubit.load();
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(_Strings.reviewTitle)),
    body:
        BlocConsumer<
          OperatorSafetyReviewDetailCubit,
          OperatorSafetyReviewDetailState
        >(
          listenWhen: (previous, current) =>
              previous.isAcknowledging && !current.isAcknowledging,
          listener: (_, state) {
            if (state.actionFailure == null) widget.onChanged?.call();
          },
          builder: (context, state) => switch (state.status) {
            OperatorSafetyReviewDetailStatus.loading =>
              const LoadingIndicator(),
            OperatorSafetyReviewDetailStatus.notFound => const AppEmptyState(
              title: _Strings.reviewNotFound,
              message: _Strings.reviewNotFoundMessage,
              icon: Icons.search_off_rounded,
            ),
            OperatorSafetyReviewDetailStatus.failure => ErrorView(
              retryLabel: _Strings.retry,
              message: state.failure?.viMessage ?? _Strings.loadFailed,
              onRetry: context.read<OperatorSafetyReviewDetailCubit>().load,
            ),
            OperatorSafetyReviewDetailStatus.ready => _content(context, state),
          },
        ),
  );

  Widget _content(BuildContext context, OperatorSafetyReviewDetailState state) {
    final review = state.review!;
    final cubit = context.read<OperatorSafetyReviewDetailCubit>();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              review.tourTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: SafetyReviewStatusBadge(status: review.status),
            ),
            if (state.isStale) ...[
              const SizedBox(height: AppSpacing.sm),
              const AppAlert(
                message: _Strings.staleReview,
                type: AppAlertType.warning,
              ),
            ],
            if (review.isWithdrawn) ...[
              const SizedBox(height: AppSpacing.sm),
              const AppAlert(message: _Strings.withdrawn),
            ],
            const SizedBox(height: AppSpacing.md),
            _Section(
              title: _Strings.sectionWeather,
              rows: {
                _Strings.eventType: review.eventType,
                _Strings.severity: severityLabel(review.severity),
                _Strings.description: review.description,
                _Strings.authority: review.originalAuthority,
                _Strings.riskLevel: review.officialRiskLevel?.toString(),
                _Strings.directive: review.verifiedDirective,
                _Strings.affectedArea: review.affectedAreaSummary,
                _Strings.validFrom: _date(review.validFromUtc),
                _Strings.validTo: _date(review.validToUtc),
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            _Section(
              title: _Strings.sectionDeparture,
              rows: {
                _Strings.scheduleStart: _date(review.scheduleStartAtUtc),
                _Strings.scheduleEnd: _date(review.scheduleEndAtUtc),
                _Strings.scheduleStatus: departureStatusLabel(
                  review.scheduleStatus,
                ),
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            _Section(
              title: _Strings.sectionResponse,
              rows: {
                _Strings.noticeSent: _date(review.urgentNoticeSentAtUtc),
                _Strings.deadline: _date(review.acknowledgementDeadlineUtc),
                if (review.acknowledgedAtUtc != null)
                  _Strings.acknowledgedAt: _date(review.acknowledgedAtUtc),
                if (review.escalatedAtUtc != null)
                  _Strings.escalatedAt: _date(review.escalatedAtUtc),
                if (review.escalationContact != null)
                  _Strings.escalationContact: review.escalationContact,
                // Before an acknowledgement this field only holds the system evaluation text.
                if (review.acknowledgedAtUtc != null &&
                    review.immediateInstructions != null)
                  _Strings.acknowledgementNote: review.immediateInstructions,
              },
            ),
            if (state.actionFailure case final failure?) ...[
              const SizedBox(height: AppSpacing.md),
              AppAlert(message: failure.viMessage, type: AppAlertType.error),
            ],
            if (review.canAcknowledge) ...[
              const SizedBox(height: AppSpacing.md),
              const Text(_Strings.acknowledgeExplanation),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _instructions,
                maxLength: EmergencyDecision.instructionsMaxLength,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: _Strings.instructionsOptional,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                key: const Key('safety-acknowledge'),
                onPressed: state.isAcknowledging || state.isOffline
                    ? null
                    : () => cubit.acknowledgeReview(
                        immediateInstructions: _instructions.text,
                      ),
                icon: const Icon(Icons.check_rounded),
                label: const Text(_Strings.acknowledge),
              ),
            ],
            if (review.scheduleStatus == 'Scheduled') ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                key: const Key('safety-open-decision'),
                onPressed: () => _openDecision(review),
                icon: const Icon(Icons.warning_amber_rounded),
                label: const Text(_Strings.reviewDecision),
              ),
            ],
            if (review.hasTerminalDecision) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                key: const Key('safety-manage-evidence'),
                onPressed: () => _openDecision(review),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text(_Strings.manageEvidence),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String? _date(DateTime? value) =>
      value == null ? null : TripFormatters.formatVietnamDateTime(value);
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final Map<String, String?> rows;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        for (final entry in rows.entries)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                Text(entry.value ?? _Strings.notProvided),
              ],
            ),
          ),
      ],
    ),
  );
}
