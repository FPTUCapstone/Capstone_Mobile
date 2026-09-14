import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';

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

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthSessionCubit, AuthSessionState>(
      listener: (context, state) {
        if (state.isAuthenticated) {
          context.go(AppRoutes.traveler);
        } else if (state.startResendCooldown) {
          _startResendCooldown();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Verify your email')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: BlocBuilder<AuthSessionCubit, AuthSessionState>(
              builder: (context, state) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 32),
                    const Icon(Icons.mark_email_read_outlined, size: 64),
                    const SizedBox(height: 24),
                    Text(
                      'Check your email',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'We sent a verification link to your registered email address. Open the link, then return here to activate your TripMate account.',
                      textAlign: TextAlign.center,
                    ),
                    if (_maskedEmail != null) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: Chip(
                          avatar: const Icon(Icons.mail_outline, size: 18),
                          label: Text(_maskedEmail!),
                        ),
                      ),
                    ],
                    if (state.successMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        state.successMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                    if (state.status == AuthSessionStatus.failure) ...[
                      const SizedBox(height: 16),
                      Text(
                        state.errorMessage ?? 'Verification failed.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    AppButton(
                      isLoading: state.isResendingVerificationEmail,
                      label: _resendSecondsLeft > 0
                          ? 'Resend Email (${_resendSecondsLeft}s)'
                          : 'Resend Verification Email',
                      onPressed: state.isLoading || _resendSecondsLeft > 0
                          ? null
                          : () => context
                                .read<AuthSessionCubit>()
                                .resendVerificationEmail(),
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      isLoading:
                          state.isLoading &&
                          state.operation == AuthSessionOperation.verifyEmail,
                      label: 'I verified my email',
                      onPressed: state.isLoading
                          ? null
                          : () =>
                                context.read<AuthSessionCubit>().verifyEmail(),
                    ),
                    TextButton(
                      onPressed: state.isLoading
                          ? null
                          : () => context.go(AppRoutes.login),
                      child: const Text('Back to sign in'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
