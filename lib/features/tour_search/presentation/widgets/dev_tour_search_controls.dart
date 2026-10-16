import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_search_query.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/cubit/tour_search_cubit.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/cubit/tour_search_state.dart';

class DevTourSearchControls extends StatefulWidget {
  const DevTourSearchControls({
    required this.state,
    required this.cubit,
    super.key,
  });
  final TourSearchState state;
  final TourSearchCubit cubit;
  @override
  State<DevTourSearchControls> createState() => _DevTourSearchControlsState();
}

class _DevTourSearchControlsState extends State<DevTourSearchControls> {
  late final _keyword = TextEditingController(text: widget.state.query.keyword);
  TourSearchState get state => widget.state;
  TourSearchCubit get cubit => widget.cubit;
  @override
  void didUpdateWidget(covariant DevTourSearchControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.query.keyword != state.query.keyword) {
      _keyword.text = state.query.keyword ?? '';
    }
  }

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.sm),
    child: Column(
      children: [
        TextFormField(
          key: const Key('dev-search-keyword'),
          controller: _keyword,
          maxLength: 300,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            labelText: 'Tìm tour bằng mô tả',
            counterText: '',
            prefixIcon: Icon(Icons.search),
          ),
          onFieldSubmitted: (value) =>
              cubit.applyV2Query(state.query.copyWith(keyword: value)),
        ),
        Wrap(
          spacing: AppSpacing.xs,
          children: [
            for (final mode in const {
              'lexical': 'Từ khóa',
              'semantic': 'Ngữ nghĩa',
              'hybrid': 'Kết hợp',
            }.entries)
              ChoiceChip(
                label: Text(mode.value),
                selected: state.query.mode == mode.key,
                onSelected: (_) =>
                    cubit.applyV2Query(state.query.copyWith(mode: mode.key)),
              ),
          ],
        ),
        DropdownButtonFormField<String>(
          key: ValueKey(state.query.sort),
          initialValue: state.query.sort,
          decoration: const InputDecoration(labelText: 'Sắp xếp'),
          items: [
            for (final sort in const {
              'relevance': 'Độ phù hợp',
              'priceAsc': 'Giá tăng dần',
              'priceDesc': 'Giá giảm dần',
              'rating': 'Đánh giá',
              'departureDate': 'Ngày khởi hành',
            }.entries)
              DropdownMenuItem(value: sort.key, child: Text(sort.value)),
          ],
          onChanged: (value) =>
              cubit.applyV2Query(state.query.copyWith(sort: value)),
        ),
        if (state.isRefreshing) const LinearProgressIndicator(),
      ],
    ),
  );
}

class DevTourSearchFilterSheet extends StatefulWidget {
  const DevTourSearchFilterSheet({required this.cubit, super.key});
  final TourSearchCubit cubit;
  @override
  State<DevTourSearchFilterSheet> createState() =>
      _DevTourSearchFilterSheetState();
}

class _DevTourSearchFilterSheetState extends State<DevTourSearchFilterSheet> {
  late final TourSearchQuery _initial = widget.cubit.state.query;
  late final _destination = TextEditingController(text: _initial.destination);
  late final _min = TextEditingController(text: _initial.minPrice?.toString());
  late final _max = TextEditingController(text: _initial.maxPrice?.toString());
  late final _duration = TextEditingController(
    text: _initial.durationDays?.toString(),
  );
  late final _rating = TextEditingController(
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
            _field(_duration, 'Số ngày', number: true),
            _field(_rating, 'Đánh giá tối thiểu (1–5)', number: true),
            if (state.categoriesLoading) const LinearProgressIndicator(),
            if (state.categoriesFailure != null)
              TextButton.icon(
                onPressed: widget.cubit.loadCategories,
                icon: const Icon(Icons.refresh),
                label: const Text('Không tải được danh mục. Thử lại'),
              ),
            DropdownButtonFormField<String>(
              initialValue:
                  state.categories.any((item) => item.code == _category)
                  ? _category
                  : null,
              decoration: const InputDecoration(labelText: 'Danh mục'),
              items: [
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text('Tất cả'),
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
              child: const Text('Đặt lại'),
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
  }) => TextField(
    controller: controller,
    keyboardType: number
        ? const TextInputType.numberWithOptions(decimal: true)
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
            final today = DateTime.now();
            final selected = await showDatePicker(
              context: context,
              initialDate: value ?? today,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (mounted && selected != null) changed(selected);
          },
        ),
      ),
      if (value != null)
        IconButton(
          tooltip: 'Xóa $label',
          onPressed: () => changed(null),
          icon: const Icon(Icons.close),
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
      query.toV2QueryParameters();
      widget.cubit.applyV2Query(query);
      Navigator.pop(context);
    } on ValidationFailure catch (failure) {
      setState(() => _error = failure.message);
    } on FormatException {
      setState(() => _error = 'Vui lòng nhập giá trị số hợp lệ.');
    }
  }
}
