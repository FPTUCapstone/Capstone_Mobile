import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart' show LocationPermission;
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/location/device_location_service.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/address_suggestion.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/selectable_poi.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/address_search_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/create_itinerary_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/create_itinerary_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/poi_search_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/poi_search_state.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';

final class CreateItineraryPage extends StatefulWidget {
  const CreateItineraryPage({super.key});

  @override
  State<CreateItineraryPage> createState() => _CreateItineraryPageState();
}

class _CreateItineraryPageState extends State<CreateItineraryPage> {
  static const _planningTimeZone = 'Asia/Ho_Chi_Minh';

  DeviceLocation? _startLocation;
  String? _startLabel;
  SelectablePoi? _explorationPoi;
  SelectablePoi? _endPoi;
  final List<SelectablePoi> _mandatoryPois = [];
  late DateTime _startAt;
  int? _availableMinutes = 480;
  final _hoursController = TextEditingController(text: '8');
  final _minutesController = TextEditingController(text: '0');
  String? _durationError;
  var _transportMode = TransportMode.motorbike;
  var _restPreference = RestPreference.auto;
  var _returnToStart = true;
  var _searchRadiusKm = 10.0;
  double? _budgetVnd;
  String? _budgetError;
  final _budgetController = TextEditingController();
  String? _formError;
  bool _waitingForCurrentLocation = false;

  @override
  void initState() {
    super.initState();
    _startAt = planningWallClockNow().add(const Duration(minutes: 30));
  }

