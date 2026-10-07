import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_booking_request.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_capability.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/cubit/commercial_service_booking_cubit.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/cubit/commercial_service_booking_state.dart';
import 'package:trip_mate_mobile/features/poi/presentation/theme/poi_palette.dart';

class CommercialServiceBookingPage extends StatefulWidget {
  const CommercialServiceBookingPage({super.key});

  @override
  State<CommercialServiceBookingPage> createState() =>
      _CommercialServiceBookingPageState();
}

class _CommercialServiceBookingPageState
    extends State<CommercialServiceBookingPage> {
  late final TextEditingController _dateController;
  late final TextEditingController _timeController;
  late final TextEditingController _specialRequestController;
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    final initial = context.read<CommercialServiceBookingCubit>().state;
    _dateController = TextEditingController(text: initial.requestedDateIso);
    _timeController = TextEditingController(text: initial.requestedTime);
    _specialRequestController = TextEditingController(
      text: initial.specialRequest,
    );
    _fullNameController = TextEditingController(text: initial.contactFullName);
    _phoneController = TextEditingController(text: initial.contactPhoneNumber);
    _emailController = TextEditingController(text: initial.contactEmail);
  }

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _specialRequestController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _syncControllers(CommercialServiceBookingState state) {
    if (_dateController.text != state.requestedDateIso) {
      _dateController.text = state.requestedDateIso;
    }
    if (_timeController.text != state.requestedTime) {
      _timeController.text = state.requestedTime;
    }
    if (_specialRequestController.text != state.specialRequest) {
      _specialRequestController.text = state.specialRequest;
    }
    if (_fullNameController.text != state.contactFullName) {
      _fullNameController.text = state.contactFullName;
    }
    if (_phoneController.text != state.contactPhoneNumber) {
      _phoneController.text = state.contactPhoneNumber;
    }
    if (_emailController.text != state.contactEmail) {
      _emailController.text = state.contactEmail;
    }
  }

  static void _handleBack(BuildContext context, int poiId, bool isDemoMode) {
    if (context.canPop()) {
      context.pop();
    } else if (poiId > 0) {
      context.go(AppRoutes.commercialServiceDetail(poiId, demo: isDemoMode));
    } else {
      context.go(AppRoutes.explore);
    }
  }

  Future<void> _showSubmitConfirmationDialog(
    BuildContext context,
    CommercialServiceBookingState state,
  ) async {
    final cubit = context.read<CommercialServiceBookingCubit>();
    final optionName = state.selectedOption?.name ?? 'Unselected option';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('commercial_booking_submit_confirm_dialog'),
        title: const Text('Confirm Booking Request (CR-05)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to submit this commercial service booking request? The initial status will be Pending Confirmation (BR-89).',
              ),
              const SizedBox(height: 12),
              Text(
                'Option: $optionName',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                'Date & Time: ${state.requestedDateIso} at ${state.requestedTime}',
              ),
              Text('Quantity: ${state.quantity}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('commercial_booking_confirm_dialog_cancel'),
            style: TextButton.styleFrom(minimumSize: const Size(88, 48)),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('commercial_booking_confirm_dialog_accept'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(120, 48),
              backgroundColor: PoiPalette.teal,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm Submit'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      cubit.submitRequest();
    }
  }

  Future<void> _showCancelPendingDialog(
    BuildContext context,
    CommercialServiceBookingRequest request,
  ) async {
    final cubit = context.read<CommercialServiceBookingCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('commercial_booking_cancel_confirm_dialog'),
        title: const Text('Cancel Pending Request (CR-05)'),
        content: SingleChildScrollView(
          child: Text(
            'Are you sure you want to cancel request ${request.requestId} for ${request.serviceName}? '
            'Once cancelled, this request will transition to Cancelled status (BR-89, BR-76).',
          ),
        ),
        actions: [
          TextButton(
            key: const Key('commercial_booking_cancel_dialog_keep'),
            style: TextButton.styleFrom(minimumSize: const Size(88, 48)),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep Request'),
          ),
          FilledButton(
            key: const Key('commercial_booking_cancel_dialog_accept'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(120, 48),
              backgroundColor: const Color(0xFFC62828),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      cubit.cancelPendingRequest();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<
      CommercialServiceBookingCubit,
      CommercialServiceBookingState
    >(
      listener: (_, state) => _syncControllers(state),
      builder: (context, state) {
        final cubit = context.read<CommercialServiceBookingCubit>();
        final composite = state.composite;
        final isDemoInteractable =
            state.isDemoMode &&
            state.status != CommercialServiceBookingStatus.pendingIntegration;

        return Scaffold(
          backgroundColor: PoiPalette.background,
          appBar: AppBar(
            backgroundColor: PoiPalette.navy,
            foregroundColor: Colors.white,
            leading: IconButton(
              key: const Key('commercial_booking_back_button'),
              onPressed: () =>
                  _handleBack(context, state.poiId, state.isDemoMode),
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back),
            ),
            title: const Text(
              'Commercial Service Booking',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!state.isDemoMode ||
                          state.status ==
                              CommercialServiceBookingStatus
                                  .pendingIntegration) ...[
                        _ProductionPendingBanner(),
                        const SizedBox(height: 16),
                      ],
                      if (kDebugMode && state.isDemoMode) ...[
                        _DemoSimulationControlsCard(
                          state: state,
                          onToggleClosed: cubit.toggleSimulateServiceClosed,
                          onToggleDateTimeUnavailable:
                              cubit.toggleSimulateDateTimeUnavailable,
                          onToggleSystemFailure:
                              cubit.toggleSimulateSystemFailure,
                          onPresetDate: (dateIso) {
                            _dateController.text = dateIso;
                            cubit.updateRequestedDate(dateIso);
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      _SummaryCard(composite: composite, poiId: state.poiId),
                      if (state.validationMessage != null) ...[
                        const SizedBox(height: 16),
                        Semantics(
                          liveRegion: true,
                          label: state.validationMessage,
                          child: Container(
                            key: const Key(
                              'commercial_booking_validation_banner',
                            ),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFE53935),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Color(0xFFC62828),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    state.validationMessage!,
                                    style: const TextStyle(
                                      color: Color(0xFFB71C1C),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (state.status ==
                              CommercialServiceBookingStatus.failure &&
                          state.errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Semantics(
                          liveRegion: true,
                          label: state.errorMessage,
                          child: Container(
                            key: const Key('commercial_booking_msg127_banner'),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFE53935),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.cloud_off_outlined,
                                  color: Color(0xFFC62828),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    state.errorMessage!,
                                    style: const TextStyle(
                                      color: Color(0xFFB71C1C),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (state.statusMessage != null) ...[
                        const SizedBox(height: 16),
                        _StatusMessageBanner(
                          message: state.statusMessage!,
                          bookingStatus: state.activeRequest?.status,
                        ),
                      ],
                      if (state.activeRequest != null) ...[
                        const SizedBox(height: 16),
                        _ActiveRequestPanel(
                          request: state.activeRequest!,
                          onCancelPending: () => _showCancelPendingDialog(
                            context,
                            state.activeRequest!,
                          ),
                          onSimulateConfirm: cubit.simulateProviderConfirm,
                          onSimulateReject: cubit.simulateProviderReject,
                          onStartNewRequest: cubit.startNewRequest,
                        ),
                      ],
                      if (state.activeRequest == null) ...[
                        const SizedBox(height: 16),
                        _BookingInputFormCard(
                          state: state,
                          enabled: isDemoInteractable,
                          dateController: _dateController,
                          timeController: _timeController,
                          specialRequestController: _specialRequestController,
                          onSelectOption: cubit.selectOption,
                          onDateChanged: cubit.updateRequestedDate,
                          onTimeChanged: cubit.updateRequestedTime,
                          onQuantityChanged: cubit.updateQuantity,
                          onSpecialRequestChanged: cubit.updateSpecialRequest,
                        ),
                        const SizedBox(height: 16),
                        _ContactInformationCard(
                          state: state,
                          enabled: isDemoInteractable,
                          fullNameController: _fullNameController,
                          phoneController: _phoneController,
                          emailController: _emailController,
                          onFullNameChanged: cubit.updateContactFullName,
                          onPhoneChanged: cubit.updateContactPhoneNumber,
                          onEmailChanged: cubit.updateContactEmail,
                        ),
                        const SizedBox(height: 16),
                        _EstimatedAmountCard(state: state),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            Semantics(
                              button: true,
                              enabled: isDemoInteractable,
                              label: isDemoInteractable
                                  ? 'Submit Request'
                                  : 'Submit Request disabled pending server integration',
                              child: FilledButton.icon(
                                key: const Key(
                                  'commercial_booking_submit_button',
                                ),
                                onPressed: isDemoInteractable
                                    ? () => _showSubmitConfirmationDialog(
                                        context,
                                        state,
                                      )
                                    : null,
                                icon: const Icon(Icons.send_outlined),
                                label: const Text('Submit Request'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(180, 48),
                                  backgroundColor: PoiPalette.teal,
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              key: const Key(
                                'commercial_booking_secondary_back_button',
                              ),
                              onPressed: () => _handleBack(
                                context,
                                state.poiId,
                                state.isDemoMode,
                              ),
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Back'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(110, 48),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProductionPendingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          'Pending Server Integration: Commercial service booking API is not available in Production.',
      child: Container(
        key: const Key('commercial_booking_production_pending_banner'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFB300)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: Color(0xFFE65100)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Pending Server Integration (NO_BACKEND): Commercial service booking endpoints and server-calculated amounts are not yet exposed by Capstone_BE. Submit Request is disabled in Production so no fake booking ID or fake charge is created (BR-63, BR-88, BR-89).',
                style: TextStyle(
                  color: Color(0xFF4E342E),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoSimulationControlsCard extends StatelessWidget {
  const _DemoSimulationControlsCard({
    required this.state,
    required this.onToggleClosed,
    required this.onToggleDateTimeUnavailable,
    required this.onToggleSystemFailure,
    required this.onPresetDate,
  });

  final CommercialServiceBookingState state;
  final ValueChanged<bool> onToggleClosed;
  final ValueChanged<bool> onToggleDateTimeUnavailable;
  final ValueChanged<bool> onToggleSystemFailure;
  final ValueChanged<String> onPresetDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('commercial_booking_demo_simulation_card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PoiPalette.teal),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.science_outlined, color: PoiPalette.teal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Debug Demo Booking Controls (UC-31)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: PoiPalette.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                key: const Key('demo_toggle_service_closed'),
                label: const Text('Simulate Closed (MSG75)'),
                selected: state.simulateServiceClosed,
                onSelected: onToggleClosed,
              ),
              FilterChip(
                key: const Key('demo_toggle_datetime_unavailable'),
                label: const Text('Simulate Slot Unavailable (MSG70)'),
                selected: state.simulateDateTimeUnavailable,
                onSelected: onToggleDateTimeUnavailable,
              ),
              FilterChip(
                key: const Key('demo_toggle_system_failure'),
                label: const Text('Simulate Failure (MSG127)'),
                selected: state.simulateSystemFailure,
                onSelected: onToggleSystemFailure,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                key: const Key('demo_preset_past_date_button'),
                label: const Text('Set Past Date (2020-01-01)'),
                onPressed: () => onPresetDate('2020-01-01'),
              ),
              ActionChip(
                key: const Key('demo_preset_valid_date_button'),
                label: const Text('Set Valid Date (2026-10-15)'),
                onPressed: () => onPresetDate('2026-10-15'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.composite, required this.poiId});

  final CommercialServiceDetailComposite? composite;
  final int poiId;

  @override
  Widget build(BuildContext context) {
    final serviceName =
        composite?.poi.name ?? 'Commercial Service (POI #$poiId)';
    final categoryLabel =
        composite?.commercialCategory?.canonicalName ??
        composite?.poi.categoryName ??
        'Pending Server Integration';
    final addressLabel =
        composite?.poi.address ?? 'Address pending server integration';
    final priceLabel =
        (composite != null &&
            composite!.isCommercialDataBackedByServer &&
            composite!.priceRangeLabel != null)
        ? composite!.priceRangeLabel!
        : 'Pending Server Integration — Commercial pricing is not returned by GET /api/v1/pois/{id}.';

    return Container(
      key: const Key('commercial_booking_summary_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PoiPalette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Service Summary',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: PoiPalette.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _SummaryLine(label: 'Service Name', value: serviceName),
          const SizedBox(height: 6),
          _SummaryLine(label: 'Category', value: categoryLabel),
          const SizedBox(height: 6),
          _SummaryLine(label: 'Address', value: addressLabel),
          const SizedBox(height: 6),
          _SummaryLine(label: 'Price Information', value: priceLabel),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 132,
          child: Text(
            '$label:',
            style: const TextStyle(
              color: PoiPalette.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: PoiPalette.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _BookingInputFormCard extends StatelessWidget {
  const _BookingInputFormCard({
    required this.state,
    required this.enabled,
    required this.dateController,
    required this.timeController,
    required this.specialRequestController,
    required this.onSelectOption,
    required this.onDateChanged,
    required this.onTimeChanged,
    required this.onQuantityChanged,
    required this.onSpecialRequestChanged,
  });

  final CommercialServiceBookingState state;
  final bool enabled;
  final TextEditingController dateController;
  final TextEditingController timeController;
  final TextEditingController specialRequestController;
  final ValueChanged<String> onSelectOption;
  final ValueChanged<String> onDateChanged;
  final ValueChanged<String> onTimeChanged;
  final ValueChanged<int> onQuantityChanged;
  final ValueChanged<String> onSpecialRequestChanged;

  @override
  Widget build(BuildContext context) {
    final options = state.composite?.options ?? const [];
    final availableSlots =
        state.composite?.availability?.availableTimeSlots ?? const [];
    final selectedOption = state.selectedOption;

    return Container(
      key: const Key('commercial_booking_input_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PoiPalette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Booking Details',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: PoiPalette.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Selected Service Option *',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: PoiPalette.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (options.isEmpty)
            Text(
              'Pending Server Integration — No bookable service options are available in Production.',
              key: const Key('commercial_booking_no_options_notice'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: PoiPalette.muted,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Column(
              children: [
                for (final option in options) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Semantics(
                      button: true,
                      selected: selectedOption?.optionId == option.optionId,
                      label:
                          'Select ${option.name}, ${_formatVnd(option.unitPriceVnd)} per ${option.priceUnitLabel}, ${option.availableQuantity} available',
                      child: InkWell(
                        key: Key(
                          'commercial_booking_option_${option.optionId}',
                        ),
                        borderRadius: BorderRadius.circular(12),
                        onTap: enabled
                            ? () => onSelectOption(option.optionId)
                            : null,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selectedOption?.optionId == option.optionId
                                ? PoiPalette.tealSoft
                                : PoiPalette.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedOption?.optionId == option.optionId
                                  ? PoiPalette.teal
                                  : PoiPalette.line,
                              width: selectedOption?.optionId == option.optionId
                                  ? 2
                                  : 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                selectedOption?.optionId == option.optionId
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color:
                                    selectedOption?.optionId == option.optionId
                                    ? PoiPalette.teal
                                    : PoiPalette.muted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      option.name,
                                      style: const TextStyle(
                                        color: PoiPalette.navy,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_formatVnd(option.unitPriceVnd)} / ${option.priceUnitLabel} · ${option.availableQuantity} available',
                                      style: const TextStyle(
                                        color: PoiPalette.teal,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('commercial_booking_date_field'),
            controller: dateController,
            enabled: enabled,
            onChanged: onDateChanged,
            decoration: InputDecoration(
              labelText: 'Requested Date (YYYY-MM-DD) *',
              hintText: '2026-10-15',
              errorText: state.fieldErrors['requestedDate'],
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('commercial_booking_time_field'),
            controller: timeController,
            enabled: enabled,
            onChanged: onTimeChanged,
            decoration: InputDecoration(
              labelText: 'Requested Time (HH:mm) *',
              hintText: '14:00',
              errorText:
                  state.fieldErrors['requestedTime'] ??
                  state.fieldErrors['availability'],
              border: const OutlineInputBorder(),
            ),
          ),
          if (availableSlots.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final slot in availableSlots)
                  ChoiceChip(
                    key: Key('commercial_booking_slot_$slot'),
                    label: Text(slot),
                    selected: state.requestedTime == slot,
                    onSelected: enabled
                        ? (_) {
                            timeController.text = slot;
                            onTimeChanged(slot);
                          }
                        : null,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quantity *',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: PoiPalette.navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (selectedOption != null)
                      Text(
                        'Available: ${selectedOption.availableQuantity}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: PoiPalette.muted,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('commercial_booking_quantity_decrement'),
                tooltip: 'Decrease quantity',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: enabled && state.quantity > 1
                    ? () => onQuantityChanged(state.quantity - 1)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Semantics(
                label: 'Selected quantity ${state.quantity}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '${state.quantity}',
                    key: const Key('commercial_booking_quantity_value'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              IconButton(
                key: const Key('commercial_booking_quantity_increment'),
                tooltip: 'Increase quantity',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: enabled
                    ? () => onQuantityChanged(state.quantity + 1)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          if (state.fieldErrors['quantity'] != null) ...[
            const SizedBox(height: 4),
            Text(
              state.fieldErrors['quantity']!,
              key: const Key('commercial_booking_quantity_error'),
              style: const TextStyle(
                color: Color(0xFFC62828),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            key: const Key('commercial_booking_special_request_field'),
            controller: specialRequestController,
            enabled: enabled,
            maxLines: 2,
            onChanged: onSpecialRequestChanged,
            decoration: const InputDecoration(
              labelText: 'Special Request (Optional)',
              hintText: 'Early check-in, dietary preference, child seat...',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactInformationCard extends StatelessWidget {
  const _ContactInformationCard({
    required this.state,
    required this.enabled,
    required this.fullNameController,
    required this.phoneController,
    required this.emailController,
    required this.onFullNameChanged,
    required this.onPhoneChanged,
    required this.onEmailChanged,
  });

  final CommercialServiceBookingState state;
  final bool enabled;
  final TextEditingController fullNameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final ValueChanged<String> onFullNameChanged;
  final ValueChanged<String> onPhoneChanged;
  final ValueChanged<String> onEmailChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('commercial_booking_contact_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PoiPalette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact Information',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: PoiPalette.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('commercial_booking_contact_name_field'),
            controller: fullNameController,
            enabled: enabled,
            onChanged: onFullNameChanged,
            decoration: InputDecoration(
              labelText: 'Contact Full Name *',
              errorText: state.fieldErrors['contactFullName'],
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('commercial_booking_contact_phone_field'),
            controller: phoneController,
            enabled: enabled,
            keyboardType: TextInputType.phone,
            onChanged: onPhoneChanged,
            decoration: InputDecoration(
              labelText: 'Contact Phone Number *',
              errorText: state.fieldErrors['contactPhoneNumber'],
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('commercial_booking_contact_email_field'),
            controller: emailController,
            enabled: enabled,
            keyboardType: TextInputType.emailAddress,
            onChanged: onEmailChanged,
            decoration: InputDecoration(
              labelText: 'Contact Email *',
              errorText: state.fieldErrors['contactEmail'],
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _EstimatedAmountCard extends StatelessWidget {
  const _EstimatedAmountCard({required this.state});

  final CommercialServiceBookingState state;

  @override
  Widget build(BuildContext context) {
    final previewAmount = state.demoPreviewEstimatedAmountVnd;
    return Container(
      key: const Key('commercial_booking_estimated_amount_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PoiPalette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estimated Amount',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: PoiPalette.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (!state.isDemoMode || previewAmount == null)
            Text(
              'Pending Server Integration (BR-63: Server computes authoritative booking amount)',
              key: const Key('commercial_booking_amount_pending_text'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: PoiPalette.muted,
                fontStyle: FontStyle.italic,
              ),
            )
          else ...[
            Text(
              _formatVnd(previewAmount),
              key: const Key('commercial_booking_demo_amount_value'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: PoiPalette.teal,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Demo Preview Amount (BR-63: Server computes authoritative amount in Production)',
              key: const Key('commercial_booking_demo_amount_caption'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: PoiPalette.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusMessageBanner extends StatelessWidget {
  const _StatusMessageBanner({
    required this.message,
    required this.bookingStatus,
  });

  final String message;
  final CommercialBookingStatus? bookingStatus;

  @override
  Widget build(BuildContext context) {
    final isNegative =
        bookingStatus == CommercialBookingStatus.rejected ||
        bookingStatus == CommercialBookingStatus.cancelled;
    final bgColor = isNegative
        ? const Color(0xFFFFF3E0)
        : const Color(0xFFE8F5E9);
    final borderColor = isNegative
        ? const Color(0xFFFF9800)
        : const Color(0xFF43A047);
    final textColor = isNegative
        ? const Color(0xFFE65100)
        : const Color(0xFF1B5E20);

    return Semantics(
      liveRegion: true,
      label: message,
      child: Container(
        key: const Key('commercial_booking_status_banner'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isNegative ? Icons.info_outline : Icons.check_circle_outline,
              color: textColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveRequestPanel extends StatelessWidget {
  const _ActiveRequestPanel({
    required this.request,
    required this.onCancelPending,
    required this.onSimulateConfirm,
    required this.onSimulateReject,
    required this.onStartNewRequest,
  });

  final CommercialServiceBookingRequest request;
  final VoidCallback onCancelPending;
  final VoidCallback onSimulateConfirm;
  final VoidCallback onSimulateReject;
  final VoidCallback onStartNewRequest;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('commercial_booking_active_request_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PoiPalette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Booking Request ${request.requestId}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: PoiPalette.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Chip(
                key: const Key('commercial_booking_request_status_chip'),
                label: Text(
                  request.status.canonicalLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SummaryLine(label: 'Service Name', value: request.serviceName),
          const SizedBox(height: 4),
          _SummaryLine(
            label: 'Category',
            value: request.category.canonicalName,
          ),
          const SizedBox(height: 4),
          _SummaryLine(
            label: 'Selected Option',
            value: request.selectedOption.name,
          ),
          const SizedBox(height: 4),
          _SummaryLine(
            label: 'Date & Time',
            value: '${request.requestedDateIso} · ${request.requestedTime}',
          ),
          const SizedBox(height: 4),
          _SummaryLine(label: 'Quantity', value: '${request.quantity}'),
          const SizedBox(height: 4),
          _SummaryLine(
            label: 'Contact',
            value:
                '${request.contactInfo.fullName} · ${request.contactInfo.phoneNumber} · ${request.contactInfo.email}',
          ),
          const SizedBox(height: 4),
          _SummaryLine(
            label: 'Demo Preview Amount (BR-63)',
            value: _formatVnd(request.estimatedAmountVnd),
          ),
          if (request.status == CommercialBookingStatus.confirmed) ...[
            const SizedBox(height: 12),
            Container(
              key: const Key('commercial_booking_itinerary_reflection_note'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PoiPalette.tealSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.event_available, color: PoiPalette.teal),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Confirmed service is reflected in your booking history and linked itinerary stop (PC-03, BR-89).',
                      style: TextStyle(
                        color: PoiPalette.navy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (request.status == CommercialBookingStatus.cancelled) ...[
            const SizedBox(height: 12),
            Container(
              key: const Key('commercial_booking_br76_refund_notice'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PoiPalette.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Cancellation recorded (BR-89). If any payment was captured, refunds are processed through the original payment channel (BR-76).',
                style: TextStyle(
                  color: PoiPalette.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (request.status ==
              CommercialBookingStatus.pendingConfirmation) ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  key: const Key('commercial_booking_cancel_request_button'),
                  onPressed: onCancelPending,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel Pending Request'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(180, 48),
                    foregroundColor: const Color(0xFFC62828),
                  ),
                ),
                FilledButton.tonalIcon(
                  key: const Key('commercial_booking_simulate_confirm_button'),
                  onPressed: onSimulateConfirm,
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Simulate Provider Confirm'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(180, 48),
                  ),
                ),
                FilledButton.tonalIcon(
                  key: const Key('commercial_booking_simulate_reject_button'),
                  onPressed: onSimulateReject,
                  icon: const Icon(Icons.do_not_disturb_on_outlined),
                  label: const Text('Simulate Provider Reject'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(180, 48),
                  ),
                ),
              ],
            ),
          ],
          if (request.status == CommercialBookingStatus.rejected ||
              request.status == CommercialBookingStatus.cancelled) ...[
            FilledButton.icon(
              key: const Key('commercial_booking_new_request_button'),
              onPressed: onStartNewRequest,
              icon: const Icon(Icons.refresh),
              label: const Text('Submit Another Request'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(180, 48),
                backgroundColor: PoiPalette.teal,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatVnd(int amount) {
  final raw = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final posFromEnd = raw.length - i;
    buffer.write(raw[i]);
    if (posFromEnd > 1 && posFromEnd % 3 == 1) {
      buffer.write(',');
    }
  }
  return '₫$buffer';
}
