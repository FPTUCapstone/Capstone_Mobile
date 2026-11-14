import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_search_query.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/cubit/tour_search_cubit.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/cubit/tour_search_state.dart';

import 'package:trip_mate_mobile/features/tour_search/presentation/resources/public_search_copy.dart';

class PublicTourSearchControls extends StatefulWidget {
  const PublicTourSearchControls({
    required this.state,
    required this.cubit,
    this.useEnglish = false,
    super.key,
  });

  final TourSearchState state;
  final TourSearchCubit cubit;
  final bool useEnglish;

  @override
  State<PublicTourSearchControls> createState() =>
      _PublicTourSearchControlsState();
}

class _PublicTourSearchControlsState extends State<PublicTourSearchControls> {
  String copy(SearchText key) => publicSearchCopy(key, widget.useEnglish);

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
          decoration: InputDecoration(
            labelText: copy(SearchText.keyword),
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
          decoration: InputDecoration(labelText: copy(SearchText.sort)),
          items: [
            DropdownMenuItem(
              value: 'relevance',
              child: Text(copy(SearchText.relevance)),
            ),
            DropdownMenuItem(
              value: 'priceAsc',
              child: Text(copy(SearchText.priceAsc)),
            ),
            DropdownMenuItem(
              value: 'priceDesc',
              child: Text(copy(SearchText.priceDesc)),
            ),
            DropdownMenuItem(
              value: 'rating',
              child: Text(copy(SearchText.ratingSort)),
            ),
            DropdownMenuItem(
              value: 'departureDate',
              child: Text(copy(SearchText.departure)),
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
  const PublicTourSearchFilterSheet({
    required this.cubit,
    this.useEnglish = false,
    super.key,
  });

  final TourSearchCubit cubit;
  final bool useEnglish;

  @override
  State<PublicTourSearchFilterSheet> createState() =>
      _PublicTourSearchFilterSheetState();
}

class _PublicTourSearchFilterSheetState
    extends State<PublicTourSearchFilterSheet> {
  String copy(SearchText key) => publicSearchCopy(key, widget.useEnglish);

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
  String? _errorField;

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
              copy(SearchText.filters),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            _field(_destination, copy(SearchText.destination)),
            _date(
              copy(SearchText.start),
              _start,
              (value) => setState(() => _start = value),
            ),
            _date(
              copy(SearchText.end),
              _end,
              (value) => setState(() => _end = value),
              errorText: _errorField == 'endDate' ? _error : null,
            ),
            _field(_min, copy(SearchText.min), number: true),
            _field(_max, copy(SearchText.max), number: true),
            _field(_duration, copy(SearchText.duration), number: true),
            _field(_rating, copy(SearchText.rating), decimal: true),
            if (state.categoriesLoading) const LinearProgressIndicator(),
            if (state.categoriesFailure != null)
              TextButton.icon(
                onPressed: widget.cubit.loadCategories,
                icon: const Icon(Icons.refresh),
                label: Text(copy(SearchText.retryCategories)),
              ),
            DropdownButtonFormField<String>(
              initialValue:
                  state.categories.any((item) => item.code == _category)
                  ? _category
                  : null,
              decoration: InputDecoration(
                labelText: copy(SearchText.category),
                errorText: _errorField == 'category' ? _error : null,
              ),
              items: [
                DropdownMenuItem(
                  value: '',
                  child: Text(copy(SearchText.allCategories)),
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
            if (_error != null && _errorField == null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _apply,
              child: Text(copy(SearchText.apply)),
            ),
            TextButton(
              onPressed: () {
                widget.cubit.resetFilters();
                Navigator.pop(context);
              },
              child: Text(copy(SearchText.clear)),
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
    decoration: InputDecoration(
      labelText: label,
      errorText:
          (identical(controller, _min) && _errorField == 'minPrice') ||
              (identical(controller, _max) && _errorField == 'maxPrice') ||
              (identical(controller, _duration) && _errorField == 'duration') ||
              (identical(controller, _rating) && _errorField == 'rating') ||
              (identical(controller, _destination) &&
                  _errorField == 'destination')
          ? _error
          : null,
    ),
  );

  Widget _date(
    String label,
    DateTime? value,
    ValueChanged<DateTime?> changed, {
    String? errorText,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: TextButton.icon(
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                '$label: ${value == null ? copy(SearchText.chooseDate) : _displayDate(value)}',
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
                  builder: (context, child) => Localizations.override(
                    context: context,
                    locale: Locale(widget.useEnglish ? 'en' : 'vi'),
                    delegates: GlobalMaterialLocalizations.delegates,
                    child: child,
                  ),
                );
                if (mounted && selected != null) changed(selected);
              },
            ),
          ),
          if (value != null)
            IconButton(
              onPressed: () => changed(null),
              icon: const Icon(Icons.close),
              tooltip: publicSearchClearDate(label, widget.useEnglish),
            ),
        ],
      ),
      if (errorText != null)
        Text(
          errorText,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
    ],
  );

  String _displayDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year.toString().padLeft(4, '0')}';

  void _apply() {
    final start = _start;
    final end = _end;
    if (start != null && end != null && start.isAfter(end)) {
      setState(() {
        _errorField = 'endDate';
        _error = copy(SearchText.invalidDateRange);
      });
      return;
    }
    void reject(String field, SearchText message) {
      setState(() {
        _errorField = field;
        _error = copy(message);
      });
    }

    final numbers = {
      'minPrice': _min.text.trim(),
      'maxPrice': _max.text.trim(),
      'duration': _duration.text.trim(),
      'rating': _rating.text.trim(),
    };
    final min = int.tryParse(numbers['minPrice']!);
    final max = int.tryParse(numbers['maxPrice']!);
    final duration = int.tryParse(numbers['duration']!);
    final rating = double.tryParse(numbers['rating']!);
    if (_destination.text.trim().length >
        TourSearchQuery.maxDestinationLength) {
      reject('destination', SearchText.invalidDestination);
      return;
    }
    if (numbers['minPrice']!.isNotEmpty &&
        (min == null ||
            min < TourSearchQuery.minPriceLimit ||
            min > TourSearchQuery.maxPriceLimit)) {
      reject('minPrice', SearchText.invalidPrice);
      return;
    }
    if (numbers['maxPrice']!.isNotEmpty &&
        (max == null ||
            max < TourSearchQuery.minPriceLimit ||
            max > TourSearchQuery.maxPriceLimit)) {
      reject('maxPrice', SearchText.invalidPrice);
      return;
    }
    if (min != null && max != null && min > max) {
      reject('minPrice', SearchText.invalidPriceRange);
      return;
    }
    if (numbers['duration']!.isNotEmpty && (duration == null || duration < 1)) {
      reject('duration', SearchText.invalidDuration);
      return;
    }
    if (numbers['rating']!.isNotEmpty &&
        (rating == null || !rating.isFinite || rating < 1 || rating > 5)) {
      reject('rating', SearchText.invalidRating);
      return;
    }
    final state = widget.cubit.state;
    if (_category != null &&
        !state.categoriesLoading &&
        state.categoriesFailure == null &&
        !state.categories.any((category) => category.code == _category)) {
      reject('category', SearchText.invalidCategory);
      return;
    }
    try {
      final query = _initial.copyWith(
        destination: _destination.text.trim(),
        departureDate: _start,
        endDate: _end,
        minPrice: min,
        maxPrice: max,
        durationDays: duration,
        minimumRating: rating,
        category: _category,
      );
      query.toPublicQueryParameters();
      widget.cubit.applyPublicQuery(query);
      Navigator.pop(context);
    } on ValidationFailure {
      setState(() {
        _errorField = null;
        _error = copy(SearchText.invalidFilter);
      });
    }
  }
}
