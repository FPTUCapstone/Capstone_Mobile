import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/emergency_tour/resources/emergency_copy_vi.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/emergency_decision.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/emergency_evidence_cubit.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/resources/operator_weather_safety_vi.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';

typedef _Strings = OperatorWeatherSafetyStringsVi;

/// Adds, updates or withdraws evidence on a committed decision. Links and text
/// only: no file, camera, gallery or location access.
class EmergencyEvidenceEditor extends StatefulWidget {
  const EmergencyEvidenceEditor({super.key});

  @override
  State<EmergencyEvidenceEditor> createState() =>
      _EmergencyEvidenceEditorState();
}

class _EmergencyEvidenceEditorState extends State<EmergencyEvidenceEditor> {
  final _form = GlobalKey<FormState>();
  final _url = TextEditingController();
  final _authority = TextEditingController();
  final _reference = TextEditingController();
  bool _showEmptyError = false;

  @override
  void initState() {
    super.initState();
    unawaited(context.read<EmergencyEvidenceCubit>().load());
  }

  /// The form always shows what the Backend holds, so a field the Operator did
  /// not touch is sent back unchanged.
  void _fillFrom(EmergencyEvidence evidence) {
    _url.text = evidence.url ?? '';
    _authority.text = evidence.authorityReference ?? '';
    _reference.text = evidence.reference ?? '';
  }

  @override
  void dispose() {
    _url.dispose();
    _authority.dispose();
    _reference.dispose();
    super.dispose();
  }

  static String? _clean(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  void _save() {
    final evidence = EmergencyEvidence(
      url: _clean(_url),
      authorityReference: _clean(_authority),
      reference: _clean(_reference),
    );
    final isEmpty =
        evidence.url == null &&
        evidence.authorityReference == null &&
        evidence.reference == null;
    setState(() => _showEmptyError = isEmpty);
    if (isEmpty || !(_form.currentState?.validate() ?? false)) return;
    unawaited(context.read<EmergencyEvidenceCubit>().saveEvidence(evidence));
  }

  Future<void> _withdraw() async {
    final cubit = context.read<EmergencyEvidenceCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text(_Strings.evidenceWithdrawTitle),
        content: const Text(_Strings.evidenceWithdrawMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(_Strings.keepTour),
          ),
          FilledButton(
            key: const Key('evidence-withdraw-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(_Strings.evidenceWithdrawConfirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await cubit.withdrawEvidence();
  }

  @override
  Widget build(BuildContext context) => AppCard(
    key: const Key('evidence-editor'),
    child: BlocConsumer<EmergencyEvidenceCubit, EmergencyEvidenceState>(
      listenWhen: (previous, current) => previous.current != current.current,
      listener: (_, state) {
        if (state.current case final current?) _fillFrom(current.evidence);
      },
      builder: (context, state) {
        // Editing needs the saved values first, or a save would erase them.
        final isBusy =
            state.status == EmergencyEvidenceStatus.submitting ||
            state.current == null;
        return Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _Strings.manageEvidenceTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(_Strings.evidenceClears),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                key: const Key('evidence-url'),
                controller: _url,
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
                key: const Key('evidence-authority'),
                controller: _authority,
                maxLength: EmergencyEvidence.authorityReferenceMaxLength,
                decoration: const InputDecoration(
                  labelText: _Strings.authorityReference,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                key: const Key('evidence-reference'),
                controller: _reference,
                maxLength: EmergencyEvidence.referenceMaxLength,
                decoration: const InputDecoration(
                  labelText: _Strings.evidenceReference,
                  border: OutlineInputBorder(),
                ),
              ),
              if (_showEmptyError)
                const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppAlert(
                    message: _Strings.evidenceEmpty,
                    type: AppAlertType.warning,
                  ),
                ),
              if (state.status == EmergencyEvidenceStatus.saved)
                const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppAlert(
                    message: _Strings.evidenceSaved,
                    type: AppAlertType.success,
                  ),
                ),
              if (state.status == EmergencyEvidenceStatus.withdrawn)
                const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppAlert(
                    message: _Strings.evidenceWithdrawn,
                    type: AppAlertType.success,
                  ),
                ),
              if (state.failure case final failure?)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppAlert(
                    message: failure.viMessage,
                    type: AppAlertType.error,
                  ),
                ),
              FilledButton(
                key: const Key('evidence-save'),
                onPressed: isBusy ? null : _save,
                child: const Text(_Strings.evidenceSave),
              ),
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton(
                key: const Key('evidence-withdraw'),
                onPressed: isBusy ? null : _withdraw,
                child: const Text(_Strings.evidenceWithdraw),
              ),
            ],
          ),
        );
      },
    ),
  );
}
