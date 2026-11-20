import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/revenue_report.dart';
import 'package:trip_mate_mobile/shared/formatters/visit_price_format.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';

enum _ChartMetric { net, gross, commission, refunded }

class RevenuePeriodChart extends StatefulWidget {
  const RevenuePeriodChart({required this.periods, super.key});
  final List<RevenuePeriod> periods;

  @override
  State<RevenuePeriodChart> createState() => _RevenuePeriodChartState();
}

class _RevenuePeriodChartState extends State<RevenuePeriodChart> {
  var _metric = _ChartMetric.net;
  String? _selectedKey;

  String _label(_ChartMetric metric) => switch (metric) {
    _ChartMetric.net => 'Thực nhận',
    _ChartMetric.gross => 'Giá trị đặt tour',
    _ChartMetric.commission => 'Hoa hồng',
    _ChartMetric.refunded => 'Tiền hoàn',
  };

  num _value(RevenuePeriod period) => switch (_metric) {
    _ChartMetric.net => period.netAmount,
    _ChartMetric.gross => period.grossRevenue,
    _ChartMetric.commission => period.commission,
    _ChartMetric.refunded => period.refundedAmount,
  };

  @override
  Widget build(BuildContext context) {
    if (widget.periods.isEmpty) {
      return const AppCard(
        child: Text('Chưa có dữ liệu biểu đồ trong kỳ này.'),
      );
    }
    final selected =
        widget.periods.where((p) => p.periodKey == _selectedKey).firstOrNull ??
        widget.periods.first;
    final maximum = widget.periods.fold<double>(
      0,
      (maximum, period) => math.max(maximum, _value(period).abs().toDouble()),
    );
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Biến động theo kỳ',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<_ChartMetric>(
            initialValue: _metric,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Chỉ tiêu biểu đồ'),
            items: [
              for (final metric in _ChartMetric.values)
                DropdownMenuItem(value: metric, child: Text(_label(metric))),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _metric = value);
            },
          ),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              '${selected.periodLabel} · ${_label(_metric)}: ${formatVnd(_value(selected))}',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Chạm một kỳ để xem giá trị. Đường ngang là mốc 0.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          SizedBox(
            height: largeText ? 300 : 240,
            child: ListView.builder(
              key: const PageStorageKey('revenue-chart-scroll'),
              scrollDirection: Axis.horizontal,
              itemExtent: largeText ? 220 : 150,
              itemCount: widget.periods.length,
              itemBuilder: (context, index) {
                final period = widget.periods[index];
                final value = _value(period);
                final height = maximum == 0
                    ? 0.0
                    : 72 * value.abs().toDouble() / maximum;
                return Semantics(
                  button: true,
                  selected: period.periodKey == selected.periodKey,
                  label:
                      '${period.periodLabel}, ${_label(_metric)} ${formatVnd(value)}',
                  child: InkWell(
                    key: Key('revenue-period-$index'),
                    onTap: () =>
                        setState(() => _selectedKey = period.periodKey),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 76,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                width: 30,
                                height: value > 0 ? height : 0,
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                          Container(
                            key: Key('revenue-zero-axis-$index'),
                            height: 1,
                            color: AppColors.muted,
                          ),
                          SizedBox(
                            height: 76,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Container(
                                width: 30,
                                height: value < 0 ? height : 0,
                                color: Colors.deepOrange,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Text(
                              period.periodLabel,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.fade,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Material(
            type: MaterialType.transparency,
            child: ExpansionTile(
              key: const PageStorageKey('revenue-period-values-expansion'),
              tilePadding: EdgeInsets.zero,
              title: const Text('Xem giá trị từng kỳ'),
              children: [
                SizedBox(
                  height: 250,
                  child: ListView.builder(
                    key: const PageStorageKey('revenue-period-values-scroll'),
                    itemCount: widget.periods.length,
                    itemBuilder: (context, index) {
                      final period = widget.periods[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '${period.periodLabel}: ${formatVnd(_value(period))}',
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
