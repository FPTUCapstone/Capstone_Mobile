import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_coastal_app_bar.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({this.email, super.key});

  final String? email;

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  Timer? _resendTimer;
  int _resendSecondsLeft = 0;
  String? _maskedEmail;
  String? _verificationErrorMessage;
  bool _verificationActionPending = false;

  @override
  void initState() {
    super.initState();
    _resolveMaskedEmail();
  }

  Future<void> _resolveMaskedEmail() async {
    final routeEmail = widget.email?.trim();
    final email = routeEmail != null && routeEmail.isNotEmpty
        ? routeEmail
        : await context.read<AuthSessionCubit>().currentFirebaseUserEmail;
    if (!mounted) return;
    setState(() => _maskedEmail = _maskEmail(email));
  }

  String? _maskEmail(String? email) {
    if (email == null) return null;
    final separator = email.indexOf('@');
    if (separator <= 0 || separator == email.length - 1) return null;
    return '${email[0]}***${email.substring(separator)}';
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsLeft = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSecondsLeft <= 1) {
        timer.cancel();
        setState(() => _resendSecondsLeft = 0);
        return;
      }
      setState(() => _resendSecondsLeft -= 1);
    });
  }

  void _runVerificationAction(Future<void> Function() action) {
    setState(() {
      _verificationActionPending = true;
      _verificationErrorMessage = null;
    });
    unawaited(action());
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return BlocListener<AuthSessionCubit, AuthSessionState>(
      listener: (context, state) {
        if (state.isAuthenticated) {
          context.go(AppRoutes.traveler);
        } else if (state.status == AuthSessionStatus.failure &&
            _verificationActionPending) {
          setState(() {
            _verificationActionPending = false;
            _verificationErrorMessage =
                state.errorMessage ?? 'Xác minh thất bại.';
          });
          if (state.startResendCooldown) {
            _startResendCooldown();
          }
        } else if (state.startResendCooldown) {
          _verificationActionPending = false;
          _startResendCooldown();
        }
      },
      child: Scaffold(
        backgroundColor: c.canvas,
        appBar: const AppCoastalAppBar(title: 'Xác minh email'),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: BlocBuilder<AuthSessionCubit, AuthSessionState>(
                  builder: (context, state) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppSpacing.md),
                        AppCard(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    color: c.tealSoftContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.mark_email_read_outlined,
                                    size: 34,
                                    color: c.brandTeal,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'Kiểm tra hộp thư của bạn',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: AppTypography.displayFont,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: c.textPrimary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Chúng tôi đã gửi liên kết xác minh đến địa chỉ email bạn đăng ký. Hãy mở liên kết rồi quay lại đây để kích hoạt tài khoản TripMate.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  height: 1.45,
                                  color: c.textSecondary,
                                ),
                              ),
                              if (_maskedEmail != null) ...[
                                const SizedBox(height: AppSpacing.md),
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: c.tealSoftContainer,
                                      borderRadius: BorderRadius.circular(
                                        TripMateRadius.pill,
                                      ),
                                      border: Border.all(
                                        color: c.brandTeal.withValues(
                                          alpha: 0.25,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.mail_outline,
                                          size: 16,
                                          color: c.brandTeal,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _maskedEmail!,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: c.brandTeal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              if (state.successMessage != null) ...[
                                const SizedBox(height: AppSpacing.md),
                                AppAlert(
                                  type: AppAlertType.success,
                                  message: state.successMessage!,
                                ),
                              ],
                              if (_verificationErrorMessage != null) ...[
                                const SizedBox(height: AppSpacing.md),
                                AppAlert(
                                  type: AppAlertType.error,
                                  message: _verificationErrorMessage!,
                                ),
                              ],
                              const SizedBox(height: AppSpacing.lg),
                              FilledButton.tonal(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  backgroundColor: c.tealSoftContainer,
                                  foregroundColor: c.brandTeal,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed:
                                    state.isLoading || _resendSecondsLeft > 0
                                    ? null
                                    : () => _runVerificationAction(
                                        context
                                            .read<AuthSessionCubit>()
                                            .resendVerificationEmail,
                                      ),
                                child: state.isResendingVerificationEmail
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: c.brandTeal,
                                        ),
                                      )
                                    : Text(
                                        _resendSecondsLeft > 0
                                            ? 'Gửi lại email (${_resendSecondsLeft}s)'
                                            : 'Gửi lại email xác minh',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              AppButton(
                                isLoading:
                                    state.isLoading &&
                                    state.operation ==
                                        AuthSessionOperation.verifyEmail,
                                label: 'Tôi đã xác minh email',
                                onPressed: state.isLoading
                                    ? null
                                    : () => _runVerificationAction(
                                        context
                                            .read<AuthSessionCubit>()
                                            .verifyEmail,
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextButton(
                          onPressed: state.isLoading
                              ? null
                              : () => context.go(AppRoutes.login),
                          child: const Text('Quay lại đăng nhập'),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
