import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/commercial_booking_repository.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/commercial_booking_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_coastal_app_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/app_empty_state.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

final class CommercialBookingRequestsPage extends StatefulWidget {
  const CommercialBookingRequestsPage({super.key});

  @override
  State<CommercialBookingRequestsPage> createState() =>
      _CommercialBookingRequestsPageState();
}

final class _CommercialBookingRequestsPageState
    extends State<CommercialBookingRequestsPage> {
  final _requests = <TravelerServiceRequest>[];
  bool _loading = false;
  bool _more = true;
  bool _loadingFailed = false;
  int? _cancelling;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _loadingFailed = false;
    });
    try {
      final page = await context.read<CommercialBookingCubit>().requests(
        beforeId: reset || _requests.isEmpty ? null : _requests.last.id,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _requests.clear();
        _requests.addAll(page);
        _more = page.length == 20;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingFailed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel(TravelerServiceRequest request) async {
    if (_cancelling != null || _loading) return;
    setState(() => _cancelling = request.id);
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text('Hủy yêu cầu ${request.requestCode}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Quay lại'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Xác nhận hủy'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
      try {
        await context.read<CommercialBookingCubit>().cancel(request.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã hủy yêu cầu đặt dịch vụ.')),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Không thể hủy yêu cầu. Hệ thống sẽ tải lại trạng thái.',
              ),
            ),
          );
        }
      }
      if (mounted) await _load(reset: true);
    } finally {
      if (mounted) setState(() => _cancelling = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return Scaffold(
      backgroundColor: c.canvas,
      appBar: const AppCoastalAppBar(title: 'Yêu cầu đặt dịch vụ'),
      body: RefreshIndicator(
        color: c.brandTeal,
        onRefresh: () => _load(reset: true),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (_loading)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: LinearProgressIndicator(
                  color: c.brandTeal,
                  backgroundColor: c.surfaceElevated,
                ),
              ),
            if (_loadingFailed)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Center(
                  child: TextButton(
                    onPressed: () => _load(reset: true),
                    child: const Text('Không tải được yêu cầu · Thử lại'),
                  ),
                ),
              ),
            if (_requests.isEmpty && !_loading && !_loadingFailed)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: AppEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Bạn chưa có yêu cầu đặt dịch vụ.',
                ),
              ),
            for (final request in _requests)
              Padding(
                key: ValueKey(request.id),
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              '${request.requestCode} · ${request.serviceName}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: c.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          StatusBadge(
                            label: _status(request.status),
                            type: _badgeType(request.status),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_outlined,
                            size: 14,
                            color: c.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${TripFormatters.formatVietnamDateTime(request.startsAt)} · Số lượng ${request.quantity}',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: c.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (request.status == 'PendingConfirmation') ...[
                        Divider(height: 18, color: c.borderSubtle),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _loading || _cancelling != null
                                ? null
                                : () => _cancel(request),
                            style: TextButton.styleFrom(
                              foregroundColor: c.error,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('Hủy yêu cầu'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            if (_requests.isNotEmpty && _more && !_loading)
              Center(
                child: OutlinedButton(
                  onPressed: () => _load(reset: false),
                  child: const Text('Tải thêm'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  StatusBadgeType _badgeType(String status) => switch (status) {
    'PendingConfirmation' => StatusBadgeType.warning,
    'Confirmed' || 'Completed' => StatusBadgeType.success,
    'Rejected' || 'Cancelled' || 'NoShow' => StatusBadgeType.error,
    _ => StatusBadgeType.neutral,
  };

  String _status(String status) => switch (status) {
    'PendingConfirmation' => 'Chờ xác nhận',
    'Confirmed' => 'Đã xác nhận',
    'Rejected' => 'Đã từ chối',
    'Expired' => 'Đã hết hạn',
    'Cancelled' => 'Đã hủy',
    'Completed' => 'Đã hoàn tất',
    'NoShow' => 'Không đến',
    _ => status,
  };
}
