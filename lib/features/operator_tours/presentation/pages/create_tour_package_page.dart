import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_draft.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/cubit/create_tour_package_cubit.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/cubit/create_tour_package_state.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_summary.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_list_cubit.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_list_state.dart';

final class CreateTourPackagePage extends StatefulWidget {
  const CreateTourPackagePage({super.key});
  @override
  State<CreateTourPackagePage> createState() => _CreateTourPackagePageState();
}

final class _CreateTourPackagePageState extends State<CreateTourPackagePage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _duration = TextEditingController(text: '1');
  final List<_TourStop> _stops = [];
  final List<_Departure> _departures = [];
  // Catalogue ids in the order the operator chose them (the order is the display order).
  final List<int> _destinationIds = [];
  int? _policyId;
  var _step = 0;

  @override
  void initState() {
    super.initState();
    final start = DateTime.now().add(const Duration(days: 1));
    _departures.add(
      _Departure(start: start, end: start.add(const Duration(hours: 8))),
    );
  }

  @override
  void dispose() {
    for (final controller in [_title, _description, _price, _duration]) {
      controller.dispose();
    }
    super.dispose();
  }

  int? _positiveInt(String value) {
    final number = int.tryParse(value.trim());
    return number != null && number > 0 ? number : null;
  }

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? '$label is required.' : null;

  bool _isWholeVnd(num? value) => value == null || value == value.truncate();

  bool _validStep() {
    if (_step == 0) {
      if (!_formKey.currentState!.validate()) return false;
      if (_destinationIds.isEmpty) {
        return _notice('Select at least one destination.');
      }
      if (_policyId == null) {
        return _notice('Select a cancellation policy.');
      }
      return true;
    }
    if (_step == 1 && _stops.isEmpty) {
      return _notice('Add at least one point of interest.');
    }
    if (_step == 1) {
      final duration = _positiveInt(_duration.text) ?? 1;
      if (_stops.any((stop) => stop.dayNo > duration)) {
        return _notice('Each stop must be on a day within the tour duration.');
      }
    }
    if (_step == 2 && _departures.isEmpty) {
      return _notice('Add at least one departure schedule.');
    }
    return true;
  }

  bool _notice(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    return false;
  }

  Future<void> _choosePoi() async {
    final poi = await showModalBottomSheet<PoiSummary>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider(
        create: (_) => serviceLocator<PoiListCubit>()..loadInitial(),
        child: const _PoiPickerSheet(),
      ),
    );
    if (mounted && poi != null) setState(() => _stops.add(_TourStop(poi: poi)));
  }

  Future<void> _editStop(int index) async {
    final old = _stops[index];
    final day = TextEditingController(text: '${old.dayNo}');
    final stay = TextEditingController(text: '${old.stayMinutes}');
    final result = await showDialog<_TourStop>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(old.poi.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: day,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Day number'),
            ),
            TextField(
              controller: stay,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Stay duration (minutes)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              old.copyWith(
                dayNo: _positiveInt(day.text) ?? old.dayNo,
                stayMinutes: _positiveInt(stay.text) ?? old.stayMinutes,
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    day.dispose();
    stay.dispose();
    if (mounted && result != null) setState(() => _stops[index] = result);
  }

  Future<void> _editDeparture(int index) async {
    final old = _departures[index];
    final date = await showDatePicker(
      context: context,
      initialDate: old.start,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (!mounted || date == null) return;
    final capacity = TextEditingController(text: '${old.capacity}');
    final meeting = TextEditingController(text: old.meetingPoint);
    final minimumCapacity = TextEditingController(
      text: '${old.minimumCapacity}',
    );
    final adultPrice = TextEditingController(
      text: old.adultPrice?.toString() ?? _price.text,
    );
    final childPrice = TextEditingController(
      text: old.childPrice?.toString() ?? '',
    );
    final infantPrice = TextEditingController(
      text: old.infantPrice?.toString() ?? '',
    );
    final result = await showDialog<_Departure>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Departure schedule'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(MaterialLocalizations.of(context).formatMediumDate(date)),
            TextField(
              controller: capacity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Capacity'),
            ),
            TextField(
              controller: minimumCapacity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minimum passengers',
              ),
            ),
            TextField(
              controller: adultPrice,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Adult price (VND)'),
            ),
            TextField(
              controller: childPrice,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Child price (optional)',
              ),
            ),
            TextField(
              controller: infantPrice,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Infant price (optional)',
              ),
            ),
            TextField(
              controller: meeting,
              decoration: const InputDecoration(labelText: 'Meeting point'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final start = DateTime(
                date.year,
                date.month,
                date.day,
                old.start.hour,
                old.start.minute,
              );
              Navigator.pop(
                dialogContext,
                _Departure(
                  start: start,
                  end: start.add(old.end.difference(old.start)),
                  capacity: _positiveInt(capacity.text) ?? old.capacity,
                  minimumCapacity:
                      _positiveInt(minimumCapacity.text) ?? old.minimumCapacity,
                  adultPrice:
                      num.tryParse(adultPrice.text.trim()) ?? old.adultPrice,
                  childPrice: childPrice.text.trim().isEmpty
                      ? null
                      : num.tryParse(childPrice.text.trim()),
                  infantPrice: infantPrice.text.trim().isEmpty
                      ? null
                      : num.tryParse(infantPrice.text.trim()),
                  meetingPoint: meeting.text,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    capacity.dispose();
    meeting.dispose();
    minimumCapacity.dispose();
    adultPrice.dispose();
    childPrice.dispose();
    infantPrice.dispose();
    if (mounted && result != null) setState(() => _departures[index] = result);
  }

  void _submit() {
    if (_stops.isEmpty || _departures.isEmpty) {
      _notice('Add at least one itinerary stop and one departure schedule.');
      return;
    }
    final price = num.tryParse(_price.text.trim());
    final duration = _positiveInt(_duration.text);
    final policyId = _policyId;
    if (price == null || price <= 0 || duration == null || policyId == null) {
      return;
    }
    if (_destinationIds.isEmpty) {
      _notice('Select at least one destination.');
      return;
    }
    final invalidDeparture = _departures.any(
      (departure) =>
          departure.minimumCapacity > departure.capacity ||
          (departure.adultPrice != null && departure.adultPrice! <= 0) ||
          (departure.childPrice != null && departure.childPrice! < 0) ||
          (departure.infantPrice != null && departure.infantPrice! < 0),
    );
    if (invalidDeparture) {
      _notice(
        'Each departure needs a positive adult price and a minimum capacity no greater than capacity.',
      );
      return;
    }
    final prices = [
      price,
      for (final departure in _departures) ...[
        departure.adultPrice,
        departure.childPrice,
        departure.infantPrice,
      ],
    ];
    if (!prices.every(_isWholeVnd)) {
      _notice('Prices must be whole VND amounts.');
      return;
    }
    context.read<CreateTourPackageCubit>().submit(
      TourPackageDraft(
        title: _title.text,
        description: _description.text,
        basePrice: price,
        durationDays: duration,
        destinationIds: List.unmodifiable(_destinationIds),
        cancellationPolicyTemplateId: policyId,
        itineraryItems: _stops
            .asMap()
            .entries
            .map(
              (entry) => TourItineraryStopDraft(
                poiId: entry.value.poi.id,
                dayNo: entry.value.dayNo,
                sequenceNo: entry.key + 1,
                stayDurationMinutes: entry.value.stayMinutes,
              ),
            )
            .toList(growable: false),
        schedules: _departures
            .map(
              (item) => TourScheduleDraft(
                startAtUtc: item.start,
                endAtUtc: item.end,
                totalCapacity: item.capacity,
                minimumCapacity: item.minimumCapacity,
                adultPrice: item.adultPrice ?? price,
                childPrice: item.childPrice,
                infantPrice: item.infantPrice,
                meetingPoint: item.meetingPoint,
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<CreateTourPackageCubit, CreateTourPackageState>(
    listenWhen: (previous, current) => previous.status != current.status,
    listener: (context, state) {
      if (state.status == CreateTourPackageStatus.failure &&
          state.failure != null) {
        _notice(state.failure!.message);
      }
      if (state.status == CreateTourPackageStatus.success) {
        _notice('Tour draft saved.');
        context.go(AppRoutes.operator);
      }
    },
    builder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Create tour package')),
      body: SafeArea(
        child: Stepper(
          currentStep: _step,
          onStepTapped: (value) {
            if (value <= _step || _validStep()) setState(() => _step = value);
          },
          onStepContinue: () {
            if (!_validStep()) return;
            if (_step == 3) {
              _submit();
            } else {
              setState(() => _step++);
            }
          },
          onStepCancel: _step == 0
              ? () => context.pop()
              : () => setState(() => _step--),
          controlsBuilder: (_, details) => Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Row(
              children: [
                FilledButton(
                  onPressed: state.status == CreateTourPackageStatus.submitting
                      ? null
                      : details.onStepContinue,
                  child: Text(_step == 3 ? 'Save draft' : 'Continue'),
                ),
                const SizedBox(width: AppSpacing.sm),
                TextButton(
                  onPressed: details.onStepCancel,
                  child: Text(_step == 0 ? 'Cancel' : 'Back'),
                ),
              ],
            ),
          ),
          steps: [
            Step(
              title: const Text('Basic information'),
              content: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _title,
                      decoration: const InputDecoration(
                        labelText: 'Tour title',
                      ),
                      validator: (value) => _required(value, 'Tour title'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _description,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                      validator: (value) => _required(value, 'Description'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _price,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Base price (VND)',
                      ),
                      validator: (value) {
                        final price = num.tryParse(value ?? '');
                        if (price == null || price <= 0) {
                          return 'Enter a positive price.';
                        }
                        return _isWholeVnd(price)
                            ? null
                            : 'Enter a whole VND amount.';
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _duration,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Duration (days)',
                      ),
                      validator: (value) => _positiveInt(value ?? '') == null
                          ? 'Enter a positive number of days.'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _OptionsSection(
                      state: state,
                      selectedDestinationIds: _destinationIds,
                      selectedPolicyId: _policyId,
                      onToggleDestination: (id) => setState(() {
                        if (_destinationIds.contains(id)) {
                          _destinationIds.remove(id);
                        } else if (_destinationIds.length < _maxDestinations) {
                          _destinationIds.add(id);
                        }
                      }),
                      onPolicyChanged: (id) => setState(() => _policyId = id),
                      onRetry: () =>
                          context.read<CreateTourPackageCubit>().loadOptions(),
                    ),
                  ],
                ),
              ),
              isActive: _step >= 0,
            ),
            Step(
              title: Text('Itinerary (${_stops.length})'),
              content: Column(
                children: [
                  const Text(
                    'Choose active locations from the TripMate catalogue, then adjust each visit.',
                  ),
                  for (final entry in _stops.asMap().entries)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(child: Text('${entry.key + 1}')),
                      title: Text(entry.value.poi.name),
                      subtitle: Text(
                        'Day ${entry.value.dayNo} · ${entry.value.stayMinutes} min${entry.value.poi.isOpenNow ? ' · Open now' : ''}',
                      ),
                      onTap: () => _editStop(entry.key),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () =>
                            setState(() => _stops.removeAt(entry.key)),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _choosePoi,
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: const Text('Add point of interest'),
                    ),
                  ),
                ],
              ),
              isActive: _step >= 1,
            ),
            Step(
              title: Text('Schedules (${_departures.length})'),
              content: Column(
                children: [
                  const Text(
                    'Add every departure you intend to sell. Capacity is managed per departure.',
                  ),
                  for (final entry in _departures.asMap().entries)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        MaterialLocalizations.of(
                          context,
                        ).formatMediumDate(entry.value.start),
                      ),
                      subtitle: Text(
                        '${entry.value.capacity} seats · Adult ${entry.value.adultPrice ?? _price.text} VND${entry.value.meetingPoint.trim().isEmpty ? '' : ' · ${entry.value.meetingPoint}'}',
                      ),
                      onTap: () => _editDeparture(entry.key),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _departures.length == 1
                            ? null
                            : () => setState(
                                () => _departures.removeAt(entry.key),
                              ),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final start = _departures.last.start.add(
                          const Duration(days: 7),
                        );
                        setState(
                          () => _departures.add(
                            _Departure(
                              start: start,
                              end: start.add(const Duration(hours: 8)),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add departure'),
                    ),
                  ),
                ],
              ),
              isActive: _step >= 2,
            ),
            Step(
              title: const Text('Review & save'),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title.text,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${_stops.length} stops · ${_departures.length} departures · ${_price.text} VND',
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'This is saved as a Draft. You can submit it for approval separately.',
                  ),
                ],
              ),
              isActive: _step >= 3,
            ),
          ],
        ),
      ),
    ),
  );
}

