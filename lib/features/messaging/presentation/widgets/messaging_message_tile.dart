import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/features/messaging/domain/messaging.dart';

class MessagingMessageTile extends StatelessWidget {
  const MessagingMessageTile({
    super.key,
    required this.message,
    required this.thread,
    required this.userId,
    required this.busy,
    required this.onInteract,
    this.onOpenQr,
  });

  final ChatMessage message;
  final ChatThread thread;
  final int userId;
  final bool busy;
  final Future<String?> Function(ChatInteraction action, int? optionIndex)
  onInteract;
  final void Function(ChatMessage message)? onOpenQr;

  bool get _isMine => message.senderUserId == userId;

  @override
  Widget build(BuildContext context) {
    final isStructured = message.type != ChatMessageType.text;
    final align = _isMine && !isStructured
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (!_isMine || isStructured)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
              child: Text(
                _senderHeader(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isStructured
                  ? 520
                  : MediaQuery.sizeOf(context).width * 0.78,
            ),
            child: switch (message.type) {
              ChatMessageType.text => _buildTextCard(context),
              ChatMessageType.poll => _buildPollCard(context),
              ChatMessageType.broadcast => _buildBroadcastCard(context),
              ChatMessageType.rollCall => _buildRollCallCard(context),
              ChatMessageType.splitBill => _buildSplitBillCard(context),
            },
          ),
        ],
      ),
    );
  }

  String _senderHeader() {
    if (thread.kind == ChatKind.group &&
        thread.hostUserId != null &&
        message.senderUserId == thread.hostUserId) {
      return '${message.senderName} · Trưởng nhóm';
    }
    return message.senderName;
  }

  Widget _buildTextCard(BuildContext context) {
    final bg = _isMine ? AppColors.secondary : AppColors.cardBackground;
    final fg = _isMine ? Colors.white : AppColors.ink;
    final metaColor = _isMine ? Colors.white70 : AppColors.muted;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: _isMine ? null : Border.all(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              softWrap: true,
              style: TextStyle(color: fg, fontSize: 14, height: 1.35),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.createdAtUtc),
                  style: TextStyle(color: metaColor, fontSize: 11),
                ),
                if (thread.kind == ChatKind.direct &&
                    _isMine &&
                    message.isReadByOther == true) ...[
                  const SizedBox(width: 6),
                  Text(
                    'Đã xem',
                    style: TextStyle(color: metaColor, fontSize: 11),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPollCard(BuildContext context) {
    final meta = message.metadata;
    final groupState = message.groupState;
    final options = meta?.pollOptions ?? const <String>[];
    final counts = groupState?.pollVoteCounts ?? const <int, int>{};
    final totalVotes = counts.values.fold<int>(0, (sum, c) => sum + c);
    final myVote = groupState?.myPollVoteOption;
    final disabled = busy || thread.isReadOnly;

    return _StructuredCard(
      badgeText: 'BÌNH CHỌN',
      badgeBg: const Color(0xFFE0E7FF),
      badgeFg: const Color(0xFF3730A3),
      title: meta?.title?.trim().isNotEmpty == true
          ? meta!.title!
          : message.content,
      timeLabel: _formatTime(message.createdAtUtc),
      children: [
        for (var i = 0; i < options.length; i++) ...[
          const SizedBox(height: 8),
          InkWell(
            key: Key('vote_${message.id}_$i'),
            onTap: disabled
                ? null
                : () => onInteract(ChatInteraction.vote, myVote == i ? -1 : i),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: myVote == i ? AppColors.primarySoft : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: myVote == i ? AppColors.secondary : AppColors.line,
                  width: myVote == i ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    myVote == i
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: myVote == i ? AppColors.secondary : AppColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      options[i],
                      softWrap: true,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${counts[i] ?? 0} phiếu',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Tổng cộng $totalVotes lượt bình chọn',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    );
  }

  Widget _buildBroadcastCard(BuildContext context) {
    final meta = message.metadata;
    final state = message.groupState;
    final title = meta?.title?.trim().isNotEmpty == true
        ? meta!.title!
        : message.content;
    final body = meta?.content?.trim() ?? '';
    final isReadByMe = state?.isReadByMe ?? false;
    final readCount = state?.readByCount ?? 0;

    return _StructuredCard(
      badgeText: 'THÔNG BÁO NHÓM',
      badgeBg: const Color(0xFFFEE2E2),
      badgeFg: const Color(0xFF991B1B),
      title: title,
      timeLabel: _formatTime(message.createdAtUtc),
      children: [
        if (body.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            body,
            softWrap: true,
            style: const TextStyle(color: AppColors.ink),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.tonal(
              key: Key('ack_${message.id}'),
              onPressed: busy || thread.isReadOnly || isReadByMe
                  ? null
                  : () => onInteract(ChatInteraction.acknowledge, null),
              child: Text(isReadByMe ? 'Đã xác nhận đã đọc' : 'Tôi đã đọc'),
            ),
            Text(
              '$readCount người đã xác nhận',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRollCallCard(BuildContext context) {
    final meta = message.metadata;
    final state = message.groupState;
    final title = meta?.title?.trim().isNotEmpty == true
        ? meta!.title!
        : message.content;
    final isPresent = state?.isPresentByMe ?? false;
    final presentCount = state?.presentCount ?? 0;

    return _StructuredCard(
      badgeText: 'ĐIỂM DANH',
      badgeBg: AppColors.primarySoft,
      badgeFg: AppColors.secondaryDark,
      title: title,
      timeLabel: _formatTime(message.createdAtUtc),
      children: [
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton(
              key: Key('checkin_${message.id}'),
              onPressed: busy || thread.isReadOnly || isPresent
                  ? null
                  : () => onInteract(ChatInteraction.checkin, null),
              child: Text(isPresent ? 'Đã có mặt' : 'Tôi có mặt'),
            ),
            Text(
              '$presentCount người đã có mặt',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSplitBillCard(BuildContext context) {
    final meta = message.metadata;
    final state = message.groupState;
    final shares = meta?.shares ?? const <ChatExpenseShare>[];
    final totalVnd = meta?.totalAmountVnd;
    final hasValidSplit =
        totalVnd != null &&
        totalVnd > 0 &&
        shares.isNotEmpty &&
        (meta?.accountNumber?.trim().isNotEmpty ?? false) &&
        (meta?.bankCode?.trim().isNotEmpty ?? false);

    final paidIds = state?.paidUserIds ?? const <int>[];
    final isPaidByMe = paidIds.contains(userId);
    final myShares = shares.where((s) => s.userId == userId).toList();
    final title = meta?.title?.trim().isNotEmpty == true
        ? meta!.title!
        : message.content;

    return _StructuredCard(
      badgeText: 'CHIA TIỀN (VIETQR)',
      badgeBg: const Color(0xFFDCFCE7),
      badgeFg: const Color(0xFF166534),
      title: title,
      timeLabel: _formatTime(message.createdAtUtc),
      children: [
        const SizedBox(height: 8),
        if (!hasValidSplit)
          const Text(
            'Không có phần chia hợp lệ cho khoản chi này.',
            style: TextStyle(color: AppColors.error, fontSize: 13),
          )
        else ...[
          Text(
            'Tổng chi: ${formatVnd(totalVnd)} · ${shares.length} thành viên',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          if (myShares.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Phần của bạn: ${formatVnd(myShares.first.amountVnd)}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.secondary,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Đã thanh toán: ${paidIds.length}/${shares.length}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: Key('open_qr_${message.id}'),
                onPressed: onOpenQr == null ? null : () => onOpenQr!(message),
                icon: const Icon(Icons.qr_code_2, size: 18),
                label: const Text('Quét VietQR'),
              ),
              FilledButton(
                key: Key('mark_paid_${message.id}'),
                onPressed: busy || thread.isReadOnly || isPaidByMe
                    ? null
                    : () => onInteract(ChatInteraction.togglePayment, null),
                child: Text(
                  isPaidByMe ? 'Đã chuyển tiền' : 'Tôi đã chuyển tiền',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _StructuredCard extends StatelessWidget {
  const _StructuredCard({
    required this.badgeText,
    required this.badgeBg,
    required this.badgeFg,
    required this.title,
    required this.timeLabel,
    required this.children,
  });

  final String badgeText;
  final Color badgeBg;
  final Color badgeFg;
  final String title;
  final String timeLabel;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        color: badgeFg,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  timeLabel,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              softWrap: true,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.ink,
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

String formatVnd(int amount) {
  final raw = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(raw[i]);
  }
  return '$buffer đ';
}

String _formatTime(DateTime utc) {
  final local = utc.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}
