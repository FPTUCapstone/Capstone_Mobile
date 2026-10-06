import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/tour_booking/domain/entities/booking_participant.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/cubit/tour_booking_cubit.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/cubit/tour_booking_state.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_detail.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/theme/tour_search_palette.dart';

/// Screen #66 — Tour Booking Page (UC-27 Book Tour).
class TourBookingPage extends StatelessWidget {
  const TourBookingPage({
    required this.tourId,
    this.scheduleId,
    this.initialDetail,
    this.initialSummary,
    this.isDemoMode = false,
    super.key,
  });

  final String tourId;
  final String? scheduleId;
  final TourDetail? initialDetail;
  final TourSummary? initialSummary;
  final bool isDemoMode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TourBookingCubit(
        tourId: tourId,
        initialScheduleId: scheduleId,
        initialDetail: initialDetail,
        initialSummary: initialSummary,
        isDemoMode: isDemoMode,
      )..load(),
      child: _TourBookingView(tourId: tourId),
    );
  }
}

class _TourBookingView extends StatelessWidget {
  const _TourBookingView({required this.tourId});

  final String tourId;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TourBookingCubit, TourBookingState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status &&
          curr.status == TourBookingStatus.bookingCreated &&
          curr.createdBooking != null,
      listener: (context, state) {
        final booking = state.createdBooking!;
        if (state.statusMessage != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                key: const Key('booking-created-snackbar'),
                content: Text(state.statusMessage!),
                backgroundColor: TourSearchPalette.teal,
              ),
            );
        }
        context.push(
          AppRoutes.bookingPayment(booking.bookingId, demo: state.isDemoMode),
          extra: booking,
        );
      },
      builder: (context, state) {
        final cubit = context.read<TourBookingCubit>();
        return Scaffold(
          backgroundColor: TourSearchPalette.background,
          appBar: AppBar(
            title: const Text('Đặt Tour'),
            backgroundColor: Colors.white,
            foregroundColor: TourSearchPalette.navy,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Trở về',
              onPressed: () => _handleBack(context, state),
            ),
          ),
          body: SafeArea(
            child: switch (state.status) {
              TourBookingStatus.initial ||
              TourBookingStatus.loading => const Center(
                child: CircularProgressIndicator(color: TourSearchPalette.teal),
              ),
              TourBookingStatus.error => _BookingErrorView(
                message: state.errorMessage ?? TourBookingState.msg127,
                onRetry: cubit.load,
              ),
              TourBookingStatus.pendingIntegration => _BookingPendingView(
                tourId: tourId,
                detail: state.initialDetail,
                summary: state.initialSummary,
              ),
              TourBookingStatus.ready ||
              TourBookingStatus.submitting ||
              TourBookingStatus.bookingCreated => _BookingFormView(
                state: state,
                cubit: cubit,
              ),
            },
          ),
          bottomNavigationBar:
              (state.status == TourBookingStatus.ready ||
                  state.status == TourBookingStatus.submitting ||
                  state.status == TourBookingStatus.bookingCreated)
              ? _BookingBottomBar(state: state, cubit: cubit)
              : null,
        );
      },
    );
  }

  void _handleBack(BuildContext context, TourBookingState state) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.tourDetail(tourId, demo: state.isDemoMode));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Production Pending Integration View (!isDemoMode)
// ─────────────────────────────────────────────────────────────────────────────

class _BookingPendingView extends StatelessWidget {
  const _BookingPendingView({required this.tourId, this.detail, this.summary});

