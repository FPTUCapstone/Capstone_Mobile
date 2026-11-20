import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/widgets/operator_finance_view.dart';

/// Keeps the existing shell entry while the live finance feature owns its state.
class OperatorRevenueView extends StatelessWidget {
  const OperatorRevenueView({
    this.isDemoMode = false,
    this.isActive = true,
    super.key,
  });
  final bool isDemoMode;
  final bool isActive;

  @override
  Widget build(BuildContext context) =>
      OperatorFinanceView(isDemoMode: isDemoMode, isActive: isActive);
}