  @override
  void dispose() {
    _budgetController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<PoiSearchCubit, PoiSearchState>(
          listener: (context, state) {
            final location = state.currentLocation;
            if (_waitingForCurrentLocation && location != null) {
              setState(() {
                _waitingForCurrentLocation = false;
                _startLocation = location;
                _startLabel = 'Current location';
              });
            }
            if (state.status == PoiSearchStatus.failure &&
                state.message != null) {
              setState(() => _waitingForCurrentLocation = false);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.message!)));
            }
          },
        ),
        BlocListener<CreateItineraryCubit, CreateItineraryState>(
          listener: (context, state) {
            if (state.status == CreateItineraryStatus.failure &&
                state.message != null) {
              setState(() => _formError = state.message);
            }
            if (state.status == CreateItineraryStatus.success &&
                state.result != null) {
              context.pushNamed(
                AppRouteNames.itineraryDetail,
                pathParameters: {
                  'itineraryId': state.result!.itineraryId.toString(),
                },
              );
            }
          },
        ),
      ],
      child: BlocBuilder<CreateItineraryCubit, CreateItineraryState>(
        builder: (context, itineraryState) {
          final isGenerating =
              itineraryState.status == CreateItineraryStatus.generating;
          final isLocating = context.select<PoiSearchCubit, bool>(
            (cubit) => cubit.state.status == PoiSearchStatus.locating,
          );
          return AppPageScaffold(
            title: 'Create itinerary',
            content: [
              const Text(
                'Start with where you are, then choose the places that matter to you.',
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_formError != null) ...[
                AppAlert(message: _formError!, type: AppAlertType.error),
                const SizedBox(height: AppSpacing.md),
              ],
              _LocationCard(
                title: 'Starting point',
                value: _startLabel,
                isLocating: isLocating,
                onCurrentLocation: isGenerating || isLocating
                    ? null
                    : _useCurrentLocation,
                onChoosePlace: isGenerating ? null : _showStartPicker,
              ),
              const SizedBox(height: AppSpacing.md),
              _PoiField(
                label: 'Explore around',
                value: _explorationPoi?.name,
                helper: 'Choose the area or attraction you want to explore.',
                onTap: isGenerating || _startLocation == null
                    ? null
                    : () => _showPoiPicker(_PoiTarget.exploration),
              ),
              const SizedBox(height: AppSpacing.md),
              _PoiField(
                label: 'Finish at',
                value: _returnToStart ? null : _endPoi?.name,
                helper: _returnToStart
                    ? 'Turn off "Return to starting point" below to choose '
                          'where the trip ends.'
                    : 'Choose where the trip ends.',
                onTap: isGenerating || _returnToStart || _startLocation == null
                    ? null
                    : () => _showPoiPicker(_PoiTarget.end),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Return to starting point'),
                value: _returnToStart,
                onChanged: isGenerating
                    ? null
                    : (value) => setState(() => _returnToStart = value),
              ),
              const SizedBox(height: AppSpacing.md),
              _SettingsCard(
                startAt: _startAt,
                availableMinutes: _availableMinutes,
                transportMode: _transportMode,
                restPreference: _restPreference,
                searchRadiusKm: _searchRadiusKm,
                budgetController: _budgetController,
                budgetError: _budgetError,
                enabled: !isGenerating,
                onStartAtChanged: _pickStartTime,
                hoursController: _hoursController,
                minutesController: _minutesController,
                durationError: _durationError,
                onDurationChanged: (_) => _updateDuration(),
                onTransportChanged: (value) =>
                    setState(() => _transportMode = value),
                onRestChanged: (value) =>
                    setState(() => _restPreference = value),
                onRadiusChanged: (value) => setState(() {
                  _searchRadiusKm = value;
                  _mandatoryPois.clear();
                }),
                onBudgetChanged: _updateBudget,
              ),
              const SizedBox(height: AppSpacing.md),
              _MandatoryPois(
                pois: _mandatoryPois,
                enabled: !isGenerating && _startLocation != null,
                onAdd: () => _showPoiPicker(_PoiTarget.mandatory),
                onRemove: (poi) => setState(() => _mandatoryPois.remove(poi)),
              ),
            ],
            footer: AppButton(
              label: 'Generate itinerary',
              isLoading: isGenerating,
              onPressed: isGenerating ? null : _submit,
            ),
          );
        },
      ),
    );
  }

  void _useCurrentLocation() {
    setState(() {
      _formError = null;
      _waitingForCurrentLocation = true;
    });
    context.read<PoiSearchCubit>().useCurrentLocation();
  }

  /// Time available is typed freely (hours + minutes): one hour up to three
  /// days, and the trip may run past midnight.
  void _updateDuration() {
    int? parse(TextEditingController controller) {
      final text = controller.text.trim();
      return text.isEmpty ? 0 : int.tryParse(text);
    }

    final hours = parse(_hoursController);
    final minutes = parse(_minutesController);
    setState(() {
      if (hours == null || minutes == null || minutes > 59) {
        _availableMinutes = null;
        _durationError = 'Enter whole hours and 0–59 minutes.';
        return;
      }
      final total = hours * 60 + minutes;
      if (total < minAvailableMinutes) {
        _availableMinutes = null;
        _durationError = 'Plan at least 1 hour.';
      } else if (total > maxAvailableMinutes) {
        _availableMinutes = null;
        _durationError = 'A trip can last at most 72 hours (3 days).';
      } else {
        _availableMinutes = total;
        _durationError = null;
      }
    });
  }

  void _updateBudget(String text) {
    final normalized = text.replaceAll(',', '').trim();
    if (normalized.isEmpty) {
      setState(() {
        _budgetVnd = null;
        _budgetError = null;
      });
      return;
    }

    final parsed = double.tryParse(normalized);
    setState(() {
      _budgetVnd = parsed != null && parsed.isFinite && parsed > 0
          ? parsed
          : null;
      _budgetError = _budgetVnd == null
          ? 'Enter a positive budget or leave this field blank.'
          : null;
    });
  }

  Future<void> _pickStartTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startAt,
      firstDate: planningWallClockNow(),
      lastDate: planningWallClockNow().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _startAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _showStartPicker() async {
    // The sheet is a separate route outside this page's provider subtree, so
    // the page's cubits are handed to it explicitly.
    final poiSearchCubit = context.read<PoiSearchCubit>();
    final addressSearchCubit = context.read<AddressSearchCubit>();
    final choice = await showModalBottomSheet<_StartChoice>(
      context: context,
      isScrollControlled: true,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: poiSearchCubit),
          BlocProvider.value(value: addressSearchCubit),
        ],
        child: _StartPlacePickerSheet(
          near: _startLocation ?? poiSearchCubit.state.currentLocation,
        ),
      ),
    );
    if (choice == null || !mounted) return;
    setState(() {
      _formError = null;
      _waitingForCurrentLocation = false;
      _startLocation = DeviceLocation(
        latitude: choice.latitude,
        longitude: choice.longitude,
      );
      _startLabel = choice.label;
    });
  }

  Future<void> _showPoiPicker(_PoiTarget target) async {
    // The sheet is a separate route outside this page's provider subtree, so
    // the page's cubit is handed to it explicitly.
    final poiSearchCubit = context.read<PoiSearchCubit>();
    final selected = await showModalBottomSheet<SelectablePoi>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: poiSearchCubit,
        child: _PoiPickerSheet(
          near: switch (target) {
            _PoiTarget.mandatory when _explorationPoi != null => DeviceLocation(
              latitude: _explorationPoi!.latitude,
              longitude: _explorationPoi!.longitude,
            ),
            _ => _startLocation,
          },
          radiusKm: target == _PoiTarget.mandatory
              ? _searchRadiusKm.round()
              : null,
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _formError = null;
      switch (target) {
        case _PoiTarget.exploration:
          _explorationPoi = selected;
          _mandatoryPois.clear();
        case _PoiTarget.end:
          _endPoi = selected;
        case _PoiTarget.mandatory:
          if (_mandatoryPois.length < 6 && !_mandatoryPois.contains(selected)) {
            _mandatoryPois.add(selected);
          }
      }
    });
  }

  void _submit() {
    final startLocation = _startLocation;
    final explorationPoi = _explorationPoi;
    if (startLocation == null || explorationPoi == null) {
      setState(() {
        _formError = 'Choose a starting point and an area to explore.';
      });
      return;
    }

    if (!_returnToStart && _endPoi == null) {
      setState(() {
        _formError =
            'Choose a finishing location or enable "Return to starting point".';
      });
      return;
    }

    if (_budgetError != null) {
      setState(() => _formError = _budgetError);
      return;
    }

    final availableMinutes = _availableMinutes;
    if (availableMinutes == null) {
      setState(() => _formError = _durationError);
      return;
    }

    context.read<CreateItineraryCubit>().generate(
      ItineraryGenerationRequest(
        startAt: formatPlanningDateTime(_startAt),
        timeZoneId: _planningTimeZone,
        startLatitude: startLocation.latitude,
        startLongitude: startLocation.longitude,
        explorationLatitude: explorationPoi.latitude,
        explorationLongitude: explorationPoi.longitude,
        endPoiId: _returnToStart ? null : _endPoi?.id,
        returnToStart: _returnToStart,
        availableMinutes: availableMinutes,
        transportMode: _transportMode,
        searchRadiusKm: _searchRadiusKm,
        mandatoryPoiIds: _mandatoryPois.map((poi) => poi.id).toList(),
        restPreference: _restPreference,
        budgetVnd: _budgetVnd,
      ),
    );
  }
}

