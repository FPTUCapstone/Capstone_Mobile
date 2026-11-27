import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/operator_payment_channel/domain/entities/payment_channel_status.dart';
import 'package:trip_mate_mobile/features/operator_payment_channel/presentation/cubit/operator_payment_channel_cubit.dart';
import 'package:trip_mate_mobile/features/operator_payment_channel/presentation/cubit/operator_payment_channel_state.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';

class OperatorPaymentChannelPage extends StatefulWidget {
  const OperatorPaymentChannelPage({super.key});

  @override
  State<OperatorPaymentChannelPage> createState() =>
      _OperatorPaymentChannelPageState();
}

class _OperatorPaymentChannelPageState
    extends State<OperatorPaymentChannelPage> {
  @override
  void initState() {
    super.initState();
    context.read<OperatorPaymentChannelCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kênh thanh toán payOS')),
      body:
          BlocBuilder<OperatorPaymentChannelCubit, OperatorPaymentChannelState>(
            builder: (context, state) {
              if (state.loadStatus == PaymentChannelLoadStatus.loading ||
                  state.loadStatus == PaymentChannelLoadStatus.idle) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.loadStatus == PaymentChannelLoadStatus.failure) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          state.loadError ??
                              'Không thể tải thông tin kênh thanh toán.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton(
                          onPressed: () => context
                              .read<OperatorPaymentChannelCubit>()
                              .load(),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final channel = state.channel;
              if (channel == null) return const SizedBox.shrink();
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  _StatusCard(channel: channel),
                  const SizedBox(height: AppSpacing.md),
                  if (state.actionError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(
                        state.actionError!,
                        style: const TextStyle(color: AppColors.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (channel.canSubmitCredentials) ...[
                    _CredentialsForm(
                      isBusy: state.isBusy,
                      onSubmit: (req) => context
                          .read<OperatorPaymentChannelCubit>()
                          .submitCredentials(req),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (channel.canVerify)
                    FilledButton.icon(
                      onPressed: state.isBusy
                          ? null
                          : () => context
                                .read<OperatorPaymentChannelCubit>()
                                .verify(),
                      icon: state.isVerifying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.verified_outlined),
                      label: const Text('Yêu cầu xác minh'),
                    ),
                ],
              );
            },
          ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.channel});
  final PaymentChannelStatus channel;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (channel.status) {
      PaymentChannelState.noChannel => ('Chưa thiết lập', AppColors.muted),
      PaymentChannelState.pendingVerification => (
        'Chờ xác minh',
        Colors.orange,
      ),
      PaymentChannelState.pendingAdminApproval => ('Chờ duyệt', Colors.blue),
      PaymentChannelState.ready => ('Hoạt động', Colors.green),
      PaymentChannelState.disabled => ('Đã vô hiệu', AppColors.error),
    };
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Trạng thái kênh',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (channel.beneficiaryAccountName != null) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            _InfoRow(
              label: 'Tài khoản thụ hưởng',
              value: channel.beneficiaryAccountName!,
            ),
            if (channel.beneficiaryAccountNumberMasked != null)
              _InfoRow(
                label: 'Số tài khoản',
                value: channel.beneficiaryAccountNumberMasked!,
              ),
            if (channel.beneficiaryBankCode != null)
              _InfoRow(label: 'Ngân hàng', value: channel.beneficiaryBankCode!),
          ],
          if (channel.status == PaymentChannelState.pendingAdminApproval)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Thông tin đã được gửi. Vui lòng chờ Admin TripMate xác minh kênh thanh toán của bạn.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
            ),
          if (channel.status == PaymentChannelState.ready)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Kênh thanh toán đã sẵn sàng. Khách hàng sẽ thanh toán trực tiếp vào tài khoản của bạn.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CredentialsForm extends StatefulWidget {
  const _CredentialsForm({required this.isBusy, required this.onSubmit});
  final bool isBusy;
  final void Function(SubmitCredentialsRequest) onSubmit;

  @override
  State<_CredentialsForm> createState() => _CredentialsFormState();
}

class _CredentialsFormState extends State<_CredentialsForm> {
  final _formKey = GlobalKey<FormState>();
  final _clientId = TextEditingController();
  final _apiKey = TextEditingController();
  final _checksumKey = TextEditingController();
  final _accountNumber = TextEditingController();
  final _accountName = TextEditingController();
  final _bankCode = TextEditingController();

  @override
  void dispose() {
    _clientId.dispose();
    _apiKey.dispose();
    _checksumKey.dispose();
    _accountNumber.dispose();
    _accountName.dispose();
    _bankCode.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSubmit(
      SubmitCredentialsRequest(
        clientId: _clientId.text.trim(),
        apiKey: _apiKey.text.trim(),
        checksumKey: _checksumKey.text.trim(),
        beneficiaryAccountNumber: _accountNumber.text.trim(),
        beneficiaryAccountName: _accountName.text.trim(),
        beneficiaryBankCode: _bankCode.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thông tin tích hợp payOS',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Lấy từ dashboard.payos.vn → Thông tin tài khoản.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.md),
            _field(controller: _clientId, label: 'Client ID'),
            _field(
              controller: _apiKey,
              label: 'API Key',
              obscure: true,
              helperText: 'Không được lưu hoặc chia sẻ khóa này.',
            ),
            _field(
              controller: _checksumKey,
              label: 'Checksum Key',
              obscure: true,
            ),
            const Divider(height: AppSpacing.xl),
            Text(
              'Tài khoản thụ hưởng',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            _field(controller: _accountNumber, label: 'Số tài khoản'),
            _field(controller: _accountName, label: 'Tên chủ tài khoản'),
            _field(
              controller: _bankCode,
              label: 'Mã ngân hàng (VD: VCB, TCB)',
              helperText: 'Dùng mã ngân hàng theo chuẩn payOS.',
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: widget.isBusy ? null : _submit,
                child: widget.isBusy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Lưu thông tin'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    String? helperText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          helperMaxLines: 2,
        ),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Vui lòng nhập $label.' : null,
      ),
    );
  }
}
