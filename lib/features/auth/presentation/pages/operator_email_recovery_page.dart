import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/core/utils/validators.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/operator_email_recovery_cubit.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';
import 'package:trip_mate_mobile/shared/widgets/app_password_field.dart';
import 'package:trip_mate_mobile/shared/widgets/app_section_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_text_field.dart';

class OperatorEmailRecoveryPage extends StatefulWidget {
  const OperatorEmailRecoveryPage({this.email, super.key});

  final String? email;

  @override
  State<OperatorEmailRecoveryPage> createState() =>
      _OperatorEmailRecoveryPageState();
}

class _OperatorEmailRecoveryPageState extends State<OperatorEmailRecoveryPage> {
  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(text: widget.email);
  final _passwordController = TextEditingController();
  Timer? _cooldownTimer;
  var _cooldownSeconds = 0;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  void _submit({required bool send}) {
    if (!_formKey.currentState!.validate()) return;
    final cubit = context.read<OperatorEmailRecoveryCubit>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (send) {
      cubit.sendEmail(email: email, password: password);
    } else {
      cubit.checkEmail(email: email, password: password);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return BlocConsumer<OperatorEmailRecoveryCubit, OperatorEmailRecoveryState>(
      listenWhen: (previous, current) =>
          previous.phase != OperatorEmailRecoveryPhase.sent &&
          current.phase == OperatorEmailRecoveryPhase.sent,
      listener: (_, _) => _startCooldown(),
      builder: (context, state) => AppPageScaffold(
        title: 'Xác minh email đối tác',
        content: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: c.tealSoftContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.mark_email_read_outlined,
                  size: 26,
                  color: c.brandTeal,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hoàn tất xác minh email',
                      style: TextStyle(
                        fontFamily: AppTypography.displayFont,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Xác nhận liên kết trong hộp thư để tiếp tục.',
                      style: TextStyle(fontSize: 13, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Nếu bạn đã gửi hồ sơ nhà điều hành tour, hãy nhập đúng email và mật khẩu đã đăng ký. '
            'Mở liên kết trong hộp thư rồi quay lại đây để xác nhận.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const AppAlert(
            message:
                'Việc xác minh email không tự động phê duyệt hồ sơ. '
                'Hồ sơ vẫn ở trạng thái Chờ phê duyệt cho đến khi quản trị viên xét duyệt.',
          ),
          const SizedBox(height: AppSpacing.md),
          AppSectionCard(
            title: 'Thông tin tài khoản',
            icon: Icons.verified_user_outlined,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  AppTextField(
                    controller: _emailController,
                    label: 'Địa chỉ email',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: Validators.email,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppPasswordField(
                    controller: _passwordController,
                    label: 'Mật khẩu',
                    textInputAction: TextInputAction.done,
                    validator: (value) =>
                        Validators.requiredField(value, fieldName: 'mật khẩu'),
                  ),
                ],
              ),
            ),
          ),
          if (state.message != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppAlert(
              message: state.message!,
              type: switch (state.phase) {
                OperatorEmailRecoveryPhase.verified => AppAlertType.success,
                OperatorEmailRecoveryPhase.error => AppAlertType.error,
                _ => AppAlertType.info,
              },
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed:
                state.isBusy ||
                    state.phase == OperatorEmailRecoveryPhase.verified ||
                    _cooldownSeconds > 0
                ? null
                : () => _submit(send: true),
            child: Text(
              _cooldownSeconds > 0
                  ? 'Gửi lại sau ${_cooldownSeconds}s'
                  : 'Gửi email xác minh',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed:
                state.isBusy ||
                    state.phase == OperatorEmailRecoveryPhase.verified
                ? null
                : () => _submit(send: false),
            child: const Text('Tôi đã xác minh email'),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: state.isBusy ? null : () => context.go(AppRoutes.login),
            child: const Text('Đăng nhập'),
          ),
        ],
      ),
    );
  }
}
