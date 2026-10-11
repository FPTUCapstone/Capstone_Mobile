import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/register_operator_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/services/operator_document_picker.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_password_field.dart';
import 'package:trip_mate_mobile/shared/widgets/app_text_field.dart';

class OperatorRegistrationPage extends StatefulWidget {
  const OperatorRegistrationPage({required this.documentPicker, super.key});

  final OperatorDocumentPicker documentPicker;

  @override
  State<OperatorRegistrationPage> createState() =>
      _OperatorRegistrationPageState();
}

class _OperatorRegistrationPageState extends State<OperatorRegistrationPage> {
  Timer? _resendTimer;
  int _resendSecondsLeft = 0;
  final _controllers = <String, TextEditingController>{
    for (final field in [
      'email',
      'password',
      'confirmPassword',
      'companyName',
      'businessLicenseNo',
      'taxCode',
      'contactPerson',
      'businessAddress',
      'contactPhone',
    ])
      field: TextEditingController(),
  };

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RegisterOperatorCubit, RegisterOperatorState>(
      buildWhen: (previous, current) =>
          previous.step != current.step ||
          previous.phase != current.phase ||
          previous.isBusy != current.isBusy ||
          previous.notice != current.notice ||
          !mapEquals(previous.errors, current.errors) ||
          previous.businessLicence != current.businessLicence ||
          !listEquals(
            previous.supportingDocuments,
            current.supportingDocuments,
          ) ||
          previous.acceptedTerms != current.acceptedTerms ||
          previous.emailSent != current.emailSent ||
          previous.alreadyVerified != current.alreadyVerified ||
          previous.resumeExistingIdentity != current.resumeExistingIdentity,
      builder: (context, state) {
        final content = switch (state.phase) {
          RegisterOperatorPhase.awaitingVerification => _verificationContent(
            state,
          ),
          RegisterOperatorPhase.submitted => _submittedContent(state),
          RegisterOperatorPhase.uncertain => _uncertainContent(state),
          RegisterOperatorPhase.editing => _wizardContent(state),
        };
        final footer = switch (state.phase) {
          RegisterOperatorPhase.editing => _wizardFooter(state),
          RegisterOperatorPhase.uncertain => _uncertainFooter(state),
          RegisterOperatorPhase.awaitingVerification => _verificationFooter(
            state,
          ),
          RegisterOperatorPhase.submitted => _submittedFooter(state),
        };
        return Scaffold(
          appBar: AppBar(
            title: Text(
              state.phase == RegisterOperatorPhase.awaitingVerification
                  ? 'Verify your email'
                  : 'Register Tour Operator',
            ),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.lg,
                  ),
                  children: content,
                ),
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: footer,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _wizardContent(RegisterOperatorState state) => [
    Text(
      'Complete the form, verify your email, then submit your application.',
      style: Theme.of(context).textTheme.bodyMedium,
    ),
    const SizedBox(height: AppSpacing.md),
    _StepIndicator(step: state.step),
    const SizedBox(height: AppSpacing.lg),
    Text(switch (state.step) {
      0 => '1. Account',
      1 => '2. Company',
      _ => '3. Documents and terms',
    }, style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: AppSpacing.md),
    if (state.notice != null) ...[
      AppAlert(message: state.notice!, type: AppAlertType.error),
      const SizedBox(height: AppSpacing.md),
    ],
    ...switch (state.step) {
      0 => _accountFields(state),
      1 => _companyFields(state),
      _ => _documentsFields(state),
    },
  ];

  List<Widget> _accountFields(RegisterOperatorState state) => [
    CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: state.resumeExistingIdentity,
      onChanged: state.isBusy
          ? null
          : (value) => context
                .read<RegisterOperatorCubit>()
                .setResumeExistingIdentity(value ?? false),
      title: const Text('Continue an unfinished registration'),
      subtitle: const Text(
        'Use the same email and password. You will need to re-enter the form and choose the documents again.',
      ),
    ),
    const SizedBox(height: AppSpacing.sm),
    _textField(
      state,
      'email',
      'Email address',
      keyboardType: TextInputType.emailAddress,
    ),
    const SizedBox(height: AppSpacing.md),
    _passwordField(
      state,
      'password',
      'Password',
      helperText: '8–72 characters: uppercase, lowercase, number and symbol.',
    ),
    const SizedBox(height: AppSpacing.md),
    _passwordField(state, 'confirmPassword', 'Confirm password'),
  ];

  List<Widget> _companyFields(RegisterOperatorState state) => [
    _textField(state, 'companyName', 'Company name'),
    const SizedBox(height: AppSpacing.md),
    _textField(
      state,
      'businessLicenseNo',
      'Business licence number',
      helperText: 'e.g. 79-0123/2026/TCDL-GPLHQT or 01-0456/2025/SDL-GPLHND',
    ),
    const SizedBox(height: AppSpacing.md),
    _textField(
      state,
      'taxCode',
      'Tax code',
      helperText: '10 digits, or 10 digits-3 digits for a branch',
    ),
    const SizedBox(height: AppSpacing.md),
    _textField(state, 'contactPerson', 'Contact person'),
    const SizedBox(height: AppSpacing.md),
    _textField(state, 'businessAddress', 'Business address (optional)'),
    const SizedBox(height: AppSpacing.md),
    _textField(
      state,
      'contactPhone',
      'Contact phone (optional)',
      keyboardType: TextInputType.phone,
    ),
  ];

  List<Widget> _documentsFields(RegisterOperatorState state) => [
    const Text('PDF, JPG or PNG; maximum 5 MB per file.'),
    const SizedBox(height: AppSpacing.md),
    OutlinedButton.icon(
      onPressed: state.isBusy ? null : _pickLicence,
      icon: const Icon(Icons.upload_file_outlined),
      label: const Text('Choose business licence'),
    ),
    if (state.businessLicence != null)
      Text(state.businessLicence!.fileName, overflow: TextOverflow.ellipsis),
    _inlineError(state, 'businessLicenseDocument'),
    const SizedBox(height: AppSpacing.md),
    OutlinedButton.icon(
      onPressed: state.isBusy ? null : _pickSupporting,
      icon: const Icon(Icons.attach_file_outlined),
      label: const Text('Choose supporting documents (optional, up to 5)'),
    ),
    if (state.supportingDocuments.isNotEmpty)
      ...state.supportingDocuments.map(
        (file) => Text(file.fileName, overflow: TextOverflow.ellipsis),
      ),
    _inlineError(state, 'supportingDocuments'),
    const SizedBox(height: AppSpacing.md),
    CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: state.acceptedTerms,
      onChanged: state.isBusy
          ? null
          : (accepted) => context
                .read<RegisterOperatorCubit>()
                .setAcceptedTerms(accepted ?? false),
      title: const Text(
        'I accept the Terms of Service, Privacy Policy and Partner Agreement.',
      ),
    ),
    _inlineError(state, 'acceptTerms'),
    const SizedBox(height: AppSpacing.sm),
    const AppAlert(
      message:
          'Your application is sent only after you verify the email. After submission it remains Pending Approval until an administrator reviews it.',
    ),
  ];

