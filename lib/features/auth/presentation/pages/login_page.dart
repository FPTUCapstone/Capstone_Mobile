import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/utils/validators.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';
import 'package:trip_mate_mobile/shared/widgets/app_password_field.dart';
import 'package:trip_mate_mobile/shared/widgets/app_text_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({this.notice, super.key});

  final String? notice;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _keepSignedIn = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthSessionCubit, AuthSessionState>(
      builder: (context, session) {
        return AppPageScaffold(
          showAppBar: false,
          content: [
            const SizedBox(height: AppSpacing.lg),
            const _TripMateMark(),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Chào mừng trở lại',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Đăng nhập để tiếp tục lên kế hoạch cho chuyến đi.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  AppTextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    label: 'Địa chỉ email',
                    prefixIcon: const Icon(Icons.mail_outline, size: 19),
                    textInputAction: TextInputAction.next,
                    validator: Validators.email,
                  ),
                  const SizedBox(height: AppSpacing.sm),
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
            const SizedBox(height: 6),
            Row(
              children: [
                Checkbox(
                  value: _keepSignedIn,
                  visualDensity: VisualDensity.compact,
                  onChanged: (value) {
                    setState(() => _keepSignedIn = value ?? false);
                  },
                ),
                const Expanded(
                  child: Text(
                    'Ghi nhớ đăng nhập',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: session.isLoading
                      ? null
                      : () => context.push(AppRoutes.forgotPassword),
                  child: const Text('Quên mật khẩu?'),
                ),
              ],
            ),
            if (widget.notice != null) ...[
              const SizedBox(height: AppSpacing.xs),
              AppAlert(message: widget.notice!, type: AppAlertType.success),
            ],
            // A completed local sign-out that could not reach the server
            // arrives as an unauthenticated state carrying the approved notice.
            if (session.status == AuthSessionStatus.failure ||
                (session.status == AuthSessionStatus.unauthenticated &&
                    session.errorMessage != null)) ...[
              const SizedBox(height: AppSpacing.xs),
              AppAlert(
                message: session.errorMessage ?? 'Không thể đăng nhập lúc này.',
                type: AppAlertType.error,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            AppButton(
              isLoading: session.isLoading,
              label: 'Đăng nhập',
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: Text(
                    'hoặc tiếp tục với',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: session.isLoading
                  ? null
                  : () => context.read<AuthSessionCubit>().signInWithGoogle(),
              icon: const Text(
                'G',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              label: const Text('Tiếp tục với Google'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Chưa có tài khoản TripMate?',
                  style: TextStyle(fontSize: 13),
                ),
                TextButton(
                  onPressed: _showAccountTypeSheet,
                  child: const Text('Tạo tài khoản'),
                ),
              ],
            ),
            Center(
              child: TextButton.icon(
                onPressed: () => context.go(AppRoutes.guestHome),
                icon: const Icon(Icons.travel_explore, size: 18),
                label: const Text('Duyệt khám phá không cần đăng nhập'),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAccountTypeSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Chọn loại tài khoản',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Tài khoản Du khách',
                onPressed: () {
                  Navigator.pop(sheetContext);
                  context.push(AppRoutes.travelerRegistration);
                },
              ),
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  context.push(AppRoutes.operatorRegistration);
                },
                child: const Text('Tài khoản Nhà điều hành tour'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    context.read<AuthSessionCubit>().signIn(
      email: _emailController.text,
      password: _passwordController.text,
      keepSignedIn: _keepSignedIn,
    );
  }
}

class _TripMateMark extends StatelessWidget {
  const _TripMateMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        'assets/images/logo/tripmate_emblem_512.png',
        width: 68,
        height: 68,
        fit: BoxFit.contain,
      ),
    );
  }
}
