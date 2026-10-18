import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/payment/domain/entities/payment_link.dart';
import 'package:trip_mate_mobile/features/payment/presentation/cubit/payment_cubit.dart';
import 'package:trip_mate_mobile/features/payment/presentation/cubit/payment_state.dart';
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
  Timer? _confirmationTimer;
  var _secondsToHome = 5;
  var _paymentConfirmed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<PaymentCubit>().startPayment(widget.bookingId);
  }

  @override
  void dispose() {
    _confirmationTimer?.cancel();
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
    for (var attempt = 0; attempt < 10 && mounted; attempt++) {
      await context.read<PaymentCubit>().refreshStatus(widget.bookingId);
      if (!mounted || context.read<PaymentCubit>().state.paymentStatus?.isPaid == true) {
        return;
      }
      if (attempt < 9) await Future<void>.delayed(const Duration(milliseconds: 1500));
    }
  }

  void _startSuccessCountdown() {
    if (_paymentConfirmed) return;
    _paymentConfirmed = true;
    _secondsToHome = 5;
    _confirmationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsToHome--);
      if (_secondsToHome <= 0) {
        timer.cancel();
        context.go(AppRoutes.home);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Thanh Toán Điện Tử',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F1B2D),
        elevation: 0.5,
        centerTitle: true,
      ),
      body: BlocConsumer<PaymentCubit, PaymentState>(
        listener: (context, state) {
          if (state.failure != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.failure!.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
          if (state.paymentStatus?.isPaid == true) {
            _startSuccessCountdown();
          }
        },
        builder: (context, state) {
          if (state.isLoading && state.paymentStatus == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: AppSpacing.md),
                  Text(
                    'Đang kết nối cổng thanh toán…',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
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
              secondsToHome: _secondsToHome,
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MÃ ĐẶT TOUR',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    bookingCode,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F1B2D),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Chờ thanh toán',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tổng thanh toán:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
              Text(
                _formatMoney(amount, currency),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          if (expiresAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 14,
                  color: Color(0xFFE02D4D),
                ),
                const SizedBox(width: 4),
                Text(
                  'Hạn giữ chỗ: ${_formatDateTime(expiresAt!)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE02D4D),
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF99F6E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFCCFBF1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.developer_mode,
                  color: Color(0xFF0F766E),
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TripMate Mock Gateway',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Môi trường giả lập kiểm thử giao dịch',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Chọn kết quả mô phỏng giao dịch:',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: isLoading ? null : () => onSubmit('Success'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text(
              'Thanh toán thành công (Success)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          FilledButton.icon(
            onPressed: isLoading ? null : () => onSubmit('Cancelled'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.cancel_outlined, size: 18),
            label: const Text(
              'Hủy thanh toán (Cancel)',
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
    required this.onGoHome,
  });

  final String checkoutUrl;
  final String? qrCode;
  final bool isLoading;
  final VoidCallback onOpenUrl;
  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.qr_code_2,
                  color: Color(0xFF0369A1),
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PayOS — Cổng Thanh Toán Online',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'VietQR quét mã thanh toán 30+ ngân hàng',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (qrCode != null && qrCode!.isNotEmpty) ...[
            const Text(
              'Quét VietQR để thanh toán',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: QrImageView(data: qrCode!, size: 220),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Mở ứng dụng ngân hàng để quét mã. TripMate sẽ tự xác nhận khi PayOS gửi webhook.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          FilledButton.icon(
            onPressed: isLoading || checkoutUrl.isEmpty ? null : onOpenUrl,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
            onPressed: onGoHome,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF334155),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
  const _PaidSuccessView({required this.status, required this.secondsToHome});
  final BookingPaymentStatus status;
  final int secondsToHome;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 80,
            width: 80,
            decoration: const BoxDecoration(
              color: Color(0xFFD1FAE5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF059669),
              size: 48,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Thanh Toán Thành Công!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F1B2D),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Đơn đặt tour ${status.bookingCode} đã hoàn tất thanh toán.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tự động trở về trang chủ sau $secondsToHome giây.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: () => context.go(AppRoutes.tripHistoryPath()),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
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
              foregroundColor: const Color(0xFF475569),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
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
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 80,
            width: 80,
            decoration: const BoxDecoration(
              color: Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.timer_off_outlined,
              color: Color(0xFFDC2626),
              size: 48,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Đơn Tour Đã Hết Hạn',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F1B2D),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Thời gian giữ chỗ cho đơn ${status.bookingCode} đã kết thúc. Chỗ ngồi đã được giải phóng.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: () => context.go(AppRoutes.tourSearch),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
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
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 80,
            width: 80,
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cancel_outlined,
              color: Color(0xFFD97706),
              size: 48,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Giao Dịch Đã Hủy',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F1B2D),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Bạn đã hủy thao tác tại cổng thanh toán. Chỗ giữ cho đơn ${status.bookingCode} vẫn được bảo lưu đến ${_formatDateTime(status.paymentExpiresAt)}.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
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
              foregroundColor: const Color(0xFF475569),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text(
              'Về trang chủ',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
