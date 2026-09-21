import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/theme/tour_search_palette.dart';

/// Modal bottom sheet for tour search filters.
///
/// Collects destination, departure date, min price, and max price,
/// validates client-side, and returns the filter values via callback.
class TourSearchFilterSheet extends StatefulWidget {
  const TourSearchFilterSheet({
    required this.onApply,
    required this.onReset,
    this.initialDestination,
    this.initialDepartureDate,
    this.initialMinPrice,
    this.initialMaxPrice,
    super.key,
  });

  final void Function({
    String? destination,
    DateTime? departureDate,
    int? minPrice,
    int? maxPrice,
  })
  onApply;

  final VoidCallback onReset;
  final String? initialDestination;
  final DateTime? initialDepartureDate;
  final int? initialMinPrice;
  final int? initialMaxPrice;

  @override
  State<TourSearchFilterSheet> createState() => _TourSearchFilterSheetState();
}

class _TourSearchFilterSheetState extends State<TourSearchFilterSheet> {
  late final TextEditingController _destinationController;
  late final TextEditingController _minPriceController;
  late final TextEditingController _maxPriceController;
  DateTime? _selectedDate;
  String? _priceError;

  @override
  void initState() {
    super.initState();
    _destinationController = TextEditingController(
      text: widget.initialDestination ?? '',
    );
    _minPriceController = TextEditingController(
      text: widget.initialMinPrice?.toString() ?? '',
    );
    _maxPriceController = TextEditingController(
      text: widget.initialMaxPrice?.toString() ?? '',
    );
    _selectedDate = widget.initialDepartureDate;
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Drag handle ────────────────────────────────────────
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: TourSearchPalette.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Bộ lọc tìm kiếm',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: TourSearchPalette.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Destination ────────────────────────────────────────
              Text(
                'Điểm đến',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: TourSearchPalette.navyLight,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: _destinationController,
                maxLength: 300,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Ví dụ: Đà Nẵng',
                  counterText: '',
                  prefixIcon: const Icon(Icons.place_outlined),
                  filled: true,
                  fillColor: TourSearchPalette.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: TourSearchPalette.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: TourSearchPalette.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Departure Date ─────────────────────────────────────
              Text(
                'Ngày khởi hành',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: TourSearchPalette.navyLight,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                    suffixIcon: _selectedDate != null
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Xóa ngày',
                            onPressed: () =>
                                setState(() => _selectedDate = null),
                          )
                        : null,
                    filled: true,
                    fillColor: TourSearchPalette.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: TourSearchPalette.cardBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: TourSearchPalette.cardBorder,
                      ),
                    ),
                  ),
                  child: Text(
                    _selectedDate != null
                        ? '${_selectedDate!.day.toString().padLeft(2, '0')}/'
                              '${_selectedDate!.month.toString().padLeft(2, '0')}/'
                              '${_selectedDate!.year}'
                        : 'Chọn ngày khởi hành',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: _selectedDate != null
                          ? TourSearchPalette.navy
                          : TourSearchPalette.muted,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Price Range ────────────────────────────────────────
              Text(
                'Khoảng giá (VNĐ)',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: TourSearchPalette.navyLight,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minPriceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: 'Giá tối thiểu',
                        filled: true,
                        fillColor: TourSearchPalette.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: TourSearchPalette.cardBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: TourSearchPalette.cardBorder,
                          ),
                        ),
                      ),
                      onChanged: (_) => _clearPriceError(),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    child: Text('–'),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _maxPriceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: 'Giá tối đa',
                        filled: true,
                        fillColor: TourSearchPalette.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: TourSearchPalette.cardBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: TourSearchPalette.cardBorder,
                          ),
                        ),
                      ),
                      onChanged: (_) => _clearPriceError(),
                    ),
                  ),
                ],
              ),
              if (_priceError != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _priceError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: TourSearchPalette.soldOut,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),

              // ── Action Buttons ─────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _handleReset,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        side: BorderSide(color: TourSearchPalette.cardBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Đặt lại'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _handleApply,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        backgroundColor: TourSearchPalette.teal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Áp dụng bộ lọc'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clearPriceError() {
    if (_priceError != null) {
      setState(() => _priceError = null);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      helpText: 'Chọn ngày khởi hành',
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _handleApply() {
    final destination = _destinationController.text.trim();
    final minText = _minPriceController.text.trim();
    final maxText = _maxPriceController.text.trim();

    final minPrice = minText.isNotEmpty ? int.tryParse(minText) : null;
    final maxPrice = maxText.isNotEmpty ? int.tryParse(maxText) : null;

    if (minPrice != null && (minPrice < 0 || minPrice > 9999999999)) {
      setState(() {
        _priceError = 'Giá tối thiểu phải từ 0 đến 9.999.999.999 VNĐ.';
      });
      return;
    }

    if (maxPrice != null && (maxPrice < 0 || maxPrice > 9999999999)) {
      setState(() {
        _priceError = 'Giá tối đa phải từ 0 đến 9.999.999.999 VNĐ.';
      });
      return;
    }

    if (minPrice != null && maxPrice != null && minPrice > maxPrice) {
      setState(() {
        _priceError = 'Giá tối thiểu không được lớn hơn giá tối đa.';
      });
      return;
    }

    widget.onApply(
      destination: destination.isNotEmpty ? destination : null,
      departureDate: _selectedDate,
      minPrice: minPrice,
      maxPrice: maxPrice,
    );
    Navigator.of(context).pop();
  }

  void _handleReset() {
    widget.onReset();
    Navigator.of(context).pop();
  }
}
