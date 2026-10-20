import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

/// Revenue, Analytics, Payout History and Settlement Request view for Tour Operator (SRS #89, #90, #91, #92).
class OperatorRevenueView extends StatelessWidget {
  const OperatorRevenueView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // Revenue Overview Hero
        _buildFinancialHero(context),
        const SizedBox(height: AppSpacing.md),

        // Actions: Request Payout & Export Report
        _buildActionButtons(context),
        const SizedBox(height: AppSpacing.lg),

        // Revenue by Tour Package Breakdown
        _buildTourBreakdownSection(context),
        const SizedBox(height: AppSpacing.lg),

        // Payout Settlement History (SRS #91)
        _buildPayoutHistorySection(context),
      ],
    );
  }

  Widget _buildFinancialHero(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00152A), Color(0xFF004D40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Số dư khả dụng thanh toán',
            style: TextStyle(
              color: Color(0xFF6DF5E1),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '38.500.000 đ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(color: Colors.white24),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _financeStat('Tổng doanh thu', '142.800.000 đ'),
              _financeStat('Đang xử lý', '12.500.000 đ'),
              _financeStat('Phí nền tảng (8%)', '11.424.000 đ'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _financeStat(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _showPayoutRequestDialog(context),
            icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
            label: const Text('Rút tiền / Payout'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showExportReportDialog(context),
            icon: const Icon(Icons.file_download_outlined, size: 18),
            label: const Text('Xuất báo cáo'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTourBreakdownSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Doanh thu theo gói Tour',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: const [
              _TourRevenueItem(
                title: 'Bà Nà Hills & Cầu Vàng',
                bookingsCount: 8,
                revenue: '20.000.000 đ',
                percentage: '52%',
              ),
              Divider(height: 1, indent: 16),
              _TourRevenueItem(
                title: 'Khám phá Hội An & Rừng dừa',
                bookingsCount: 6,
                revenue: '11.700.000 đ',
                percentage: '30%',
              ),
              Divider(height: 1, indent: 16),
              _TourRevenueItem(
                title: 'Cố đô Huế Di Sản',
                bookingsCount: 4,
                revenue: '6.800.000 đ',
                percentage: '18%',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPayoutHistorySection(BuildContext context) {
    final payouts = [
      {
        'id': 'PO-2026-089',
        'date': '15/10/2026',
        'amount': '25.000.000 đ',
        'bank': 'Vietcombank ****5678',
        'status': 'HOÀN TẤT',
        'type': StatusBadgeType.success,
      },
      {
        'id': 'PO-2026-074',
        'date': '01/10/2026',
        'amount': '32.000.000 đ',
        'bank': 'Vietcombank ****5678',
        'status': 'HOÀN TẤT',
        'type': StatusBadgeType.success,
      },
      {
        'id': 'PO-2026-061',
        'date': '15/09/2026',
        'amount': '18.500.000 đ',
        'bank': 'Vietcombank ****5678',
        'status': 'HOÀN TẤT',
        'type': StatusBadgeType.success,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lịch sử quyết toán Payout',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final p in payouts)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.arrow_downward,
                      size: 18,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p['id'] as String,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${p['bank']} · ${p['date']}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        p['amount'] as String,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      StatusBadge(
                        label: p['status'] as String,
                        type: p['type'] as StatusBadgeType,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showPayoutRequestDialog(BuildContext context) {
    final controller = TextEditingController(text: '30000000');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yêu cầu thanh toán Payout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Số dư khả dụng: 38.500.000 đ',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Số tiền yêu cầu rút (VND)',
                suffixText: 'VND',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Tài khoản thụ hưởng: Vietcombank\nSố TK: 0123456789012\nChủ TK: CTY TNHH DU LICH DA NANG DISCOVERY',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Yêu cầu quyết toán đã được gửi đến Administrator.',
                  ),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Gửi yêu cầu'),
          ),
        ],
      ),
    );
  }

  void _showExportReportDialog(BuildContext context) {
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
              const Text(
                'Xuất báo cáo doanh thu',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              const Text(
                'Chọn định dạng xuất dữ liệu đối soát tài chính:',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                leading: const Icon(
                  Icons.table_chart,
                  color: Color(0xFF059669),
                ),
                title: const Text('Báo cáo Excel (.xlsx)'),
                subtitle: const Text('Đầy đủ dữ liệu đơn đặt và hành khách'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đang xuất báo cáo Excel...')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.picture_as_pdf,
                  color: Color(0xFFE11D48),
                ),
                title: const Text('Báo cáo PDF (.pdf)'),
                subtitle: const Text('Bản in tổng hợp và chữ ký xác nhận'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đang xuất báo cáo PDF...')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TourRevenueItem extends StatelessWidget {
  const _TourRevenueItem({
    required this.title,
    required this.bookingsCount,
    required this.revenue,
    required this.percentage,
  });

  final String title;
  final int bookingsCount;
  final String revenue;
  final String percentage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$bookingsCount lượt đặt · Chiếm $percentage',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Text(
            revenue,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
