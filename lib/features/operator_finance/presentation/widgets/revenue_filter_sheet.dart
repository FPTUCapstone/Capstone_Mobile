import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/revenue_query.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/cubit/operator_revenue_cubit.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/widgets/revenue_financial_details.dart';

class RevenueFilterSheet extends StatefulWidget {
  const RevenueFilterSheet({required this.cubit, super.key});
  final OperatorRevenueCubit cubit;
  @override
  State<RevenueFilterSheet> createState() => _RevenueFilterSheetState();
}

class _RevenueFilterSheetState extends State<RevenueFilterSheet> {
  late RevenueQuery _draft = widget.cubit.state.query;
  bool _submitted = false;

  Future<void> _date(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _draft.startDate : _draft.endDate,
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 30),
    );
    if (picked == null || !mounted) return;
    setState(
      () => _draft = start
          ? _draft.copyWith(startDate: picked)
          : _draft.copyWith(endDate: picked),
    );
  }

  void _preset(RevenueQuery query) => setState(
    () => _draft = _draft.copyWith(
      startDate: query.startDate,
      endDate: query.endDate,
    ),
  );

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<OperatorRevenueCubit, OperatorRevenueState>(
    bloc: widget.cubit,
    builder: (context, state) => SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Bộ lọc báo cáo', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const Text('Tháng này'),
                onPressed: () => _preset(widget.cubit.currentMonthQuery()),
              ),
              ActionChip(
                label: const Text('Tháng trước'),
                onPressed: () => _preset(widget.cubit.previousMonthQuery()),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _date(true),
            child: Text('Từ ngày: ${financeDay(_draft.startDate)}'),
          ),
          OutlinedButton(
            onPressed: () => _date(false),
            child: Text('Đến ngày: ${financeDay(_draft.endDate)}'),
          ),
          if (_submitted && !_draft.isValid)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Ngày kết thúc phải bằng hoặc sau ngày bắt đầu.',
                style: TextStyle(color: Colors.red),
              ),
            ),
          const Text(
            'Khoảng ngày được tính theo giờ Việt Nam, gồm cả ngày kết thúc.',
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _draft.granularity,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Nhóm theo'),
            items: const [
              DropdownMenuItem(value: 'daily', child: Text('Ngày')),
              DropdownMenuItem(value: 'weekly', child: Text('Tuần')),
              DropdownMenuItem(value: 'monthly', child: Text('Tháng')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _draft = _draft.copyWith(granularity: value));
              }
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey(
              'finance-tour-options-${state.options.length}-${_draft.tourId}',
            ),
            initialValue: _draft.tourId,
            isExpanded: true,
            hint: const Text('Tất cả tour'),
            decoration: const InputDecoration(labelText: 'Gói tour'),
            items: [
              const DropdownMenuItem<int>(
                value: null,
                child: Text('Tất cả tour'),
              ),
              if (_draft.tourId != null &&
                  !state.options.any((tour) => tour.id == _draft.tourId))
                DropdownMenuItem<int>(
                  value: _draft.tourId,
                  child: Text('Tour #${_draft.tourId} (đang lọc)'),
                ),
              for (final tour in state.options)
                DropdownMenuItem(
                  value: tour.id,
                  child: Text(
                    '${tour.code} · ${tour.title}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => setState(
              () => _draft = value == null
                  ? _draft.copyWith(clearTour: true)
                  : _draft.copyWith(tourId: value),
            ),
          ),
          if (state.optionsLoading)
            const LinearProgressIndicator(
              semanticsLabel: 'Đang tải danh sách tour',
            ),
          if (state.optionsError != null) ...[
            Text(state.optionsError!),
            TextButton(
              onPressed: widget.cubit.loadOptions,
              child: const Text('Tải lại danh sách tour'),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              setState(() => _submitted = true);
              if (_draft.isValid) Navigator.pop(context, _draft);
            },
            child: const Text('Áp dụng'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
        ],
      ),
    ),
  );
}
