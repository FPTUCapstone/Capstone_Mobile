import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/booking/domain/entities/booking_quote.dart';
import 'package:trip_mate_mobile/features/booking/domain/entities/participant_type.dart';
import 'package:trip_mate_mobile/features/booking/presentation/cubit/book_tour_cubit.dart';
import 'package:trip_mate_mobile/features/booking/presentation/cubit/book_tour_state.dart';

String _formatMoney(int amount, String currency) {
  final text = amount.toString();
  final buffer = StringBuffer();
  final length = text.length;
  for (var i = 0; i < length; i++) {
    if (i > 0 && (length - i) % 3 == 0) buffer.write('.');
    buffer.write(text[i]);
  }
  final normalized = currency.trim().toUpperCase();
  if (normalized == 'VND') {
    buffer.write('₫');
  } else if (normalized.isNotEmpty) {
    buffer.write(' $normalized');
  }
  return buffer.toString();
}

String _formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${pad(local.day)}/${pad(local.month)}/${local.year} ${pad(local.hour)}:${pad(local.minute)}';
}

/// UC-27 Book Tour. Ends at a confirmed PendingPayment booking; "Pay now" is the only
/// handoff to UC-28 and this page never selects a payment method or starts a gateway call.
final class BookTourPage extends StatelessWidget {
  const BookTourPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Book Tour',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F1B2D),
        elevation: 0.5,
        centerTitle: true,
      ),
      body: BlocConsumer<BookTourCubit, BookTourState>(
        listenWhen: (previous, current) =>
            previous.submitStatus != current.submitStatus &&
            current.submitStatus == SubmitStatus.failure,
        listener: (context, state) {
          final failure = state.submitFailure;
          if (failure != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: Text(failure.message)),
                  ],
                ),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.submitStatus == SubmitStatus.success &&
              state.createdBooking != null) {
            return _BookingConfirmedView(booking: state.createdBooking!);
          }
          return _BookingFormView(state: state);
        },
      ),
    );
  }
}

final class _BookingFormView extends StatefulWidget {
  const _BookingFormView({required this.state});
  final BookTourState state;

  @override
  State<_BookingFormView> createState() => _BookingFormViewState();
}

