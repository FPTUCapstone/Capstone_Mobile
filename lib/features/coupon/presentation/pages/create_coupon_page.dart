import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/coupon/domain/entities/coupon_draft.dart';
import 'package:trip_mate_mobile/features/coupon/presentation/cubit/create_coupon_cubit.dart';
import 'package:trip_mate_mobile/features/coupon/presentation/cubit/create_coupon_state.dart';

final class CreateCouponPage extends StatefulWidget {
  const CreateCouponPage({super.key});

  @override
  State<CreateCouponPage> createState() => _CreateCouponPageState();
}

final class _CreateCouponPageState extends State<CreateCouponPage> {
  static const _maximumMoneyAmount = 9999999999.99;
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _discount = TextEditingController();
  final _cap = TextEditingController();
  final _minimumOrder = TextEditingController(text: '0');
  final _usageLimit = TextEditingController();
  final _perUserLimit = TextEditingController();
  final _tourSearch = TextEditingController();
  CouponDiscountType _discountType = CouponDiscountType.percentage;
  late DateTime _startsAt;
  late DateTime _endsAt;
  final Set<int> _tourIds = {};
  String _tourQuery = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startsAt = DateTime(now.year, now.month, now.day, now.hour + 1);
    _endsAt = _startsAt.add(const Duration(days: 7));
    context.read<CreateCouponCubit>().loadTours();
  }

  @override
  void dispose() {
    _code.dispose();
    _discount.dispose();
    _cap.dispose();
    _minimumOrder.dispose();
    _usageLimit.dispose();
    _perUserLimit.dispose();
    _tourSearch.dispose();
    super.dispose();
  }

  String _newCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return 'TRIP-${List.generate(6, (_) => alphabet[random.nextInt(alphabet.length)]).join()}';
  }

  Future<void> _pickDateTime({required bool starts}) async {
    final initial = starts ? _startsAt : _endsAt;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted || time == null) return;
    setState(() {
      final value = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (starts) {
        _startsAt = value;
      } else {
        _endsAt = value;
      }
    });
  }

  int? _optionalLimit(TextEditingController controller) =>
      controller.text.trim().isEmpty
      ? null
      : int.tryParse(controller.text.trim());
  num? _number(TextEditingController controller) =>
      num.tryParse(controller.text.trim());

  bool _isSupportedMoney(
    TextEditingController controller, {
    bool allowZero = false,
  }) {
    final text = controller.text.trim();
    final amount = _number(controller);
    return RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(text) &&
        amount != null &&
        amount <= _maximumMoneyAmount &&
        (allowZero ? amount >= 0 : amount > 0);
  }

  String? _optionalPositiveInteger(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    final value = int.tryParse(text);
    return value == null || value <= 0
        ? 'Enter a whole number greater than 0, or leave blank.'
        : null;
  }

  String? _positiveNumber(
    TextEditingController controller,
    String label, {
    num? max,
  }) {
    final value = _number(controller);
    if (!_isSupportedMoney(controller) ||
        value == null ||
        (max != null && value > max)) {
      return max == null
          ? '$label must be greater than 0.'
          : '$label must be between 1 and $max.';
    }
    return null;
  }

  void _submit() {
    final validForm = _formKey.currentState!.validate();
    if (!validForm) return;
    if (_endsAt.compareTo(_startsAt) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End time must be later than start time.'),
        ),
      );
      return;
    }
    final minimumOrder = _number(_minimumOrder) ?? 0;
    if (_discountType == CouponDiscountType.flat &&
        minimumOrder > 0 &&
        _number(_discount)! > minimumOrder) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A fixed discount cannot exceed the minimum order.'),
        ),
      );
      return;
    }
    if (_tourIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one approved tour.')),
      );
      return;
    }
    context.read<CreateCouponCubit>().create(
      CouponDraft(
        code: _code.text,
        discountType: _discountType,
        discountValue: _number(_discount)!,
        maxDiscountAmount: _discountType == CouponDiscountType.percentage
            ? _number(_cap)
            : null,
        minOrderAmount: _number(_minimumOrder) ?? 0,
        usageLimit: _optionalLimit(_usageLimit),
        usageLimitPerUser: _optionalLimit(_perUserLimit),
        validFromUtc: _startsAt.toUtc(),
        validToUtc: _endsAt.toUtc(),
        applicableTourIds: _tourIds.toList(growable: false),
      ),
    );
  }

  void _resetForAnotherCoupon() {
    final now = DateTime.now();
    setState(() {
      _code.clear();
      _discount.clear();
      _cap.clear();
      _minimumOrder.text = '0';
      _usageLimit.clear();
      _perUserLimit.clear();
      _tourSearch.clear();
      _tourQuery = '';
      _discountType = CouponDiscountType.percentage;
      _startsAt = DateTime(now.year, now.month, now.day, now.hour + 1);
      _endsAt = _startsAt.add(const Duration(days: 7));
    });
    context.read<CreateCouponCubit>().prepareNextCoupon();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CreateCouponCubit, CreateCouponState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if ((state.status == CreateCouponStatus.tourLoadFailure ||
                state.status == CreateCouponStatus.submissionFailure) &&
            state.failure != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.failure!.message)));
        }
        if (state.status == CreateCouponStatus.success &&
            state.createdCode != null) {
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Coupon created'),
              content: Text(
                '${state.createdCode} is ready for your selected tours.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).maybePop();
                  },
                  child: const Text('Done'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _resetForAnotherCoupon();
                  },
                  child: const Text('Create another'),
                ),
              ],
            ),
          );
        }
      },
      builder: (context, state) {
        final normalizedQuery = _tourQuery.trim().toLowerCase();
        final visibleTours = normalizedQuery.isEmpty
            ? state.tours
            : state.tours
                  .where(
                    (tour) => '${tour.title} ${tour.destination ?? ''}'
                        .toLowerCase()
                        .contains(normalizedQuery),
                  )
                  .toList(growable: false);
        return Scaffold(
          appBar: AppBar(title: const Text('Create coupon')),
          body: SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  Text(
                    'Offer a clear discount on your approved tours.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _section(context, 'Coupon code', [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _code,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Code',
                              hintText: 'SUMMER25',
                            ),
                            validator: (value) =>
                                value == null ||
                                    !RegExp(
                                      r'^[A-Za-z0-9-]{3,30}$',
                                    ).hasMatch(value.trim())
                                ? 'Use 3–30 letters, digits, or hyphens.'
                                : null,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        OutlinedButton(
                          onPressed: () =>
                              setState(() => _code.text = _newCode()),
                          child: const Text('Generate'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text('Customers enter this at checkout.'),
                  ]),
                  _section(context, 'Discount', [
                    SegmentedButton<CouponDiscountType>(
                      segments: const [
                        ButtonSegment(
                          value: CouponDiscountType.percentage,
                          label: Text('Percentage'),
                        ),
                        ButtonSegment(
                          value: CouponDiscountType.flat,
                          label: Text('Fixed VND'),
                        ),
                      ],
                      selected: {_discountType},
                      onSelectionChanged: (value) =>
                          setState(() => _discountType = value.first),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _discount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText:
                            _discountType == CouponDiscountType.percentage
                            ? 'Discount (%)'
                            : 'Discount (VND)',
                      ),
                      validator: (_) => _positiveNumber(
                        _discount,
                        'Discount',
                        max: _discountType == CouponDiscountType.percentage
                            ? 100
                            : null,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (_discountType == CouponDiscountType.percentage) ...[
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _cap,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Maximum discount (VND)',
                        ),
                        validator: (_) =>
                            _positiveNumber(_cap, 'Maximum discount'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _minimumOrder,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Minimum order (VND)',
                      ),
                      validator: (_) {
                        return !_isSupportedMoney(
                              _minimumOrder,
                              allowZero: true,
                            )
                            ? 'Enter a non-negative amount with at most 2 decimal places.'
                            : null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                  ]),
                  _section(context, 'Availability', [
                    _dateButton(
                      context,
                      'Starts',
                      _startsAt,
                      () => _pickDateTime(starts: true),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _dateButton(
                      context,
                      'Ends',
                      _endsAt,
                      () => _pickDateTime(starts: false),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ExpansionTile(
                      title: const Text('Optional usage limits'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _usageLimit,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Total redemptions',
                                  hintText: 'Unlimited',
                                ),
                                validator: (_) =>
                                    _optionalPositiveInteger(_usageLimit),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              TextFormField(
                                controller: _perUserLimit,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Per customer',
                                  hintText: 'Unlimited',
                                ),
                                validator: (_) =>
                                    _optionalPositiveInteger(_perUserLimit),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ]),
                  _section(
                    context,
                    'Applicable tours (${_tourIds.length} selected)',
                    [
                      if (state.status == CreateCouponStatus.loadingTours)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.md),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (state.status ==
                          CreateCouponStatus.tourLoadFailure)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'We could not load your approved tours. Check your connection and try again.',
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  context.read<CreateCouponCubit>().loadTours(),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Try again'),
                            ),
                          ],
                        )
                      else if (state.tours.isEmpty)
                        const Text(
                          'No approved tours are available. Publish and get a tour approved before creating a coupon.',
                        )
                      else ...[
                        TextField(
                          controller: _tourSearch,
                          onChanged: (value) =>
                              setState(() => _tourQuery = value),
                          decoration: const InputDecoration(
                            labelText: 'Search approved tours',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (visibleTours.isEmpty)
                          const Text('No approved tours match this search.')
                        else
                          ...visibleTours.map(
                            (tour) => CheckboxListTile(
                              value: _tourIds.contains(tour.id),
                              onChanged: (selected) => setState(() {
                                if (selected ?? false) {
                                  _tourIds.add(tour.id);
                                } else {
                                  _tourIds.remove(tour.id);
                                }
                              }),
                              title: Text(tour.title),
                              subtitle: Text(
                                '${tour.destination ?? 'Destination not specified'} · ${_formatVnd(tour.basePrice)}',
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Card(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        '${_discountType == CouponDiscountType.percentage ? '${_discount.text.isEmpty ? '0' : _discount.text}% off, up to ${_formatVnd(_number(_cap))}' : '${_formatVnd(_number(_discount))} off'}\n'
                        '${_tourIds.length} selected tour(s) · ${MaterialLocalizations.of(context).formatMediumDate(_startsAt)} – ${MaterialLocalizations.of(context).formatMediumDate(_endsAt)}',
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed:
                        state.status == CreateCouponStatus.submitting ||
                            state.status == CreateCouponStatus.loadingTours
                        ? null
                        : _submit,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Text(
                        state.status == CreateCouponStatus.submitting
                            ? 'Creating coupon…'
                            : 'Create coupon',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              ...children,
            ],
          ),
        ),
      );

  Widget _dateButton(
    BuildContext context,
    String label,
    DateTime value,
    VoidCallback onPressed,
  ) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: const Icon(Icons.schedule),
    label: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        '$label: ${MaterialLocalizations.of(context).formatMediumDate(value)} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(value))}',
      ),
    ),
  );

  String _formatVnd(num? value) {
    if (value == null || value <= 0) return '₫0';
    final digits = value.toStringAsFixed(0);
    final grouped = digits.replaceAllMapped(
      RegExp(r'(?<!^)(?=(\d{3})+$)'),
      (_) => ',',
    );
    return '₫$grouped';
  }
}