const _maxDestinations = 10;

/// Destination and cancellation-policy pickers backed by the server catalogue.
final class _OptionsSection extends StatelessWidget {
  const _OptionsSection({
    required this.state,
    required this.selectedDestinationIds,
    required this.selectedPolicyId,
    required this.onToggleDestination,
    required this.onPolicyChanged,
    required this.onRetry,
  });
  final CreateTourPackageState state;
  final List<int> selectedDestinationIds;
  final int? selectedPolicyId;
  final ValueChanged<int> onToggleDestination;
  final ValueChanged<int?> onPolicyChanged;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    switch (state.optionsStatus) {
      case TourPackageOptionsStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case TourPackageOptionsStatus.failure:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.optionsFailure?.message ??
                  'Could not load destinations and cancellation policies.',
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        );
      case TourPackageOptionsStatus.ready:
        final options = state.options!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Destinations', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final destination in options.destinations)
                  FilterChip(
                    label: Text(destination.name),
                    selected: selectedDestinationIds.contains(destination.id),
                    onSelected: (_) => onToggleDestination(destination.id),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<int>(
              initialValue: selectedPolicyId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Cancellation policy',
              ),
              items: [
                for (final policy in options.policies)
                  DropdownMenuItem(
                    value: policy.id,
                    child: Text(policy.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: onPolicyChanged,
            ),
          ],
        );
    }
  }
}

