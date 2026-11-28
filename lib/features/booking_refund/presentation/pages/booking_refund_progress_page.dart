import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/booking_refund/domain/entities/booking_refund_progress.dart';
import 'package:trip_mate_mobile/features/booking_refund/presentation/cubit/booking_refund_progress_cubit.dart';
import 'package:trip_mate_mobile/features/booking_refund/presentation/cubit/booking_refund_progress_state.dart';
import 'package:trip_mate_mobile/features/support_chat/domain/entities/support_chat.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_coastal_app_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/app_section_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_sticky_action_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/loading_indicator.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

final class BookingRefundProgressPage extends StatefulWidget {
  const BookingRefundProgressPage({required this.bookingId, super.key});
  final String bookingId;

  @override
  State<BookingRefundProgressPage> createState() =>
      _BookingRefundProgressPageState();
}

final class _BookingRefundProgressPageState
    extends State<BookingRefundProgressPage> {
  @override
  void initState() {
    super.initState();
    context.read<BookingRefundProgressCubit>().load(widget.bookingId);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return Scaffold(
      backgroundColor: c.canvas,
      appBar: const AppCoastalAppBar(title: 'Tiến độ hoàn tiền'),
      bottomNavigationBar:
          BlocBuilder<BookingRefundProgressCubit, BookingRefundProgressState>(
            builder: (context, state) {
              if (state.status != BookingRefundProgressStatus.success ||
                  state.progress == null) {
                return const SizedBox.shrink();
              }
              return AppStickyActionBar(
                primaryAction: SizedBox(
                  height: 46,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.support_agent_outlined, size: 18),
                    label: const Text('Hỏi về khoản hoàn tiền này'),
                    onPressed: () => context.push(
                      context.read<AuthSessionCubit>().state.role ==
                              UserRole.tourOperator
                          ? AppRoutes.operatorSupportChat
                          : AppRoutes.supportChat,
                      extra: SupportChatContext(
                        kind: 'refund',
                        id: widget.bookingId,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      body: BlocBuilder<BookingRefundProgressCubit, BookingRefundProgressState>(
        builder: (context, state) => switch (state.status) {
          BookingRefundProgressStatus.initial ||
          BookingRefundProgressStatus.loading => const Center(
            child: LoadingIndicator(),
          ),
          BookingRefundProgressStatus.failure => _Failure(
            message:
                state.failure?.message ?? 'Không thể tải tiến độ hoàn tiền.',
            onRetry: () => context.read<BookingRefundProgressCubit>().load(
              widget.bookingId,
            ),
          ),
          BookingRefundProgressStatus.success when state.progress != null =>
            _Progress(progress: state.progress!),
          _ => const _Failure(message: 'Không thể tải tiến độ hoàn tiền.'),
        },
      ),
    );
  }
}

final class _Progress extends StatelessWidget {
  const _Progress({required this.progress});
  final BookingRefundProgress progress;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final presentation = _presentation(progress.status, c);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        AppCard(
          backgroundColor: c.surfaceCard,
          borderColor: c.borderSubtle,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MÃ ĐẶT TOUR',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: c.textMuted,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          progress.bookingCode,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: c.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  StatusBadge(
                    label: presentation.label,
                    type: presentation.badgeType,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: presentation.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  presentation.description,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: c.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _DetailCard(
          rows: [
            _Row(
              'Số tiền hoàn',
              TripFormatters.formatVnd(progress.refundAmount),
              isPrice: true,
            ),
            _Row('Ngày yêu cầu', _formatDate(progress.requestedAtUtc)),
            _Row('Hoàn tất', _formatDate(progress.processedAtUtc)),
            if (progress.nextAttemptAtUtc != null)
              _Row('Lần thử tiếp theo', _formatDate(progress.nextAttemptAtUtc)),
            if (progress.gatewayReference != null)
              _Row('Mã tham chiếu', progress.gatewayReference!),
            if (progress.attemptCount > 0)
              _Row('Số lần xử lý', '${progress.attemptCount}'),
          ],
        ),
        if (progress.status == BookingRefundStatus.failed) ...[
          const SizedBox(height: AppSpacing.md),
          const AppAlert(
            type: AppAlertType.info,
            message:
                'Bạn không cần thực hiện thêm thao tác nào. Đội ngũ hỗ trợ sẽ liên hệ nếu cần thêm thông tin.',
          ),
        ],
      ],
    );
  }
}

final class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.rows});
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return AppSectionCard(
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            AppKeyValueRow(
              label: rows[index].label,
              value: rows[index].value,
              isPrice: rows[index].isPrice,
            ),
            if (index != rows.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Divider(height: 1, color: c.borderSubtle),
              ),
          ],
        ],
      ),
    );
  }
}

