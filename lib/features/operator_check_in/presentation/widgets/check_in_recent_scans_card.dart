import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/operator_check_in/domain/entities/operator_check_in_models.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';

class CheckInRecentScansCard extends StatelessWidget {
  const CheckInRecentScansCard({
    required this.scans,
    super.key,
  });

  final List<CheckInScanItem> scans;

  @override
  Widget build(BuildContext context) {
    if (scans.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Recent scans',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: scans.take(5).length,
            separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.line),
            itemBuilder: (context, index) {
              final item = scans[index];
              final isValid = item.status == CheckInScanStatus.valid;
              final timeStr = '${item.timestamp.hour.toString().padLeft(2, '0')}:'
                  '${item.timestamp.minute.toString().padLeft(2, '0')}';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isValid ? const Color(0xFFE8F5F2) : const Color(0xFFFFF0EE),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isValid ? Icons.check : Icons.close,
                        size: 16,
                        color: isValid ? const Color(0xFF0E9F6E) : const Color(0xFFDC2626),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isValid ? item.passengerName : item.code,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isValid
                                ? '${item.participantCount} pax · $timeStr'
                                : '$timeStr · ${item.reason ?? 'rejected'}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isValid ? const Color(0xFFE8F5F2) : const Color(0xFFFFF0EE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isValid ? 'Valid' : 'Rejected',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isValid ? const Color(0xFF0E9F6E) : const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
