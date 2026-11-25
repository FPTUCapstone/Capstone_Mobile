import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart' show LocationPermission;
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' show MapboxStyles;
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/app/theme/coastal_palette.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/location/device_location_service.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/address_suggestion.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/selectable_poi.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/address_search_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/create_itinerary_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/create_itinerary_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/poi_search_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/poi_search_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/helpers/itinerary_text.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/coastal_date_time_sheets.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/trip_map.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';

final class CreateItineraryPage extends StatefulWidget {
  const CreateItineraryPage({this.useMapbox, super.key});

  /// Defaults to whether a Mapbox token is configured; false renders the
  /// lightweight drawn radius preview (used in widget tests).
  final bool? useMapbox;

  @override
  State<CreateItineraryPage> createState() => _CreateItineraryPageState();
}

class _CreateItineraryPageState extends State<CreateItineraryPage> {
  static const _planningTimeZone = 'Asia/Ho_Chi_Minh';
  static const _quickExploreAreas = [
    'Sơn Trà',
    'Bà Nà Hills',
    'Hội An',
    'Ngũ Hành Sơn',
    'Cầu Rồng',
    'Mỹ Khê',
  ];
  static const _durationPresets = <(String, int)>[
    ('4 giờ', 240),
    ('8 giờ', 480),
    ('12 giờ', 720),
    ('2 ngày', 2880),
  ];