  final String tourId;
  final TourDetail? detail;
  final TourSummary? summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = detail?.title ?? summary?.title ?? 'Tour #$tourId';
    final operatorName = detail?.operatorName ?? summary?.operatorName;
    final price = detail?.basePrice ?? summary?.basePrice;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            key: const Key('booking-pending-integration-banner'),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.hub_outlined,
                  color: Color(0xFF2563EB),
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đặt tour trực tuyến đang chờ tích hợp máy chủ',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: const Color(0xFF1D4ED8),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Chức năng tạo đơn đặt tour (UC-27), giữ chỗ tạm thời 15 phút và áp dụng mã khuyến mãi sẽ được mở khi dịch vụ Booking Backend hoàn tất tích hợp.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF1E40AF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: TourSearchPalette.cardBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: TourSearchPalette.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (operatorName != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Đơn vị tổ chức: $operatorName',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: TourSearchPalette.muted,
                      ),
                    ),
                  ],
                  if (price != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Giá tham khảo: ${_formatVnd(price)} / khách',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: TourSearchPalette.teal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error View
// ─────────────────────────────────────────────────────────────────────────────

class _BookingErrorView extends StatelessWidget {
  const _BookingErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: Color(0xFFDC2626),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Không thể tải biểu mẫu đặt tour',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: TourSearchPalette.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: TourSearchPalette.muted,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const Key('booking-error-retry-button'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
              style: FilledButton.styleFrom(
                backgroundColor: TourSearchPalette.teal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Booking Form View (UC-27)
// ─────────────────────────────────────────────────────────────────────────────

class _BookingFormView extends StatelessWidget {
  const _BookingFormView({required this.state, required this.cubit});

  final TourBookingState state;
  final TourBookingCubit cubit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (kDebugMode && state.isDemoMode) ...[
            _DemoBookingControlsBar(cubit: cubit),
            const SizedBox(height: AppSpacing.md),
          ],
          if (state.validationMessage != null) ...[
            _ValidationBanner(
              key: const Key('booking-validation-banner'),
              message: state.validationMessage!,
              isError: true,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (state.statusMessage != null) ...[
            _ValidationBanner(
              key: const Key('booking-status-banner'),
              message: state.statusMessage!,
              isError: false,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          _SummaryCard(state: state),
          const SizedBox(height: AppSpacing.md),
          _ParticipantCountCard(state: state, cubit: cubit),
          const SizedBox(height: AppSpacing.md),
          _ParticipantsSection(state: state, cubit: cubit),
          const SizedBox(height: AppSpacing.md),
          _ContactInfoCard(state: state, cubit: cubit),
          const SizedBox(height: AppSpacing.md),
          _VoucherCard(state: state, cubit: cubit),
          const SizedBox(height: AppSpacing.md),
          _PriceBreakdownCard(state: state),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _ValidationBanner extends StatelessWidget {
  const _ValidationBanner({
    required this.message,
    required this.isError,
    super.key,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final bgColor = isError ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5);
    final borderColor = isError
        ? const Color(0xFFFECACA)
        : const Color(0xFFA7F3D0);
    final textColor = isError
        ? const Color(0xFFB91C1C)
        : const Color(0xFF047857);
    final icon = isError ? Icons.error_outline : Icons.check_circle_outline;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.state});

  final TourBookingState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tourName =
        state.initialDetail?.title ??
        state.initialSummary?.title ??
        'Tour #${state.tourId}';
    final departureDate = state.departureAtUtc != null
        ? _formatDate(state.departureAtUtc!)
        : 'Chưa xác định';
    final returnDate = state.returnAtUtc != null
        ? _formatDate(state.returnAtUtc!)
        : 'Chưa xác định';

    return Card(
      key: const Key('booking-summary-card'),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: TourSearchPalette.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tóm tắt hành trình',
              style: theme.textTheme.labelLarge?.copyWith(
                color: TourSearchPalette.teal,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              tourName,
              key: const Key('booking-summary-tour-name'),
              style: theme.textTheme.titleMedium?.copyWith(
                color: TourSearchPalette.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Divider(height: AppSpacing.lg),
            _SummaryRow(
              label: 'Ngày khởi hành (Departure Date)',
              value: departureDate,
              valueKey: const Key('booking-summary-departure-date'),
            ),
            const SizedBox(height: AppSpacing.xs),
            _SummaryRow(
              label: 'Ngày kết thúc (Return Date)',
              value: returnDate,
              valueKey: const Key('booking-summary-return-date'),
            ),
            const SizedBox(height: AppSpacing.xs),
            _SummaryRow(
              label: 'Đơn giá / khách (Price per Participant)',
              value: _formatVnd(state.unitPrice),
              valueKey: const Key('booking-summary-unit-price'),
            ),
            const SizedBox(height: AppSpacing.xs),
            _SummaryRow(
              label: 'Số chỗ còn nhận (Remaining Slots)',
              value: '${state.effectiveRemainingSlots} chỗ',
              valueKey: const Key('booking-summary-remaining-slots'),
              highlightWarning: state.effectiveRemainingSlots <= 0,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueKey,
    this.highlightWarning = false,
  });

  final String label;
  final String value;
  final Key? valueKey;
  final bool highlightWarning;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: 2,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: TourSearchPalette.muted),
        ),
        Text(
          value,
          key: valueKey,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: highlightWarning
                ? const Color(0xFFDC2626)
                : TourSearchPalette.navy,
          ),
        ),
      ],
    );
  }
}

class _ParticipantCountCard extends StatelessWidget {
  const _ParticipantCountCard({required this.state, required this.cubit});

  final TourBookingState state;
  final TourBookingCubit cubit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: TourSearchPalette.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Số lượng hành khách',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: TourSearchPalette.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Tối đa ${state.effectiveRemainingSlots} chỗ khả dụng',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: TourSearchPalette.muted,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.outlined(
                  key: const Key('booking-participant-decrement'),
                  onPressed: state.participantCount > 1
                      ? () => cubit.setParticipantCount(
                          state.participantCount - 1,
                        )
                      : null,
                  icon: const Icon(Icons.remove, size: 18),
                  tooltip: 'Giảm số lượng khách',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Text(
                    '${state.participantCount}',
                    key: const Key('booking-participant-count-value'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: TourSearchPalette.navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton.outlined(
                  key: const Key('booking-participant-increment'),
                  onPressed: () =>
                      cubit.setParticipantCount(state.participantCount + 1),
                  icon: const Icon(Icons.add, size: 18),
                  tooltip: 'Tăng số lượng khách',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticipantsSection extends StatelessWidget {
  const _ParticipantsSection({required this.state, required this.cubit});

  final TourBookingState state;
  final TourBookingCubit cubit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thông tin hành khách (${state.participants.length})',
          style: theme.textTheme.titleSmall?.copyWith(
            color: TourSearchPalette.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (var i = 0; i < state.participants.length; i++) ...[
          _ParticipantCard(
            index: i,
            participant: state.participants[i],
            onChanged: (updated) => cubit.updateParticipant(i, updated),
          ),
          if (i < state.participants.length - 1)
            const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _ParticipantCard extends StatelessWidget {
  const _ParticipantCard({
    required this.index,
    required this.participant,
    required this.onChanged,
  });

  final int index;
  final BookingParticipant participant;
  final ValueChanged<BookingParticipant> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: Key('booking-participant-card-$index'),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: TourSearchPalette.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hành khách #${index + 1}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: TourSearchPalette.teal,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: Key(
                'participant-$index-name-${participant.fullName.hashCode}',
              ),
              initialValue: participant.fullName,
              decoration: const InputDecoration(
                labelText: 'Họ và tên (Full Name) *',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => onChanged(participant.copyWith(fullName: v)),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: Key(
                'participant-$index-dob-${participant.dateOfBirth.hashCode}',
              ),
              initialValue: participant.dateOfBirth,
              decoration: const InputDecoration(
                labelText: 'Ngày sinh (Date of Birth - DD/MM/YYYY) *',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => onChanged(participant.copyWith(dateOfBirth: v)),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: Key(
                'participant-$index-id-${participant.identityDocumentNumber.hashCode}',
              ),
              initialValue: participant.identityDocumentNumber,
              decoration: const InputDecoration(
                labelText: 'Số CCCD / Hộ chiếu (Identity Document Number) *',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) =>
                  onChanged(participant.copyWith(identityDocumentNumber: v)),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: Key(
                'participant-$index-phone-${participant.phoneNumber.hashCode}',
              ),
              initialValue: participant.phoneNumber,
              decoration: const InputDecoration(
                labelText: 'Số điện thoại (Phone Number) *',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              onChanged: (v) => onChanged(participant.copyWith(phoneNumber: v)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactInfoCard extends StatelessWidget {
  const _ContactInfoCard({required this.state, required this.cubit});

  final TourBookingState state;
  final TourBookingCubit cubit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contact = state.contactInfo;
    return Card(
      key: const Key('booking-contact-card'),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: TourSearchPalette.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thông tin liên hệ (Contact Information)',
              style: theme.textTheme.titleSmall?.copyWith(
                color: TourSearchPalette.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: Key('contact-name-${contact.fullName.hashCode}'),
              initialValue: contact.fullName,
              decoration: const InputDecoration(
                labelText: 'Người liên hệ (Full Name) *',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) =>
                  cubit.updateContactInfo(contact.copyWith(fullName: v)),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: Key('contact-email-${contact.email.hashCode}'),
              initialValue: contact.email,
              decoration: const InputDecoration(
                labelText: 'Email nhận vé (Email) *',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              onChanged: (v) =>
                  cubit.updateContactInfo(contact.copyWith(email: v)),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: Key('contact-phone-${contact.phoneNumber.hashCode}'),
              initialValue: contact.phoneNumber,
              decoration: const InputDecoration(
                labelText: 'Số điện thoại liên hệ (Phone Number) *',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              onChanged: (v) =>
                  cubit.updateContactInfo(contact.copyWith(phoneNumber: v)),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoucherCard extends StatefulWidget {
  const _VoucherCard({required this.state, required this.cubit});

  final TourBookingState state;
  final TourBookingCubit cubit;

  @override
  State<_VoucherCard> createState() => _VoucherCardState();
}

class _VoucherCardState extends State<_VoucherCard> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.state.voucherInput);
  }

  @override
  void didUpdateWidget(covariant _VoucherCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.voucherInput != _controller.text) {
      _controller.text = widget.state.voucherInput;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.state;
    final cubit = widget.cubit;

    return Card(
      key: const Key('booking-voucher-card'),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: TourSearchPalette.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mã khuyến mãi (Voucher Code)',
              style: theme.textTheme.titleSmall?.copyWith(
                color: TourSearchPalette.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              key: const Key('booking-voucher-input'),
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Nhập mã voucher (VD: SUMMER2026)',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: cubit.setVoucherInput,
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                FilledButton.tonal(
                  key: const Key('booking-apply-voucher-button'),
                  onPressed: cubit.applyVoucher,
                  child: const Text('Apply Voucher'),
                ),
                if (state.appliedVoucherCode != null)
                  OutlinedButton(
                    key: const Key('booking-remove-voucher-button'),
                    onPressed: cubit.removeVoucher,
                    child: const Text('Remove Voucher'),
                  ),
              ],
            ),
            if (state.voucherNotice != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                state.voucherNotice!,
                key: const Key('booking-voucher-notice'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: state.isVoucherError
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF047857),
                ),
              ),
            ],
            if (kDebugMode && state.isDemoMode) ...[
              const SizedBox(height: AppSpacing.xs),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _QuickVoucherChip(
                      code: 'SUMMER2026',
                      label: 'SUMMER2026 (-200k)',
                      onTap: () {
                        cubit.setVoucherInput('SUMMER2026');
                        cubit.applyVoucher();
                      },
                    ),
                    const SizedBox(width: 6),
                    _QuickVoucherChip(
                      code: 'VIP500',
                      label: 'VIP500 (MSG102)',
                      onTap: () {
                        cubit.setVoucherInput('VIP500');
                        cubit.applyVoucher();
                      },
                    ),
                    const SizedBox(width: 6),
                    _QuickVoucherChip(
                      code: 'EXPIRED2025',
                      label: 'EXPIRED2025 (MSG101)',
                      onTap: () {
                        cubit.setVoucherInput('EXPIRED2025');
                        cubit.applyVoucher();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickVoucherChip extends StatelessWidget {
  const _QuickVoucherChip({
    required this.code,
    required this.label,
    required this.onTap,
  });

  final String code;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      key: Key('demo-voucher-chip-$code'),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: onTap,
    );
  }
}

class _PriceBreakdownCard extends StatelessWidget {
  const _PriceBreakdownCard({required this.state});

  final TourBookingState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('booking-price-breakdown-card'),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: TourSearchPalette.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chi tiết thanh toán',
              style: theme.textTheme.titleSmall?.copyWith(
                color: TourSearchPalette.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _SummaryRow(
              label:
                  'Tạm tính (${state.participantCount} × ${_formatVnd(state.unitPrice)})',
              value: _formatVnd(state.subtotal),
              valueKey: const Key('booking-subtotal-value'),
            ),
            const SizedBox(height: AppSpacing.xs),
            _SummaryRow(
              label: state.appliedVoucherCode != null
                  ? 'Giảm giá (${state.appliedVoucherCode})'
                  : 'Giảm giá voucher',
              value: '-${_formatVnd(state.clampedDiscount)}',
              valueKey: const Key('booking-discount-value'),
            ),
            const Divider(height: AppSpacing.lg),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              children: [
                Text(
                  'Tổng thanh toán (Total Amount)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: TourSearchPalette.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _formatVnd(state.totalAmount),
                  key: const Key('booking-total-amount-value'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: TourSearchPalette.teal,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingBottomBar extends StatelessWidget {
  const _BookingBottomBar({required this.state, required this.cubit});

  final TourBookingState state;
  final TourBookingCubit cubit;

  @override
  Widget build(BuildContext context) {
    final isSubmitting = state.status == TourBookingStatus.submitting;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: TourSearchPalette.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            OutlinedButton(
              key: const Key('booking-cancel-button'),
              onPressed: isSubmitting
                  ? null
                  : () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(
                          AppRoutes.tourDetail(
                            state.tourId,
                            demo: state.isDemoMode,
                          ),
                        );
                      }
                    },
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('booking-confirm-button'),
              onPressed: isSubmitting
                  ? null
                  : () => _onConfirmPressed(context, state, cubit),
              style: FilledButton.styleFrom(
                backgroundColor: TourSearchPalette.teal,
              ),
              child: Text(isSubmitting ? 'Đang xử lý...' : 'Confirm Booking'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onConfirmPressed(
    BuildContext context,
    TourBookingState state,
    TourBookingCubit cubit,
  ) async {
    final isValid = cubit.validateBeforeConfirmation();
    if (!isValid) return;

    // CR-05: Confirmation dialog before committing booking creation.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận đặt tour'),
        content: Text(
          'Bạn xác nhận tạo đơn đặt tour cho ${state.participantCount} hành khách với tổng số tiền ${_formatVnd(state.totalAmount)}?\n\nHệ thống sẽ giữ chỗ trong 15 phút để hoàn tất thanh toán.',
        ),
        actions: [
          TextButton(
            key: const Key('booking-confirm-dialog-cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            key: const Key('booking-confirm-dialog-submit'),
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: TourSearchPalette.teal,
            ),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await cubit.confirmBooking();
    }
  }
}

class _DemoBookingControlsBar extends StatelessWidget {
  const _DemoBookingControlsBar({required this.cubit});

  final TourBookingCubit cubit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bug_report, size: 14, color: Color(0xFFB45309)),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  'UC-27 DEMO SIMULATION CONTROLS (Debug Only)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  key: const Key('demo-uc27-reset'),
                  label: const Text('Mặc định', style: TextStyle(fontSize: 11)),
                  onPressed: cubit.resetDemoSimulations,
                ),
                const SizedBox(width: 6),
                ActionChip(
                  key: const Key('demo-uc27-sold-out'),
                  label: const Text(
                    'Hết chỗ (MSG65)',
                    style: TextStyle(fontSize: 11),
                  ),
                  onPressed: cubit.simulateScheduleSoldOut,
                ),
                const SizedBox(width: 6),
                ActionChip(
                  key: const Key('demo-uc27-insufficient-slots'),
                  label: const Text(
                    'Vượt số chỗ (MSG77)',
                    style: TextStyle(fontSize: 11),
                  ),
                  onPressed: cubit.simulateInsufficientSlotsAtRevalidation,
                ),
                const SizedBox(width: 6),
                ActionChip(
                  key: const Key('demo-uc27-invalid-participant'),
                  label: const Text(
                    'Sai TT khách (MSG78)',
                    style: TextStyle(fontSize: 11),
                  ),
                  onPressed: cubit.simulateIncompleteParticipant,
                ),
                const SizedBox(width: 6),
                ActionChip(
                  key: const Key('demo-uc27-max-unpaid'),
                  label: const Text(
                    'Quá giới hạn đơn (MSG126)',
                    style: TextStyle(fontSize: 11),
                  ),
                  onPressed: cubit.simulateMaxUnpaidBookingsReached,
                ),
                const SizedBox(width: 6),
                ActionChip(
                  key: const Key('demo-uc27-error'),
                  label: const Text(
                    'Lỗi hệ thống (MSG127)',
                    style: TextStyle(fontSize: 11),
                  ),
                  onPressed: cubit.simulateError,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatVnd(int price) {
  final text = price.toString();
  final buffer = StringBuffer();
  final length = text.length;
  for (var i = 0; i < length; i++) {
    if (i > 0 && (length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(text[i]);
  }
  buffer.write('₫');
  return buffer.toString();
}

String _formatDate(DateTime dateUtc) {
  final vn = dateUtc.add(const Duration(hours: 7));
  final day = vn.day.toString().padLeft(2, '0');
  final month = vn.month.toString().padLeft(2, '0');
  return '$day/$month/${vn.year}';
}
