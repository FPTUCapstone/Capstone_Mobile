import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/booking_qr_ticket_dialog.dart';
import 'package:trip_mate_mobile/features/trip_history/data/datasources/demo_trip_history_store.dart';
import 'package:trip_mate_mobile/features/trip_history/data/repositories/trip_history_repository_impl.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_history_item.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_history_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_history_state.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/widgets/refund_status_dialog.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_empty_state.dart';
import 'package:trip_mate_mobile/shared/widgets/loading_indicator.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

/// Dedicated My Tour Bookings view embedded in the Traveler Shell (SRS #68, #69, #70).
class TravelerBookingsView extends StatefulWidget {
  const TravelerBookingsView({this.isDemoMode = false, super.key});

  final bool isDemoMode;

  @override
  State<TravelerBookingsView> createState() => _TravelerBookingsViewState();
}

class _TravelerBookingsViewState extends State<TravelerBookingsView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TripHistoryCubit _cubit;

  static const _tabs = [
    TripStatus.upcoming,
    TripStatus.completed,
    TripStatus.cancelled,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    if (serviceLocator.isRegistered<TripHistoryCubit>()) {
      _cubit = serviceLocator<TripHistoryCubit>(param1: widget.isDemoMode)
        ..loadInitial();
    } else {
      _cubit = TripHistoryCubit(
        repository: TripHistoryRepositoryImpl(
          demoStore: DemoTripHistoryStore(),
          isDemoMode: true,
        ),
        isDemoMode: true,
        demoTravelerId: DemoTripHistoryStore.demoTravelerId,
      )..loadInitial();
    }
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_cubit.state.selectedTab != _tabs[_tabController.index]) {
      _cubit.switchTab(_tabs[_tabController.index]);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<TripHistoryCubit, TripHistoryState>(
        builder: (context, state) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Traveler Đặt chỗ',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.push(AppRoutes.tripHistory),
                      icon: const Icon(Icons.history_outlined, size: 16),
                      label: const Text(TripHistoryStringsEn.tripHistoryTitle),
                    ),
                  ],
                ),
              ),
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.secondary,
                  unselectedLabelColor: AppColors.muted,
                  indicatorColor: AppColors.secondary,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(text: 'Sắp tới'),
                    Tab(text: 'Hoàn thành'),
                    Tab(text: 'Đã hủy'),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _cubit.refresh,
                  color: AppColors.secondary,
                  child: _buildBody(context, state),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, TripHistoryState state) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: LoadingIndicator());
    }

    if (state.items.isEmpty) {
      final tabName = switch (state.selectedTab) {
        TripStatus.upcoming => 'sắp tới',
        TripStatus.completed => 'đã hoàn thành',
        TripStatus.cancelled => 'đã hủy',
      };
      return AppEmptyState(
        icon: Icons.confirmation_number_outlined,
        title: 'Chưa có đặt chỗ $tabName',
        message:
            'Khám phá ngay các tour du lịch miền Trung đặc sắc và đặt chỗ dễ dàng.',
        actionLabel: 'Tìm kiếm tour ngay',
        onAction: () => context.push(AppRoutes.tourSearch),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: state.items.length,
      itemBuilder: (context, index) {
        final item = state.items[index];
        return _BookingItemCard(item: item, onRefresh: _cubit.refresh);
      },
    );
  }
}

class _BookingItemCard extends StatelessWidget {
  const _BookingItemCard({required this.item, required this.onRefresh});

  final TripHistoryItem item;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final (badgeLabel, badgeType) = switch (item.status) {
      TripStatus.upcoming => ('SẮP TỚI', StatusBadgeType.success),
      TripStatus.completed => ('HOÀN THÀNH', StatusBadgeType.info),
      TripStatus.cancelled => ('ĐÃ HỦY', StatusBadgeType.error),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.bookingCode,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                StatusBadge(label: badgeLabel, type: badgeType),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              item.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            if (item.providerName != null) ...[
              const SizedBox(height: 2),
              Text(
                'Nhà cung cấp: ${item.providerName}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
            ],
            const Divider(height: 20),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 15,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  TripFormatters.formatVietnamDate(item.departureDate),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.people_outline,
                  size: 16,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 4),
                Text(
                  '${item.participantsCount} người',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tổng thanh toán:',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
                Text(
                  TripFormatters.formatCurrencyVnd(item.totalAmount),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (item.status == TripStatus.upcoming) ...[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () =>
                          BookingQrTicketDialog.show(context, item),
                      icon: const Icon(Icons.qr_code, size: 18),
                      label: const Text('Vé điện tử QR'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: () => _showCancellationPolicy(context, item),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(90, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: const Text('Hủy vé'),
                  ),
                ] else if (item.status == TripStatus.cancelled) ...[
                  if (item.canViewRefundStatus)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          showDialog<void>(
                            context: context,
                            builder: (_) => RefundStatusDialog(
                              refundInfo: item.refundInfo!,
                              bookingCode: item.bookingCode,
                            ),
                          );
                        },
                        icon: const Icon(Icons.currency_exchange, size: 16),
                        label: const Text('Chi tiết hoàn tiền'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        ),
                      ),
                    ),
                ] else if (item.status == TripStatus.completed) ...[
                  if (item.canWriteReview)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          final reviewed = await context.push(
                            AppRoutes.tripReview(item.id),
                            extra: item,
                          );
                          if (reviewed == true) await onRefresh();
                        },
                        icon: const Icon(Icons.star_outline, size: 18),
                        label: const Text('Đánh giá chuyến đi'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCancellationPolicy(BuildContext context, TripHistoryItem item) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chính sách hủy đặt chỗ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mã đặt chỗ: ${item.bookingCode}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              '• Hủy trước 48 giờ: Hoàn lại 100% chi phí.\n'
              '• Hủy trong vòng 24 - 48 giờ: Hoàn lại 50% chi phí.\n'
              '• Hủy trong vòng 24 giờ trước giờ khởi hành: Không áp dụng hoàn tiền theo quy định của nhà điều hành.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Yêu cầu hủy sẽ được gửi đến nhà điều hành tour để xác nhận và xử lý hoàn tiền.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Yêu cầu hủy đặt chỗ đã được ghi nhận.'),
                ),
              );
            },
            child: const Text('Xác nhận yêu cầu hủy'),
          ),
        ],
      ),
    );
  }
}
