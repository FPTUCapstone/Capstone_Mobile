import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/features/messaging/domain/messaging.dart';
import 'package:trip_mate_mobile/features/messaging/presentation/widgets/messaging_message_tile.dart';

class VietQrSheet extends StatefulWidget {
  const VietQrSheet({
    super.key,
    required this.message,
    required this.userId,
    required this.readOnly,
    required this.onMarkPaid,
  });

  final ChatMessage message;
  final int userId;
  final bool readOnly;
  final Future<String?> Function() onMarkPaid;

  @override
  State<VietQrSheet> createState() => _VietQrSheetState();
}

class _VietQrSheetState extends State<VietQrSheet> {
  static const _bankCodes = <String, String>{
    'Vietcombank': 'VCB',
    'MBBank': 'MB',
    'Techcombank': 'TCB',
    'ACB': 'ACB',
    'VPBank': 'VPB',
    'BIDV': 'BIDV',
    'VietinBank': 'ICB',
    'TPBank': 'TPB',
  };

  static const _bankLabels = <String, String>{
    'Vietcombank': 'Vietcombank',
    'MBBank': 'MB Bank',
    'Techcombank': 'Techcombank',
    'ACB': 'ACB',
    'VPBank': 'VPBank',
    'BIDV': 'BIDV',
    'VietinBank': 'VietinBank',
    'TPBank': 'TPBank',
  };

  int _retryCount = 0;
  bool _saving = false;
  bool _copied = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final meta = widget.message.metadata;
    final shares = meta?.shares ?? const <ChatExpenseShare>[];
    final myShare = shares.where((s) => s.userId == widget.userId).toList();
    final amountVnd = myShare.isNotEmpty
        ? myShare.first.amountVnd
        : (meta?.totalAmountVnd ?? 0);
    final rawBank = meta?.bankCode?.trim() ?? '';
    final bankCode = _bankCodes[rawBank] ?? rawBank;
    final bankLabel = _bankLabels[rawBank] ?? rawBank;
    final accountNumber = meta?.accountNumber?.trim() ?? '';
    final accountName = meta?.accountName?.trim() ?? '';
    final title = meta?.title?.trim().isNotEmpty == true
        ? meta!.title!
        : widget.message.content;
    final isPaid =
        widget.message.groupState?.paidUserIds.contains(widget.userId) ?? false;

    final qrUri = Uri.https(
      'img.vietqr.io',
      '/image/${Uri.encodeComponent(bankCode)}-${Uri.encodeComponent(accountNumber)}-compact2.png',
      {
        'amount': amountVnd.toString(),
        'addInfo': 'TripMate: $title',
        'accountName': accountName,
        if (_retryCount > 0) 'retry': _retryCount.toString(),
      },
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Thanh toán VietQR',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Text(
              'Quét mã trong ứng dụng ngân hàng; TripMate không tự chuyển tiền.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                width: 240,
                height: 240,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: Image.network(
                  qrUri.toString(),
                  key: ValueKey(qrUri.toString()),
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text(
                            'Đang tải mã VietQR…',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.qr_code_2,
                          size: 36,
                          color: AppColors.warning,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Không tải được ảnh VietQR. Vui lòng thử lại hoặc chuyển khoản thủ công.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => setState(() => _retryCount++),
                          child: const Text('Thử tải lại mã QR'),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                children: [
                  _DetailRow(label: 'Số tiền', value: formatVnd(amountVnd)),
                  const Divider(height: 16),
                  _DetailRow(label: 'Người nhận', value: accountName),
                  const SizedBox(height: 6),
                  _DetailRow(label: 'Ngân hàng', value: bankLabel),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text(
                        'Số tài khoản',
                        style: TextStyle(fontSize: 13, color: AppColors.muted),
                      ),
                      const Spacer(),
                      Text(
                        accountNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Sao chép số tài khoản',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          _copied ? Icons.check : Icons.copy,
                          size: 16,
                          color: AppColors.secondary,
                        ),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: accountNumber),
                          );
                          if (mounted) {
                            setState(() => _copied = true);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving || isPaid || widget.readOnly
                  ? null
                  : () async {
                      final navigator = Navigator.of(context);
                      setState(() {
                        _saving = true;
                        _error = null;
                      });
                      final err = await widget.onMarkPaid();
                      if (!mounted) {
                        return;
                      }
                      if (err == null) {
                        navigator.pop();
                      } else {
                        setState(() {
                          _saving = false;
                          _error = err;
                        });
                      }
                    },
              child: Text(
                isPaid
                    ? 'Đã đánh dấu chuyển tiền'
                    : _saving
                    ? 'Đang lưu…'
                    : 'Tôi đã chuyển tiền',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
