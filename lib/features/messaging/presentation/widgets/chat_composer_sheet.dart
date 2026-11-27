import 'package:flutter/material.dart';

enum GroupComposerKind { poll, broadcast, rollCall, splitBill }

typedef ChatParticipant = ({int userId, String displayName});

/// Presentation-only form. A null result means the server confirmed the save.
class ChatComposerSheet extends StatefulWidget {
  const ChatComposerSheet({
    super.key,
    required this.kind,
    required this.participants,
    required this.senderName,
    required this.onSubmit,
  });
  final GroupComposerKind kind;
  final List<ChatParticipant> participants;
  final String senderName;
  final Future<String?> Function(
    String type,
    String content,
    Map<String, Object?> metadata,
  )
  onSubmit;
  @override
  State<ChatComposerSheet> createState() => _ChatComposerSheetState();
}

class _ChatComposerSheetState extends State<ChatComposerSheet> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _amount = TextEditingController();
  final _account = TextEditingController();
  late final _name = TextEditingController(text: widget.senderName);
  final _options = [TextEditingController(), TextEditingController()];
  String _bank = 'Vietcombank';
  String? _error;
  bool _saving = false;
  static const banks = [
    'Vietcombank',
    'MBBank',
    'Techcombank',
    'ACB',
    'VPBank',
    'BIDV',
    'VietinBank',
    'TPBank',
  ];
  bool get _expense => widget.kind == GroupComposerKind.splitBill;
  String get _label => switch (widget.kind) {
    GroupComposerKind.poll => 'Tạo bình chọn',
    GroupComposerKind.broadcast => 'Thông báo nhóm',
    GroupComposerKind.rollCall => 'Tạo điểm danh',
    GroupComposerKind.splitBill => 'Chia tiền chuyến đi',
  };
  int? get _vnd {
    final raw = _amount.text.trim();
    if (!RegExp(r'^(?:\d+|\d{1,3}(?:[.,]\d{3})+)$').hasMatch(raw)) return null;
    final value = int.tryParse(raw.replaceAll(RegExp('[.,]'), ''));
    return value != null && value > 0 && value <= 9007199254740991
        ? value
        : null;
  }

  @override
  void dispose() {
    for (final c in [_title, _body, _amount, _account, _name, ..._options]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final title = _title.text.trim();
    final data = <String, Object?>{'title': title};
    late String type;
    switch (widget.kind) {
      case GroupComposerKind.poll:
        type = 'poll';
        data.addAll({
          'question': title,
          'options': _options.map((c) => {'text': c.text.trim()}).toList(),
        });
      case GroupComposerKind.broadcast:
        type = 'broadcast';
        data.addAll({'content': _body.text.trim(), 'priority': 'normal'});
      case GroupComposerKind.rollCall:
        type = 'roll_call';
        data['totalMembers'] = widget.participants.length;
      case GroupComposerKind.splitBill:
        type = 'split_bill';
        final members = [...widget.participants]
          ..sort((a, b) => a.userId.compareTo(b.userId));
        if (members.isEmpty ||
            members.any((m) => m.userId <= 0) ||
            members.map((m) => m.userId).toSet().length != members.length) {
          setState(
            () => _error =
                'Chưa tải được danh sách thành viên hợp lệ. Vui lòng mở lại khoản chi.',
          );
          return;
        }
        final total = _vnd!;
        data.addAll({
          'totalAmount': total,
          'payerName': _name.text.trim(),
          'payerBankName': _bank,
          'payerBankAccount': _account.text.trim(),
          'participants': [
            for (var i = 0; i < members.length; i++)
              {
                'userId': members[i].userId,
                'displayName': members[i].displayName,
                'amount':
                    total ~/ members.length +
                    (i < total % members.length ? 1 : 0),
              },
          ],
        });
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    String? error;
    try {
      error = await widget.onSubmit(type, title, data);
    } catch (_) {
      error = 'Chưa lưu được nội dung. Vui lòng thử lại.';
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = error;
    });
    if (error == null && Navigator.canPop(context)) Navigator.pop(context);
  }

  String? _required(String? v) =>
      v == null || v.trim().isEmpty ? 'Vui lòng nhập nội dung.' : null;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _label,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('chat_tool_title'),
              controller: _title,
              enabled: !_saving,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: widget.kind == GroupComposerKind.poll
                    ? 'Câu hỏi'
                    : 'Tiêu đề',
              ),
              validator: _required,
            ),
            if (widget.kind == GroupComposerKind.poll) ...[
              for (var i = 0; i < _options.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextFormField(
                    controller: _options[i],
                    enabled: !_saving,
                    maxLength: 200,
                    decoration: InputDecoration(labelText: 'Lựa chọn ${i + 1}'),
                    validator: _required,
                  ),
                ),
              TextButton.icon(
                onPressed: _saving || _options.length >= 6
                    ? null
                    : () =>
                          setState(() => _options.add(TextEditingController())),
                icon: const Icon(Icons.add),
                label: const Text('Thêm lựa chọn (tối đa 6)'),
              ),
            ],
            if (widget.kind == GroupComposerKind.broadcast)
              TextFormField(
                controller: _body,
                enabled: !_saving,
                minLines: 3,
                maxLines: 6,
                maxLength: 4000,
                decoration: const InputDecoration(
                  labelText: 'Nội dung thông báo',
                ),
                validator: _required,
              ),
            if (_expense) ...[
              TextFormField(
                key: const Key('chat_expense_amount'),
                controller: _amount,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tổng số tiền (VND)',
                ),
                validator: (_) => _vnd == null
                    ? 'Vui lòng nhập số tiền VND nguyên dương hợp lệ.'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _bank,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Ngân hàng nhận'),
                items: banks
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: _saving ? null : (b) => setState(() => _bank = b!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('chat_expense_account'),
                controller: _account,
                enabled: !_saving,
                maxLength: 30,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Số tài khoản nhận',
                ),
                validator: (v) =>
                    RegExp(r'^\d{6,30}$').hasMatch(v?.trim() ?? '')
                    ? null
                    : 'Số tài khoản phải có từ 6 đến 30 chữ số.',
              ),
              TextFormField(
                controller: _name,
                enabled: !_saving,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Tên người nhận'),
                validator: _required,
              ),
              const SizedBox(height: 8),
              Text(
                'Chia đều cho ${widget.participants.length} thành viên đang hoạt động; phần lẻ phân bổ theo mã thành viên. '
                'TripMate không tự chuyển hoặc xác minh tiền trong ngân hàng.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('chat_tool_save'),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Đang lưu…' : 'Gửi vào nhóm'),
            ),
          ],
        ),
      ),
    ),
  );
}
