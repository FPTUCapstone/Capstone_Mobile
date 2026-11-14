import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/shared/widgets/app_shimmer.dart';

enum TourDiscoveryFeedState { content, loading, empty, error }

class TourDiscoveryMotionSkeleton extends StatelessWidget {
  const TourDiscoveryMotionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return AppShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: c.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.borderSubtle),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ColoredBox(color: Color(0xFFF1F5F9)),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 12,
                        width: 170,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 18,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        height: 14,
                        width: 220,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < 2; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.borderSubtle),
              ),
              child: Row(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 11,
                          width: 130,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 16,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 12,
                          width: 150,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class TourDiscoveryEmptyView extends StatelessWidget {
  const TourDiscoveryEmptyView({super.key, required this.onTapSearch});

  final VoidCallback onTapSearch;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: c.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.borderSubtle),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.travel_explore_outlined, size: 36, color: c.textMuted),
          const SizedBox(height: 10),
          Text(
            'Chưa có tour công khai phù hợp',
            style: TextStyle(
              fontFamily: AppTypography.displayFont,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Khám phá danh mục đầy đủ để tìm lịch trình mới nhất.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTypography.uiFont,
              fontSize: 12,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onTapSearch,
            child: const Text('Mở tìm kiếm tour'),
          ),
        ],
      ),
    );
  }
}

class TourDiscoveryErrorView extends StatelessWidget {
  const TourDiscoveryErrorView({
    super.key,
    this.onRetry,
    required this.onTapSearch,
  });

  final VoidCallback? onRetry;
  final VoidCallback onTapSearch;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.borderSubtle),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, color: c.error, size: 32),
          const SizedBox(height: 8),
          Text(
            'Không thể tải gợi ý tour',
            style: TextStyle(
              fontFamily: AppTypography.displayFont,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Vui lòng kiểm tra kết nối mạng và thử lại.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTypography.uiFont,
              fontSize: 12,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (onRetry != null) ...[
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Thử lại'),
                ),
                const SizedBox(width: 8),
              ],
              FilledButton(
                onPressed: onTapSearch,
                child: const Text('Tìm kiếm tour'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
