import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/tripmate_visual_tokens.dart';
import 'package:trip_mate_mobile/core/utils/validators.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
import 'package:trip_mate_mobile/features/auth/presentation/widgets/operator_review_process.dart';
import 'package:trip_mate_mobile/shared/widgets/anchored_action_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';
import 'package:trip_mate_mobile/shared/widgets/section_card.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

/// UC-02 Tour Operator Registration (Screen #40).
///
/// The Backend does not yet expose an operator registration or document-upload
/// capability, so this screen presents the canonical Report 3 form for review
/// and client-side validation only. Nothing is submitted, uploaded or stored,
/// and no application state is ever produced locally.
class OperatorRegistrationPage extends StatefulWidget {
  const OperatorRegistrationPage({super.key});

  @override
  State<OperatorRegistrationPage> createState() =>
      _OperatorRegistrationPageState();
}

class _OperatorRegistrationPageState extends State<OperatorRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _companyController = TextEditingController();
  final _licenceNumberController = TextEditingController();
  final _taxController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  var _agreementAccepted = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _companyController.dispose();
    _licenceNumberController.dispose();
    _taxController.dispose();
    _addressController.dispose();
    _contactPersonController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TripMateVisualTheme(
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return Scaffold(
            appBar: AppBar(title: const Text('Business Account')),
            bottomNavigationBar: const AnchoredActionBar(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CapabilityNote(
                    message:
                        'Operator application submission is not available in '
                        'the mobile app yet.',
                  ),
                  SizedBox(height: AppSpacing.xs),
                  AppButton(label: 'Submit application', onPressed: null),
                ],
              ),
            ),
            body: AppPageScaffold(
              showAppBar: false,
              content: [
                SegmentedButton<UserRole>(
                  segments: const [
                    ButtonSegment(
                      value: UserRole.traveler,
                      label: Text('Traveler'),
                    ),
                    ButtonSegment(
                      value: UserRole.tourOperator,
                      label: Text('Tour Operator'),
                    ),
                  ],
                  selected: const {UserRole.tourOperator},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    if (selection.first == UserRole.traveler) {
                      context.go(AppRoutes.travelerRegistration);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                _FormCard(
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tour Operator registration',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          'Your application is reviewed by an Administrator. '
                          'You cannot publish tours or receive bookings until '
                          'it is approved.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          child: Divider(height: 1),
                        ),
                        const SectionHeader(
                          number: 1,
                          title: 'Account information',
                        ),
                        _LabeledField(
                          label: 'Email address',
                          icon: Icons.mail_outline,
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: Validators.email,
                        ),
                        _LabeledField(
                          label: 'Password',
                          icon: Icons.lock_outline,
                          controller: _passwordController,
                          isPassword: true,
                          validator: Validators.password,
                        ),
                        _LabeledField(
                          label: 'Confirm password',
                          icon: Icons.lock_reset_outlined,
                          controller: _confirmController,
                          isPassword: true,
                          validator: _confirmPasswordValidator,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const SectionHeader(
                          number: 2,
                          title: 'Company & legal information',
                        ),
                        _LabeledField(
                          label: 'Company name',
                          icon: Icons.apartment_outlined,
                          controller: _companyController,
                          textCapitalization: TextCapitalization.words,
                          validator: (value) => Validators.requiredField(
                            value,
                            fieldName: 'Company name',
                          ),
                        ),
                        _LabeledField(
                          label: 'Business licence number',
                          icon: Icons.badge_outlined,
                          controller: _licenceNumberController,
                          validator: (value) => Validators.requiredField(
                            value,
                            fieldName: 'Business licence number',
                          ),
                        ),
                        _LabeledField(
                          label: 'Tax code',
                          icon: Icons.receipt_long_outlined,
                          controller: _taxController,
                          validator: (value) => Validators.requiredField(
                            value,
                            fieldName: 'Tax code',
                          ),
                        ),
                        _LabeledField(
                          label: 'Business address',
                          icon: Icons.location_on_outlined,
                          controller: _addressController,
                          maxLines: 2,
                          textCapitalization: TextCapitalization.sentences,
                          validator: (value) => Validators.requiredField(
                            value,
                            fieldName: 'Business address',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const SectionHeader(number: 3, title: 'Contact person'),
                        _LabeledField(
                          label: 'Contact person',
                          icon: Icons.person_outline,
                          controller: _contactPersonController,
                          textCapitalization: TextCapitalization.words,
                          validator: (value) => Validators.requiredField(
                            value,
                            fieldName: 'Contact person',
                          ),
                        ),
                        _LabeledField(
                          label: 'Contact phone number',
                          icon: Icons.phone_outlined,
                          controller: _contactPhoneController,
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            final requiredError = Validators.requiredField(
                              value,
                              fieldName: 'Contact phone number',
                            );
                            return requiredError ?? Validators.phone(value);
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const SectionHeader(
                          number: 4,
                          title: 'Business documents',
                        ),
                        const _UnavailableDocumentZone(
                          title: 'Business licence document',
                          requirement: 'Required',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const _UnavailableDocumentZone(
                          title: 'Supporting documents',
                          requirement: 'Where applicable',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _agreementAccepted,
                          onChanged: (value) => setState(
                            () => _agreementAccepted = value ?? false,
                          ),
                          title: Text(
                            'I accept the Terms of Service, the Privacy Policy '
                            'and the Partner Agreement.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const OperatorReviewProcess(),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () => context.go(AppRoutes.login),
                  child: const Text('Back to Sign In'),
                ),
                TextButton(
                  onPressed: () => context.go(AppRoutes.travelerRegistration),
                  child: const Text('Create traveler account instead'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String? _confirmPasswordValidator(String? value) {
    final requiredError = Validators.requiredField(
      value,
      fieldName: 'Confirm password',
    );
    if (requiredError != null) {
      return requiredError;
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match. Please re-enter.';
    }
    return null;
  }
}

/// The white, rounded form surface from the Stitch registration design.
class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const radius = BorderRadius.all(
      Radius.circular(TripMateVisualTokens.cardRadius),
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: radius,
        boxShadow: TripMateVisualTokens.cardShadow,
      ),
      // A Material surface so the agreement tile can draw its ink.
      child: Material(
        color: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: child,
        ),
      ),
    );
  }
}

/// A required form field in the Stitch style: a label with a required marker
/// above a 48px input with a leading icon.
class _LabeledField extends StatefulWidget {
  const _LabeledField({
    required this.label,
    required this.icon,
    required this.controller,
    required this.validator,
    this.isPassword = false,
    this.keyboardType,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final IconData icon;
  final bool isPassword;
  final TextInputType? keyboardType;
  final String label;
  final int maxLines;
  final TextCapitalization textCapitalization;
  final FormFieldValidator<String> validator;

  @override
  State<_LabeledField> createState() => _LabeledFieldState();
}

class _LabeledFieldState extends State<_LabeledField> {
  var _obscured = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(widget.label, isRequired: true),
          TextFormField(
            key: ValueKey('operator-field:${widget.label}'),
            controller: widget.controller,
            keyboardType: widget.keyboardType,
            maxLines: widget.isPassword ? 1 : widget.maxLines,
            minLines: 1,
            obscureText: widget.isPassword && _obscured,
            textCapitalization: widget.textCapitalization,
            validator: widget.validator,
            decoration: InputDecoration(
              // Stitch inputs sit on the page surface inside the white card.
              fillColor: Theme.of(context).colorScheme.surface,
              prefixIcon: Icon(widget.icon, size: 20),
              suffixIcon: widget.isPassword
                  ? IconButton(
                      onPressed: () => setState(() => _obscured = !_obscured),
                      tooltip: _obscured ? 'Show password' : 'Hide password',
                      icon: Icon(
                        _obscured
                            ? Icons.visibility_outlined
                            : Icons.visibility_off,
                        size: 20,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// The Stitch document drop zone, shown in a neutral unavailable state: the
/// upload capability does not exist yet, so there is no picker, no file and no
/// uploaded or failed state.
class _UnavailableDocumentZone extends StatelessWidget {
  const _UnavailableDocumentZone({
    required this.title,
    required this.requirement,
  });

  final String requirement;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return CustomPaint(
      painter: _DashedBorderPainter(color: scheme.outline),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: 44,
                child: Icon(
                  Icons.cloud_off_outlined,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              requirement,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              "Document upload isn't available in the app yet.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const StatusBadge(label: 'Unavailable'),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(TripMateVisualTokens.cardRadius),
        ),
      );
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
