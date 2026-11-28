import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/features/booking/domain/entities/booking_quote.dart';
import 'package:trip_mate_mobile/features/booking/domain/entities/participant_type.dart';
import 'package:trip_mate_mobile/features/booking/presentation/booking_contact_validation.dart';
import 'package:trip_mate_mobile/features/booking/presentation/cubit/book_tour_cubit.dart';
import 'package:trip_mate_mobile/features/booking/presentation/cubit/book_tour_state.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_coastal_app_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/app_section_card.dart';

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
    final c = context.tmColors;
    return Scaffold(
      backgroundColor: c.canvas,
      appBar: const AppCoastalAppBar(title: 'Đặt tour', centerTitle: true),
      body: BlocConsumer<BookTourCubit, BookTourState>(
        listenWhen: (previous, current) =>
            previous.submitStatus != current.submitStatus &&
            current.submitStatus == SubmitStatus.failure,
        listener: (context, state) {
          final failure = state.submitFailure;
          if (failure != null) {
            final colors = context.tmColors;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.error_outline, color: colors.textOnBrand),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: Text(failure.message)),
                  ],
                ),
                backgroundColor: colors.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(TripMateRadius.sm),
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
  bool _showContactErrors = false;
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

  InputDecoration _inputDecoration(
    TripMateColors c, {
    required String labelText,
    required String hintText,
    required IconData icon,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: labelText,
      errorText: errorText,
      hintText: hintText,
      prefixIcon: Icon(icon, size: 20, color: c.textSecondary),
      filled: true,
      fillColor: c.canvas,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TripMateRadius.sm),
        borderSide: BorderSide(color: c.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TripMateRadius.sm),
        borderSide: BorderSide(color: c.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TripMateRadius.sm),
        borderSide: BorderSide(color: c.brandTeal, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final state = widget.state;
    final cubit = context.read<BookTourCubit>();
    final theme = Theme.of(context);

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Step & Assurance Banner ──────────────────────────────────────
          AppCard(
            backgroundColor: c.tealSoftContainer,
            borderColor: c.borderSubtle,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.brandTeal.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.event_available_rounded,
                    color: c.brandTeal,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đặt trực tiếp với nhà điều hành',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Xác nhận giữ chỗ và báo giá trực tiếp theo thời gian thực.',
                        style: theme.textTheme.bodySmall?.copyWith(
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

          // ── Section 1: Travelers Count ──────────────────────────────────
          AppSectionCard(
            title: 'Số lượng khách',
            icon: Icons.people_alt_outlined,
            subtitle: 'Chọn số lượng chỗ cho chuyến đi này',
            child: Column(
              children: [
                _ParticipantCounter(
                  label: 'Người lớn',
                  subtitle: 'Từ 12 tuổi trở lên',
                  icon: Icons.person_outline,
                  value: state.participantCounts.adult,
                  minValue: 1,
                  onChanged: (value) => cubit.updateParticipantCounts(
                    state.participantCounts.copyWith(adult: value),
                  ),
                ),
                Divider(color: c.borderSubtle, height: 16),
                _ParticipantCounter(
                  label: 'Trẻ em',
                  subtitle: 'Từ 2 đến 11 tuổi',
                  icon: Icons.child_care_outlined,
                  value: state.participantCounts.child,
                  onChanged: (value) => cubit.updateParticipantCounts(
                    state.participantCounts.copyWith(child: value),
                  ),
                ),
                Divider(color: c.borderSubtle, height: 16),
                _ParticipantCounter(
                  label: 'Em bé',
                  subtitle: 'Dưới 2 tuổi',
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
          AppSectionCard(
            title: 'Thông tin người đặt',
            icon: Icons.badge_outlined,
            subtitle: 'Xác nhận đặt tour và vé điện tử sẽ gửi về địa chỉ này',
            child: Column(
              children: [
                TextField(
                  key: const Key('booking-lead-full-name'),
                  controller: _fullNameController,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    c,
                    labelText: 'Họ và tên *',
                    hintText: 'VD: Nguyễn Văn A',
                    icon: Icons.person_outline_rounded,
                    errorText: _showContactErrors
                        ? BookingContactValidation.fullName(state.leadFullName)
                        : null,
                  ),
                  onChanged: cubit.updateLeadFullName,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  key: const Key('booking-lead-phone'),
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    c,
                    labelText: 'Số điện thoại *',
                    hintText: 'VD: 0912345678',
                    icon: Icons.phone_outlined,
                    errorText: _showContactErrors
                        ? BookingContactValidation.phone(state.leadPhone)
                        : null,
                  ),
                  onChanged: cubit.updateLeadPhone,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  key: const Key('booking-lead-email'),
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  decoration: _inputDecoration(
                    c,
                    labelText: 'Email',
                    hintText: 'VD: nguyenvana@example.com',
                    icon: Icons.mail_outline_rounded,
                    errorText: _showContactErrors
                        ? BookingContactValidation.email(state.leadEmail)
                        : null,
                  ),
                  onChanged: cubit.updateLeadEmail,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Section 3: Voucher Code ─────────────────────────────────────
          AppSectionCard(
            title: 'Mã ưu đãi / Voucher',
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
                        decoration: _inputDecoration(
                          c,
                          labelText: 'Nhập mã ưu đãi',
                          hintText: 'NHẬP MÃ',
                          icon: Icons.discount_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    FilledButton(
                      onPressed: () => cubit.applyVoucherCode(
                        _voucherController.text.trim(),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(80, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            TripMateRadius.sm,
                          ),
                        ),
                      ),
                      child: const Text(
                        'Áp dụng',
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
                      color: c.successContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: c.success.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: c.success,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Đã áp dụng mã: ${state.quote!.appliedVoucherCode ?? ''} '
                            '(-${_formatMoney(state.quote!.discountAmount, state.quote!.currency)})',
                            style: TextStyle(
                              color: c.success,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
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
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xxs,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: CheckboxListTile(
                value: state.agreedToTerms,
                onChanged: (value) => cubit.setAgreedToTerms(value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                activeColor: c.brandTeal,
                title: Text(
                  'Tôi xác nhận thông tin trên là chính xác và đồng ý với điều khoản đặt tour cùng chính sách hủy.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: c.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Submit Primary Action ────────────────────────────────────────
          FilledButton(
            onPressed: state.canAttemptSubmit
                ? () {
                    setState(() => _showContactErrors = true);
                    if (state.canSubmit) cubit.submit();
                  }
                : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(TripMateRadius.sm),
              ),
              elevation: 0,
            ),
            child: state.submitStatus == SubmitStatus.submitting
                ? SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: c.textOnBrand,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Xác nhận đặt tour',
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
              Icon(Icons.verified_user_outlined, size: 14, color: c.textMuted),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Đơn đặt tour sẽ được tạo ở trạng thái Chờ thanh toán và giữ chỗ an toàn.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: c.textMuted,
                    fontSize: 11,
                  ),
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
    final c = context.tmColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: c.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: c.textSecondary),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: c.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(color: c.textMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: c.canvas,
              borderRadius: BorderRadius.circular(TripMateRadius.sm),
              border: Border.all(color: c.borderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: value > minValue ? () => onChanged(value - 1) : null,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(TripMateRadius.sm),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.remove_rounded,
                      size: 20,
                      color: value > minValue
                          ? c.textPrimary
                          : c.actionDisabledText,
                    ),
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 32),
                  alignment: Alignment.center,
                  child: Text(
                    '$value',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => onChanged(value + 1),
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(TripMateRadius.sm),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.add_rounded,
                      size: 20,
                      color: c.brandTeal,
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
    final c = context.tmColors;
    if (state.quoteStatus == QuoteStatus.idle) return const SizedBox.shrink();
    if (state.quoteStatus == QuoteStatus.failure) {
      return AppAlert(
        type: AppAlertType.error,
        message: state.quoteFailure?.message ?? 'Không thể tải báo giá.',
      );
    }

    final quote = state.quote;

    return AppSectionCard(
      title: 'Chi tiết giá',
      icon: Icons.receipt_long_outlined,
      trailing: quote != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: c.tealSoftContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.airline_seat_recline_normal_rounded,
                    size: 14,
                    color: c.brandTeal,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${quote.remainingSlots} chỗ trống',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: c.brandTeal,
                    ),
                  ),
                ],
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.quoteStatus == QuoteStatus.loading && quote == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(color: c.brandTeal),
              ),
            )
          else if (quote != null) ...[
            for (final line in quote.priceBreakdown)
              if (line.quantity > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: AppKeyValueRow(
                    label:
                        '${line.quantity} × ${_participantLabel(line.participantType)}',
                    subtitle:
                        '${_formatMoney(line.unitPrice, quote.currency)} / khách',
                    value: _formatMoney(line.lineAmount, quote.currency),
                    isPrice: true,
                  ),
                ),
            if (quote.discountAmount > 0) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.discount_outlined,
                            size: 16,
                            color: c.success,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Giảm giá (${quote.appliedVoucherCode ?? ''})',
                              style: TextStyle(
                                color: c.success,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '-${_formatMoney(quote.discountAmount, quote.currency)}',
                      style: AppTypography.price(c.success, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: c.borderSubtle, height: 1),
            ),
            AppKeyValueRow(
              label: 'Tổng thanh toán',
              subtitle: 'Đã bao gồm thuế và phí',
              value: _formatMoney(quote.totalAmount, quote.currency),
              isPrice: true,
              isProminent: true,
            ),
          ],
        ],
      ),
    );
  }

  static String _participantLabel(ParticipantType type) => switch (type) {
    ParticipantType.adult => 'Người lớn',
    ParticipantType.child => 'Trẻ em',
    ParticipantType.infant => 'Em bé',
  };
}

String _bookingStatusLabel(String status) => switch (status) {
  'PendingPayment' => 'Chờ thanh toán',
  'Confirmed' => 'Đã xác nhận',
  'PendingOperatorConfirmation' => 'Chờ nhà điều hành xác nhận',
  'Cancelled' => 'Đã hủy',
  'Expired' => 'Đã hết hạn',
  _ => status,
};

final class _BookingConfirmedView extends StatelessWidget {
  const _BookingConfirmedView({required this.booking});
  final TourBooking booking;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
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
              color: c.successContainer,
              shape: BoxShape.circle,
              border: Border.all(
                color: c.success.withValues(alpha: 0.35),
                width: 3,
              ),
            ),
            child: Icon(Icons.check_circle_rounded, color: c.success, size: 64),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Đặt tour thành công!',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Đơn đặt tour của bạn đã được tạo và đang chờ thanh toán.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Ticket / Summary Card ────────────────────────────────────────
          AppCard(
            padding: EdgeInsets.zero,
            borderRadius: 18,
            child: Column(
              children: [
                // Ticket Header: Booking Code
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: c.tealSoftContainer,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(17),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MÃ ĐẶT TOUR',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: c.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            booking.bookingCode,
                            style: TextStyle(
                              fontFamily: AppTypography.uiFont,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: c.brandTeal,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        tooltip: 'Sao chép mã',
                        icon: Icon(
                          Icons.copy_rounded,
                          size: 18,
                          color: c.brandTeal,
                        ),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: booking.bookingCode),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã sao chép mã đặt tour'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: c.borderSubtle),

                // Ticket Body details
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      AppKeyValueRow(
                        label: 'Trạng thái',
                        valueWidget: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: c.warningContainer,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: c.warning.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.hourglass_top_rounded,
                                size: 14,
                                color: c.warning,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _bookingStatusLabel(booking.status),
                                style: TextStyle(
                                  color: c.warning,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppKeyValueRow(
                        label: 'Tổng thanh toán',
                        value: _formatMoney(
                          booking.totalAmount,
                          booking.currency,
                        ),
                        isPrice: true,
                        isProminent: true,
                      ),
                      const SizedBox(height: 12),
                      AppKeyValueRow(
                        label: 'Hạn thanh toán',
                        valueWidget: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 14,
                              color: c.error,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDateTime(booking.paymentExpiresAt),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: c.error,
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
          const AppAlert(
            type: AppAlertType.warning,
            message:
                'Để hoàn tất đặt tour, vui lòng thanh toán trước thời hạn hết hạn ở trên.',
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
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(TripMateRadius.sm),
              ),
            ),
            icon: const Icon(Icons.payment_rounded, size: 20),
            label: const Text(
              'Thanh toán ngay',
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
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(TripMateRadius.sm),
              ),
            ),
            child: const Text(
              'Quay lại danh sách tour',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
