import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

/// Promotional Coupons List view for Tour Operator (SRS #81, #82, #83).
class OperatorCouponsView extends StatelessWidget {
  const OperatorCouponsView({super.key});

  @override
  Widget build(BuildContext context) {
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