enum _PoiTarget { exploration, end, mandatory }

/// A starting point picked from either a geocoded address or a catalog place.
final class _StartChoice {
  const _StartChoice({
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  final String label;
  final double latitude;
  final double longitude;
}

final class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.title,
    required this.value,
    required this.isLocating,
    required this.onCurrentLocation,
    required this.onChoosePlace,
  });

  final String title;
  final String? value;
  final bool isLocating;
  final VoidCallback? onCurrentLocation;
  final VoidCallback? onChoosePlace;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(value ?? 'No starting point selected'),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: onCurrentLocation,
            icon: isLocating
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_outlined),
            label: Text(
              isLocating ? 'Finding your location…' : 'Use current location',
            ),
          ),
          TextButton.icon(
            onPressed: onChoosePlace,
            icon: const Icon(Icons.place_outlined),
            label: const Text('Choose a starting place'),
          ),
        ],
      ),
    ),
  );
}

final class _PoiField extends StatelessWidget {
  const _PoiField({
    required this.label,
    required this.value,
    required this.helper,
    required this.onTap,
  });

  final String label;
  final String? value;
  final String helper;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      enabled: onTap != null,
      title: Text(label),
      subtitle: Text(value ?? helper),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

final class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.startAt,
    required this.availableMinutes,
    required this.transportMode,
    required this.restPreference,
    required this.searchRadiusKm,
    required this.budgetController,
    required this.budgetError,
    required this.hoursController,
    required this.minutesController,
    required this.durationError,
    required this.enabled,
    required this.onStartAtChanged,
    required this.onDurationChanged,
    required this.onTransportChanged,
    required this.onRestChanged,
    required this.onRadiusChanged,
    required this.onBudgetChanged,
  });

  final DateTime startAt;
  final int? availableMinutes;
  final TextEditingController hoursController;
  final TextEditingController minutesController;
  final String? durationError;
  final TransportMode transportMode;
  final RestPreference restPreference;
  final double searchRadiusKm;
  final TextEditingController budgetController;
  final String? budgetError;
  final bool enabled;
  final VoidCallback onStartAtChanged;
  final ValueChanged<String> onDurationChanged;
  final ValueChanged<TransportMode> onTransportChanged;
  final ValueChanged<RestPreference> onRestChanged;
  final ValueChanged<double> onRadiusChanged;
  final ValueChanged<String> onBudgetChanged;

  /// "1 hour to 3 days. Ends Fri, Oct 16, 2026 at 2:30 AM." The trip may
  /// cross midnight.
  String _endLabel(BuildContext context) {
    final minutes = availableMinutes;
    if (minutes == null) return '';
    final end = startAt.add(Duration(minutes: minutes));
    final localizations = MaterialLocalizations.of(context);
    return '1 hour to 3 days. Ends '
        '${localizations.formatMediumDate(end)} at '
        '${TimeOfDay.fromDateTime(end).format(context)}.';
  }

  static const _supportedTransportModes = [
    TransportMode.walking,
    TransportMode.motorbike,
    TransportMode.car,
  ];

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Plan details', style: Theme.of(context).textTheme.titleMedium),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Start time'),
            subtitle: Text(
              '${MaterialLocalizations.of(context).formatMediumDate(startAt)} '
              'at ${TimeOfDay.fromDateTime(startAt).format(context)}',
            ),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: enabled ? onStartAtChanged : null,
          ),
          Text('Time available', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('available_hours_field'),
                  controller: hoursController,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Hours',
                    suffixText: 'h',
                  ),
                  onChanged: enabled ? onDurationChanged : null,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  key: const Key('available_minutes_field'),
                  controller: minutesController,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Minutes',
                    suffixText: 'min',
                  ),
                  onChanged: enabled ? onDurationChanged : null,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Text(
              durationError ?? _endLabel(context),
              key: const Key('available_time_helper'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: durationError == null
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Theme.of(context).colorScheme.error,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<TransportMode>(
            initialValue: transportMode,
            decoration: InputDecoration(labelText: 'How are you travelling?'),
            items: _supportedTransportModes
                .map(
                  (mode) => DropdownMenuItem(
                    value: mode,
                    child: Text(_transportLabel(mode)),
                  ),
                )
                .toList(),
            onChanged: enabled
                ? (value) {
                    if (value != null) onTransportChanged(value);
                  }
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<RestPreference>(
            initialValue: restPreference,
            decoration: const InputDecoration(labelText: 'Break preference'),
            items: RestPreference.values
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(_restLabel(value)),
                  ),
                )
                .toList(),
            onChanged: enabled
                ? (value) {
                    if (value != null) onRestChanged(value);
                  }
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Text('Search radius'),
              const SizedBox(width: AppSpacing.sm),
              Text('${searchRadiusKm.round()} km'),
            ],
          ),
          Slider(
            value: searchRadiusKm,
            min: minSearchRadiusKm.toDouble(),
            max: maxSearchRadiusKm.toDouble(),
            divisions: maxSearchRadiusKm - minSearchRadiusKm,
            label: '${searchRadiusKm.round()} km',
            onChanged: enabled ? onRadiusChanged : null,
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: budgetController,
            enabled: enabled,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Budget (VND, optional)',
              helperText:
                  'POI entry fees only. Food and transport not included.',
              errorText: budgetError,
              prefixText: '₫ ',
            ),
            onChanged: enabled ? onBudgetChanged : null,
          ),
        ],
      ),
    ),
  );
}

