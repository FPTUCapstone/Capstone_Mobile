import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/qr_scanner_dialog.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_empty_state.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

/// Customer Bookings & Passenger Manifest view for Tour Operator (SRS #84, #85, #86, #87).
class OperatorBookingsView extends StatefulWidget {
  const OperatorBookingsView({this.isDemoMode = false, super.key});

  final bool isDemoMode;

  @override
  State<OperatorBookingsView> createState() => _OperatorBookingsViewState();
}

class _OperatorBookingsViewState extends State<OperatorBookingsView> {
  var _selectedFilter = 'all';

  // Supported booking models for operator tours (Demo mode fixtures only)
  final _bookings = [
    _OperatorBookingItem(
      bookingCode: 'BK-2026-901',
      customerName: 'Nguyễn Văn An',
      phone: '0905 123 456',
      tourTitle: 'Tour Bà Nà Hills & Cầu Vàng Trọn Gói',
      departureDate: '20/10/2026 - 08:00',
      participantsCount: 2,
      totalAmount: '2.500.000 đ',
      status: _BookingStatus.checkedIn,
      passengers: ['Nguyễn Văn An (Trưởng đoàn)', 'Lê Thị Bình'],
      pickupLocation: 'Khách sạn Novotel Đà Nẵng',
    ),
    _OperatorBookingItem(
      bookingCode: 'BK-2026-902',
      customerName: 'Trần Thị Mai',
      phone: '0912 987 654',
      tourTitle: 'Tour Khám phá Hội An & Rừng Dừa Bảy Mẫu',
      departureDate: '20/10/2026 - 08:30',
      participantsCount: 3,
      totalAmount: '1.950.000 đ',
      status: _BookingStatus.pendingCheckIn,
      passengers: [
        'Trần Thị Mai',
        'Hoàng Văn Cường',
        'Hoàng Bảo Ngọc (Trẻ em)',
      ],
      pickupLocation: 'Công viên Biển Đông, Đà Nẵng',
    ),
    _OperatorBookingItem(
      bookingCode: 'BK-2026-903',
      customerName: 'David Miller',
      phone: '+84 934 555 777',
      tourTitle: 'Cố Đô Huế Di Sản & Nhã Nhạc Cung Đình',
      departureDate: '21/10/2026 - 07:30',
      participantsCount: 2,
      totalAmount: '1.700.000 đ',
      status: _BookingStatus.confirmed,
      passengers: ['David Miller (UK)', 'Sarah Miller (UK)'],
      pickupLocation: 'Hilton Da Nang',
    ),
    _OperatorBookingItem(
      bookingCode: 'BK-2026-880',
      customerName: 'Phạm Minh Đức',
      phone: '0988 333 222',
      tourTitle: 'Bán đảo Sơn Trà & Chùa Linh Ứng',
      departureDate: '18/10/2026 - 14:00',
      participantsCount: 1,
      totalAmount: '450.000 đ',
      status: _BookingStatus.cancelled,
      passengers: ['Phạm Minh Đức'],
      pickupLocation: 'Đà Nẵng',
      refundStatus: 'Chờ quyết toán hoàn tiền (100%)',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (!widget.isDemoMode) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: AppEmptyState(
              icon: Icons.confirmation_number_outlined,
              title: 'Chưa có đơn đặt tour',
              message:
                  'Tính năng quản lý danh sách hành khách và đơn đặt chỗ đang chờ kết nối API hệ thống (PENDING_BE_INTEGRATION).',
            ),
          ),
        ),
      );
    }

    final filtered = _bookings.where((b) {
      if (_selectedFilter == 'pending') {
        return b.status == _BookingStatus.pendingCheckIn ||
            b.status == _BookingStatus.confirmed;
      }
      if (_selectedFilter == 'checkedIn') {
        return b.status == _BookingStatus.checkedIn;
      }
      if (_selectedFilter == 'cancelled') {
        return b.status == _BookingStatus.cancelled;
      }
      return true;
    }).toList();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: const Color(0xFFFEF3C7),
          child: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFD97706),
                size: 16,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '[DỮ LIỆU THỬ NGHIỆM - DEMO] Danh sách khách hàng và mã đặt chỗ là dữ liệu mẫu.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Filter Chips Row
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              _filterChip('Tất cả', 'all'),
              const SizedBox(width: AppSpacing.xs),
              _filterChip('Chờ check-in', 'pending'),
              const SizedBox(width: AppSpacing.xs),
              _filterChip('Đã check-in', 'checkedIn'),
              const SizedBox(width: AppSpacing.xs),
              _filterChip('Đã hủy', 'cancelled'),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: filtered.isEmpty
              ? const AppEmptyState(
                  icon: Icons.book_online_outlined,
                  title: 'Không có đơn đặt chỗ nào',
                  message:
                      'Không tìm thấy đơn đặt tour nào theo tiêu chí lọc này.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final booking = filtered[index];
                    return _buildBookingCard(context, booking);
                  },
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? AppColors.secondary : AppColors.muted,
      ),
      selectedColor: AppColors.primarySoft,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? AppColors.secondary : AppColors.line,
      ),
      onSelected: (_) {
        setState(() => _selectedFilter = value);
      },
    );
  }

  Widget _buildBookingCard(BuildContext context, _OperatorBookingItem b) {
    final (statusLabel, statusType) = switch (b.status) {
      _BookingStatus.confirmed => ('ĐÃ XÁC NHẬN', StatusBadgeType.info),
      _BookingStatus.pendingCheckIn => (
        'CHỜ CHECK-IN',
        StatusBadgeType.warning,
      ),
      _BookingStatus.checkedIn => ('ĐÃ CHECK-IN', StatusBadgeType.success),
      _BookingStatus.cancelled => ('ĐÃ HỦY', StatusBadgeType.error),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  b.bookingCode,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.muted,
                  ),
                ),
                StatusBadge(label: statusLabel, type: statusType),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              b.tourTitle,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.person, size: 14, color: AppColors.muted),
                const SizedBox(width: 4),
                Text(
                  b.customerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.phone, size: 14, color: AppColors.muted),
                const SizedBox(width: 4),
                Text(
                  b.phone,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      b.departureDate,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  b.totalAmount,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showPassengerManifest(context, b),
                    icon: const Icon(Icons.people_outline, size: 16),
                    label: Text('Hành khách (${b.participantsCount})'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (b.status == _BookingStatus.pendingCheckIn ||
                    b.status == _BookingStatus.confirmed)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _openCheckInForBooking(context, b),
                      icon: const Icon(Icons.qr_code_scanner, size: 16),
                      label: const Text('Check-in QR'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(40),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  )
                else if (b.status == _BookingStatus.cancelled)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _showRefundAction(context, b),
                      icon: const Icon(Icons.currency_exchange, size: 16),
                      label: const Text('Xử lý hoàn tiền'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        minimumSize: const Size.fromHeight(40),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check,
                            size: 16,
                            color: AppColors.secondary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Đã đón khách',
                            style: TextStyle(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPassengerManifest(BuildContext context, _OperatorBookingItem b) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Danh sách hành khách (Manifest)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              Text(
                'Mã đặt: ${b.bookingCode} · ${b.tourTitle}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const Divider(height: 20),
              const Text(
                'Điểm đón khách:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              Text(b.pickupLocation, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Danh sách người tham gia:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 4),
              for (var i = 0; i < b.passengers.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        b.passengers[i],
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Đóng'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCheckInForBooking(
    BuildContext context,
    _OperatorBookingItem b,
  ) async {
    final scanned = await showDialog<String>(
      context: context,
      builder: (ctx) =>
          QrScannerDialog(onScanned: (code) => Navigator.pop(ctx, code)),
    );
    if (scanned != null && context.mounted) {
      setState(() {
        // Mark checked in
        final index = _bookings.indexOf(b);
        if (index != -1) {
          _bookings[index] = b.copyWith(status: _BookingStatus.checkedIn);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã check-in thành công cho khách hàng ${b.customerName}!',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _showRefundAction(BuildContext context, _OperatorBookingItem b) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xử lý hoàn tiền hủy tour'),
        content: Text(
          'Đơn đặt ${b.bookingCode} của ${b.customerName} đã hủy.\n'
          'Số tiền hoàn: ${b.totalAmount}\n\n'
          'Xác nhận gửi thông báo cho cổng thanh toán để tiến hành hoàn tiền?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy bỏ'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Chế độ dữ liệu mẫu: Thao tác giả lập thành công, không gọi API thanh toán thực tế.',
                  ),
                ),
              );
            },
            child: const Text('Xác nhận hoàn tiền'),
          ),
        ],
      ),
    );
  }
}

enum _BookingStatus { confirmed, pendingCheckIn, checkedIn, cancelled }

class _OperatorBookingItem {
  const _OperatorBookingItem({
    required this.bookingCode,
    required this.customerName,
    required this.phone,
    required this.tourTitle,
    required this.departureDate,
    required this.participantsCount,
    required this.totalAmount,
    required this.status,
    required this.passengers,
    required this.pickupLocation,
    this.refundStatus,
  });

  final String bookingCode;
  final String customerName;
  final String phone;
  final String tourTitle;
  final String departureDate;
  final int participantsCount;
  final String totalAmount;
  final _BookingStatus status;
  final List<String> passengers;
  final String pickupLocation;
  final String? refundStatus;

  _OperatorBookingItem copyWith({_BookingStatus? status}) {
    return _OperatorBookingItem(
      bookingCode: bookingCode,
      customerName: customerName,
      phone: phone,
      tourTitle: tourTitle,
      departureDate: departureDate,
      participantsCount: participantsCount,
      totalAmount: totalAmount,
      status: status ?? this.status,
      passengers: passengers,
      pickupLocation: pickupLocation,
      refundStatus: refundStatus,
    );
  }
}
