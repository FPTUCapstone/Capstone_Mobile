import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/commercial_booking_repository.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/commercial_booking_cubit.dart';

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
  }) => TextFormField(
    controller: controller,
    maxLength: length,
    keyboardType: keyboard,
    decoration: InputDecoration(labelText: label),
    validator: (value) =>
        value == null || value.trim().isEmpty ? 'Thông tin bắt buộc' : null,
  );

  String _vietnamTime(DateTime value) {
    final time = value.toUtc().add(const Duration(hours: 7));
    return '${time.day}/${time.month}/${time.year} · ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<CommercialBookingCubit>().state;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đặt dịch vụ'),
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
        final receipt? => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Yêu cầu ${receipt.requestCode}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text('Chờ nhà cung cấp xác nhận'),
              Text('Giá ước tính: ${receipt.estimatedAmount} ₫'),
            ],
          ),
        ),
        null => FutureBuilder<List<CommercialOption>>(
          future: _options,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: TextButton(
                  onPressed: () => setState(
                    () => _options = context
                        .read<CommercialBookingCubit>()
                        .options(widget.poiId),
                  ),
                  child: const Text('Không tải được dịch vụ · Thử lại'),
                ),
              );
            }
            final options = snapshot.data!;
            if (options.isEmpty) {
              return const Center(
                child: Text('Chưa có dịch vụ mở đặt tại địa điểm này.'),
              );
            }
            final slot = _slot;
            return Form(
              key: _form,
              child: SingleChildScrollView(
                key: const Key('commercial_booking_form_scroll'),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButton<CommercialOption>(
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
                    if (_option != null)
                      TextButton(
                        onPressed: _busy ? null : () => _select(_option),
                        child: const Text('Làm mới lịch'),
                      ),
                    if (_slots != null)
                      FutureBuilder<List<CommercialSlot>>(
                        future: _slots,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const LinearProgressIndicator();
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
                            return const Text('Chưa có khung giờ còn chỗ.');
                          }
                          return DropdownButton<CommercialSlot>(
                            isExpanded: true,
                            hint: const Text('Ngày giờ (Việt Nam)'),
                            value: _slot,
                            items: slots
                                .map(
                                  (item) => DropdownMenuItem(
                                    value: item,
                                    child: Text(_vietnamTime(item.startsAt)),
                                  ),
                                )
                                .toList(),
                            onChanged: _busy
                                ? null
                                : (value) => setState(() {
                                    _slot = value;
                                    _quantity = 1;
                                  }),
                          );
                        },
                      ),
                    if (booking.error != null)
                      Text(
                        booking.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (slot != null) ...[
                      Text('Số lượng · còn ${slot.remainingQuantity}'),
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Giảm số lượng',
                            onPressed: _busy || _quantity == 1
                                ? null
                                : () => setState(() => _quantity--),
                            icon: const Icon(Icons.remove),
                          ),
                          Text('$_quantity'),
                          IconButton(
                            tooltip: 'Tăng số lượng',
                            onPressed:
                                _busy || _quantity == slot.remainingQuantity
                                ? null
                                : () => setState(() => _quantity++),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      Text(
                        'Giá ước tính: ${_option!.priceAmount * _quantity} ₫',
                      ),
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
                        decoration: const InputDecoration(
                          labelText: 'Ghi chú (không bắt buộc)',
                        ),
                      ),
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
