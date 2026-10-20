import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/qr_scanner_dialog.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

/// Tour Operator Dashboard screen implementing SRS #75 & QR Check-in shortcut (SRS #88).
class OperatorDashboardView extends StatelessWidget {
  const OperatorDashboardView({required this.onNavigateToTab, super.key});

  final void Function(int index) onNavigateToTab;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // Operator Welcome Header
        _buildHeader(context),
        const SizedBox(height: AppSpacing.md),

        // Quick Operations Row
        _buildQuickOperationsBar(context),
        const SizedBox(height: AppSpacing.lg),

        // Key Metrics Bento Grid
        _buildMetricsGrid(context),
        const SizedBox(height: AppSpacing.lg),

        // Today's Departure & Check-in Status
        _buildTodayDeparturesCard(context),
        const SizedBox(height: AppSpacing.lg),

        // Recent Bookings Snapshot
        _buildRecentBookingsSection(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.business_center,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Đà Nẵng Discovery Travel',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.verified,
                    size: 16,
                    color: AppColors.secondary,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Đối tác lữ hành chính thức · Mã ĐT: OP-2026-08',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickOperationsBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00152A), Color(0xFF004D40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.qr_code_scanner, color: Color(0xFF6DF5E1), size: 20),
              SizedBox(width: 8),
              Text(
                'ĐIỂM DANH CHECK-IN TOUR',
                style: TextStyle(
                  color: Color(0xFF6DF5E1),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Quét vé điện tử QR của hành khách',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Xác thực vé nhanh chóng tại điểm đón khách và cập nhật trạng thái tham gia tức thì.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openQrScanner(context),
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Mở máy quét QR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006B5F),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.createTourPackage),
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: const Text(
                  'Tạo Tour',
                  style: TextStyle(color: Colors.white),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF6DF5E1), width: 1.2),
                  minimumSize: const Size(110, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chỉ số hoạt động',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Tour hoạt động',
                value: '4 gói',
                subtitle: '2 bản nháp',
                icon: Icons.tour_outlined,
                color: const Color(0xFF0284C7),
                onTap: () => onNavigateToTab(1), // Tours tab
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _MetricCard(
                title: 'Đơn đặt chỗ',
                value: '18 lượt',
                subtitle: '5 chờ check-in',
                icon: Icons.confirmation_number_outlined,
                color: const Color(0xFF0D9488),
                onTap: () => onNavigateToTab(2), // Bookings tab
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Doanh thu tháng',
                value: '38.500.000 đ',
                subtitle: 'Đã sẵn sàng rút',
                icon: Icons.payments_outlined,
                color: const Color(0xFF059669),
                onTap: () => onNavigateToTab(3), // Revenue tab
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _MetricCard(
                title: 'Mã giảm giá',
                value: '3 mã',
                subtitle: 'Đang áp dụng',
                icon: Icons.local_offer_outlined,
                color: const Color(0xFFD97706),
                onTap: () => onNavigateToTab(4), // Coupons tab
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTodayDeparturesCard(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.directions_bus,
                    size: 18,
                    color: AppColors.secondary,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Khởi hành hôm nay',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
              StatusBadge(
                label: '12/15 ĐÃ CHECK-IN',
                type: StatusBadgeType.success,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Tour Khám phá Ngũ Hành Sơn & Hội An Phố Cổ',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Giờ khởi hành: 08:30 · Điểm đón: Công viên Biển Đông Đà Nẵng',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => onNavigateToTab(2), // View passenger list
                icon: const Icon(Icons.people_outline, size: 16),
                label: const Text('Danh sách hành khách (15)'),
              ),
              FilledButton.icon(
                onPressed: () => _openQrScanner(context),
                icon: const Icon(Icons.qr_code_scanner, size: 16),
                label: const Text('Quét vé'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(100, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentBookingsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Đơn đặt tour gần đây',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            TextButton(
              onPressed: () => onNavigateToTab(2),
              child: const Text('Xem tất cả'),
            ),
          ],
        ),
        _recentBookingTile(
          code: 'BK-2026-901',
          name: 'Nguyễn Văn An',
          tour: 'Tour Bà Nà Hills Trọn Gói',
          guests: '2 khách',
          amount: '2.500.000 đ',
          status: 'ĐÃ XÁC NHẬN',
          statusType: StatusBadgeType.success,
        ),
        const SizedBox(height: AppSpacing.xs),
        _recentBookingTile(
          code: 'BK-2026-902',
          name: 'Trần Thị Mai',
          tour: 'Hội An Cycling & Nấu ăn',
          guests: '3 khách',
          amount: '1.950.000 đ',
          status: 'CHỜ CHECK-IN',
          statusType: StatusBadgeType.info,
        ),
      ],
    );
  }

  Widget _recentBookingTile({
    required String code,
    required String name,
    required String tour,
    required String guests,
    required String amount,
    required String status,
    required StatusBadgeType statusType,
  }) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      code,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$tour · $guests',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusBadge(label: status, type: statusType),
              const SizedBox(height: 2),
              Text(
                amount,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openQrScanner(BuildContext context) async {
    final scannedCode = await showDialog<String>(
      context: context,
      builder: (ctx) =>
          QrScannerDialog(onScanned: (code) => Navigator.pop(ctx, code)),
    );

    if (scannedCode != null && context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success),
              SizedBox(width: 8),
              Text('Check-in thành công'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mã vé: $scannedCode',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text('Hành khách: Đã xác thực hợp lệ.'),
              const Text('Trạng thái: Đã đánh dấu tham gia tour khởi hành.'),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Hoàn tất'),
            ),
          ],
        ),
      );
    }
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.muted,
                ),
              ),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