  Widget _textField(
    RegisterOperatorState state,
    String key,
    String label, {
    TextInputType? keyboardType,
    String? helperText,
  }) => AppTextField(
    controller: _controllers[key],
    label: label,
    keyboardType: keyboardType,
    helperText: helperText,
    enabled: !state.isBusy,
    errorText: state.errors[key],
    textInputAction: TextInputAction.next,
    onChanged: (value) {
      // Vietnamese IMEs may replace their composing range on the next keystroke.
      // Clearing a validation error would rebuild this field mid-composition.
      final composing = _controllers[key]!.value.composing;
      if (composing.isValid && !composing.isCollapsed) return;
      context.read<RegisterOperatorCubit>().updateField(key, value);
    },
  );

  void _commitVisibleFields() {
    final cubit = context.read<RegisterOperatorCubit>();
    final keys = cubit.state.step == 0
        ? const ['email', 'password', 'confirmPassword']
        : const [
            'companyName',
            'businessLicenseNo',
            'taxCode',
            'contactPerson',
            'businessAddress',
            'contactPhone',
          ];
    for (final key in keys) {
      final value = _controllers[key]!.text;
      if (cubit.state.values[key] != value) cubit.updateField(key, value);
    }
  }

  void _nextStep() {
    _commitVisibleFields();
    context.read<RegisterOperatorCubit>().next();
  }

  void _previousStep() {
    _commitVisibleFields();
    context.read<RegisterOperatorCubit>().back();
  }

