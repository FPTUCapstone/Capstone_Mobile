import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/coupon/domain/entities/coupon_draft.dart';
import 'package:trip_mate_mobile/features/coupon/presentation/cubit/create_coupon_cubit.dart';
import 'package:trip_mate_mobile/features/coupon/presentation/cubit/create_coupon_state.dart';
import 'package:trip_mate_mobile/shared/widgets/app_coastal_app_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/app_section_card.dart';

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
        ? 'Nhập số nguyên lớn hơn 0, hoặc để trống.'
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
          ? '$label phải lớn hơn 0.'
          : '$label phải nằm trong khoảng từ 1 đến $max.';
    }
    return null;
  }

  void _submit() {
    final validForm = _formKey.currentState!.validate();
    if (!validForm) return;
    if (_endsAt.compareTo(_startsAt) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thời gian kết thúc phải sau thời gian bắt đầu.'),
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
          content: Text(
            'Mức giảm cố định không thể vượt quá đơn hàng tối thiểu.',
          ),
        ),
      );
      return;
    }
    if (_tourIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ít nhất một tour đã duyệt.'),
        ),
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
              title: const Text('Đã tạo mã giảm giá'),
              content: Text(
                'Mã ${state.createdCode} đã sẵn sàng áp dụng cho các tour bạn chọn.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).maybePop();
                  },
                  child: const Text('Xong'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _resetForAnotherCoupon();
                  },
                  child: const Text('Tạo mã khác'),
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
        final c = context.tmColors;
        return Scaffold(
          backgroundColor: c.canvas,
          appBar: const AppCoastalAppBar(title: 'Tạo mã giảm giá'),
          body: SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  Text(
                    'Tạo ưu đãi rõ ràng cho các tour đã được duyệt của bạn.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: c.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _section(context, 'Mã giảm giá', Icons.local_offer_outlined, [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _code,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Mã ưu đãi',
                              hintText: 'SUMMER25',
                            ),
                            validator: (value) =>
                                value == null ||
                                    !RegExp(
                                      r'^[A-Za-z0-9-]{3,30}$',
                                    ).hasMatch(value.trim())
                                ? 'Dùng 3–30 chữ cái, chữ số hoặc dấu gạch ngang.'
                                : null,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        OutlinedButton(
                          onPressed: () =>
                              setState(() => _code.text = _newCode()),
                          child: const Text('Tạo tự động'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text('Khách hàng sẽ nhập mã này khi thanh toán.'),
                  ]),
                  _section(context, 'Mức giảm giá', Icons.percent_rounded, [
                    SegmentedButton<CouponDiscountType>(
                      segments: const [
                        ButtonSegment(
                          value: CouponDiscountType.percentage,
                          label: Text('Theo phần trăm'),
                        ),
                        ButtonSegment(
                          value: CouponDiscountType.flat,
                          label: Text('Số tiền cố định (VND)'),
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
                            ? 'Mức giảm (%)'
                            : 'Mức giảm (VND)',
                      ),
                      validator: (_) => _positiveNumber(
                        _discount,
                        'Mức giảm',
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
                          labelText: 'Mức giảm tối đa (VND)',
                        ),
                        validator: (_) =>
                            _positiveNumber(_cap, 'Mức giảm tối đa'),
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
                        labelText: 'Đơn hàng tối thiểu (VND)',
                      ),
                      validator: (_) {
                        return !_isSupportedMoney(
                              _minimumOrder,
                              allowZero: true,
                            )
                            ? 'Nhập số tiền không âm với tối đa 2 chữ số thập phân.'
                            : null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                  ]),
                  _section(context, 'Thời gian áp dụng', Icons.event_outlined, [
                    _dateButton(
                      context,
                      'Bắt đầu',
                      _startsAt,
                      () => _pickDateTime(starts: true),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _dateButton(
                      context,
                      'Kết thúc',
                      _endsAt,
                      () => _pickDateTime(starts: false),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ExpansionTile(
                      title: const Text('Giới hạn lượt sử dụng (tùy chọn)'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _usageLimit,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Tổng số lượt dùng',
                                  hintText: 'Không giới hạn',
                                ),
                                validator: (_) =>
                                    _optionalPositiveInteger(_usageLimit),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              TextFormField(
                                controller: _perUserLimit,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Giới hạn mỗi khách',
                                  hintText: 'Không giới hạn',
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
                    'Tour áp dụng (đã chọn ${_tourIds.length})',
                    Icons.tour_outlined,
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
                              'Không thể tải danh sách tour đã duyệt. Vui lòng kiểm tra kết nối và thử lại.',
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  context.read<CreateCouponCubit>().loadTours(),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Thử lại'),
                            ),
                          ],
                        )
                      else if (state.tours.isEmpty)
                        const Text(
                          'Chưa có tour nào được duyệt. Vui lòng gửi duyệt và mở bán tour trước khi tạo mã giảm giá.',
                        )
                      else ...[
                        TextField(
                          controller: _tourSearch,
                          onChanged: (value) =>
                              setState(() => _tourQuery = value),
                          decoration: const InputDecoration(
                            labelText: 'Tìm tour đã duyệt',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (visibleTours.isEmpty)
                          const Text('Không tìm thấy tour đã duyệt phù hợp.')
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
                                '${tour.destination ?? 'Chưa rõ điểm đến'} · ${_formatVnd(tour.basePrice)}',
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: c.tealSoftContainer,
                      borderRadius: BorderRadius.circular(TripMateRadius.lg),
                      border: Border.all(
                        color: c.brandTeal.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.confirmation_number_outlined,
                          size: 20,
                          color: c.brandTeal,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            '${_discountType == CouponDiscountType.percentage ? 'Giảm ${_discount.text.isEmpty ? '0' : _discount.text}%, tối đa ${_formatVnd(_number(_cap))}' : 'Giảm ${_formatVnd(_number(_discount))}'}\n'
                            'Đã chọn ${_tourIds.length} tour · ${MaterialLocalizations.of(context).formatMediumDate(_startsAt)} – ${MaterialLocalizations.of(context).formatMediumDate(_endsAt)}',
                            style: TextStyle(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
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
                            ? 'Đang tạo mã giảm giá…'
                            : 'Tạo mã giảm giá',
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

  Widget _section(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: AppSectionCard(
      title: title,
      icon: icon,
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
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
