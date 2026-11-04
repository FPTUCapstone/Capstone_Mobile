import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/platform/device_window.dart';
import 'package:trip_mate_mobile/features/emergency_tour/domain/entities/emergency_action.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/emergency_decision.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/emergency_decision_cubit.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/emergency_decision_state.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/widgets/emergency_evidence_editor.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/resources/operator_weather_safety_en.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_empty_state.dart';
import 'package:trip_mate_mobile/shared/widgets/loading_indicator.dart';

typedef _Strings = OperatorWeatherSafetyStringsEn;

/// The password lives only in this widget's controller. It is read once at
/// submit, cleared immediately, and cleared again on cancel, backgrounding and
/// disposal, so it never reaches Cubit state, restoration or storage.
class EmergencyDecisionPage extends StatefulWidget {
  const EmergencyDecisionPage({
    required this.tourId,
    required this.scheduleId,
    this.onDecided,
    required this.window,
    super.key,
  });

  final int tourId;
  final int scheduleId;

  /// A terminal decision committed, so the shared inbox should refresh.
  final VoidCallback? onDecided;

  final DeviceWindow window;

  @override
  State<EmergencyDecisionPage> createState() => _EmergencyDecisionPageState();
}

class _EmergencyDecisionPageState extends State<EmergencyDecisionPage>
    with WidgetsBindingObserver {
  final _form = GlobalKey<FormState>();
  final _details = TextEditingController();
  final _instructions = TextEditingController();
  final _contact = TextEditingController();
  final _evidenceUrl = TextEditingController();
  final _authority = TextEditingController();
  final _reference = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  final _detailsFocus = FocusNode();
  final _instructionsFocus = FocusNode();
  final _contactFocus = FocusNode();
  final _evidenceUrlFocus = FocusNode();
  final _authorityFocus = FocusNode();
  EmergencyReason _reason = EmergencyReason.weatherEmergency;
  bool _addLater = false;
  bool _windowSecure = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(context.read<EmergencyDecisionCubit>().refreshOnResume());
    }
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _password.clear();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_windowSecure) unawaited(widget.window.setSecure(false));
    _password
      ..clear()
      ..dispose();
    _passwordFocus.dispose();
    _detailsFocus.dispose();
    _instructionsFocus.dispose();
    _contactFocus.dispose();
    _evidenceUrlFocus.dispose();
    _authorityFocus.dispose();
    _details.dispose();
    _instructions.dispose();
    _contact.dispose();
    _evidenceUrl.dispose();
    _authority.dispose();
    _reference.dispose();
    super.dispose();
  }

  static String? _clean(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  bool get _lacksAuthorityEvidence =>
      _reason == EmergencyReason.authorityDirective &&
      _clean(_authority) == null &&
      _clean(_reference) == null &&
      !_addLater;

  void _focusFirstInvalid(EmergencyImpact impact) {
    final isStop = impact.action == EmergencyAction.emergencyStop;
    final url = _clean(_evidenceUrl);
    final invalid = [
      if (_clean(_details) == null) _detailsFocus,
      if (isStop && _clean(_instructions) == null) _instructionsFocus,
      if (isStop && _clean(_contact) == null) _contactFocus,
      if (url != null && !EmergencyEvidence.isAcceptableUrl(url))
        _evidenceUrlFocus,
      if (_lacksAuthorityEvidence) _authorityFocus,
      if (isStop && _password.text.isEmpty) _passwordFocus,
    ];
    invalid.firstOrNull?.requestFocus();
  }

  EmergencyDecision _draft(EmergencyImpact impact) {
    final evidence = EmergencyEvidence(
      url: _clean(_evidenceUrl),
      authorityReference: _clean(_authority),
      reference: _clean(_reference),
      addLater: _addLater,
    );
    return impact.action == EmergencyAction.emergencyStop
        ? EmergencyStopDecision(
            tourId: widget.tourId,
            scheduleId: widget.scheduleId,
            impactVersion: impact.impactVersion,
            reason: _reason,
            reasonDetails: _details.text.trim(),
            immediateInstructions: _instructions.text.trim(),
            emergencyContact: _contact.text.trim(),
            evidence: evidence,
          )
        : CancelBeforeDepartureDecision(
            tourId: widget.tourId,
            scheduleId: widget.scheduleId,
            impactVersion: impact.impactVersion,
            reason: _reason,
            reasonDetails: _details.text.trim(),
            emergencyContact: _clean(_contact),
            evidence: evidence,
          );
  }

  void _review(EmergencyImpact impact) {
    if (!(_form.currentState?.validate() ?? false)) {
      _focusFirstInvalid(impact);
      return;
    }
    context.read<EmergencyDecisionCubit>().prepareConfirmation(_draft(impact));
  }

  Future<void> _confirm(EmergencyDecisionState state) async {
    final impact = state.impact;
    if (impact == null) return;
    final cubit = context.read<EmergencyDecisionCubit>();
    final isStop = state.impact?.action == EmergencyAction.emergencyStop;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ConfirmationDialog(impact: impact, isStop: isStop),
    );
    if (!mounted) return;
    if (confirmed ?? false) {
      await cubit.confirm(currentPassword: _takePassword(isStop));
    } else {
      _password.clear();
      cubit.dismissConfirmation();
    }
  }

  Future<void> _retry(EmergencyDecisionState state) =>
      context.read<EmergencyDecisionCubit>().retry(
        currentPassword: _takePassword(
          state.impact?.action == EmergencyAction.emergencyStop,
        ),
      );

  String? _takePassword(bool isStop) {
    final password = _password.text;
    _password.clear();
    return isStop ? password : null;
  }

  /// Only the screen that holds the password blocks screenshots and recording.
  void _syncSecureWindow(EmergencyDecisionState state) {
    final shouldSecure =
        state.impact?.action == EmergencyAction.emergencyStop &&
        state.stage != EmergencyDecisionStage.succeeded &&
        state.stage != EmergencyDecisionStage.blocked;
    if (shouldSecure == _windowSecure) return;
    _windowSecure = shouldSecure;
    unawaited(widget.window.setSecure(shouldSecure));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(_Strings.decisionTitle)),
    body: BlocConsumer<EmergencyDecisionCubit, EmergencyDecisionState>(
      listenWhen: (previous, current) => previous.stage != current.stage,
      listener: (context, state) {
        // Nothing is on its way to the Backend, so the password does not stay.
        if (state.stage
            case EmergencyDecisionStage.ready ||
                EmergencyDecisionStage.blocked) {
          _password.clear();
        }
        switch (state.stage) {
          case EmergencyDecisionStage.awaitingConfirmation:
            _confirm(state);
          case EmergencyDecisionStage.succeeded:
            widget.onDecided?.call();
          case EmergencyDecisionStage.ready
              when state.isPasswordRejected ||
                  state.failure is ValidationFailure && _password.text.isEmpty:
            // The field is disabled until this state has been built.
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _passwordFocus.requestFocus(),
            );
          default:
            break;
        }
      },
      // From the build, so a state reached before the first frame still counts.
      builder: (context, state) {
        _syncSecureWindow(state);
        return switch (state.stage) {
          EmergencyDecisionStage.loading => const LoadingIndicator(),
          EmergencyDecisionStage.notFound => const AppEmptyState(
            title: _Strings.departureNotFound,
            message: _Strings.departureNotFoundMessage,
            icon: Icons.search_off_rounded,
          ),
          _ => _content(context, state),
        };
      },
    ),
  );

  Widget _content(BuildContext context, EmergencyDecisionState state) {
    final impact = state.impact;
    final cubit = context.read<EmergencyDecisionCubit>();
    final isDecided =
        state.stage == EmergencyDecisionStage.succeeded ||
        state.blockReason == EmergencyBlockReason.terminal ||
        // The Backend reports an ended departure as completed even when it has
        // a decision, and evidence may still be added to that decision.
        state.blockReason == EmergencyBlockReason.completed;
    final showsForm =
        impact != null &&
        !isDecided &&
        state.stage != EmergencyDecisionStage.blocked;
    return SafeArea(
      key: const Key('emergency-decision-loaded'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.result case final result?)
              _Success(result: result)
            else if (impact != null) ...[
              Text(
                impact.action == EmergencyAction.emergencyStop
                    ? _Strings.stopAction
                    : _Strings.cancelAction,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              _ImpactPanel(impact: impact),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (state.impactChanged)
              const _Notice(
                message: _Strings.impactChanged,
                type: AppAlertType.warning,
              ),
            if (state.blockReason case final reason?) ...[
              _Notice(
                message: _Strings.blockMessage(reason),
                type: AppAlertType.warning,
              ),
              if (reason != EmergencyBlockReason.terminal &&
                  reason != EmergencyBlockReason.completed)
                OutlinedButton(
                  onPressed: cubit.load,
                  child: const Text(_Strings.checkAgain),
                ),
            ],
            if (state.failure case final failure?
                when state.stage != EmergencyDecisionStage.ambiguous)
              _Notice(message: failure.message, type: AppAlertType.error),
            if (showsForm) _decisionForm(state, impact),
            if (isDecided) const EmergencyEvidenceEditor(),
          ],
        ),
      ),
    );
  }

  Widget _decisionForm(EmergencyDecisionState state, EmergencyImpact impact) {
    final isStop = impact.action == EmergencyAction.emergencyStop;
    final isAmbiguous = state.stage == EmergencyDecisionStage.ambiguous;
    final canEdit = state.stage == EmergencyDecisionStage.ready;
    final isBusy =
        state.stage == EmergencyDecisionStage.checkingImpact ||
        state.stage == EmergencyDecisionStage.submitting;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<EmergencyReason>(
            key: const Key('emergency-reason'),
            initialValue: _reason,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: _Strings.reason,
              border: OutlineInputBorder(),
            ),
            items: [
              for (final reason in EmergencyReason.values)
                DropdownMenuItem(value: reason, child: Text(reason.label)),
            ],
            onChanged: canEdit
                ? (value) => setState(() => _reason = value ?? _reason)
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          _field(
            key: 'emergency-reason-details',
            focusNode: _detailsFocus,
            controller: _details,
            label: _Strings.reasonDetails,
            enabled: canEdit,
            maxLength: EmergencyDecision.reasonDetailsMaxLength,
            lines: 3,
            required: _Strings.reasonRequired,
          ),
          if (isStop)
            _field(
              key: 'emergency-instructions',
              focusNode: _instructionsFocus,
              controller: _instructions,
              label: _Strings.instructions,
              enabled: canEdit,
              maxLength: EmergencyDecision.instructionsMaxLength,
              lines: 3,
              required: _Strings.instructionsRequired,
            ),
          _field(
            key: 'emergency-contact',
            focusNode: _contactFocus,
            controller: _contact,
            label: isStop ? _Strings.contact : _Strings.contactOptional,
            enabled: canEdit,
            maxLength: EmergencyDecision.contactMaxLength,
            required: isStop ? _Strings.contactRequired : null,
          ),
          Text(
            _Strings.evidenceTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            key: const Key('emergency-evidence-url'),
            focusNode: _evidenceUrlFocus,
            controller: _evidenceUrl,
            enabled: canEdit,
            keyboardType: TextInputType.url,
            maxLength: EmergencyEvidence.urlMaxLength,
            decoration: const InputDecoration(
              labelText: _Strings.evidenceUrl,
              hintText: _Strings.evidenceUrlHint,
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              return text.isEmpty || EmergencyEvidence.isAcceptableUrl(text)
                  ? null
                  : _Strings.evidenceUrlInvalid;
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            key: const Key('emergency-authority'),
            focusNode: _authorityFocus,
            controller: _authority,
            enabled: canEdit,
            maxLength: EmergencyEvidence.authorityReferenceMaxLength,
            decoration: const InputDecoration(
              labelText: _Strings.authorityReference,
              border: OutlineInputBorder(),
            ),
            validator: (_) => _lacksAuthorityEvidence
                ? _Strings.authorityEvidenceRequired
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            key: const Key('emergency-evidence-reference'),
            controller: _reference,
            enabled: canEdit,
            maxLength: EmergencyEvidence.referenceMaxLength,
            decoration: const InputDecoration(
              labelText: _Strings.evidenceReference,
              border: OutlineInputBorder(),
            ),
          ),
          CheckboxListTile(
            key: const Key('emergency-add-later'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(_Strings.addLater),
            value: _addLater,
            onChanged: canEdit
                ? (value) => setState(() => _addLater = value ?? false)
                : null,
          ),
          if (isStop) ...[
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: const Key('emergency-password'),
              controller: _password,
              focusNode: _passwordFocus,
              enabled: canEdit || isAmbiguous,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              enableIMEPersonalizedLearning: false,
              keyboardType: TextInputType.visiblePassword,
              decoration: const InputDecoration(
                labelText: _Strings.password,
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.isEmpty
                  ? _Strings.passwordRequired
                  : null,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (isAmbiguous)
            ..._ambiguousActions(state)
          else
            FilledButton.icon(
              key: const Key('emergency-review-decision'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: canEdit ? () => _review(impact) : null,
              icon: isBusy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.warning_amber_rounded),
              label: const Text(_Strings.reviewAndConfirm),
            ),
        ],
      ),
    );
  }

  List<Widget> _ambiguousActions(EmergencyDecisionState state) => [
    const _Notice(message: _Strings.ambiguous, type: AppAlertType.warning),
    if (state.failure case final failure?)
      _Notice(message: failure.message, type: AppAlertType.error),
    FilledButton(
      key: const Key('emergency-retry-submit'),
      onPressed: () => _retry(state),
      child: const Text(_Strings.retrySubmit),
    ),
    const SizedBox(height: AppSpacing.xs),
    OutlinedButton(
      onPressed: context.read<EmergencyDecisionCubit>().load,
      child: const Text(_Strings.checkStatus),
    ),
  ];

  Widget _field({
    required String key,
    required FocusNode focusNode,
    required TextEditingController controller,
    required String label,
    required bool enabled,
    required int maxLength,
    int lines = 1,
    String? required,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: TextFormField(
      key: Key(key),
      focusNode: focusNode,
      controller: controller,
      enabled: enabled,
      maxLength: maxLength,
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines + 3,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: required == null
          ? null
          : (value) => value == null || value.trim().isEmpty ? required : null,
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, required this.type});

  final String message;
  final AppAlertType type;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: AppAlert(message: message, type: type),
  );
}

