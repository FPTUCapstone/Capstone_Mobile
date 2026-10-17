import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

/// UC-27 Book Tour. Ends at a confirmed PendingPayment booking; "Pay now" is the only
/// handoff to UC-28 and this page never selects a payment method or starts a gateway call.
final class BookTourPage extends StatelessWidget {
  const BookTourPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book Tour')),
      body: BlocConsumer<BookTourCubit, BookTourState>(
        listenWhen: (previous, current) =>
            previous.submitStatus != current.submitStatus &&
            current.submitStatus == SubmitStatus.failure,
        listener: (context, state) {
          final failure = state.submitFailure;
          if (failure != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(failure.message)));
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Travelers', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          _ParticipantCounter(
            label: 'Adults',
            value: state.participantCounts.adult,
            minValue: 1,
            onChanged: (value) => cubit.updateParticipantCounts(
              state.participantCounts.copyWith(adult: value),
            ),
          ),
          _ParticipantCounter(
            label: 'Children',
            value: state.participantCounts.child,
            onChanged: (value) => cubit.updateParticipantCounts(
              state.participantCounts.copyWith(child: value),
            ),
          ),
          _ParticipantCounter(
            label: 'Infants',
            value: state.participantCounts.infant,
            onChanged: (value) => cubit.updateParticipantCounts(
              state.participantCounts.copyWith(infant: value),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Lead traveler', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _fullNameController,
            decoration: const InputDecoration(labelText: 'Full name *'),
            onChanged: cubit.updateLeadFullName,
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone number *'),
            onChanged: cubit.updateLeadPhone,
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            onChanged: cubit.updateLeadEmail,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _voucherController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Voucher code'),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              FilledButton.tonal(
                onPressed: () =>
                    cubit.applyVoucherCode(_voucherController.text),
                child: const Text('Apply'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _QuoteSummary(state: state),
          const SizedBox(height: AppSpacing.lg),
          CheckboxListTile(
            value: state.agreedToTerms,
            onChanged: (value) => cubit.setAgreedToTerms(value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'I confirm the information is accurate and agree to the booking terms and cancellation policy.',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: state.canSubmit ? cubit.submit : null,
            child: state.submitStatus == SubmitStatus.submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Confirm booking'),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Your booking will be created as Pending Payment and held for a limited time set by the server.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
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
    this.minValue = 0,
  });

  final String label;
  final int value;
  final int minValue;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Row(
            children: [
              IconButton(
                onPressed: value > minValue ? () => onChanged(value - 1) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              SizedBox(
                width: 24,
                child: Text('$value', textAlign: TextAlign.center),
              ),
              IconButton(
                onPressed: () => onChanged(value + 1),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
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
      return Text(
        state.quoteFailure?.message ?? 'Unable to load pricing.',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }

    final quote = state.quote;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.quoteStatus == QuoteStatus.loading && quote == null)
              const Center(child: CircularProgressIndicator())
            else if (quote != null) ...[
              for (final line in quote.priceBreakdown)
                if (line.quantity > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xxs,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${line.quantity} × ${_participantLabel(line.participantType)} '
                          '(${_formatMoney(line.unitPrice, quote.currency)})',
                        ),
                        Text(_formatMoney(line.lineAmount, quote.currency)),
                      ],
                    ),
                  ),
              if (quote.discountAmount > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Discount (${quote.appliedVoucherCode ?? ''})'),
                      Text(
                        '-${_formatMoney(quote.discountAmount, quote.currency)}',
                      ),
                    ],
                  ),
                ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    _formatMoney(quote.totalAmount, quote.currency),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              Text(
                '${quote.remainingSlots} slot(s) remaining',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
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
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Booking confirmed',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Booking code: ${booking.bookingCode}'),
                  Text('Status: ${booking.status}'),
                  Text(
                    'Total: ${_formatMoney(booking.totalAmount, booking.currency)}',
                  ),
                  Text('Pay before: ${booking.paymentExpiresAt.toLocal()}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            // UC-28 (Make Electronic Payment) is a separate, not-yet-implemented feature.
            // This explicitly stops the handoff here rather than silently doing nothing or
            // fabricating a payment flow.
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Payment (UC-28) is not yet available on mobile. Your booking is held as Pending Payment.',
                ),
              ),
            ),
            child: const Text('Pay now'),
          ),
        ],
      ),
    );
  }
}
