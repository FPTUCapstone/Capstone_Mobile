import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/operator_application_cubit.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';
import 'package:trip_mate_mobile/shared/widgets/app_section_card.dart';
import 'package:trip_mate_mobile/shared/widgets/error_view.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

class OperatorApplicationPage extends StatefulWidget {
  const OperatorApplicationPage({this.renewSession, super.key});
  final Future<void> Function()? renewSession;
  @override
  State<OperatorApplicationPage> createState() =>
      _OperatorApplicationPageState();
}

class _OperatorApplicationPageState extends State<OperatorApplicationPage> {
  bool _openingContract = false;
  String? _contractError;
  Future<void> _openContract() async {
    if (_openingContract) return;
    setState(() {
      _openingContract = true;
      _contractError = null;
    });
    try {
      final renew = widget.renewSession;
      if (renew == null) throw StateError('Session renewal unavailable');
      await renew();
      if (!mounted) return;
      await context.read<AuthSessionCubit>().reloadRenewedOperatorSession();
      if (!mounted) return;
      if (!context.read<AuthSessionCubit>().state.awaitsContractSignature) {
        throw StateError('Contract onboarding unresolved');
      }
      context.go(AppRoutes.operatorContract);
    } catch (_) {
      if (mounted) {
        setState(
          () => _contractError =
              'Chưa cập nhật được trạng thái tài khoản. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _openingContract = false);
    }
  }

  @override
  void initState() {
    super.initState();
    context.read<OperatorApplicationCubit>().loadApplication();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<OperatorApplicationCubit, OperatorApplicationState>(
    builder: (context, state) {
      final c = context.tmColors;
      if (state.status == OperatorApplicationStatus.loading) {
        return AppPageScaffold(
          title: 'Hồ sơ đối tác',
          content: [
            const SizedBox(height: AppSpacing.xl),
            Center(child: CircularProgressIndicator(color: c.brandTeal)),
          ],
        );
      }
      if (state.status == OperatorApplicationStatus.unresolved ||
          state.application == null) {
        return AppPageScaffold(
          title: 'Hồ sơ đối tác',
          content: [
            ErrorView(
              title: 'Không thể tải trạng thái hồ sơ',
              message:
                  state.errorMessage ??
                  'Không thể tải thông tin hồ sơ đối tác.',
              retryLabel: 'Thử lại',
              onRetry: context.read<OperatorApplicationCubit>().loadApplication,
            ),
          ],
          footer: const _SignOutButton(),
        );
      }
      final application = state.application!;
      final rejected = state.status == OperatorApplicationStatus.rejected;
      final pending = state.status == OperatorApplicationStatus.pending;
      final awaitsContract =
          application.userStatus == 'PendingContractSignature' ||
          context.watch<AuthSessionCubit>().state.awaitsContractSignature;

      return AppPageScaffold(
        title: 'Hồ sơ đối tác',
        onRefresh: context.read<OperatorApplicationCubit>().loadApplication,
        content: [
          AppSectionCard(
            title: application.companyName,
            icon: Icons.business_outlined,
            trailing: StatusBadge(
              label: _approvalStatusLabel(application.approvalStatus),
              type: rejected
                  ? StatusBadgeType.error
                  : pending
                  ? StatusBadgeType.warning
                  : StatusBadgeType.success,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mã số thuế: ${application.taxCode}',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Số lần nộp lại: ${application.resubmissionCount}',
                  style: TextStyle(fontSize: 13, color: c.textMuted),
                ),
              ],
            ),
          ),
          if (rejected) ...[
            const SizedBox(height: AppSpacing.md),
            AppAlert(
              title: 'Lý do từ chối',
              message: application.rejectionReason ?? 'Chưa có lý do cụ thể.',
              type: AppAlertType.error,
            ),
          ],
          if (pending) ...[
            const SizedBox(height: AppSpacing.md),
            const AppAlert(
              message:
                  'Hồ sơ của bạn đang chờ quản trị viên phê duyệt. Tính năng đăng tour và nhận đặt chỗ tạm thời chưa khả dụng.',
            ),
          ],
          if (state.status == OperatorApplicationStatus.approved) ...[
            const SizedBox(height: AppSpacing.md),
            const AppAlert(
              message: 'Hồ sơ nhà điều hành tour của bạn đã được phê duyệt.',
              type: AppAlertType.success,
            ),
            if (awaitsContract) ...[
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: _openingContract
                    ? 'Đang cập nhật…'
                    : 'Xem và ký hợp đồng',
                isLoading: _openingContract,
                onPressed: _openingContract ? null : _openContract,
              ),
            ],
            if (_contractError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              AppAlert(message: _contractError!, type: AppAlertType.error),
            ],
          ],
          const SizedBox(height: AppSpacing.md),
          AppSectionCard(
            title: 'Hồ sơ đính kèm',
            icon: Icons.folder_outlined,
            child: application.documents.isEmpty
                ? Text(
                    'Chưa có tài liệu đính kèm.',
                    style: TextStyle(fontSize: 13, color: c.textMuted),
                  )
                : Column(
                    children: [
                      for (
                        var i = 0;
                        i < application.documents.length;
                        i++
                      ) ...[
                        if (i > 0) Divider(height: 16, color: c.borderSubtle),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: c.surfaceElevated,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.description_outlined,
                                size: 18,
                                color: c.brandTeal,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_documentTypeLabel(application.documents[i].documentType)} #${application.documents[i].documentId}',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _documentStatusLabel(
                                      application.documents[i].status,
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: c.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
          ),
          if (state.successMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppAlert(
              message: state.successMessage!,
              type: AppAlertType.success,
            ),
          ],
        ],
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (rejected) ...[
              AppButton(
                label: 'Nộp lại hồ sơ',
                onPressed: () =>
                    context.push(AppRoutes.operatorApplicationResubmit),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            const _SignOutButton(),
          ],
        ),
      );
    },
  );
}

String _approvalStatusLabel(String status) => switch (status) {
  'PendingApproval' => 'Chờ phê duyệt',
  'Approved' => 'Đã phê duyệt',
  'Rejected' => 'Bị từ chối',
  _ => status,
};

String _documentTypeLabel(String type) => switch (type) {
  'BusinessLicense' => 'Giấy phép kinh doanh',
  'InternationalTourLicense' => 'Giấy phép lữ hành quốc tế',
  'DomesticTourLicense' => 'Giấy phép lữ hành nội địa',
  'SupportingDocument' => 'Tài liệu bổ sung',
  _ => type,
};

String _documentStatusLabel(String status) => switch (status) {
  'Approved' => 'Đã phê duyệt',
  'Rejected' => 'Bị từ chối',
  'Submitted' => 'Đã nộp',
  'Pending' || 'PendingApproval' || 'PendingReview' => 'Chờ phê duyệt',
  _ => status,
};

class _SignOutButton extends StatelessWidget {
  const _SignOutButton();
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () => context.read<AuthSessionCubit>().signOut(),
    icon: const Icon(Icons.logout),
    label: const Text('Đăng xuất'),
  );
}