final class _MandatoryPois extends StatelessWidget {
  const _MandatoryPois({
    required this.pois,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
  });

  final List<SelectablePoi> pois;
  final bool enabled;
  final VoidCallback onAdd;
  final ValueChanged<SelectablePoi> onRemove;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Must-see places',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text('Optional. Add up to 6 places you do not want to miss.'),
          Wrap(
            spacing: AppSpacing.xs,
            children: pois
                .map(
                  (poi) => InputChip(
                    label: Text(poi.name),
                    onDeleted: enabled ? () => onRemove(poi) : null,
                  ),
                )
                .toList(),
          ),
          TextButton.icon(
            onPressed: enabled && pois.length < 6 ? onAdd : null,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Add a must-see place'),
          ),
        ],
      ),
    ),
  );
}

final class _PoiPickerSheet extends StatefulWidget {
  const _PoiPickerSheet({this.near, this.radiusKm});

  final DeviceLocation? near;
  final int? radiusKm;

  @override
  State<_PoiPickerSheet> createState() => _PoiPickerSheetState();
}

class _PoiPickerSheetState extends State<_PoiPickerSheet> {
  final _queryController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreWhenNearEnd);
    context.read<PoiSearchCubit>().prepareScope(
      near: widget.near,
      radiusKm: widget.radiusKm,
    );
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMoreWhenNearEnd)
      ..dispose();
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose a place',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _queryController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Search places',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _search,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: BlocBuilder<PoiSearchCubit, PoiSearchState>(
                builder: (context, state) {
                  final activeScope = PoiSearchScope.fromLocation(
                    near: widget.near,
                    radiusKm: widget.radiusKm,
                  );
                  if (state.scope != activeScope &&
                      state.status != PoiSearchStatus.searching) {
                    return const Center(
                      child: Text('Search by name to find a place.'),
                    );
                  }
                  if (state.status == PoiSearchStatus.searching) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.status == PoiSearchStatus.failure) {
                    return Center(
                      child: Text(state.message ?? 'Could not load places.'),
                    );
                  }
                  if (state.results.isEmpty) {
                    return const Center(
                      child: Text('Search by name to find a place.'),
                    );
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    itemCount:
                        state.results.length + (state.isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.results.length) {
                        return const Padding(
                          padding: EdgeInsets.all(AppSpacing.md),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final poi = state.results[index];
                      return ListTile(
                        title: Text(poi.name),
                        subtitle: Text(
                          poi.address ??
                              poi.categoryName ??
                              'Point of interest',
                        ),
                        onTap: () => Navigator.of(context).pop(poi),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _search() => context.read<PoiSearchCubit>().search(
    query: _queryController.text,
    near: widget.near,
    radiusKm: widget.radiusKm,
  );

  void _loadMoreWhenNearEnd() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 200) {
      return;
    }
    context.read<PoiSearchCubit>().loadMore();
  }
}

/// Starting-point search over typed addresses (geocoded) and catalog places.
final class _StartPlacePickerSheet extends StatefulWidget {
  const _StartPlacePickerSheet({this.near});

  /// Ranks addresses closer to the Traveler when a location is known.
  final DeviceLocation? near;

  @override
  State<_StartPlacePickerSheet> createState() => _StartPlacePickerSheetState();
}

class _StartPlacePickerSheetState extends State<_StartPlacePickerSheet> {
  final _queryController = TextEditingController();
  var _hasSearched = false;
  DeviceLocation? _near;

  @override
  void initState() {
    super.initState();
    _near = widget.near;
    context.read<PoiSearchCubit>().prepareScope();
    context.read<AddressSearchCubit>().reset();
    if (_near == null) _locateQuietly();
  }

  /// Ranks address results near the Traveler even before a starting point is
  /// chosen, so "FPT University" finds the local campus first. Uses the
  /// location only when permission was already granted: opening this sheet
  /// must not raise a permission prompt.
  Future<void> _locateQuietly() async {
    if (!serviceLocator.isRegistered<DeviceLocationService>()) return;
    final service = serviceLocator<DeviceLocationService>();
    try {
      final permission = await service.checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return;
      }
      final location = await service.getCurrentLocation();
      if (mounted) setState(() => _near = location);
    } catch (_) {
      // Without a location the search simply is not ranked by distance.
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final addressAvailable = context.read<AddressSearchCubit>().isAvailable;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          top: AppSpacing.md,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose a starting place',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _queryController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: addressAvailable
                      ? 'Address or place name'
                      : 'Place name',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _search,
                  ),
                ),
                onSubmitted: (_) => _search(),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: _hasSearched
                    ? ListView(
                        children: [
                          if (addressAvailable) ..._addressSection(context),
                          ..._placeSection(context),
                        ],
                      )
                    : Center(
                        child: Text(
                          addressAvailable
                              ? 'Type a street address, hotel, or place name.'
                              : 'Search by name to find a place.',
                          textAlign: TextAlign.center,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _addressSection(BuildContext context) {
    final state = context.watch<AddressSearchCubit>().state;
    return [
      const _SectionHeader('Addresses'),
      switch (state.status) {
        AddressSearchStatus.searching => const _SectionLoading(),
        AddressSearchStatus.failure => _SectionMessage(
          state.message ?? 'Address search is unavailable right now.',
        ),
        _ when state.candidates.isEmpty => const _SectionMessage(
          'No matching address.',
        ),
        _ => Column(
          children: [
            if (state.message != null) _SectionMessage(state.message!),
            for (final candidate in state.candidates)
              ListTile(
                leading: const Icon(Icons.home_work_outlined),
                title: Text(candidate.name),
                subtitle: Text(candidate.fullAddress),
                trailing: state.resolvingId == candidate.id
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                enabled: state.resolvingId == null,
                onTap: () => _pickAddress(candidate),
              ),
          ],
        ),
      },
    ];
  }

  List<Widget> _placeSection(BuildContext context) {
    final state = context.watch<PoiSearchCubit>().state;
    return [
      const _SectionHeader('Places'),
      switch (state.status) {
        PoiSearchStatus.searching => const _SectionLoading(),
        PoiSearchStatus.failure => _SectionMessage(
          state.message ?? 'Could not load places.',
        ),
        _ when state.results.isEmpty => const _SectionMessage(
          'No matching place.',
        ),
        _ => Column(
          children: [
            for (final poi in state.results)
              ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(poi.name),
                subtitle: Text(
                  poi.address ?? poi.categoryName ?? 'Point of interest',
                ),
                onTap: () => Navigator.of(context).pop(
                  _StartChoice(
                    label: poi.name,
                    latitude: poi.latitude,
                    longitude: poi.longitude,
                  ),
                ),
              ),
          ],
        ),
      },
    ];
  }

  Future<void> _pickAddress(AddressCandidate candidate) async {
    final address = await context.read<AddressSearchCubit>().resolve(candidate);
    if (address == null || !mounted) return;
    Navigator.of(context).pop(
      _StartChoice(
        label: address.label,
        latitude: address.latitude,
        longitude: address.longitude,
      ),
    );
  }

  void _search() {
    final query = _queryController.text;
    setState(() => _hasSearched = true);
    context.read<AddressSearchCubit>().search(query, near: _near);
    context.read<PoiSearchCubit>().search(query: query);
  }
}

final class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
    child: Text(title, style: Theme.of(context).textTheme.titleSmall),
  );
}

final class _SectionLoading extends StatelessWidget {
  const _SectionLoading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(AppSpacing.sm),
    child: Center(child: CircularProgressIndicator()),
  );
}

final class _SectionMessage extends StatelessWidget {
  const _SectionMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Text(message, style: Theme.of(context).textTheme.bodySmall),
  );
}

String _transportLabel(TransportMode mode) => switch (mode) {
  TransportMode.walking => 'Walking',
  TransportMode.motorbike => 'Motorbike',
  TransportMode.car => 'Car',
  TransportMode.publicTransit => 'Public transit',
};

String _restLabel(RestPreference preference) => switch (preference) {
  RestPreference.auto => 'Suggest breaks when useful',
  RestPreference.none => 'No named rest stops',
  RestPreference.frequent => 'Prefer more breaks',
};
