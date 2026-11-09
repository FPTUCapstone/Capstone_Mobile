import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_search_query.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/cubit/tour_search_cubit.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/cubit/tour_search_state.dart';

class PublicTourSearchControls extends StatefulWidget {
  const PublicTourSearchControls({
    required this.state,
    required this.cubit,
    super.key,
  });

  final TourSearchState state;
  final TourSearchCubit cubit;

  @override
  State<PublicTourSearchControls> createState() =>
      _PublicTourSearchControlsState();
}

class _PublicTourSearchControlsState extends State<PublicTourSearchControls> {
  late final TextEditingController _keyword = TextEditingController(
    text: widget.state.query.keyword,
  );

  @override
  void didUpdateWidget(covariant PublicTourSearchControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.query.keyword != widget.state.query.keyword) {
      _keyword.text = widget.state.query.keyword ?? '';
    }
  }

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      0,
    ),
    child: Column(
      children: [
        TextField(
          key: const Key('public-search-keyword'),
          controller: _keyword,
          maxLength: 300,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            labelText: 'Từ khóa',
            counterText: '',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (value) => widget.cubit.applyPublicQuery(
            widget.state.query.copyWith(keyword: value),
          ),
        ),
        DropdownButtonFormField<String>(
          key: ValueKey(widget.state.query.sort),
          initialValue: widget.state.query.sort,
          decoration: const InputDecoration(labelText: 'Sắp xếp'),
          items: const [
            DropdownMenuItem(value: 'relevance', child: Text('Phù hợp nhất')),
            DropdownMenuItem(value: 'priceAsc', child: Text('Giá tăng dần')),
            DropdownMenuItem(value: 'priceDesc', child: Text('Giá giảm dần')),
            DropdownMenuItem(value: 'rating', child: Text('Đánh giá cao')),
            DropdownMenuItem(
              value: 'departureDate',
              child: Text('Ngày khởi hành'),
            ),
          ],
          onChanged: (value) => widget.cubit.applyPublicQuery(
            widget.state.query.copyWith(sort: value),
          ),
        ),
        if (widget.state.isRefreshing) const LinearProgressIndicator(),
      ],
    ),
  );
}

class PublicTourSearchFilterSheet extends StatefulWidget {
  const PublicTourSearchFilterSheet({required this.cubit, super.key});

  final TourSearchCubit cubit;

  @override
  State<PublicTourSearchFilterSheet> createState() =>
      _PublicTourSearchFilterSheetState();
}

class _PublicTourSearchFilterSheetState
    extends State<PublicTourSearchFilterSheet> {
  late final TourSearchQuery _initial = widget.cubit.state.query;
  late final TextEditingController _destination = TextEditingController(
    text: _initial.destination,
  );
  late final TextEditingController _min = TextEditingController(
    text: _initial.minPrice?.toString(),
  );
  late final TextEditingController _max = TextEditingController(
    text: _initial.maxPrice?.toString(),
  );
  late final TextEditingController _duration = TextEditingController(
    text: _initial.durationDays?.toString(),
  );
  late final TextEditingController _rating = TextEditingController(
    text: _initial.minimumRating?.toString(),
  );
  late DateTime? _start = _initial.departureDate;
  late DateTime? _end = _initial.endDate;
  late String? _category = _initial.category;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_destination, _min, _max, _duration, _rating]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
      ),
      child: BlocBuilder<TourSearchCubit, TourSearchState>(
        bloc: widget.cubit,
        builder: (context, state) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Bộ lọc tìm kiếm',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            _field(_destination, 'Điểm đến'),
            _date('Từ ngày', _start, (value) => setState(() => _start = value)),
            _date('Đến ngày', _end, (value) => setState(() => _end = value)),
            _field(_min, 'Giá tối thiểu', number: true),
            _field(_max, 'Giá tối đa', number: true),
            _field(_duration, 'Thời lượng (ngày)', number: true),
            _field(_rating, 'Đánh giá tối thiểu', decimal: true),
            if (state.categoriesLoading) const LinearProgressIndicator(),
            if (state.categoriesFailure != null)
              TextButton.icon(
                onPressed: widget.cubit.loadCategories,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử tải lại danh mục'),
              ),
            DropdownButtonFormField<String>(
              initialValue:
                  state.categories.any((item) => item.code == _category)
                  ? _category
                  : null,
              decoration: const InputDecoration(labelText: 'Danh mục'),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('Tất cả danh mục'),
                ),
                for (final category in state.categories)
                  DropdownMenuItem(
                    value: category.code,
                    child: Text(category.name),
                  ),
              ],
              onChanged: (value) =>
                  _category = value?.isEmpty == true ? null : value,
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _apply,
              child: const Text('Áp dụng bộ lọc'),
            ),
            TextButton(
              onPressed: () {
                widget.cubit.resetFilters();
                Navigator.pop(context);
              },
              child: const Text('Xóa bộ lọc'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool number = false,
    bool decimal = false,
  }) => TextField(
    controller: controller,
    keyboardType: number || decimal
        ? TextInputType.numberWithOptions(decimal: decimal)
        : TextInputType.text,
    decoration: InputDecoration(labelText: label),
  );

  Widget _date(
    String label,
    DateTime? value,
    ValueChanged<DateTime?> changed,
  ) => Row(
    children: [
      Expanded(
        child: TextButton.icon(
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(
            '$label: ${value == null ? 'Chọn ngày' : '${value.day}/${value.month}/${value.year}'}',
          ),
          onPressed: () async {
            // The frozen UC-24 contract permits explicit historical ranges so
            // completed departures can still be inspected. Year 1 and the
            // final day of year 9999 are excluded because their Vietnam-day
            // UTC bounds cannot be represented safely by the Backend.
            final firstDate = DateTime(2);
            final lastDate = DateTime(9999, 12, 30);
            final today = DateTime.now();
            final requested = value == null
                ? DateTime(today.year, today.month, today.day)
                : DateTime(value.year, value.month, value.day);
            final initialDate = requested.isBefore(firstDate)
                ? firstDate
                : requested.isAfter(lastDate)
                ? lastDate
                : requested;
            final selected = await showDatePicker(
              context: context,
              initialDate: initialDate,
              firstDate: firstDate,
              lastDate: lastDate,
            );
            if (mounted && selected != null) changed(selected);
          },
        ),
      ),
      if (value != null)
        IconButton(
          onPressed: () => changed(null),
          icon: const Icon(Icons.close),
          tooltip: 'Xóa $label',
        ),
    ],
  );

  void _apply() {
    int? integer(TextEditingController controller) =>
        controller.text.trim().isEmpty
        ? null
        : int.parse(controller.text.trim());
    try {
      final query = _initial.copyWith(
        destination: _destination.text.trim(),
        departureDate: _start,
        endDate: _end,
        minPrice: integer(_min),
        maxPrice: integer(_max),
        durationDays: integer(_duration),
        minimumRating: _rating.text.trim().isEmpty
            ? null
            : double.parse(_rating.text.trim()),
        category: _category,
      );
      query.toPublicQueryParameters();
      widget.cubit.applyPublicQuery(query);
      Navigator.pop(context);
    } on ValidationFailure catch (failure) {
      setState(() => _error = failure.message);
    } on FormatException {
      setState(() => _error = 'Giá trị số không hợp lệ.');
    }
  }
}
