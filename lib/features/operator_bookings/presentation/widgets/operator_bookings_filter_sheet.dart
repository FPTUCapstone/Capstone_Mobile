import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/operator_bookings/presentation/cubit/operator_bookings_cubit.dart';
import 'package:trip_mate_mobile/features/operator_bookings/presentation/cubit/operator_bookings_state.dart';
import 'package:trip_mate_mobile/features/operator_bookings/resources/operator_bookings_en.dart';
import 'package:trip_mate_mobile/features/operator_bookings/utils/operator_booking_formatters.dart';

/// Picks a calendar day; [current] is the day already chosen, if any. Null means the user dismissed it.
typedef OperatorBookingDatePicker =
    Future<DateTime?> Function(BuildContext context, DateTime? current);

Future<DateTime?> pickOperatorBookingDate(
  BuildContext context,
  DateTime? current,
) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: current ?? now,
    firstDate: DateTime(now.year - 2),
    lastDate: DateTime(now.year + 2),
  );
}

/// The tour and departure-range filters of the bookings list (SRS filters beyond the inline status and search).
class OperatorBookingsFilterSheet extends StatefulWidget {
  const OperatorBookingsFilterSheet({required this.pickDate, super.key});

  final OperatorBookingDatePicker pickDate;

  @override
  State<OperatorBookingsFilterSheet> createState() =>
      _OperatorBookingsFilterSheetState();
}

class _OperatorBookingsFilterSheetState
    extends State<OperatorBookingsFilterSheet> {
  String? _tourId;
  DateTime? _from;
  DateTime? _to;
  String? _error;

  @override
  void initState() {
    super.initState();
    final state = context.read<OperatorBookingsCubit>().state;
    _tourId = state.tourId;
    _from = state.departureFrom;
    _to = state.departureTo;
  }

  Future<void> _pick({required bool from}) async {
    final picked = await widget.pickDate(context, from ? _from : _to);
    if (picked == null || !mounted) return;
    setState(() {
      if (from) {
        _from = picked;
      } else {
        _to = picked;
      }
      _error = null;
    });
  }

  void _apply() {
    final from = _from;
    final to = _to;
    // MSG31: an inverted range is refused here, before anything is sent, and the sheet stays open.
    if (from != null &&
        to != null &&
        DateTime(
          to.year,
          to.month,
          to.day,
        ).isBefore(DateTime(from.year, from.month, from.day))) {
      setState(() => _error = OperatorBookingsStringsEn.dateRangeInvalid);
      return;
    }
    final cubit = context.read<OperatorBookingsCubit>();
    Navigator.of(context).pop();
    cubit.applyFilters(tourId: _tourId, departureFrom: from, departureTo: to);
  }

  void _reset() {
    final cubit = context.read<OperatorBookingsCubit>();
    Navigator.of(context).pop();
    cubit.clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final OperatorBookingsState state = context
        .watch<OperatorBookingsCubit>()
        .state;
    final textTheme = Theme.of(context).textTheme;
    final selectedTour = state.tourOptions.any((o) => o.id == _tourId)
        ? _tourId
        : null;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              OperatorBookingsStringsEn.filterTitle,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String?>(
              initialValue: selectedTour,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: OperatorBookingsStringsEn.filterTour,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text(OperatorBookingsStringsEn.filterAllTours),
                ),
                for (final option in state.tourOptions)
                  DropdownMenuItem<String?>(
                    value: option.id,
                    child: Text(option.title, overflow: TextOverflow.ellipsis),
                  ),
              ],
              // A failed tour list disables only this control; every other filter keeps working.
              onChanged: state.tourOptionsFailed
                  ? null
                  : (value) => setState(() => _tourId = value),
            ),
            if (state.tourOptionsFailed)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxs),
                child: Text(
                  OperatorBookingsStringsEn.filterToursUnavailable,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            _DateField(
              label: OperatorBookingsStringsEn.filterDepartureFrom,
              value: _from,
              onTap: () => _pick(from: true),
              onClear: () => setState(() {
                _from = null;
                _error = null;
              }),
            ),
            const SizedBox(height: AppSpacing.sm),
            _DateField(
              label: OperatorBookingsStringsEn.filterDepartureTo,
              value: _to,
              onTap: () => _pick(from: false),
              onClear: () => setState(() {
                _to = null;
                _error = null;
              }),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  _error!,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.error),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                TextButton(
                  onPressed: _reset,
                  child: const Text(OperatorBookingsStringsEn.filterReset),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _apply,
                  child: const Text(OperatorBookingsStringsEn.filterApply),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final current = value;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: current == null
              ? const Icon(Icons.calendar_today_outlined, size: 18)
              : IconButton(
                  tooltip: OperatorBookingsStringsEn.filterClearDate,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClear,
                ),
        ),
        child: Text(
          current == null
              ? OperatorBookingsStringsEn.filterSelectDate
              : OperatorBookingFormatters.date(
                  DateTime.utc(current.year, current.month, current.day),
                ),
        ),
      ),
    );
  }
}
