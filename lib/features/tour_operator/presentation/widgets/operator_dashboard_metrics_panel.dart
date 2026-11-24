import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/tour_operator/domain/entities/operator_dashboard_metrics.dart';
import 'package:trip_mate_mobile/features/tour_operator/presentation/cubit/operator_dashboard_cubit.dart';
import 'package:trip_mate_mobile/shared/formatters/visit_price_format.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';

class OperatorDashboardMetricsPanel extends StatefulWidget {
  const OperatorDashboardMetricsPanel({
    required this.onNavigateToTab,
    this.isDemoMode = false,
    this.isActive = true,
    this.cubit,
    super.key,
  });

  final void Function(int) onNavigateToTab;
  final bool isDemoMode;
  final bool isActive;
  final OperatorDashboardCubit? cubit;

  @override
  State<OperatorDashboardMetricsPanel> createState() =>
      _OperatorDashboardMetricsPanelState();
}

class _OperatorDashboardMetricsPanelState
    extends State<OperatorDashboardMetricsPanel>
    with WidgetsBindingObserver {
  OperatorDashboardCubit? _cubit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!widget.isDemoMode) {
      _cubit = widget.cubit ?? serviceLocator<OperatorDashboardCubit>();
      if (widget.isActive) unawaited(_cubit!.load());
    }
  }

  @override
  void didUpdateWidget(covariant OperatorDashboardMetricsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDemoMode != oldWidget.isDemoMode ||
        widget.cubit != oldWidget.cubit) {
      if (oldWidget.cubit == null) _cubit?.close();
      _cubit = widget.isDemoMode
          ? null
          : widget.cubit ?? serviceLocator<OperatorDashboardCubit>();
      if (widget.isActive) unawaited(_cubit?.load());
      return;
    }
    if (widget.isActive && !oldWidget.isActive) unawaited(_cubit?.load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isActive) {
      unawaited(_cubit?.load());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.cubit == null) _cubit?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDemoMode) {
      return _content(
        context,
        OperatorDashboardState(
          metrics: OperatorDashboardMetrics(
            activeTourCount: 4,
            monthlyBookingCount: 18,
            monthlyNetAmount: 38500000,
            activeCouponCount: 3,
            asOfUtc: DateTime.utc(2026, 11, 19),
            monthStart: DateTime(2026, 11),
            monthEndExclusive: DateTime(2026, 12),
          ),
        ),
      );
    }
    return BlocBuilder<OperatorDashboardCubit, OperatorDashboardState>(
      bloc: _cubit,
      builder: _content,
    );
  }

  Widget _content(BuildContext context, OperatorDashboardState state) {
    final metrics = state.metrics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Chỉ số hoạt động',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (!widget.isDemoMode)
              IconButton(
                tooltip: 'Làm mới chỉ số',
                onPressed: state.loading ? null : () => _cubit!.load(),
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
        if (metrics != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              'Tháng ${metrics.monthStart.month}/${metrics.monthStart.year} · Giờ Việt Nam',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
        if (state.failed)
          AppCard(
            child: Column(
              children: [
                const Text('Không thể tải chỉ số hoạt động. Vui lòng thử lại.'),
                TextButton(
                  onPressed: () => _cubit!.load(),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          )
        else if (metrics == null)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Đang tải chỉ số',
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _MetricCard(
                  title: 'Tour đang hoạt động',
                  value: '${metrics.activeTourCount} gói',
                  subtitle: 'Còn nhận đặt chỗ',
                  icon: Icons.tour_outlined,
                  color: const Color(0xFF0284C7),
                  onTap: () => widget.onNavigateToTab(1),
                ),
                _MetricCard(
                  title: 'Đơn đặt tour trong tháng',
                  value: '${metrics.monthlyBookingCount} đơn',
                  subtitle: 'Đã thanh toán, không bị hủy',
                  icon: Icons.confirmation_number_outlined,
                  color: const Color(0xFF0D9488),
                  onTap: () => widget.onNavigateToTab(2),
                ),
                _MetricCard(
                  title: 'Thực nhận trong tháng',
                  value: formatVnd(metrics.monthlyNetAmount),
                  subtitle: 'Đã quyết toán, trừ hoàn trả đã xác nhận',
                  icon: Icons.payments_outlined,
                  color: const Color(0xFF059669),
                  onTap: () => widget.onNavigateToTab(3),
                ),
                _MetricCard(
                  title: 'Mã giảm giá đang hiệu lực',
                  value: '${metrics.activeCouponCount} mã',
                  subtitle: 'Còn thời hạn và lượt dùng',
                  icon: Icons.local_offer_outlined,
                  color: const Color(0xFFD97706),
                  onTap: () => widget.onNavigateToTab(4),
                ),
              ];
              final singleColumn =
                  constraints.maxWidth < 360 ||
                  MediaQuery.textScalerOf(context).scale(14) > 20;
              return Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final card in cards)
                    SizedBox(
                      width: singleColumn
                          ? constraints.maxWidth
                          : (constraints.maxWidth - AppSpacing.sm) / 2,
                      child: card,
                    ),
                ],
              );
            },
          ),
      ],
    );
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
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(AppSpacing.md),
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
            const SizedBox(width: 4),
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
        Text(subtitle, style: TextStyle(fontSize: 11, color: color)),
      ],
    ),
  );
}