final class _BookingFormViewState extends State<_BookingFormView> {
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _voucherController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // The profile request can finish before this form is first inserted into
    // the tree, in which case didUpdateWidget will not run.
    _fillIfBlank(_fullNameController, widget.state.leadFullName);
    _fillIfBlank(_phoneController, widget.state.leadPhone);
    _fillIfBlank(_emailController, widget.state.leadEmail);
  }

  @override
  void didUpdateWidget(covariant _BookingFormView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fillIfBlank(_fullNameController, widget.state.leadFullName);
    _fillIfBlank(_phoneController, widget.state.leadPhone);
    _fillIfBlank(_emailController, widget.state.leadEmail);
  }

  static void _fillIfBlank(TextEditingController controller, String value) {
    if (controller.text.trim().isNotEmpty || value.trim().isEmpty) return;
    controller.value = controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _voucherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final cubit = context.read<BookTourCubit>();
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Step & Assurance Banner ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEAF1FE), Color(0xFFF0FDF4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD6E4FC)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBright.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.event_available_rounded,
                    color: AppColors.primaryBright,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Direct Operator Reservation',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F1B2D),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Real-time departure booking with live price quote.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Section 1: Travelers Count ──────────────────────────────────
          _CardContainer(
            title: 'Travelers',
            icon: Icons.people_alt_outlined,
            subtitle: 'Choose number of seats for this trip',
            child: Column(
              children: [
                _ParticipantCounter(
                  label: 'Adults',
                  subtitle: 'Age 12 and above',
                  icon: Icons.person_outline,
                  value: state.participantCounts.adult,
                  minValue: 1,
                  onChanged: (value) => cubit.updateParticipantCounts(
                    state.participantCounts.copyWith(adult: value),
                  ),
                ),
                const Divider(color: Color(0xFFF1F5F9), height: 16),
                _ParticipantCounter(
                  label: 'Children',
                  subtitle: 'Age 2 to 11',
                  icon: Icons.child_care_outlined,
                  value: state.participantCounts.child,
                  onChanged: (value) => cubit.updateParticipantCounts(
                    state.participantCounts.copyWith(child: value),
                  ),
                ),
                const Divider(color: Color(0xFFF1F5F9), height: 16),
                _ParticipantCounter(
                  label: 'Infants',
                  subtitle: 'Under 2 years old',
                  icon: Icons.baby_changing_station_outlined,
                  value: state.participantCounts.infant,
                  onChanged: (value) => cubit.updateParticipantCounts(
                    state.participantCounts.copyWith(infant: value),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Section 2: Lead Traveler Contact ───────────────────────────
          _CardContainer(
            title: 'Lead Traveler',
            icon: Icons.badge_outlined,
            subtitle: 'Booking confirmation & tickets will be sent here',
            child: Column(
              children: [
                TextField(
                  key: const Key('booking-lead-full-name'),
                  controller: _fullNameController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Full name *',
                    hintText: 'e.g. Nguyen Van A',
                    prefixIcon: const Icon(
                      Icons.person_outline_rounded,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  onChanged: cubit.updateLeadFullName,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  key: const Key('booking-lead-phone'),
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Phone number *',
                    hintText: 'e.g. 0912345678',
                    prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  onChanged: cubit.updateLeadPhone,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  key: const Key('booking-lead-email'),
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'e.g. traveler@example.com',
                    prefixIcon: const Icon(
                      Icons.mail_outline_rounded,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  onChanged: cubit.updateLeadEmail,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Section 3: Voucher Code ─────────────────────────────────────
          _CardContainer(
            title: 'Promo / Voucher Code',
            icon: Icons.local_offer_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _voucherController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Voucher code',
                          hintText: 'ENTER CODE',
                          prefixIcon: const Icon(
                            Icons.discount_outlined,
                            size: 20,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    FilledButton(
                      onPressed: () => cubit.applyVoucherCode(
                        _voucherController.text.trim(),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(80, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Apply',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                if (state.quote != null && state.quote!.discountAmount > 0) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Applied code: ${state.quote!.appliedVoucherCode ?? ''} '
                          '(-${_formatMoney(state.quote!.discountAmount, state.quote!.currency)})',
                          style: const TextStyle(
                            color: Color(0xFF065F46),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Section 4: Live Server Quote ────────────────────────────────
          _QuoteSummary(state: state),
          const SizedBox(height: AppSpacing.md),

          // ── Terms & Agreement ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: CheckboxListTile(
                value: state.agreedToTerms,
                onChanged: (value) => cubit.setAgreedToTerms(value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                activeColor: AppColors.primary,
                title: Text(
                  'I confirm the information is accurate and agree to the booking terms and cancellation policy.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF334155),
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Submit Primary Action ────────────────────────────────────────
          FilledButton(
            onPressed: state.canSubmit ? cubit.submit : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: const Color(0xFFCBD5E1),
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: state.canSubmit ? 2 : 0,
            ),
            child: state.submitStatus == SubmitStatus.submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Confirm booking',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.verified_user_outlined,
                size: 14,
                color: AppColors.muted,
              ),
              const SizedBox(width: 4),
              Text(
                'Your booking will be created as Pending Payment and held safely.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

/// Unified Card Container for consistent card-based UI.
final class _CardContainer extends StatelessWidget {
  const _CardContainer({
    required this.title,
    required this.child,
    this.icon,
    this.subtitle,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1FE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F1B2D),
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

final class _ParticipantCounter extends StatelessWidget {
  const _ParticipantCounter({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.minValue = 0,
  });

  final String label;
  final String? subtitle;
  final IconData? icon;
  final int value;
  final int minValue;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: const Color(0xFF475569)),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Color(0xFF0F1B2D),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: value > minValue ? () => onChanged(value - 1) : null,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.remove_rounded,
                      size: 20,
                      color: value > minValue
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 32),
                  alignment: Alignment.center,
                  child: Text(
                    '$value',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF0F1B2D),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => onChanged(value + 1),
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.add_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders the server's quote verbatim (BR-63): no amount here is computed by this widget.
final class _QuoteSummary extends StatelessWidget {
  const _QuoteSummary({required this.state});
  final BookTourState state;

  @override
  Widget build(BuildContext context) {
    if (state.quoteStatus == QuoteStatus.idle) return const SizedBox.shrink();
    if (state.quoteStatus == QuoteStatus.failure) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                state.quoteFailure?.message ?? 'Unable to load pricing.',
                style: const TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final quote = state.quote;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF1FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Price Breakdown',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F1B2D),
                    ),
                  ),
                ],
              ),
              if (quote != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.airline_seat_recline_normal_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${quote.remainingSlots} slot(s) left',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (state.quoteStatus == QuoteStatus.loading && quote == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (quote != null) ...[
            for (final line in quote.priceBreakdown)
              if (line.quantity > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${line.quantity} × ${_participantLabel(line.participantType)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Color(0xFF0F1B2D),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_formatMoney(line.unitPrice, quote.currency)} each',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatMoney(line.lineAmount, quote.currency),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF0F1B2D),
                        ),
                      ),
                    ],
                  ),
                ),
            if (quote.discountAmount > 0) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.discount_outlined,
                          size: 16,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Discount (${quote.appliedVoucherCode ?? ''})',
                          style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '-${_formatMoney(quote.discountAmount, quote.currency)}',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: Color(0xFFF1F5F9), height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    Text(
                      'All taxes & fees included',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.muted.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
                Text(
                  _formatMoney(quote.totalAmount, quote.currency),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _participantLabel(ParticipantType type) => switch (type) {
    ParticipantType.adult => 'Adult',
    ParticipantType.child => 'Child',
    ParticipantType.infant => 'Infant',
  };
}

final class _BookingConfirmedView extends StatelessWidget {
  const _BookingConfirmedView({required this.booking});
  final TourBooking booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        children: [
          // ── Celebration Icon ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFA7F3D0), width: 3),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 64,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Booking Confirmed!',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F1B2D),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your reservation is reserved and held in Pending Payment.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Ticket / Summary Card ────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                // Ticket Header: Booking Code
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'BOOKING CODE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            booking.bookingCode,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        tooltip: 'Copy Code',
                        icon: const Icon(
                          Icons.copy_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: booking.bookingCode),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Booking code copied to clipboard'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Ticket Body details
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      _DetailRow(
                        label: 'Status',
                        valueWidget: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFCD34D)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.hourglass_top_rounded,
                                size: 14,
                                color: Color(0xFFD97706),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                booking.status,
                                style: const TextStyle(
                                  color: Color(0xFF92400E),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DetailRow(
                        label: 'Total Amount',
                        valueText: _formatMoney(
                          booking.totalAmount,
                          booking.currency,
                        ),
                        isProminent: true,
                      ),
                      const SizedBox(height: 12),
                      _DetailRow(
                        label: 'Pay Before',
                        valueWidget: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              size: 14,
                              color: Color(0xFFE02D4D),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDateTime(booking.paymentExpiresAt),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Color(0xFFE02D4D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Payment Callout Notice ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'To complete your booking, please submit payment before the expiration deadline above.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF92400E),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Actions ──────────────────────────────────────────────────────
          FilledButton.icon(
            onPressed: () {
              context.push(
                AppRoutes.payment(
                  booking.bookingId,
                  bookingCode: booking.bookingCode,
                  amount: booking.totalAmount,
                  currency: booking.currency,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.payment_rounded, size: 20),
            label: const Text(
              'Pay now',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF475569),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Back to tours',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

final class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    this.valueText,
    this.valueWidget,
    this.isProminent = false,
  });

  final String label;
  final String? valueText;
  final Widget? valueWidget;
  final bool isProminent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        if (valueWidget != null)
          valueWidget!
        else
          Text(
            valueText ?? '',
            style: TextStyle(
              fontSize: isProminent ? 17 : 14,
              fontWeight: isProminent ? FontWeight.w800 : FontWeight.w600,
              color: isProminent ? AppColors.primary : const Color(0xFF0F1B2D),
            ),
          ),
      ],
    );
  }
}
