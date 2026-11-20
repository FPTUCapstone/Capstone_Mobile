import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/cubit/operator_revenue_cubit.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/cubit/operator_settlement_history_cubit.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/widgets/operator_finance_overview.dart';

class OperatorFinanceView extends StatefulWidget {
  const OperatorFinanceView({
    this.isActive = true,
    this.isDemoMode = false,
    this.revenueCubit,
    this.settlementCubit,
    this.onOpenHistory,
    super.key,
  });

  final bool isActive;
  final bool isDemoMode;
  final OperatorRevenueCubit? revenueCubit;
  final OperatorSettlementHistoryCubit? settlementCubit;
  final VoidCallback? onOpenHistory;

  @override
  State<OperatorFinanceView> createState() => _OperatorFinanceViewState();
}

class _OperatorFinanceViewState extends State<OperatorFinanceView>
    with WidgetsBindingObserver {
  late OperatorRevenueCubit _revenue;
  late OperatorSettlementHistoryCubit _history;
  late bool _ownsRevenue;
  late bool _ownsHistory;
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _configure();
    if (widget.isActive) unawaited(_load());
  }

  void _configure() {
    _ownsRevenue = widget.isDemoMode || widget.revenueCubit == null;
    _ownsHistory = widget.isDemoMode || widget.settlementCubit == null;
    _revenue = _ownsRevenue
        ? serviceLocator<OperatorRevenueCubit>(param1: widget.isDemoMode)
        : widget.revenueCubit!;
    _history = _ownsHistory
        ? serviceLocator<OperatorSettlementHistoryCubit>(
            param1: widget.isDemoMode,
          )
        : widget.settlementCubit!;
  }

  void _closeOwned() {
    if (_ownsRevenue) unawaited(_revenue.close());
    if (_ownsHistory) unawaited(_history.close());
  }

  Future<void> _load({bool refresh = false}) async {
    final wasOpened = _opened;
    _opened = true;
    await Future.wait([
      refresh && wasOpened ? _revenue.refresh() : _revenue.ensureLoaded(),
      refresh && wasOpened ? _history.refresh() : _history.ensureLoaded(),
    ]);
  }

  @override
  void didUpdateWidget(covariant OperatorFinanceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDemoMode != widget.isDemoMode ||
        oldWidget.revenueCubit != widget.revenueCubit ||
        oldWidget.settlementCubit != widget.settlementCubit) {
      _closeOwned();
      _opened = false;
      _configure();
      if (widget.isActive) unawaited(_load());
    } else if (widget.isActive && !oldWidget.isActive) {
      unawaited(_load(refresh: true));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isActive) {
      setState(() => unawaited(_load(refresh: true)));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _closeOwned();
    super.dispose();
  }

  void _openHistory() {
    if (widget.onOpenHistory case final callback?) {
      callback();
      return;
    }
    final path = widget.isDemoMode
        ? '${AppRoutes.operatorSettlementHistory}?demo=true'
        : AppRoutes.operatorSettlementHistory;
    context.push(path);
  }

  @override
  Widget build(BuildContext context) => !_opened
      ? const SizedBox.shrink()
      : OperatorFinanceOverview(
          key: ObjectKey(_revenue),
          revenueCubit: _revenue,
          settlementCubit: _history,
          isDemoMode: widget.isDemoMode,
          onRefresh: () => _load(refresh: true),
          onOpenHistory: _openHistory,
        );
}