  Widget _passwordField(
    RegisterOperatorState state,
    String key,
    String label, {
    String? helperText,
  }) => AppPasswordField(
    controller: _controllers[key]!,
    label: label,
    enabled: !state.isBusy,
    errorText: state.errors[key],
    helperText: helperText,
    onChanged: (value) =>
        context.read<RegisterOperatorCubit>().updateField(key, value),
  );

  Widget _inlineError(RegisterOperatorState state, String key) {
    final message = state.errors[key];
    if (message == null) return const SizedBox.shrink();
    return Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }

  Widget _wizardFooter(RegisterOperatorState state) {
    final cubit = context.read<RegisterOperatorCubit>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.isBusy) const Center(child: CircularProgressIndicator()),
        Row(
          children: [
            if (state.step > 0) ...[
              OutlinedButton(
                onPressed: state.isBusy ? null : _previousStep,
                child: const Text('Back'),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: FilledButton(
                onPressed: state.isBusy
                    ? null
                    : state.step == 2
                    ? cubit.submit
                    : _nextStep,
                child: Text(state.step == 2 ? 'Verify email first' : 'Next'),
              ),
            ),
          ],
        ),
        if (state.step == 0)
          TextButton(
            onPressed: state.isBusy ? null : () => context.go(AppRoutes.login),
            child: const Text('Back to Sign In'),
          ),
        if (state.step == 0)
          TextButton(
            onPressed: state.isBusy
                ? null
                : () => context.push(AppRoutes.operatorEmailRecovery),
            child: const Text('Already submitted? Finish email verification'),
          ),
      ],
    );
  }

  List<Widget> _uncertainContent(RegisterOperatorState state) => [
    const AppAlert(
      title: 'Registration status unknown',
      message:
          'The server may already have saved your application. Keep this Firebase account and do not submit a new registration automatically.',
      type: AppAlertType.warning,
    ),
    if (state.notice != null) ...[
      const SizedBox(height: AppSpacing.md),
      AppAlert(message: state.notice!, type: AppAlertType.info),
    ],
  ];

  Widget _uncertainFooter(RegisterOperatorState state) {
    final cubit = context.read<RegisterOperatorCubit>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.isBusy) const Center(child: CircularProgressIndicator()),
        if (state.canRetryOriginal)
          FilledButton(
            onPressed: state.isBusy ? null : cubit.retryUnknownOutcome,
            child: const Text('Retry original request with same account'),
          ),
        TextButton(
          onPressed: state.isBusy
              ? null
              : () => context.push(
                  AppRoutes.operatorEmailRecovery,
                  extra: state.values['email'],
                ),
          child: const Text('Already submitted? Finish email confirmation'),
        ),
        TextButton(
          onPressed: state.isBusy ? null : () => context.go(AppRoutes.login),
          child: const Text('Sign In'),
        ),
      ],
    );
  }

  List<Widget> _verificationContent(RegisterOperatorState state) => [
    const SizedBox(height: AppSpacing.xl),
    Icon(
      Icons.mark_email_unread_outlined,
      size: 64,
      color: Theme.of(context).colorScheme.primary,
    ),
    const SizedBox(height: AppSpacing.md),
    Text(
      state.alreadyVerified ? 'Email verified' : 'Check your email',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineSmall,
    ),
    const SizedBox(height: AppSpacing.sm),
    Text(
      state.alreadyVerified
          ? 'Your email is verified. Review your details and submit the application below.'
          : 'Open the verification link, then return here to submit your application. No application has been sent yet.',
      textAlign: TextAlign.center,
    ),
    if (_maskedEmail(state.values['email']) case final maskedEmail?) ...[
      const SizedBox(height: AppSpacing.md),
      Center(
        child: Chip(
          avatar: const Icon(Icons.mail_outline, size: 18),
          label: Text(maskedEmail),
        ),
      ),
    ],
    const SizedBox(height: AppSpacing.lg),
    const AppAlert(
      title: 'Application not submitted yet',
      message:
          'Keep this app open until you submit. If you leave, continue with the same email and password and select the documents again.',
      type: AppAlertType.info,
    ),
    if (state.notice != null) ...[
      const SizedBox(height: AppSpacing.md),
      AppAlert(
        message: state.notice!,
        type:
            state.notice ==
                    'Verification email sent. Please check your inbox.' ||
                state.notice?.startsWith('Your email is already verified') ==
                    true
            ? AppAlertType.info
            : AppAlertType.warning,
      ),
    ],
  ];

  Widget _verificationFooter(RegisterOperatorState state) {
    final cubit = context.read<RegisterOperatorCubit>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.isBusy) const Center(child: CircularProgressIndicator()),
        if (!state.alreadyVerified)
          OutlinedButton(
            onPressed: state.isBusy || _resendSecondsLeft > 0
                ? null
                : _resendVerificationEmail,
            child: Text(
              _resendSecondsLeft > 0
                  ? 'Resend in ${_resendSecondsLeft}s'
                  : 'Resend verification email',
            ),
          ),
        FilledButton(
          onPressed: state.isBusy ? null : cubit.confirmVerifiedEmail,
          child: Text(
            state.alreadyVerified
                ? 'Submit application'
                : 'I verified my email — submit application',
          ),
        ),
        TextButton(
          onPressed: state.isBusy ? null : () => context.go(AppRoutes.login),
          child: const Text('Sign In'),
        ),
      ],
    );
  }

  List<Widget> _submittedContent(RegisterOperatorState state) => [
    const SizedBox(height: AppSpacing.xl),
    Icon(
      Icons.task_alt_outlined,
      size: 64,
      color: Theme.of(context).colorScheme.primary,
    ),
    const SizedBox(height: AppSpacing.md),
    Text(
      'Application submitted',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineSmall,
    ),
    const SizedBox(height: AppSpacing.md),
    const AppAlert(
      title: 'Pending Approval',
      message:
          'An administrator must review your application before you can publish tours or receive bookings.',
      type: AppAlertType.success,
    ),
    if (state.notice != null) ...[
      const SizedBox(height: AppSpacing.md),
      AppAlert(message: state.notice!, type: AppAlertType.warning),
    ],
  ];

  Widget _submittedFooter(RegisterOperatorState state) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (state.outcome?.verificationSynced == false)
        TextButton(
          onPressed: () => context.push(
            AppRoutes.operatorEmailRecovery,
            extra: state.values['email'],
          ),
          child: const Text('Finish email confirmation'),
        ),
      TextButton(
        onPressed: () => context.go(AppRoutes.login),
        child: const Text('Sign In'),
      ),
    ],
  );

  String? _maskedEmail(String? email) {
    if (email == null) return null;
    final separator = email.indexOf('@');
    if (separator <= 0 || separator == email.length - 1) return null;
    return '${email[0]}***${email.substring(separator)}';
  }

  Future<void> _resendVerificationEmail() async {
    await context.read<RegisterOperatorCubit>().resendEmail();
    if (!mounted) return;
    if (context.read<RegisterOperatorCubit>().state.notice !=
        'Verification email sent. Please check your inbox.') {
      return;
    }
    _resendTimer?.cancel();
    setState(() => _resendSecondsLeft = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSecondsLeft <= 1) {
        timer.cancel();
        setState(() => _resendSecondsLeft = 0);
      } else {
        setState(() => _resendSecondsLeft--);
      }
    });
  }

  Future<void> _pickLicence() async {
    try {
      final files = await widget.documentPicker.pick(multiple: false);
      if (!mounted || files == null || files.isEmpty) return;
      context.read<RegisterOperatorCubit>().setBusinessLicence(files.first);
    } catch (_) {
      _showPickerError();
    }
  }

  Future<void> _pickSupporting() async {
    try {
      final files = await widget.documentPicker.pick(multiple: true);
      if (!mounted || files == null) return;
      context.read<RegisterOperatorCubit>().setSupportingDocuments(files);
    } catch (_) {
      _showPickerError();
    }
  }

  void _showPickerError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not read the selected file. Please try again.'),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) => Row(
    children: List.generate(
      3,
      (index) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
          child: Semantics(
            label:
                'Step ${index + 1} of 3: ${['Account', 'Company', 'Documents'][index]}${index == step ? ', current' : ''}',
            child: LinearProgressIndicator(
              value: index <= step ? 1 : 0,
              minHeight: 6,
              borderRadius: BorderRadius.circular(AppSpacing.xs),
            ),
          ),
        ),
      ),
    ),
  );
}
