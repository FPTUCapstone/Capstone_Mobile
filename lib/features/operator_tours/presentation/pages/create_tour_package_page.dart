import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_detail.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_draft.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/cubit/create_tour_package_cubit.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/cubit/create_tour_package_state.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/pages/operator_tours_page.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/widgets/tour_package_widgets.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_summary.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_list_cubit.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_list_state.dart';

const _photosStep = 3;
const _reviewStep = 4;

/// Four-step-plus-photos editor for one tour package. With [initial] it edits (or, for a package
/// that is no longer a Draft/Rejected, only shows) an existing package; without it, it creates one.
final class CreateTourPackagePage extends StatefulWidget {
  const CreateTourPackagePage({this.initial, super.key});
  final TourPackageDetail? initial;
  @override
  State<CreateTourPackagePage> createState() => _CreateTourPackagePageState();
}

final class _CreateTourPackagePageState extends State<CreateTourPackagePage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _duration = TextEditingController(text: '1');
  final _inclusions = TextEditingController();
  final _exclusions = TextEditingController();
  final _highlights = TextEditingController();
  final _requirements = TextEditingController();
  final List<_TourStop> _stops = [];
  final List<_Departure> _departures = [];
  // Catalogue ids in the order the operator chose them (the order is the display order).
  final List<int> _destinationIds = [];
  int? _policyId;
  var _step = 0;

  bool get _isEditing => widget.initial != null;

  /// A package that is awaiting review, approved or published cannot be changed.
  bool get _readOnly => _isEditing && !widget.initial!.status.isEditable;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial == null) {
      final start = DateTime.now().add(const Duration(days: 1));
      _departures.add(
        _Departure(start: start, end: start.add(const Duration(hours: 8))),
      );
      return;
    }
    final names = context.read<CreateTourPackageCubit>().state.poiNames;
    _title.text = initial.title;
    _description.text = initial.description;
    _price.text = initial.basePrice.toString();
    _duration.text = '${initial.durationDays}';
    _inclusions.text = initial.inclusions ?? '';
    _exclusions.text = initial.exclusions ?? '';
    _highlights.text = initial.highlights ?? '';
    _requirements.text = initial.travellerRequirements ?? '';
    _destinationIds.addAll(initial.destinationIds);
    _policyId = initial.cancellationPolicyTemplateId;
    final ordered = [...initial.itineraryItems]
      ..sort((a, b) {
        final byDay = a.dayNo.compareTo(b.dayNo);
        return byDay != 0 ? byDay : a.sequenceNo.compareTo(b.sequenceNo);
      });
    for (final item in ordered) {
      _stops.add(
        _TourStop(
          poiId: item.poiId,
          name: names[item.poiId] ?? 'Point of interest #${item.poiId}',
          dayNo: item.dayNo,
          stayMinutes: item.stayDurationMinutes,
          plannedTime: item.plannedTime,
          notes: item.notes,
        ),
      );
    }
    for (final departure in initial.departures) {
      _departures.add(
        _Departure(
          start: departure.startAtUtc.toLocal(),
          end: departure.endAtUtc.toLocal(),
          capacity: departure.totalCapacity,
          minimumCapacity: departure.minimumCapacity,
          adultPrice: departure.adultPrice,
          childPrice: departure.childPrice,
          infantPrice: departure.infantPrice,
          meetingPoint: departure.meetingPoint ?? '',
          registrationDeadline: departure.registrationDeadlineAtUtc?.toLocal(),
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _description,
      _price,
      _duration,
      _inclusions,
      _exclusions,
      _highlights,
      _requirements,
    ]) {
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
    if (mounted && poi != null) {
      setState(
        () => _stops.add(
          _TourStop(
            poiId: poi.id,
            name: poi.name,
            isOpenNow: poi.isOpenNow,
            stayMinutes: poi.averageVisitDurationMinutes > 0
                ? poi.averageVisitDurationMinutes
                : 60,
          ),
        ),
      );
    }
  }

  Future<void> _editStop(int index) async {
    if (_readOnly) return;
    final old = _stops[index];
    final day = TextEditingController(text: '${old.dayNo}');
    final stay = TextEditingController(text: '${old.stayMinutes}');
    final result = await showDialog<_TourStop>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(old.name),
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
    if (_readOnly) return;
    final old = _departures[index];
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: old.start.isBefore(now) ? now : old.start,
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
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
    DateTime? deadline = old.registrationDeadline;
    final result = await showDialog<_Departure>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Departure schedule'),
          content: SingleChildScrollView(
            child: Column(
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
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Adult price (whole VND)',
                  ),
                ),
                TextField(
                  controller: childPrice,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Child price (optional)',
                  ),
                ),
                TextField(
                  controller: infantPrice,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Infant price (optional)',
                  ),
                ),
                TextField(
                  controller: meeting,
                  decoration: const InputDecoration(labelText: 'Meeting point'),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        deadline == null
                            ? 'No registration deadline'
                            : 'Register by ${MaterialLocalizations.of(context).formatMediumDate(deadline!)}',
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: date.subtract(const Duration(days: 1)),
                          firstDate: now,
                          lastDate: date.subtract(const Duration(days: 1)),
                        );
                        if (picked != null) {
                          setDialogState(() => deadline = picked);
                        }
                      },
                      child: const Text('Set'),
                    ),
                    if (deadline != null)
                      TextButton(
                        onPressed: () => setDialogState(() => deadline = null),
                        child: const Text('Clear'),
                      ),
                  ],
                ),
              ],
            ),
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
                        _positiveInt(minimumCapacity.text) ??
                        old.minimumCapacity,
                    adultPrice:
                        num.tryParse(adultPrice.text.trim()) ?? old.adultPrice,
                    childPrice: childPrice.text.trim().isEmpty
                        ? null
                        : num.tryParse(childPrice.text.trim()),
                    infantPrice: infantPrice.text.trim().isEmpty
                        ? null
                        : num.tryParse(infantPrice.text.trim()),
                    meetingPoint: meeting.text,
                    registrationDeadline: deadline,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
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

  /// Validates the whole form and builds the request, or explains what is wrong and returns null.
  TourPackageDraft? _buildDraft() {
    final policyId = _policyId;
    final price = num.tryParse(_price.text.trim());
    final duration = _positiveInt(_duration.text);
    if (_title.text.trim().isEmpty ||
        _description.text.trim().isEmpty ||
        price == null ||
        price <= 0 ||
        duration == null ||
        policyId == null) {
      _notice('Complete the basic information first.');
      return null;
    }
    if (_destinationIds.isEmpty) {
      _notice('Select at least one destination.');
      return null;
    }
    if (_stops.isEmpty || _departures.isEmpty) {
      _notice('Add at least one itinerary stop and one departure schedule.');
      return null;
    }
    if (_stops.any((stop) => stop.dayNo > duration)) {
      _notice('Each stop must be on a day within the tour duration.');
      return null;
    }
    final invalidDeparture = _departures.any(
      (departure) =>
          departure.minimumCapacity > departure.capacity ||
          (departure.adultPrice != null && departure.adultPrice! <= 0) ||
          (departure.childPrice != null && departure.childPrice! < 0) ||
          (departure.infantPrice != null && departure.infantPrice! < 0) ||
          (departure.registrationDeadline != null &&
              !departure.registrationDeadline!.isBefore(departure.start)),
    );
    if (invalidDeparture) {
      _notice(
        'Each departure needs a positive adult price, a minimum capacity no greater than capacity, and a registration deadline before it starts.',
      );
      return null;
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
      return null;
    }
    // Stops keep the order the operator arranged; sequence is per day, starting at 1.
    final sequenceByDay = <int, int>{};
    final initial = widget.initial;
    return TourPackageDraft(
      title: _title.text,
      description: _description.text,
      basePrice: price,
      durationDays: duration,
      categoryId: initial?.categoryId,
      timeZoneId: initial?.timeZoneId,
      inclusions: _inclusions.text,
      exclusions: _exclusions.text,
      highlights: _highlights.text,
      travellerRequirements: _requirements.text,
      destinationIds: List.unmodifiable(_destinationIds),
      cancellationPolicyTemplateId: policyId,
      itineraryItems: [
        for (final stop in _stops)
          TourItineraryStopDraft(
            poiId: stop.poiId,
            dayNo: stop.dayNo,
            sequenceNo: sequenceByDay.update(
              stop.dayNo,
              (value) => value + 1,
              ifAbsent: () => 1,
            ),
            stayDurationMinutes: stop.stayMinutes,
            plannedTime: stop.plannedTime,
            notes: stop.notes,
          ),
      ],
      schedules: [
        for (final item in _departures)
          TourScheduleDraft(
            startAtUtc: item.start,
            endAtUtc: item.end,
            totalCapacity: item.capacity,
            minimumCapacity: item.minimumCapacity,
            registrationDeadlineAtUtc: item.registrationDeadline,
            adultPrice: item.adultPrice ?? price,
            childPrice: item.childPrice,
            infantPrice: item.infantPrice,
            meetingPoint: item.meetingPoint,
          ),
      ],
    );
  }

  void _save() {
    final draft = _buildDraft();
    if (draft != null) context.read<CreateTourPackageCubit>().submit(draft);
  }

  Future<void> _submitForReview() async {
    final draft = _buildDraft();
    if (draft == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Submit for review?'),
        content: const Text(
          'Your current changes are saved first. After submission the package cannot be edited until an administrator reviews it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<CreateTourPackageCubit>().saveAndSubmitForReview(
        draft,
      );
    }
  }

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: [
      BlocListener<CreateTourPackageCubit, CreateTourPackageState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          if (state.status == CreateTourPackageStatus.failure &&
              state.failure != null) {
            _notice(state.failure!.message);
          }
          if (state.status == CreateTourPackageStatus.success) {
            if (_isEditing) {
              _notice('Changes saved.');
            } else {
              _notice(
                'Tour draft saved. Add a cover photo, then submit it for review.',
              );
              context.pushReplacement(
                AppRoutes.editTourPackagePath(state.tourId!),
              );
            }
          }
        },
      ),
      BlocListener<CreateTourPackageCubit, CreateTourPackageState>(
        listenWhen: (previous, current) =>
            previous.reviewStatus != current.reviewStatus,
        listener: (context, state) {
          if (state.reviewStatus == TourReviewStatus.failure &&
              state.reviewFailure != null) {
            _notice(state.reviewFailure!.message);
          }
          if (state.reviewStatus == TourReviewStatus.submitted) {
            _notice('Submitted for review.');
            context.pop();
          }
        },
      ),
      BlocListener<CreateTourPackageCubit, CreateTourPackageState>(
        listenWhen: (previous, current) =>
            previous.mediaFailure != current.mediaFailure &&
            current.mediaFailure != null,
        listener: (context, state) => _notice(state.mediaFailure!.message),
      ),
    ],
    child: BlocBuilder<CreateTourPackageCubit, CreateTourPackageState>(
      builder: (context, state) => Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit tour package' : 'Create tour package'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (widget.initial?.status == TourPackageStatus.rejected &&
                  widget.initial?.rejectionReason != null)
                TourPackageBanner(
                  icon: Icons.report_gmailerrorred_outlined,
                  message:
                      'Rejected: ${widget.initial!.rejectionReason}. Fix the issues and submit again.',
                ),
              if (_readOnly)
                TourPackageBanner(
                  icon: Icons.lock_outline,
                  message:
                      'This package is ${tourStatusLabel(widget.initial!.status).toLowerCase()} and cannot be edited.',
                ),
              Expanded(child: _stepper(context, state)),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _stepper(BuildContext context, CreateTourPackageState state) {
    final saving = state.status == CreateTourPackageStatus.submitting;
    final submittingReview = state.reviewStatus == TourReviewStatus.submitting;
    final busy = saving || submittingReview;
    return Stepper(
      currentStep: _step,
      onStepTapped: (value) {
        if (value <= _step || _validStep()) setState(() => _step = value);
      },
      onStepContinue: () {
        if (_step < _reviewStep) {
          if (_validStep()) setState(() => _step++);
        }
      },
      onStepCancel: _step == 0
          ? () => context.pop()
          : () => setState(() => _step--),
      controlsBuilder: (_, details) => details.stepIndex != _step
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  if (_step < _reviewStep)
                    FilledButton(
                      onPressed: details.onStepContinue,
                      child: const Text('Continue'),
                    )
                  else if (!_readOnly) ...[
                    FilledButton(
                      onPressed: busy ? null : _save,
                      child: Text(saving ? 'Saving...' : 'Save draft'),
                    ),
                    if (_isEditing)
                      OutlinedButton(
                        onPressed: busy ? null : _submitForReview,
                        child: Text(
                          submittingReview
                              ? 'Submitting...'
                              : 'Submit for review',
                        ),
                      ),
                  ],
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
          content: _basicStep(state),
          isActive: _step >= 0,
        ),
        Step(
          title: Text('Itinerary (${_stops.length})'),
          content: _itineraryStep(),
          isActive: _step >= 1,
        ),
        Step(
          title: Text('Schedules (${_departures.length})'),
          content: _scheduleStep(),
          isActive: _step >= 2,
        ),
        Step(
          title: const Text('Photos'),
          content: _isEditing
              ? TourPhotosSection(
                  media: state.media,
                  busy: state.mediaBusy,
                  readOnly: _readOnly,
                  onAdd: () =>
                      context.read<CreateTourPackageCubit>().addImage(),
                  onSetPrimary: (id) => context
                      .read<CreateTourPackageCubit>()
                      .setPrimaryImage(id),
                  onDelete: (id) =>
                      context.read<CreateTourPackageCubit>().deleteImage(id),
                )
              : const Text(
                  'Save the draft first. You can add the cover photo on the next screen.',
                ),
          isActive: _step >= _photosStep,
        ),
        Step(
          title: const Text('Preview & save'),
          content: _reviewStep_(state),
          isActive: _step >= _reviewStep,
        ),
      ],
    );
  }

  Widget _basicStep(CreateTourPackageState state) => Form(
    key: _formKey,
    child: Column(
      children: [
        TextFormField(
          controller: _title,
          enabled: !_readOnly,
          decoration: const InputDecoration(labelText: 'Tour title'),
          validator: (value) => _required(value, 'Tour title'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: _description,
          enabled: !_readOnly,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Description'),
          validator: (value) => _required(value, 'Description'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: _price,
          enabled: !_readOnly,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Base price (VND)'),
          validator: (value) {
            final price = num.tryParse(value ?? '');
            if (price == null || price <= 0) return 'Enter a positive price.';
            return _isWholeVnd(price) ? null : 'Enter a whole VND amount.';
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: _duration,
          enabled: !_readOnly,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Duration (days)'),
          validator: (value) => _positiveInt(value ?? '') == null
              ? 'Enter a positive number of days.'
              : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final (controller, label) in [
          (_highlights, 'Highlights (optional)'),
          (_inclusions, 'Inclusions (optional)'),
          (_exclusions, 'Exclusions (optional)'),
          (_requirements, 'Traveller requirements (optional)'),
        ]) ...[
          TextFormField(
            controller: controller,
            enabled: !_readOnly,
            minLines: 1,
            maxLines: 4,
            maxLength: 4000,
            decoration: InputDecoration(labelText: label),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        const SizedBox(height: AppSpacing.sm),
        TourOptionsSection(
          state: state,
          enabled: !_readOnly,
          selectedDestinationIds: _destinationIds,
          selectedPolicyId: _policyId,
          onToggleDestination: (id) => setState(() {
            if (_destinationIds.contains(id)) {
              _destinationIds.remove(id);
            } else if (_destinationIds.length < maxTourDestinations) {
              _destinationIds.add(id);
            }
          }),
          onPolicyChanged: (id) => setState(() => _policyId = id),
          onRetry: () => context.read<CreateTourPackageCubit>().loadOptions(),
        ),
      ],
    ),
  );

  Widget _itineraryStep() => Column(
    children: [
      const Text(
        'Choose active locations from the TripMate catalogue, then adjust each visit.',
      ),
      for (final entry in _stops.asMap().entries)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(child: Text('${entry.key + 1}')),
          title: Text(entry.value.name),
          subtitle: Text(
            'Day ${entry.value.dayNo} · ${entry.value.stayMinutes} min${entry.value.isOpenNow ? ' · Open now' : ''}',
          ),
          onTap: () => _editStop(entry.key),
          trailing: _readOnly
              ? null
              : IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove stop',
                  onPressed: () => setState(() => _stops.removeAt(entry.key)),
                ),
        ),
      if (!_readOnly)
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _choosePoi,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Add point of interest'),
          ),
        ),
    ],
  );

  Widget _scheduleStep() => Column(
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
          trailing: _readOnly || _departures.length == 1
              ? null
              : IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove departure',
                  onPressed: () =>
                      setState(() => _departures.removeAt(entry.key)),
                ),
        ),
      if (!_readOnly)
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () {
              final start = _departures.last.start.add(const Duration(days: 7));
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
  );

  Widget _reviewStep_(CreateTourPackageState state) {
    final detail = state.detail;
    final options = state.options;
    final destinationNames = [
      for (final id in _destinationIds)
        options?.destinations
                .where((destination) => destination.id == id)
                .map((destination) => destination.name)
                .firstOrNull ??
            'Destination #$id',
    ];
    final policyName = options?.policies
        .where((policy) => policy.id == _policyId)
        .map((policy) => policy.name)
        .firstOrNull;
    final cover = state.media.where((item) => item.isPrimary).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TourPreviewCard(
          title: _title.text.trim().isEmpty ? 'Untitled tour' : _title.text,
          coverUrl: cover?.url,
          destinations: destinationNames,
          durationDays: _positiveInt(_duration.text),
          basePrice: num.tryParse(_price.text.trim()),
          highlights: _highlights.text,
          inclusions: _inclusions.text,
          exclusions: _exclusions.text,
          policyName: policyName,
          days: _previewDays(),
          departures: [
            for (final departure in _departures)
              '${MaterialLocalizations.of(context).formatMediumDate(departure.start)} · ${departure.capacity} seats · Adult ${departure.adultPrice ?? _price.text} VND',
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (detail != null) ...[
          TourReadinessSection(
            blockers: detail.reviewBlockers,
            warnings: detail.warnings,
            poiNames: state.poiNames,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(
          _isEditing
              ? 'Readiness and warnings reflect the last saved version.'
              : 'This is saved as a Draft. Add a cover photo, then submit it for review.',
        ),
      ],
    );
  }

  Map<int, List<String>> _previewDays() {
    final days = <int, List<String>>{};
    for (final stop in _stops) {
      days.putIfAbsent(stop.dayNo, () => []).add(stop.name);
    }
    return Map.fromEntries(
      days.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }
}

final class _TourStop {
  const _TourStop({
    required this.poiId,
    required this.name,
    this.dayNo = 1,
    this.stayMinutes = 60,
    this.isOpenNow = false,
    this.plannedTime,
    this.notes,
  });
  final int poiId;
  final String name;
  final int dayNo;
  final int stayMinutes;
  final bool isOpenNow;
  final String? plannedTime;
  final String? notes;
  _TourStop copyWith({int? dayNo, int? stayMinutes}) => _TourStop(
    poiId: poiId,
    name: name,
    dayNo: dayNo ?? this.dayNo,
    stayMinutes: stayMinutes ?? this.stayMinutes,
    isOpenNow: isOpenNow,
    plannedTime: plannedTime,
    notes: notes,
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
    this.registrationDeadline,
  });
  final DateTime start;
  final DateTime end;
  final int capacity;
  final int minimumCapacity;
  final num? adultPrice;
  final num? childPrice;
  final num? infantPrice;
  final String meetingPoint;
  final DateTime? registrationDeadline;
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