  late final bool _useMapbox =
      widget.useMapbox ??
      (locateOptional<AppConfig>()?.mapboxAccessToken != null);

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
    final palette = CoastalPalette.of(context);
    return MultiBlocListener(
      listeners: [
        BlocListener<PoiSearchCubit, PoiSearchState>(
          listener: (context, state) {
            final location = state.currentLocation;
            if (_waitingForCurrentLocation && location != null) {
              setState(() {
                _waitingForCurrentLocation = false;
                _startLocation = location;
                _startLabel = 'Vị trí hiện tại';
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
                // UC-10: tells the detail page to refresh the AI sentences.
                extra: state.result!.pendingExplanation(DateTime.now()),
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
          return Scaffold(
            backgroundColor: palette.canvas,
            appBar: AppBar(
              backgroundColor: palette.canvas,
              foregroundColor: palette.ink,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              titleSpacing: Navigator.canPop(context) ? 0 : AppSpacing.md,
              title: Text(
                'Lập lịch trình',
                style: TextStyle(
                  fontFamily: AppTypography.displayFont,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: palette.ink,
                ),
              ),
            ),
            body: SafeArea(
              top: false,
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      4,
                      AppSpacing.md,
                      AppSpacing.xl,
                    ),
                    children: [
                      Text(
                        'Chọn điểm đến, thời gian và phương tiện — TripMate tự động sắp xếp cung đường hợp lý nhất.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: palette.secondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_formError != null) ...[
                        AppAlert(
                          message: _formError!,
                          type: AppAlertType.error,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      if (_getTravelFeasibilityWarning()
                          case final travelWarning?) ...[
                        AppAlert(
                          message: travelWarning,
                          type: AppAlertType.warning,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      _JourneyCard(
                        palette: palette,
                        startLabel: _startLabel,
                        hasStartLocation: _startLocation != null,
                        explorationName: _explorationPoi?.name,
                        endName: _endPoi?.name,
                        returnToStart: _returnToStart,
                        isLocating: isLocating,
                        enabled: !isGenerating,
                        quickAreas: _quickExploreAreas,
                        onCurrentLocation: isGenerating || isLocating
                            ? null
                            : _useCurrentLocation,
                        onChooseStart: isGenerating ? null : _showStartPicker,
                        onChooseExploration:
                            isGenerating || _startLocation == null
                            ? null
                            : () => _showPoiPicker(_PoiTarget.exploration),
                        onQuickAreaTap: isGenerating || _startLocation == null
                            ? null
                            : (area) => _showPoiPicker(
                                _PoiTarget.exploration,
                                initialQuery: area,
                              ),
                        onChooseEnd:
                            isGenerating ||
                                _returnToStart ||
                                _startLocation == null
                            ? null
                            : () => _showPoiPicker(_PoiTarget.end),
                        onReturnChanged: isGenerating
                            ? null
                            : (value) => setState(() => _returnToStart = value),
                      ),
                      const SizedBox(height: 12),
                      _SearchRadiusMapCard(
                        palette: palette,
                        useMapbox: _useMapbox,
                        startLocation: _startLocation,
                        explorationPoi: _explorationPoi,
                        searchRadiusKm: _searchRadiusKm,
                        enabled: !isGenerating,
                        onRadiusChanged: (value) => setState(() {
                          _searchRadiusKm = value;
                          final exp = _explorationPoi;
                          if (exp != null) {
                            _mandatoryPois.removeWhere((poi) {
                              if (poi.id == exp.id) return false;
                              final dist = _calculateDistanceKm(
                                exp.latitude,
                                exp.longitude,
                                poi.latitude,
                                poi.longitude,
                              );
                              return dist > value;
                            });
                          } else {
                            _mandatoryPois.clear();
                          }
                        }),
                      ),
                      const SizedBox(height: 12),
                      _SettingsCard(
                        palette: palette,
                        startAt: _startAt,
                        availableMinutes: _availableMinutes,
                        durationPresets: _durationPresets,
                        transportMode: _transportMode,
                        restPreference: _restPreference,
                        budgetController: _budgetController,
                        budgetError: _budgetError,
                        hoursController: _hoursController,
                        minutesController: _minutesController,
                        durationError: _durationError,
                        enabled: !isGenerating,
                        onPickDate: _pickStartDate,
                        onPickTime: _pickStartTimeOnly,
                        onPresetDuration: _applyDurationPreset,
                        onDurationChanged: (_) => _updateDuration(),
                        onTransportChanged: (value) =>
                            setState(() => _transportMode = value),
                        onRestChanged: (value) =>
                            setState(() => _restPreference = value),
                        onBudgetChanged: _updateBudget,
                      ),
                      const SizedBox(height: 12),
                      _MandatoryPois(
                        palette: palette,
                        pois: _mandatoryPois,
                        primaryPoiId: _explorationPoi?.id,
                        enabled: !isGenerating && _startLocation != null,
                        onAdd: () => _showPoiPicker(_PoiTarget.mandatory),
                        onRemove: (poi) =>
                            setState(() => _mandatoryPois.remove(poi)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            bottomNavigationBar: _StickyPlanFooter(
              palette: palette,
              routeLabel: _explorationPoi != null
                  ? 'Đến: ${_explorationPoi!.name}'
                  : (_startLabel != null
                        ? 'Từ: $_startLabel'
                        : 'Chưa chọn hành trình'),
              hasRoute: _startLocation != null || _explorationPoi != null,
              startAt: _startAt,
              availableMinutes: _availableMinutes,
              transportMode: _transportMode,
              searchRadiusKm: _searchRadiusKm,
              isGenerating: isGenerating,
              onSubmit: _submit,
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

  void _applyDurationPreset(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    _hoursController.text = '$hours';
    _minutesController.text = '$minutes';
    setState(() {
      _availableMinutes = totalMinutes;
      _durationError = null;
    });
  }

  double _calculateDistanceKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLng = (lng2 - lng1) * math.pi / 180.0;
    final midLat = ((lat1 + lat2) / 2.0) * math.pi / 180.0;
    final x = dLng * math.cos(midLat);
    final y = dLat;
    return math.sqrt(x * x + y * y) * earthRadiusKm;
  }

  String? _getTravelFeasibilityWarning() {
    final start = _startLocation;
    final exp = _explorationPoi;
    final available = _availableMinutes;
    if (start == null || exp == null || available == null || available <= 0) {
      return null;
    }
    final distKm = _calculateDistanceKm(
      start.latitude,
      start.longitude,
      exp.latitude,
      exp.longitude,
    );

    final speedKmh = switch (_transportMode) {
      TransportMode.walking => 4.5,
      TransportMode.motorbike => 35.0,
      TransportMode.car => 30.0,
      TransportMode.publicTransit => 20.0,
    };
    final roundTripHours = (distKm * 2) / speedKmh;
    final roundTripMinutes = (roundTripHours * 60).round();
    if (roundTripMinutes > 0.5 * available) {
      return 'Lưu ý về thời gian di chuyển: Thời gian di chuyển 2 chiều ước tính '
          'khoảng $roundTripMinutes phút, chiếm hơn 50% thời lượng chuyến đi '
          '($available phút). Bạn nên cân nhắc chọn phương tiện nhanh hơn hoặc '
          'tăng thời lượng chuyến đi.';
    }
    return null;
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
        _durationError = 'Nhập số giờ nguyên và 0–59 phút.';
        return;
      }
      final total = hours * 60 + minutes;
      if (total < minAvailableMinutes) {
        _availableMinutes = null;
        _durationError = 'Thời lượng tối thiểu là 1 giờ.';
      } else if (total > maxAvailableMinutes) {
        _availableMinutes = null;
        _durationError = 'Chuyến đi tối đa 72 giờ (3 ngày).';
      } else {
        _availableMinutes = total;
        _durationError = null;
      }
    });
  }

  void _updateBudget(String text) {
    final normalized = text.replaceAll(',', '').replaceAll('.', '').trim();
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
          ? 'Nhập ngân sách lớn hơn 0 hoặc để trống.'
          : null;
    });
  }

  Future<void> _pickStartDate() async {
    final now = planningWallClockNow();
    final date = await showCoastalDatePickerSheet(
      context: context,
      initialDate: _startAt,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    setState(() {
      _startAt = DateTime(
        date.year,
        date.month,
        date.day,
        _startAt.hour,
        _startAt.minute,
      );
    });
  }

  Future<void> _pickStartTimeOnly() async {
    final time = await showCoastalTimePickerSheet(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startAt),
      selectedDate: _startAt,
      availableMinutes: _availableMinutes,
    );
    if (time == null || !mounted) return;
    setState(() {
      _startAt = DateTime(
        _startAt.year,
        _startAt.month,
        _startAt.day,
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
      showDragHandle: true,
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

  Future<void> _showPoiPicker(_PoiTarget target, {String? initialQuery}) async {
    // The sheet is a separate route outside this page's provider subtree, so
    // the page's cubit is handed to it explicitly.
    final poiSearchCubit = context.read<PoiSearchCubit>();
    final selected = await showModalBottomSheet<SelectablePoi>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
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
          isExploration: target == _PoiTarget.exploration,
          initialQuery: initialQuery,
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _formError = null;
      switch (target) {
        case _PoiTarget.exploration:
          final previousPrimaryId = _explorationPoi?.id;
          _explorationPoi = selected;
          _mandatoryPois.removeWhere((poi) => poi.id == previousPrimaryId);
          if (!_mandatoryPois.any((poi) => poi.id == selected.id)) {
            if (_mandatoryPois.length >= 6) {
              _mandatoryPois.removeLast();
            }
            _mandatoryPois.insert(0, selected);
          }
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
        _formError = 'Vui lòng chọn điểm xuất phát và khu vực khám phá.';
      });
      return;
    }

    if (!_returnToStart && _endPoi == null) {
      setState(() {
        _formError =
            'Vui lòng chọn điểm kết thúc hoặc bật "Quay về điểm xuất phát".';
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

/// Above this radius the form warns that stops may be far apart (Review 2).
const _wideRadiusKm = 30;

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

final class _JourneyCard extends StatelessWidget {
  const _JourneyCard({
    required this.palette,
    required this.startLabel,
    required this.hasStartLocation,
    required this.explorationName,
    required this.endName,
    required this.returnToStart,
    required this.isLocating,
    required this.enabled,
    required this.quickAreas,
    required this.onCurrentLocation,
    required this.onChooseStart,
    required this.onChooseExploration,
    required this.onQuickAreaTap,
    required this.onChooseEnd,
    required this.onReturnChanged,
  });

  final CoastalPalette palette;
  final String? startLabel;
  final bool hasStartLocation;
  final String? explorationName;
  final String? endName;
  final bool returnToStart;
  final bool isLocating;
  final bool enabled;
  final List<String> quickAreas;
  final VoidCallback? onCurrentLocation;
  final VoidCallback? onChooseStart;
  final VoidCallback? onChooseExploration;
  final ValueChanged<String>? onQuickAreaTap;
  final VoidCallback? onChooseEnd;
  final ValueChanged<bool>? onReturnChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1. Hành trình của bạn',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Chọn tự do điểm xuất phát và khu vực muốn khám phá',
            style: TextStyle(fontSize: 11.5, color: palette.secondary),
          ),
          const SizedBox(height: 14),
          // Point A with vertical dashed connector down to Point B (Web parity)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      _RouteBadge(label: 'A', background: palette.primary),
                      Expanded(
                        child: CustomPaint(
                          size: const Size(2, double.infinity),
                          painter: _DashedConnectorPainter(
                            color: palette.border,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Điểm xuất phát',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: palette.ink,
                                ),
                              ),
                            ),
                            FilledButton.tonal(
                              key: const Key('use_current_location_button'),
                              style: FilledButton.styleFrom(
                                backgroundColor: palette.softAccent,
                                foregroundColor: palette.primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: const StadiumBorder(),
                                textStyle: const TextStyle(
                                  fontFamily: AppTypography.uiFont,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onPressed: onCurrentLocation,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isLocating) ...[
                                    const SizedBox.square(
                                      dimension: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.8,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                  ],
                                  Text(
                                    isLocating
                                        ? 'Đang tìm vị trí…'
                                        : 'Dùng vị trí hiện tại',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _PickerBox(
                          key: const Key('choose_start_place_field'),
                          palette: palette,
                          text: startLabel ?? 'Chưa chọn điểm xuất phát',
                          actionLabel: startLabel == null ? 'Chọn' : 'Đổi',
                          hasValue: startLabel != null,
                          onTap: onChooseStart,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Point B: Exploration area
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      _RouteIconBadge(
                        icon: Icons.star,
                        background: palette.accent,
                      ),
                      if (!returnToStart)
                        Expanded(
                          child: CustomPaint(
                            size: const Size(2, double.infinity),
                            painter: _DashedConnectorPainter(
                              color: palette.border,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Khu vực khám phá',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: palette.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _PickerBox(
                        key: const Key('explore_around_field'),
                        palette: palette,
                        text:
                            explorationName ??
                            (hasStartLocation
                                ? 'Chọn khu vực hoặc điểm tham quan...'
                                : 'Chọn điểm xuất phát trước để mở khóa'),
                        actionLabel: explorationName == null ? 'Chọn' : 'Đổi',
                        hasValue: explorationName != null,
                        onTap: onChooseExploration,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Gợi ý nhanh:',
                            style: TextStyle(
                              fontSize: 11,
                              color: palette.secondary,
                            ),
                          ),
                          for (final area in quickAreas)
                            Builder(
                              builder: (context) {
                                final isSelected =
                                    explorationName != null &&
                                    explorationName!.toLowerCase().contains(
                                      area.toLowerCase(),
                                    );
                                return InkWell(
                                  borderRadius: BorderRadius.circular(999),
                                  onTap: onQuickAreaTap == null
                                      ? null
                                      : () => onQuickAreaTap!(area),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? palette.softAccent
                                          : palette.surface,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: isSelected
                                            ? palette.primary
                                            : palette.border,
                                      ),
                                    ),
                                    child: Text(
                                      area,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? palette.primary
                                            : (onQuickAreaTap == null
                                                  ? palette.secondary
                                                  : palette.ink),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!returnToStart) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: _RouteIconBadge(
                    icon: Icons.flag_outlined,
                    background: palette.ink,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Điểm kết thúc',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: palette.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _PickerBox(
                        key: const Key('finish_at_field'),
                        palette: palette,
                        text: endName ?? 'Chọn nơi kết thúc chuyến đi...',
                        actionLabel: endName == null ? 'Chọn' : 'Đổi',
                        hasValue: endName != null,
                        onTap: onChooseEnd,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: palette.border, height: 1),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quay về điểm xuất phát khi kết thúc hành trình',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: palette.ink,
                      ),
                    ),
                    Text(
                      'Tắt đi nếu bạn muốn kết thúc chuyến đi tại một địa điểm khác',
                      style: TextStyle(fontSize: 11, color: palette.secondary),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: returnToStart,
                activeThumbColor: Colors.white,
                activeTrackColor: palette.primary,
                onChanged: onReturnChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _RouteBadge extends StatelessWidget {
  const _RouteBadge({required this.label, required this.background});

  final String label;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

final class _RouteIconBadge extends StatelessWidget {
  const _RouteIconBadge({required this.icon, required this.background});

  final IconData icon;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: 12, color: Colors.white),
    );
  }
}

final class _PickerBox extends StatelessWidget {
  const _PickerBox({
    required this.palette,
    required this.text,
    required this.actionLabel,
    required this.hasValue,
    required this.onTap,
    super.key,
  });

  final CoastalPalette palette;
  final String text;
  final String actionLabel;
  final bool hasValue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? palette.surface : palette.canvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(11),
        side: BorderSide(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                    color: hasValue ? palette.ink : palette.secondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                actionLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: enabled ? palette.primary : palette.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _DashedConnectorPainter extends CustomPainter {
  const _DashedConnectorPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const dash = 4.0;
    const gap = 3.5;
    var y = 4.0;
    while (y < size.height - 4) {
      final endY = math.min(y + dash, size.height - 4);
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, endY),
        paint,
      );
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedConnectorPainter oldDelegate) =>
      oldDelegate.color != color;
}

final class _SearchRadiusMapCard extends StatelessWidget {
  const _SearchRadiusMapCard({
    required this.palette,
    required this.useMapbox,
    required this.startLocation,
    required this.explorationPoi,
    required this.searchRadiusKm,
    required this.enabled,
    required this.onRadiusChanged,
  });

  final CoastalPalette palette;
  final bool useMapbox;
  final DeviceLocation? startLocation;
  final SelectablePoi? explorationPoi;
  final double searchRadiusKm;
  final bool enabled;
  final ValueChanged<double> onRadiusChanged;

  @override
  Widget build(BuildContext context) {
    final radiusInt = searchRadiusKm.round();
    final hasAnyPoint = startLocation != null || explorationPoi != null;
    final circleCenter = explorationPoi != null
        ? NavigationCoordinate(
            latitude: explorationPoi!.latitude,
            longitude: explorationPoi!.longitude,
          )
        : (startLocation != null
              ? NavigationCoordinate(
                  latitude: startLocation!.latitude,
                  longitude: startLocation!.longitude,
                )
              : null);

    return Container(
      key: const Key('search_radius_map_card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bản đồ khu vực & Bán kính tìm kiếm',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Xem trước vị trí xuất phát và phạm vi gợi ý',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: palette.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.softAccent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$radiusInt km',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: palette.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 185,
              decoration: BoxDecoration(
                border: Border.all(color: palette.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: !hasAnyPoint
                  ? _EmptyRadiusMapPlaceholder(
                      palette: palette,
                      radiusKm: radiusInt,
                    )
                  : (useMapbox
                        ? _buildLiveMap(circleCenter!)
                        : _RadiusFallbackCanvas(
                            palette: palette,
                            hasStart: startLocation != null,
                            hasExploration: explorationPoi != null,
                            radiusKm: radiusInt,
                          )),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Bán kính tìm kiếm',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                  ),
                ),
              ),
              Text(
                'R = $radiusInt km',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: palette.ink,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: palette.primary,
              thumbColor: palette.primary,
              inactiveTrackColor: palette.border,
              trackHeight: 3.5,
            ),
            child: Slider(
              value: searchRadiusKm,
              min: minSearchRadiusKm.toDouble(),
              max: maxSearchRadiusKm.toDouble(),
              divisions: maxSearchRadiusKm - minSearchRadiusKm,
              label: '$radiusInt km',
              onChanged: enabled ? onRadiusChanged : null,
            ),
          ),
          Row(
            children: [
              Flexible(
                child: Text(
                  '1 km (Gần)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: palette.secondary),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '50 km (Ngoại ô)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10.5, color: palette.secondary),
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '100 km (Liên tỉnh)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 10.5, color: palette.secondary),
                ),
              ),
            ],
          ),
          if (radiusInt > _wideRadiusKm)
            Padding(
              key: const Key('wide_radius_warning'),
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Trên $_wideRadiusKm km, các điểm có thể cách xa nhau: mất nhiều '
                'thời gian di chuyển hơn và ít điểm vừa lịch trình hơn.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palette.error),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLiveMap(NavigationCoordinate circleCenter) {
    final ring = tripMapCircleRing(circleCenter, searchRadiusKm);
    final markers = <TripMapMarker>[
      if (startLocation case final start?)
        TripMapMarker(
          id: 1,
          coordinate: NavigationCoordinate(
            latitude: start.latitude,
            longitude: start.longitude,
          ),
          label: 'Điểm xuất phát',
          badge: 'A',
          color: palette.primary,
          showLabel: false,
        ),
      if (explorationPoi case final exp?)
        TripMapMarker(
          id: 2,
          coordinate: NavigationCoordinate(
            latitude: exp.latitude,
            longitude: exp.longitude,
          ),
          label: exp.name,
          badge: '★',
          color: palette.accent,
          showLabel: false,
        ),
    ];
    return TripMap(
      mapWidgetKey: const ValueKey('mapbox-plan-radius-map'),
      styleUri: MapboxStyles.MAPBOX_STREETS,
      camera: TripMapCamera.fitMarkers,
      showUserLocation: false,
      markers: markers,
      polygons: [
        TripMapPolygon(
          points: ring,
          fillColor: palette.primary,
          fillOpacity: 0.14,
          outlineColor: palette.primary,
        ),
      ],
      lines: [
        TripMapLine(
          points: ring,
          color: palette.primary,
          width: 2.0,
          opacity: 0.72,
        ),
      ],
    );
  }
}

final class _EmptyRadiusMapPlaceholder extends StatelessWidget {
  const _EmptyRadiusMapPlaceholder({
    required this.palette,
    required this.radiusKm,
  });

  final CoastalPalette palette;
  final int radiusKm;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: _CoastalMapBackdropPainter(
            primary: palette.primary,
            accent: palette.accent,
            showPins: false,
          ),
        ),
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: palette.surface.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Chọn điểm xuất phát hoặc khu vực khám phá để kích hoạt bản đồ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'TripMate sẽ tìm kiếm các địa điểm trong bán kính $radiusKm km',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: palette.secondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

final class _RadiusFallbackCanvas extends StatelessWidget {
  const _RadiusFallbackCanvas({
    required this.palette,
    required this.hasStart,
    required this.hasExploration,
    required this.radiusKm,
  });

  final CoastalPalette palette;
  final bool hasStart;
  final bool hasExploration;
  final int radiusKm;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: _CoastalMapBackdropPainter(
            primary: palette.primary,
            accent: palette.accent,
            showPins: true,
            hasStart: hasStart,
            hasExploration: hasExploration,
          ),
        ),
        Positioned(
          left: 10,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: palette.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: palette.border),
            ),
            child: Text(
              'Phạm vi $radiusKm km',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: palette.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

final class _CoastalMapBackdropPainter extends CustomPainter {
  const _CoastalMapBackdropPainter({
    required this.primary,
    required this.accent,
    required this.showPins,
    this.hasStart = false,
    this.hasExploration = false,
  });

  final Color primary;
  final Color accent;
  final bool showPins;
  final bool hasStart;
  final bool hasExploration;

  @override
  void paint(Canvas canvas, Size size) {
    // Soft coastal sea + land backdrop matching Mapbox streets tone.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFD6EEF8),
    );
    final landPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.62, 0)
      ..quadraticBezierTo(
        size.width * 0.56,
        size.height * 0.45,
        size.width * 0.72,
        size.height,
      )
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(landPath, Paint()..color = const Color(0xFFF3F0E6));

    // Subtle river & road accents.
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    canvas
      ..drawLine(
        Offset(size.width * 0.1, size.height * 0.35),
        Offset(size.width * 0.65, size.height * 0.55),
        roadPaint,
      )
      ..drawLine(
        Offset(size.width * 0.42, 0),
        Offset(size.width * 0.52, size.height),
        roadPaint,
      );

    // Translucent search radius circle + dashed outline.
    final center = Offset(size.width * 0.58, size.height * 0.48);
    final radius = math.min(size.width, size.height) * 0.33;
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = primary.withValues(alpha: 0.14),
    );
    final ringPaint = Paint()
      ..color = primary.withValues(alpha: 0.7)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    const dashCount = 24;
    for (var i = 0; i < dashCount; i++) {
      final startAngle = (2 * math.pi * i) / dashCount;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        (math.pi / dashCount) * 1.15,
        false,
        ringPaint,
      );
    }

    if (showPins) {
      if (hasStart) {
        final p = Offset(size.width * 0.42, size.height * 0.42);
        canvas
          ..drawCircle(p, 10, Paint()..color = primary)
          ..drawCircle(
            p,
            10,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
      }
      if (hasExploration) {
        canvas
          ..drawCircle(center, 10, Paint()..color = accent)
          ..drawCircle(
            center,
            10,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CoastalMapBackdropPainter oldDelegate) =>
      oldDelegate.showPins != showPins ||
      oldDelegate.hasStart != hasStart ||
      oldDelegate.hasExploration != hasExploration;
}

final class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.palette,
    required this.startAt,
    required this.availableMinutes,
    required this.durationPresets,
    required this.transportMode,
    required this.restPreference,
    required this.budgetController,
    required this.budgetError,
    required this.hoursController,
    required this.minutesController,
    required this.durationError,
    required this.enabled,
    required this.onPickDate,
    required this.onPickTime,
    required this.onPresetDuration,
    required this.onDurationChanged,
    required this.onTransportChanged,
    required this.onRestChanged,
    required this.onBudgetChanged,
  });

  final CoastalPalette palette;
  final DateTime startAt;
  final int? availableMinutes;
  final List<(String, int)> durationPresets;
  final TextEditingController hoursController;
  final TextEditingController minutesController;
  final String? durationError;
  final TransportMode transportMode;
  final RestPreference restPreference;
  final TextEditingController budgetController;
  final String? budgetError;
  final bool enabled;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final ValueChanged<int> onPresetDuration;
  final ValueChanged<String> onDurationChanged;
  final ValueChanged<TransportMode> onTransportChanged;
  final ValueChanged<RestPreference> onRestChanged;
  final ValueChanged<String> onBudgetChanged;

  static const _supportedTransportModes = [
    (TransportMode.walking, Icons.directions_walk, 'Đi bộ'),
    (TransportMode.motorbike, Icons.two_wheeler, 'Xe máy'),
    (TransportMode.car, Icons.directions_car_outlined, 'Ô tô'),
  ];

  static const _restChoices = [
    (RestPreference.auto, 'Tự động'),
    (RestPreference.none, 'Không nghỉ'),
    (RestPreference.frequent, 'Nghỉ nhiều'),
  ];

  String _dateLabel() {
    final dd = startAt.day.toString().padLeft(2, '0');
    final mm = startAt.month.toString().padLeft(2, '0');
    return '$dd/$mm/${startAt.year}';
  }

  String _timeLabel(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _endBadgeLabel() {
    final minutes = availableMinutes;
    if (minutes == null) return '';
    final end = startAt.add(Duration(minutes: minutes));
    final sameDay =
        end.year == startAt.year &&
        end.month == startAt.month &&
        end.day == startAt.day;
    if (sameDay) {
      return '${_timeLabel(startAt)} → ${_timeLabel(end)} (cùng ngày)';
    }
    final dd = end.day.toString().padLeft(2, '0');
    final mm = end.month.toString().padLeft(2, '0');
    return '${_timeLabel(startAt)} → ${_timeLabel(end)} ($dd/$mm)';
  }

  String _endHelperLabel() {
    final minutes = availableMinutes;
    if (minutes == null) return '';
    final end = startAt.add(Duration(minutes: minutes));
    final dd = end.day.toString().padLeft(2, '0');
    final mm = end.month.toString().padLeft(2, '0');
    return 'Từ 1 giờ đến 3 ngày. Kết thúc lúc ${_timeLabel(end)} ngày $dd/$mm/${end.year}.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '2. Thời gian & Phương tiện',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Chuyến đi từ 1 giờ đến 3 ngày, có thể kéo dài qua đêm',
            style: TextStyle(fontSize: 11.5, color: palette.secondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniTapField(
                  fieldKey: const Key('start_date_field'),
                  palette: palette,
                  label: 'Ngày bắt đầu',
                  value: _dateLabel(),
                  icon: Icons.calendar_today_outlined,
                  onTap: enabled ? onPickDate : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniTapField(
                  fieldKey: const Key('start_time_field'),
                  palette: palette,
                  label: 'Giờ xuất phát',
                  value: _timeLabel(startAt),
                  icon: Icons.schedule_outlined,
                  onTap: enabled ? onPickTime : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Thời lượng dự kiến',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                  ),
                ),
              ),
              if (availableMinutes != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: palette.softAccent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _endBadgeLabel(),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: palette.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final (label, mins) in durationPresets) ...[
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: enabled ? () => onPresetDuration(mins) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: availableMinutes == mins
                            ? palette.primary
                            : palette.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: availableMinutes == mins
                              ? palette.primary
                              : palette.border,
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: availableMinutes == mins
                              ? palette.onPrimary
                              : palette.ink,
                        ),
                      ),
                    ),
                  ),
                ),
                if (mins != durationPresets.last.$2) const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 10),
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
                    labelText: 'Giờ',
                    suffixText: 'g',
                    isDense: true,
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
                    labelText: 'Phút',
                    suffixText: 'ph',
                    isDense: true,
                  ),
                  onChanged: enabled ? onDurationChanged : null,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              durationError ?? _endHelperLabel(),
              key: const Key('available_time_helper'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: durationError == null
                    ? palette.secondary
                    : palette.error,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Phương tiện di chuyển',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final (mode, icon, label) in _supportedTransportModes) ...[
                Expanded(
                  child: InkWell(
                    key: ValueKey('transport_${mode.name}'),
                    borderRadius: BorderRadius.circular(11),
                    onTap: enabled ? () => onTransportChanged(mode) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: transportMode == mode
                            ? palette.softAccent
                            : palette.surface,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: transportMode == mode
                              ? palette.primary
                              : palette.border,
                          width: transportMode == mode ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icon,
                            size: 16,
                            color: transportMode == mode
                                ? palette.primary
                                : palette.secondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: transportMode == mode
                                  ? palette.primary
                                  : palette.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (mode != TransportMode.car) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Nhịp độ nghỉ ngơi',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final (pref, label) in _restChoices) ...[
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: enabled ? () => onRestChanged(pref) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: restPreference == pref
                            ? palette.softAccent
                            : palette.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: restPreference == pref
                              ? palette.primary
                              : palette.border,
                          width: restPreference == pref ? 1.4 : 1,
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: restPreference == pref
                              ? palette.primary
                              : palette.ink,
                        ),
                      ),
                    ),
                  ),
                ),
                if (pref != RestPreference.frequent) const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: budgetController,
            enabled: enabled,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Ngân sách (VNĐ, tùy chọn)',
              helperText: 'Chỉ tính vé tham quan và ăn uống dự kiến.',
              errorText: budgetError,
              prefixText: '₫ ',
            ),
            onChanged: enabled ? onBudgetChanged : null,
          ),
        ],
      ),
    );
  }
}

final class _MiniTapField extends StatelessWidget {
  const _MiniTapField({
    required this.palette,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.fieldKey,
  });

  final CoastalPalette palette;
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: palette.ink,
          ),
        ),
        const SizedBox(height: 5),
        Material(
          key: fieldKey,
          color: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: palette.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: palette.ink,
                      ),
                    ),
                  ),
                  Icon(icon, size: 15, color: palette.secondary),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

final class _MandatoryPois extends StatelessWidget {
  const _MandatoryPois({
    required this.palette,
    required this.pois,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
    this.primaryPoiId,
  });

  final CoastalPalette palette;
  final List<SelectablePoi> pois;
  final bool enabled;
  final VoidCallback onAdd;
  final ValueChanged<SelectablePoi> onRemove;
  final int? primaryPoiId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '3. Điểm nhất định ghé (tùy chọn)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Chọn tối đa 6 địa điểm bạn không muốn bỏ lỡ.',
            style: TextStyle(fontSize: 11.5, color: palette.secondary),
          ),
          if (pois.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: 4,
              children: pois.map((poi) {
                final isPrimary = poi.id == primaryPoiId;
                return InputChip(
                  label: Text(
                    isPrimary ? '${poi.name} (Điểm chính)' : poi.name,
                  ),
                  onDeleted: enabled ? () => onRemove(poi) : null,
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.primary,
              side: BorderSide(color: palette.border),
            ),
            onPressed: enabled && pois.length < 6 ? onAdd : null,
            icon: const Icon(Icons.add_location_alt_outlined, size: 18),
            label: const Text('Thêm điểm nhất định ghé'),
          ),
        ],
      ),
    );
  }
}

final class _StickyPlanFooter extends StatelessWidget {
  const _StickyPlanFooter({
    required this.palette,
    required this.routeLabel,
    required this.hasRoute,
    required this.startAt,
    required this.availableMinutes,
    required this.transportMode,
    required this.searchRadiusKm,
    required this.isGenerating,
    required this.onSubmit,
  });

  final CoastalPalette palette;
  final String routeLabel;
  final bool hasRoute;
  final DateTime startAt;
  final int? availableMinutes;
  final TransportMode transportMode;
  final double searchRadiusKm;
  final bool isGenerating;
  final VoidCallback onSubmit;

  String _hhmm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _timeSummary() {
    final minutes = availableMinutes;
    if (minutes == null) return 'Thời lượng chưa hợp lệ';
    final end = startAt.add(Duration(minutes: minutes));
    final dd = startAt.day.toString().padLeft(2, '0');
    final mm = startAt.month.toString().padLeft(2, '0');
    final shortDur = minutes % 60 == 0
        ? '${minutes ~/ 60}h'
        : '${minutes ~/ 60}h${minutes % 60}p';
    return '$shortDur ($dd/$mm • ${_hhmm(startAt)}–${_hhmm(end)})';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  _SummaryPill(
                    label: routeLabel,
                    palette: palette,
                    highlighted: hasRoute,
                    maxWidth: 132,
                  ),
                  _SummaryPill(label: _timeSummary(), palette: palette),
                  _SummaryPill(
                    label: transportLabel(transportMode),
                    palette: palette,
                  ),
                  _SummaryPill(
                    label: 'R = ${searchRadiusKm.round()} km',
                    palette: palette,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: palette.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isGenerating ? null : onSubmit,
                  child: isGenerating
                      ? SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: palette.onPrimary,
                          ),
                        )
                      : const Text('Tạo lịch trình tối ưu'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.palette,
    this.highlighted = false,
    this.maxWidth,
  });

  final String label;
  final CoastalPalette palette;
  final bool highlighted;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        color: highlighted ? palette.primary : palette.ink,
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: highlighted ? palette.softAccent : palette.canvas,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted ? palette.softAccent : palette.border,
        ),
      ),
      child: maxWidth == null
          ? text
          : ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth!),
              child: text,
            ),
    );
  }
}