class _ImpactPanel extends StatelessWidget {
  const _ImpactPanel({required this.impact});

  final EmergencyImpact impact;

  @override
  Widget build(BuildContext context) => AppCard(
    key: const Key('emergency-impact-panel'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _Strings.impactTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('${_Strings.passengers}: ${impact.totalPassengerCount}'),
        Text('${_Strings.paidBookings}: ${impact.paidBookingCount}'),
        Text('${_Strings.unpaidBookings}: ${impact.unpaidBookingCount}'),
        Text('${_Strings.activeSessions}: ${impact.activeSessionCount}'),
        Text('${_Strings.unusedTickets}: ${impact.unusedTicketCount}'),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          _Strings.paymentHandlingNotice,
          style: TextStyle(color: AppColors.muted),
        ),
      ],
    ),
  );
}

class _ConfirmationDialog extends StatelessWidget {
  const _ConfirmationDialog({required this.impact, required this.isStop});

  final EmergencyImpact impact;
  final bool isStop;

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    icon: const Icon(Icons.warning_amber_rounded, color: AppColors.error),
    title: Text(
      isStop ? _Strings.confirmStopTitle : _Strings.confirmCancelTitle,
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _Strings.confirmImpact(
            impact.totalPassengerCount,
            impact.paidBookingCount,
            impact.unpaidBookingCount,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(_Strings.confirmIrreversible),
      ],
    ),
    actions: [
      TextButton(
        key: const Key('emergency-confirm-cancel'),
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text(_Strings.keepTour),
      ),
      FilledButton(
        key: const Key('emergency-confirm-submit'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
        ),
        onPressed: () => Navigator.of(context).pop(true),
        child: Text(
          isStop ? _Strings.confirmStopSubmit : _Strings.confirmCancelSubmit,
        ),
      ),
    ],
  );
}

class _Success extends StatelessWidget {
  const _Success({required this.result});

  final EmergencyOperationResult result;

  @override
  Widget build(BuildContext context) => Padding(
    key: const Key('emergency-success'),
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: AppAlert(
      title: result.action == EmergencyAction.emergencyStop
          ? _Strings.successStopped
          : _Strings.successCancelled,
      message: _Strings.successMessage(result.affectedBookingCount),
      type: AppAlertType.success,
    ),
  );
}
