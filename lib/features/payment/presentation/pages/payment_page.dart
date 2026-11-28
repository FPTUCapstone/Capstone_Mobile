import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/features/payment/domain/entities/payment_link.dart';
import 'package:trip_mate_mobile/features/payment/presentation/cubit/payment_cubit.dart';
import 'package:trip_mate_mobile/features/payment/presentation/cubit/payment_state.dart';
import 'package:trip_mate_mobile/shared/widgets/app_bottom_sheet_scaffold.dart';
import 'package:trip_mate_mobile/shared/widgets/app_coastal_app_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/app_section_card.dart';
import 'package:url_launcher/url_launcher.dart';

String _formatMoney(int amount, String currency) {
  final text = amount.toString();
  final buffer = StringBuffer();
  final length = text.length;
  for (var i = 0; i < length; i++) {
    if (i > 0 && (length - i) % 3 == 0) buffer.write('.');
    buffer.write(text[i]);
  }
  final normalized = currency.trim().toUpperCase();
  if (normalized == 'VND') {
    buffer.write('₫');
  } else if (normalized.isNotEmpty) {
    buffer.write(' $normalized');
  }
  return buffer.toString();
}

String _formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${pad(local.day)}/${pad(local.month)}/${local.year} ${pad(local.hour)}:${pad(local.minute)}';
}

final class PaymentPage extends StatefulWidget {
  const PaymentPage({
    required this.bookingId,
    this.initialBookingCode,
    this.initialAmount,
    this.initialCurrency,
    super.key,
  });

  final String bookingId;
  final String? initialBookingCode;
  final int? initialAmount;
  final String? initialCurrency;

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

final class _PaymentPageState extends State<PaymentPage>
    with WidgetsBindingObserver {
  var _checkoutWasOpened = false;
  Timer? _statusPollTimer;
  var _paymentConfirmed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<PaymentCubit>().startPayment(widget.bookingId);
  }

