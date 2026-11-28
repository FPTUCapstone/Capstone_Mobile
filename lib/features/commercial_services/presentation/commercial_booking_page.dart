import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/commercial_booking_repository.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/commercial_booking_cubit.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_coastal_app_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/app_empty_state.dart';
import 'package:trip_mate_mobile/shared/widgets/app_section_card.dart';

final class CommercialBookingPage extends StatefulWidget {
  const CommercialBookingPage({
    required this.poiId,
    this.itineraryId,
    super.key,
  });

  final int poiId;
  final int? itineraryId;

  @override
  State<CommercialBookingPage> createState() => _CommercialBookingPageState();
}

final class _CommercialBookingPageState extends State<CommercialBookingPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _notes = TextEditingController();
  late Future<List<CommercialOption>> _options = context
      .read<CommercialBookingCubit>()
      .options(widget.poiId);
  Future<List<CommercialSlot>>? _slots;
  CommercialOption? _option;
  CommercialSlot? _slot;
  var _quantity = 1;
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final option = _option;
    final slot = _slot;
    if (_busy ||
        option == null ||
        slot == null ||
        !_form.currentState!.validate()) {
      return;
    }
    final request = (
      serviceId: option.id,
      startsAt: slot.startsAt,
      quantity: _quantity,
      contactName: _name.text.trim(),
      contactPhone: _phone.text.trim(),
      contactEmail: _email.text.trim(),
      specialRequest: _notes.text.trim(),
      itineraryId: widget.itineraryId,
    );
    setState(() => _busy = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Gửi yêu cầu đặt dịch vụ?'),
          content: const Text(
            'Nhà cung cấp sẽ xem xét yêu cầu. Bạn thanh toán trực tiếp khi sử dụng dịch vụ.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Quay lại'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xác nhận gửi'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final cubit = context.read<CommercialBookingCubit>();
      await cubit.submit(request);
      if (!mounted || !cubit.state.refreshAvailability) return;
      setState(() {
        _slot = null;
        _quantity = 1;
        _slots = cubit.availability(option.id);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _select(CommercialOption? option) {
    context.read<CommercialBookingCubit>().clearError();
    setState(() {
      _option = option;
      _slot = null;
      _quantity = 1;
      _slots = option == null
          ? null
          : context.read<CommercialBookingCubit>().availability(option.id);
    });
  }

  Widget _field(
    String label,
    TextEditingController controller,
    int length, {
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: TextFormField(
      controller: controller,
      maxLength: length,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label, counterText: ''),
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'Thông tin bắt buộc' : null,
    ),
  );

  String _vietnamTime(DateTime value) {
    final time = value.toUtc().add(const Duration(hours: 7));
    return '${time.day}/${time.month}/${time.year} · ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final booking = context.watch<CommercialBookingCubit>().state;
    return Scaffold(
      backgroundColor: c.canvas,
      appBar: AppCoastalAppBar(
        title: 'Đặt dịch vụ',
        actions: [
          IconButton(
            tooltip: 'Yêu cầu của tôi',
            onPressed: _busy
                ? null
                : () => context.push(AppRoutes.commercialBookingRequests),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
        ],
      ),
      body: switch (booking.receipt) {
        final receipt? => SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: c.successContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle_outline_rounded,
                      size: 32,
                      color: c.success,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Yêu cầu ${receipt.requestCode}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTypography.displayFont,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: c.warningContainer,
                      borderRadius: BorderRadius.circular(TripMateRadius.pill),
                      border: Border.all(
                        color: c.warning.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      'Chờ nhà cung cấp xác nhận',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: c.warning,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: c.tealSoftContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Giá ước tính: ${receipt.estimatedAmount} ₫',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: c.brandTeal,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () =>
                      context.push(AppRoutes.commercialBookingRequests),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Xem yêu cầu của tôi'),
                ),
              ],
            ),
          ),
        ),
        null => FutureBuilder<List<CommercialOption>>(
          future: _options,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Center(
                child: CircularProgressIndicator(color: c.brandTeal),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off_outlined, size: 42, color: c.error),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                        onPressed: () => setState(
                          () => _options = context
                              .read<CommercialBookingCubit>()
                              .options(widget.poiId),
                        ),
                        child: const Text('Không tải được dịch vụ · Thử lại'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final options = snapshot.data!;
            if (options.isEmpty) {
              return const AppEmptyState(
                icon: Icons.storefront_outlined,
                title: 'Chưa có dịch vụ mở đặt tại địa điểm này.',
              );
            }
            final slot = _slot;
            return Form(
              key: _form,
              child: SingleChildScrollView(
                key: const Key('commercial_booking_form_scroll'),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSectionCard(
                      title: 'Dịch vụ & khung giờ',
                      icon: Icons.event_available_outlined,
                      trailing: _option != null
                          ? TextButton(
                              onPressed: _busy ? null : () => _select(_option),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              child: const Text('Làm mới lịch'),
                            )
                          : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: c.canvas,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: c.borderSubtle),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<CommercialOption>(
                                isExpanded: true,
                                hint: const Text('Chọn dịch vụ'),
                                value: _option,
                                onChanged: _busy ? null : _select,
                                items: options
                                    .map(
                                      (item) => DropdownMenuItem(
                                        value: item,
                                        child: Text(item.name),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                          if (_slots != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            FutureBuilder<List<CommercialSlot>>(
                              future: _slots,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState !=
                                    ConnectionState.done) {
                                  return LinearProgressIndicator(
                                    color: c.brandTeal,
                                    backgroundColor: c.surfaceElevated,
                                  );
                                }
                                if (snapshot.hasError) {
                                  return TextButton(
                                    onPressed: () => _select(_option),
                                    child: const Text(
                                      'Không tải được lịch · Thử lại',
                                    ),
                                  );
                                }
                                final slots = snapshot.data!;
                                if (slots.isEmpty) {
                                  return Text(
                                    'Chưa có khung giờ còn chỗ.',
                                    style: TextStyle(color: c.textSecondary),
                                  );
                                }
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                  ),
                                  decoration: BoxDecoration(
                                    color: c.canvas,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: c.borderSubtle),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<CommercialSlot>(
                                      isExpanded: true,
                                      hint: const Text('Ngày giờ (Việt Nam)'),
                                      value: _slot,
                                      items: slots
                                          .map(
                                            (item) => DropdownMenuItem(
                                              value: item,
                                              child: Text(
                                                _vietnamTime(item.startsAt),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: _busy
                                          ? null
                                          : (value) => setState(() {
                                              _slot = value;
                                              _quantity = 1;
                                            }),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                          if (slot != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Số lượng · còn ${slot.remainingQuantity}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: c.textPrimary,
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: c.canvas,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: c.borderSubtle),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Giảm số lượng',
                                        onPressed: _busy || _quantity == 1
                                            ? null
                                            : () => setState(() => _quantity--),
                                        icon: const Icon(Icons.remove),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                        ),
                                        child: Text(
                                          '$_quantity',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: c.textPrimary,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Tăng số lượng',
                                        onPressed:
                                            _busy ||
                                                _quantity ==
                                                    slot.remainingQuantity
                                            ? null
                                            : () => setState(() => _quantity++),
                                        icon: const Icon(Icons.add),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: c.tealSoftContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Giá ước tính: ${_option!.priceAmount * _quantity} ₫',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                  color: c.brandTeal,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (booking.error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      AppAlert(
                        type: AppAlertType.error,
                        message: booking.error!,
                      ),
                    ],
                    if (slot != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      AppSectionCard(
                        title: 'Thông tin liên hệ',
                        icon: Icons.person_outline,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _field('Họ tên liên hệ', _name, 150),
                            _field(
                              'Số điện thoại',
                              _phone,
                              20,
                              keyboard: TextInputType.phone,
                            ),
                            _field(
                              'Email',
                              _email,
                              256,
                              keyboard: TextInputType.emailAddress,
                            ),
                            TextFormField(
                              controller: _notes,
                              maxLength: 1000,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Ghi chú (không bắt buộc)',
                                counterText: '',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: Text(_busy ? 'Đang xử lý…' : 'Gửi yêu cầu'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      },
    );
  }
}