final class _TourStop {
  const _TourStop({required this.poi, this.dayNo = 1, this.stayMinutes = 60});
  final PoiSummary poi;
  final int dayNo;
  final int stayMinutes;
  _TourStop copyWith({int? dayNo, int? stayMinutes}) => _TourStop(
    poi: poi,
    dayNo: dayNo ?? this.dayNo,
    stayMinutes: stayMinutes ?? this.stayMinutes,
  );
}

final class _Departure {
  const _Departure({
    required this.start,
    required this.end,
    this.capacity = 20,
    this.minimumCapacity = 1,
    this.adultPrice,
    this.childPrice,
    this.infantPrice,
    this.meetingPoint = '',
  });
  final DateTime start;
  final DateTime end;
  final int capacity;
  final int minimumCapacity;
  final num? adultPrice;
  final num? childPrice;
  final num? infantPrice;
  final String meetingPoint;
}

final class _PoiPickerSheet extends StatefulWidget {
  const _PoiPickerSheet();
  @override
  State<_PoiPickerSheet> createState() => _PoiPickerSheetState();
}

final class _PoiPickerSheetState extends State<_PoiPickerSheet> {
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                labelText: 'Search points of interest',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () =>
                      context.read<PoiListCubit>().submitSearch(_search.text),
                ),
              ),
              onSubmitted: context.read<PoiListCubit>().submitSearch,
            ),
          ),
          Expanded(
            child: BlocBuilder<PoiListCubit, PoiListState>(
              builder: (_, state) {
                if (state.status == PoiListStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.status == PoiListStatus.failure) {
                  return Center(
                    child: Text(
                      state.failure?.message ?? 'Could not load locations.',
                    ),
                  );
                }
                if (state.items.isEmpty) {
                  return const Center(
                    child: Text('No active points of interest found.'),
                  );
                }
                return ListView.builder(
                  itemCount: state.items.length,
                  itemBuilder: (_, index) {
                    final poi = state.items[index];
                    return ListTile(
                      title: Text(poi.name),
                      subtitle: Text(
                        '${poi.categoryName}${poi.isOpenNow ? ' · Open now' : ''}',
                      ),
                      trailing: const Icon(Icons.add_circle_outline),
                      onTap: () => Navigator.pop(context, poi),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
