import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_empty_state.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

/// Promotional Coupons List view for Tour Operator (SRS #81, #82, #83).
class OperatorCouponsView extends StatelessWidget {
  const OperatorCouponsView({this.isDemoMode = false, super.key});

  final bool isDemoMode;

  @override
  Widget build(BuildContext context) {
    if (!isDemoMode) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push(AppRoutes.createCoupon),
          icon: const Icon(Icons.add),
          label: const Text('Tạo coupon mới'),
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
        ),
        body: const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: AppEmptyState(
              icon: Icons.confirmation_number_outlined,
              title: 'Chưa có mã khuyến mãi',
              message:
                  'Tính năng quản lý và phân phối coupon đối tác đang chờ kết nối API hệ thống (PENDING_BE_INTEGRATION).',
            ),
          ),
        ),
      );
    }

    final coupons = [
      _CouponData(
        code: 'DANANG2026',
        discount: 'Giảm 15%',
        description: 'Áp dụng cho tất cả các tour khởi hành từ Đà Nẵng',
        validUntil: 'Hạn dùng: 31/12/2026',
        usage: 'Đã dùng 24 / 50 lượt',
        isActive: true,
      ),
      _CouponData(
        code: 'SUMMERTRIP',
        discount: 'Giảm 100.000 đ',
        description: 'Đơn đặt từ 2 khách trở lên cho Tour Hội An',
        validUntil: 'Hạn dùng: 30/11/2026',
        usage: 'Đã dùng 48 / 50 lượt',
        isActive: true,
      ),
      _CouponData(
        code: 'EARLYBIRD',
        discount: 'Giảm 10%',
        description: 'Đặt tour trước 7 ngày khởi hành',
        validUntil: 'Đã hết hạn: 30/09/2026',
        usage: 'Đã dùng 30 / 30 lượt',
        isActive: false,
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.createCoupon),
        icon: const Icon(Icons.add),
        label: const Text('Tạo coupon mới'),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF59E0B)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFD97706),
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '[DỮ LIỆU THỬ NGHIỆM - DEMO] Danh sách mã giảm giá dưới đây là dữ liệu mẫu.',
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mã khuyến mãi & Coupon',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              Text(
                '${coupons.length} mã giảm giá',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final c in coupons)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: c.isActive
                                ? AppColors.primarySoft
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: c.isActive
                                  ? AppColors.secondary.withValues(alpha: 0.3)
                                  : AppColors.line,
                            ),
                          ),
                          child: Text(
                            c.code,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: c.isActive
                                  ? AppColors.secondary
                                  : AppColors.muted,
                            ),
                          ),
                        ),
                        StatusBadge(
                          label: c.isActive ? 'ĐANG ÁP DỤNG' : 'HẾT HẠN',
                          type: c.isActive
                              ? StatusBadgeType.success
                              : StatusBadgeType.neutral,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      c.discount,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                    const Divider(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          c.validUntil,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                        Text(
                          c.usage,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CouponData {
  const _CouponData({
    required this.code,
    required this.discount,
    required this.description,
    required this.validUntil,
    required this.usage,
    required this.isActive,
  });

  final String code;
  final String discount;
  final String description;
  final String validUntil;
  final String usage;
  final bool isActive;
}