final class _Row {
  const _Row(this.label, this.value, {this.isPrice = false});
  final String label;
  final String value;
  final bool isPrice;
}

final class _Failure extends StatelessWidget {
  const _Failure({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppAlert(message: message, type: AppAlertType.error),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ],
      ),
    ),
  );
}

({
  String label,
  String description,
  StatusBadgeType badgeType,
  Color background,
})
_presentation(BookingRefundStatus status, TripMateColors c) => switch (status) {
  BookingRefundStatus.pendingOperatorConfirmation => (
    label: 'Chờ xác nhận',
    description:
        'Yêu cầu hoàn tiền của bạn đang chờ nhà điều hành tour xác nhận.',
    badgeType: StatusBadgeType.info,
    background: c.infoContainer,
  ),
  BookingRefundStatus.awaitingPartnerReturn => (
    label: 'Chờ đối tác hoàn trả',
    description:
        'Chúng tôi đang chờ nhà điều hành tour hoàn trả phần tiền đối ứng trước khi xử lý hoàn tiền cho bạn.',
    badgeType: StatusBadgeType.info,
    background: c.infoContainer,
  ),
  BookingRefundStatus.returnReported => (
    label: 'Đối tác đã báo hoàn trả',
    description:
        'Nhà điều hành tour đã báo cáo hoàn trả phần tiền đối ứng. Đội ngũ của chúng tôi đang xác nhận trước khi xử lý hoàn tiền.',
    badgeType: StatusBadgeType.info,
    background: c.infoContainer,
  ),
  BookingRefundStatus.returnReceived => (
    label: 'Đã nhận tiền từ đối tác',
    description:
        'Đội ngũ của chúng tôi đã xác nhận nhận tiền từ đối tác. Khoản hoàn tiền của bạn đang chờ xử lý thanh toán.',
    badgeType: StatusBadgeType.info,
    background: c.infoContainer,
  ),
  BookingRefundStatus.reconciliation => (
    label: 'Đang đối soát',
    description:
        'Đội ngũ của chúng tôi đang kiểm tra đối soát hồ sơ hoàn tiền. Khoản hoàn tiền chưa được xác nhận hoàn tất.',
    badgeType: StatusBadgeType.warning,
    background: c.warningContainer,
  ),
  BookingRefundStatus.escalated => (
    label: 'Đã chuyển cấp xem xét',
    description:
        'Khoản hoàn tiền của bạn cần được kiểm tra chuyên sâu hơn và chưa được xác nhận hoàn tất.',
    badgeType: StatusBadgeType.warning,
    background: c.warningContainer,
  ),
  BookingRefundStatus.processed => (
    label: 'Hoàn tiền thành công',
    description: 'Khoản hoàn tiền đã hoàn tất qua kênh thanh toán ban đầu.',
    badgeType: StatusBadgeType.success,
    background: c.successContainer,
  ),
  BookingRefundStatus.manualReview => (
    label: 'Đang kiểm tra thủ công',
    description:
        'Đội ngũ của chúng tôi đang xác minh khoản hoàn tiền này với cổng thanh toán.',
    badgeType: StatusBadgeType.warning,
    background: c.warningContainer,
  ),
  BookingRefundStatus.failed => (
    label: 'Cần hỗ trợ xử lý',
    description:
        'Hệ thống chưa thể hoàn tiền tự động. Đội ngũ hỗ trợ sẽ chủ động liên hệ xử lý.',
    badgeType: StatusBadgeType.error,
    background: c.errorContainer,
  ),
  BookingRefundStatus.rejected => (
    label: 'Không duyệt hoàn tiền',
    description:
        'Yêu cầu hoàn tiền này không được chấp thuận theo chính sách áp dụng.',
    badgeType: StatusBadgeType.neutral,
    background: c.surfaceElevated,
  ),
  BookingRefundStatus.retryPending => (
    label: 'Đã lên lịch thử lại',
    description: 'Hệ thống sẽ sớm thực hiện lại giao dịch hoàn tiền.',
    badgeType: StatusBadgeType.info,
    background: c.infoContainer,
  ),
  BookingRefundStatus.processing => (
    label: 'Đang xử lý hoàn tiền',
    description: 'Cổng thanh toán đang xử lý khoản hoàn tiền của bạn.',
    badgeType: StatusBadgeType.info,
    background: c.infoContainer,
  ),
  BookingRefundStatus.pending => (
    label: 'Đã tiếp nhận yêu cầu',
    description: 'Yêu cầu hoàn tiền của bạn đã được tiếp nhận.',
    badgeType: StatusBadgeType.info,
    background: c.infoContainer,
  ),
};

String _formatDate(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