final class _PoiPickerSheet extends StatefulWidget {
  const _PoiPickerSheet({
    this.near,
    this.radiusKm,
    this.isExploration = false,
    this.initialQuery,
  });

  final DeviceLocation? near;
  final int? radiusKm;
  final bool isExploration;
  final String? initialQuery;

  @override
  State<_PoiPickerSheet> createState() => _PoiPickerSheetState();
}

class _PoiPickerSheetState extends State<_PoiPickerSheet> {
  final _queryController = TextEditingController();
  final _scrollController = ScrollController();

  static const _popularSuggestions = [
    'Bà Nà Hills',
    'Sơn Trà',
    'Ngũ Hành Sơn',
    'Cầu Rồng',
    'Mỹ Khê',
    'Hội An',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreWhenNearEnd);
    final seed = widget.initialQuery?.trim();
    if (seed != null && seed.isNotEmpty) {
      _queryController.text = seed;
    }
    context.read<PoiSearchCubit>().prepareScope(
      near: widget.near,
      radiusKm: widget.radiusKm,
    );
    if (widget.isExploration || (seed != null && seed.isNotEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _search();
      });
    }
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
        top: AppSpacing.xs,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chọn địa điểm',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _queryController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Tìm kiếm địa điểm',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _search,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
            if (widget.isExploration) ...[
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xxs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Gợi ý:',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  for (final suggestion in _popularSuggestions)
                    ActionChip(
                      label: Text(suggestion),
                      labelStyle: Theme.of(context).textTheme.bodySmall,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onPressed: () {
                        _queryController.text = suggestion;
                        _search();
                      },
                    ),
                ],
              ),
            ],
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
                      child: Text('Nhập tên để tìm địa điểm.'),
                    );
                  }
                  if (state.status == PoiSearchStatus.searching) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.status == PoiSearchStatus.failure) {
                    return Center(
                      child: Text(
                        state.message ?? 'Không thể tải danh sách địa điểm.',
                      ),
                    );
                  }
                  if (state.results.isEmpty) {
                    return const Center(
                      child: Text('Nhập tên để tìm địa điểm.'),
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
                          poi.address ?? poi.categoryName ?? 'Điểm tham quan',
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
          top: AppSpacing.xs,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chọn điểm xuất phát',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _queryController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: addressAvailable
                      ? 'Địa chỉ hoặc tên địa điểm'
                      : 'Tên địa điểm',
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
                              ? 'Nhập tên đường, khách sạn hoặc địa điểm.'
                              : 'Nhập tên để tìm địa điểm.',
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
      const _SectionHeader('Địa chỉ'),
      switch (state.status) {
        AddressSearchStatus.searching => const _SectionLoading(),
        AddressSearchStatus.failure => _SectionMessage(
          state.message ?? 'Tìm kiếm địa chỉ hiện không khả dụng.',
        ),
        _ when state.candidates.isEmpty => const _SectionMessage(
          'Không tìm thấy địa chỉ phù hợp.',
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
      const _SectionHeader('Địa điểm'),
      switch (state.status) {
        PoiSearchStatus.searching => const _SectionLoading(),
        PoiSearchStatus.failure => _SectionMessage(
          state.message ?? 'Không thể tải danh sách địa điểm.',
        ),
        _ when state.results.isEmpty => const _SectionMessage(
          'Không tìm thấy địa điểm phù hợp.',
        ),
        _ => Column(
          children: [
            for (final poi in state.results)
              ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(poi.name),
                subtitle: Text(
                  poi.address ?? poi.categoryName ?? 'Điểm tham quan',
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