  @override
  void dispose() {
    _statusPollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _checkoutWasOpened) {
      _checkoutWasOpened = false;
      _refreshStatusAfterCheckout();
    }
  }

  Future<void> _refreshStatusAfterCheckout() async {
    // PayOS may return the traveler to the app just before its webhook updates
    // our database. Check briefly before exposing another payment action.
    final paymentCubit = context.read<PaymentCubit>();
    for (var attempt = 0; attempt < 10 && mounted; attempt++) {
      await paymentCubit.refreshStatus(widget.bookingId);
      if (!mounted || paymentCubit.state.paymentStatus?.isPaid == true) {
        return;
      }
      if (attempt < 9) {
        await Future<void>.delayed(const Duration(milliseconds: 1500));
      }
    }
  }

  /// UC-29 W2/M2: a paid booking stays on this page, which leads to its
  /// e-ticket; it no longer returns home by itself.
  void _onPaymentConfirmed() {
    if (_paymentConfirmed) return;
    _paymentConfirmed = true;
    _statusPollTimer?.cancel();
    _statusPollTimer = null;
  }

  void _startStatusPolling() {
    if (_statusPollTimer != null) return;
    _statusPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        context.read<PaymentCubit>().refreshStatus(widget.bookingId);
      }
    });
  }

  Future<void> _launchCheckout(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Liên kết thanh toán không hợp lệ.')),
        );
      }
      return;
    }

    try {
      // canLaunchUrl is unreliable on Android 11+ unless every browser intent
      // is declared in <queries>. Let Android resolve the HTTPS link directly.
      var opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
      if (opened) {
        _checkoutWasOpened = true;
        return;
      }
    } catch (_) {
      // Fall through to the actionable message below.
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở liên kết thanh toán.')),
      );
    }
  }

  Future<void> _openBankingApp(String? paymentDeepLink) async {
    final uri = paymentDeepLink == null ? null : Uri.tryParse(paymentDeepLink);
    // A gateway may provide a bank-app deep link in the future. Never fall back
    // to the PayOS web checkout here: the native QR flow must stay in-app.
    if (uri != null &&
        uri.hasScheme &&
        uri.scheme != 'http' &&
        uri.scheme != 'https') {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
      } catch (_) {
        // Show the same actionable guidance below.
      }
    }

    if (!mounted) return;
    await showAppModalBottomSheet<void>(
      context: context,
      title: 'Mở ứng dụng ngân hàng',
      builder: (sheetContext) {
        final c = sheetContext.tmColors;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'TripMate không thu thập thông tin ngân hàng. Hãy mở ứng dụng ngân hàng của bạn, chọn Quét QR và quét mã VietQR trên màn hình này.',
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: c.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => Navigator.of(sheetContext).pop(),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Đã hiểu'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return Scaffold(
      backgroundColor: c.canvas,
      appBar: const AppCoastalAppBar(
        title: 'Thanh Toán Điện Tử',
        centerTitle: true,
      ),
      body: BlocConsumer<PaymentCubit, PaymentState>(
        listener: (context, state) {
          if (state.paymentLink?.qrCode?.isNotEmpty == true) {
            _startStatusPolling();
          }
          if (state.failure != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.failure!.message),
                backgroundColor: context.tmColors.error,
              ),
            );
          }
          if (state.paymentStatus?.isPaid == true) {
            _onPaymentConfirmed();
          }
          if (state.paymentStatus?.isCancelledTx == true) {
            _statusPollTimer?.cancel();
            _statusPollTimer = null;
          }
        },
        builder: (context, state) {
          if (state.isLoading && state.paymentStatus == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: c.brandTeal),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Đang kết nối cổng thanh toán…',
                    style: TextStyle(fontSize: 14, color: c.textSecondary),
                  ),
                ],
              ),
            );
          }

          final status = state.paymentStatus;
          final link = state.paymentLink;

          // 1. Success / Paid State
          if (status != null && status.isPaid) {
            return _PaidSuccessView(
              status: status,
              bookingId: int.tryParse(widget.bookingId),
            );
          }

          // 2. Expired State
          if (status != null && status.isExpired) {
            return _ExpiredView(status: status);
          }

          // 3. Cancelled State
          if (status != null && status.isCancelledTx) {
            return _CancelledView(
              status: status,
              onRetry: () =>
                  context.read<PaymentCubit>().startPayment(widget.bookingId),
            );
          }

          // 4. Active Checkout / Mock Checkout View
          final active = status?.activePayment;
          final isMock =
              active?.gateway == 'Mock' ||
              link?.checkoutUrl.contains('/checkout/mock') == true;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Booking Info Card
                _BookingSummaryCard(
                  bookingCode:
                      status?.bookingCode ??
                      widget.initialBookingCode ??
                      widget.bookingId,
                  amount:
                      active?.amount ??
                      widget.initialAmount ??
                      link?.amount ??
                      0,
                  currency:
                      active?.currency ??
                      widget.initialCurrency ??
                      link?.currency ??
                      'VND',
                  expiresAt: status?.paymentExpiresAt,
                ),
                const SizedBox(height: AppSpacing.lg),

                if (isMock)
                  _MockGatewayCard(
                    paymentId: active?.paymentId ?? link?.paymentId ?? 0,
                    bookingId: widget.bookingId,
                    isLoading: state.isLoading,
                    onSubmit: (outcome) =>
                        context.read<PaymentCubit>().submitMockOutcome(
                          paymentId: active?.paymentId ?? link?.paymentId ?? 0,
                          bookingId: widget.bookingId,
                          outcome: outcome,
                        ),
                  )
                else
                  _PayOsGatewayCard(
                    checkoutUrl: active?.checkoutUrl ?? link?.checkoutUrl ?? '',
                    qrCode: link?.qrCode,
                    isLoading: state.isLoading,
                    onOpenUrl: () {
                      final url =
                          active?.checkoutUrl ?? link?.checkoutUrl ?? '';
                      if (url.isNotEmpty) _launchCheckout(url);
                    },
                    onGoHome: () => context.go(AppRoutes.home),
                    onOpenBankApp: () => _openBankingApp(link?.qrCode),
                    onCancel: () => context.read<PaymentCubit>().cancelPayment(
                      widget.bookingId,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

final class _BookingSummaryCard extends StatelessWidget {
  const _BookingSummaryCard({
    required this.bookingCode,
    required this.amount,
    required this.currency,
    this.expiresAt,
  });

  final String bookingCode;
  final int amount;
  final String currency;
  final DateTime? expiresAt;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        letterSpacing: 0.5,
                        color: c.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bookingCode,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: c.warningContainer,
                  borderRadius: BorderRadius.circular(TripMateRadius.pill),
                ),
                child: Text(
                  'Chờ thanh toán',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: c.warning,
                  ),
                ),
              ),
            ],
          ),
          Divider(height: 24, color: c.borderSubtle),
          AppKeyValueRow(
            label: 'Tổng thanh toán:',
            value: _formatMoney(amount, currency),
            isPrice: true,
            isProminent: true,
          ),
          if (expiresAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 14, color: c.error),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Hạn giữ chỗ: ${_formatDateTime(expiresAt!)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

final class _MockGatewayCard extends StatelessWidget {
  const _MockGatewayCard({
    required this.paymentId,
    required this.bookingId,
    required this.isLoading,
    required this.onSubmit,
  });

  final int paymentId;
  final String bookingId;
  final bool isLoading;
  final void Function(String outcome) onSubmit;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return AppSectionCard(
      title: 'Cổng thanh toán mô phỏng TripMate',
      subtitle: 'Môi trường giả lập kiểm thử giao dịch',
      icon: Icons.developer_mode,
      borderColor: c.brandTeal.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Chọn kết quả mô phỏng giao dịch:',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: isLoading ? null : () => onSubmit('Success'),
            style: FilledButton.styleFrom(
              backgroundColor: c.success,
              foregroundColor: c.textOnBrand,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(TripMateRadius.sm),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text(
              'Thanh toán thành công',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          FilledButton.icon(
            onPressed: isLoading ? null : () => onSubmit('Cancelled'),
            style: FilledButton.styleFrom(
              backgroundColor: c.warning,
              foregroundColor: c.textOnBrand,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(TripMateRadius.sm),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.cancel_outlined, size: 18),
            label: const Text(
              'Hủy thanh toán',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

final class _PayOsGatewayCard extends StatelessWidget {
  const _PayOsGatewayCard({
    required this.checkoutUrl,
    this.qrCode,
    required this.isLoading,
    required this.onOpenUrl,
    required this.onOpenBankApp,
    required this.onGoHome,
    required this.onCancel,
  });

  final String checkoutUrl;
  final String? qrCode;
  final bool isLoading;
  final VoidCallback onOpenUrl;
  final VoidCallback onOpenBankApp;
  final VoidCallback onGoHome;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return AppSectionCard(
      title: 'PayOS — Cổng thanh toán trực tuyến',
      subtitle: 'VietQR quét mã thanh toán 30+ ngân hàng',
      icon: Icons.qr_code_2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (qrCode != null && qrCode!.isNotEmpty) ...[
            Text(
              'Quét VietQR để thanh toán',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  // QR codes require a crisp white quiet-zone for camera contrast.
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(TripMateRadius.sm),
                  border: Border.all(color: c.borderSubtle),
                ),
                child: QrImageView(data: qrCode!, size: 220),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Mở ứng dụng ngân hàng để quét mã. TripMate sẽ tự động xác nhận ngay khi thanh toán thành công.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: c.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: isLoading ? null : onOpenBankApp,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(TripMateRadius.sm),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.account_balance_outlined, size: 18),
              label: const Text(
                'Mở ứng dụng ngân hàng',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (qrCode == null || qrCode!.isEmpty)
            FilledButton.icon(
              onPressed: isLoading || checkoutUrl.isEmpty ? null : onOpenUrl,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(TripMateRadius.sm),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.open_in_browser, size: 18),
              label: const Text(
                'Mở trang PayOS',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            onPressed: isLoading ? null : onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: c.error,
              side: BorderSide(color: c.error.withValues(alpha: 0.45)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(TripMateRadius.sm),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.cancel_outlined, size: 18),
            label: const Text(
              'Hủy thanh toán',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            onPressed: onGoHome,
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(TripMateRadius.sm),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.home_outlined, size: 18),
            label: const Text(
              'Về trang chủ',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

final class _PaidSuccessView extends StatelessWidget {
  const _PaidSuccessView({required this.status, required this.bookingId});
  final BookingPaymentStatus status;

  /// The e-ticket action needs a real (numeric) booking id.
  final int? bookingId;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 80,
            width: 80,
            decoration: BoxDecoration(
              color: c.successContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_rounded, color: c.success, size: 48),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Thanh Toán Thành Công!',
            style: TextStyle(
              fontFamily: AppTypography.displayFont,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Đơn đặt tour ${status.bookingCode} đã hoàn tất thanh toán.',
            style: TextStyle(fontSize: 13.5, color: c.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (bookingId case final id? when id > 0) ...[
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.bookingETicket(id)),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(TripMateRadius.sm),
                ),
                minimumSize: const Size.fromHeight(50),
              ),
              icon: const Icon(Icons.qr_code_2, size: 18),
              label: const Text(
                'Xem vé điện tử',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          OutlinedButton.icon(
            onPressed: () => context.go(AppRoutes.tripHistoryPath()),
            style: OutlinedButton.styleFrom(
              foregroundColor: c.brandTeal,
              side: BorderSide(color: c.borderStrong),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(TripMateRadius.sm),
              ),
              minimumSize: const Size.fromHeight(50),
            ),
            icon: const Icon(Icons.card_travel, size: 18),
            label: const Text(
              'Quản lý chuyến đi',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: () => context.go(AppRoutes.home),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(TripMateRadius.sm),
              ),
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text(
              'Về Trang Chủ',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

final class _ExpiredView extends StatelessWidget {
  const _ExpiredView({required this.status});
  final BookingPaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 80,
            width: 80,
            decoration: BoxDecoration(
              color: c.errorContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.timer_off_outlined, color: c.error, size: 48),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Đơn Tour Đã Hết Hạn',
            style: TextStyle(
              fontFamily: AppTypography.displayFont,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Thời gian giữ chỗ cho đơn ${status.bookingCode} đã kết thúc. Chỗ ngồi đã được giải phóng.',
            style: TextStyle(fontSize: 13.5, color: c.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: () => context.go(AppRoutes.tourSearch),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(TripMateRadius.sm),
              ),
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text(
              'Khám phá các tour khác',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

final class _CancelledView extends StatelessWidget {
  const _CancelledView({required this.status, required this.onRetry});

  final BookingPaymentStatus status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 80,
            width: 80,
            decoration: BoxDecoration(
              color: c.warningContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.cancel_outlined, color: c.warning, size: 48),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Giao Dịch Đã Hủy',
            style: TextStyle(
              fontFamily: AppTypography.displayFont,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Bạn đã hủy thao tác tại cổng thanh toán. Chỗ giữ cho đơn ${status.bookingCode} vẫn được bảo lưu đến ${_formatDateTime(status.paymentExpiresAt)}.',
            style: TextStyle(fontSize: 13.5, color: c.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(TripMateRadius.sm),
              ),
              minimumSize: const Size.fromHeight(50),
            ),
            icon: const Icon(Icons.payment_rounded, size: 18),
            label: const Text(
              'Tiến hành thanh toán lại',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: () => context.go(AppRoutes.home),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(TripMateRadius.sm),
              ),
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text(
              'Về Trang Chủ',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
