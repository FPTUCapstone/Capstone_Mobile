import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/support_chat/domain/entities/support_chat.dart';
import 'package:trip_mate_mobile/features/support_chat/presentation/cubit/support_chat_cubit.dart';
import 'package:trip_mate_mobile/features/support_chat/presentation/support_chat_navigation.dart';

class SupportChatPage extends StatefulWidget {
  const SupportChatPage({super.key});

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> {
  final _message = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _message.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final cubit = context.read<SupportChatCubit>();
    if (cubit.state.loading || _message.text.trim().isEmpty) return;
    final text = _message.text;
    unawaited(cubit.send(text));
    if (text.length <= 2000) _message.clear();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      unawaited(
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  void _performAction(SupportChatAction action) {
    final cubit = context.read<SupportChatCubit>();
    if (cubit.state.loading || !cubit.hasAction(action)) return;
    if (action.type == SupportChatActionType.selectContext) {
      unawaited(cubit.performAction(action));
      return;
    }
    final location = SupportChatNavigation.locationFor(action.url ?? '');
    if (location == null) return;
    FocusScope.of(context).unfocus();
    context.push(location);
  }

  Widget? _actionButton(SupportChatAction action, SupportChatState state) {
    final location = action.type == SupportChatActionType.navigate
        ? SupportChatNavigation.locationFor(action.url ?? '')
        : null;
    if (action.type == SupportChatActionType.navigate && location == null) {
      return null;
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.all(AppSpacing.md),
            minimumSize: const Size.fromHeight(56),
            side: const BorderSide(color: AppColors.line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: state.loading ? null : () => _performAction(action),
          child: Semantics(
            label: action.label,
            hint: action.description,
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  action.label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(height: 1.35),
                ),
                if (action.description case final description?)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxs),
                    child: Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                        height: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _actions(
    List<SupportChatAction> actions,
    SupportChatState state,
  ) {
    final widgets = <Widget>[];
    for (var index = 0; index < actions.length; index++) {
      final action = actions[index];
      final next = index + 1 < actions.length ? actions[index + 1] : null;
      if (action.type == SupportChatActionType.selectContext &&
          action.context?.kind == 'tour' &&
          action.context!.isValid &&
          next?.type == SupportChatActionType.navigate &&
          next?.url == '/tours/${action.context!.id}') {
        widgets.add(_tourCard(action, next!, state));
        index++;
      } else {
        final button = _actionButton(action, state);
        if (button != null) widgets.add(button);
      }
    }
    return widgets;
  }

  Widget _tourCard(
    SupportChatAction choice,
    SupportChatAction navigation,
    SupportChatState state,
  ) => Container(
    key: ValueKey('support-tour-${choice.context!.id}'),
    width: double.infinity,
    margin: const EdgeInsets.only(top: AppSpacing.sm),
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.cardBackground,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            choice.label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (choice.description case final description?) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.muted,
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xxs,
          children: [
            TextButton.icon(
              onPressed: state.loading ? null : () => _performAction(choice),
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('Hỏi về tour'),
            ),
            TextButton.icon(
              onPressed: state.loading
                  ? null
                  : () => _performAction(navigation),
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Xem tour'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _messageBubble(SupportChatMessage entry) {
    final isUser = entry.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: isUser ? null : double.infinity,
        constraints: isUser
            ? BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .84)
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.cardBackground,
          border: Border.all(
            color: isUser ? AppColors.primary : AppColors.line,
          ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isUser ? 'Bạn' : 'Hỗ trợ TripMate',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isUser
                    ? Colors.white.withValues(alpha: 0.78)
                    : AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            SelectableText(
              entry.content,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 14.5,
                height: 1.5,
                color: isUser ? Colors.white : AppColors.ink,
              ),
            ),
            if (entry.sources.isNotEmpty)
              ExpansionTile(
                title: Text(
                  'Nguồn tham khảo (${entry.sources.length})',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isUser ? Colors.white70 : AppColors.muted,
                  ),
                ),
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                shape: const Border(),
                collapsedShape: const Border(),
                children: [
                  for (final source in entry.sources)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Text(
                          source.title,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: isUser ? Colors.white : AppColors.muted,
                              ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _contextKindLabel(String? kind) => switch (kind) {
    'tour' => 'tour',
    'refund' => 'hoàn tiền',
    'itinerary' => 'lịch trình',
    'booking' => 'đơn đặt tour',
    _ => kind ?? '',
  };

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<SupportChatCubit, SupportChatState>(
    listener: (_, state) {
      if (state.messages.isEmpty && state.failure == null) _message.clear();
      _scrollToLatest();
    },
    builder: (context, state) {
      final cubit = context.read<SupportChatCubit>();
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: const Text('Trò chuyện hỗ trợ'),
          backgroundColor: AppColors.cardBackground,
          surfaceTintColor: Colors.transparent,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, thickness: 1, color: AppColors.line),
          ),
          actions: [
            IconButton(
              tooltip: 'Xóa cuộc trò chuyện',
              onPressed: cubit.reset,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (state.context != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 4,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    border: Border(bottom: BorderSide(color: AppColors.line)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.link_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Đang chọn ${_contextKindLabel(state.context?.kind)} #${state.context?.id}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      if (state.context != null)
                        IconButton(
                          tooltip: 'Xóa ngữ cảnh',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => cubit.selectContext(null),
                          icon: const Icon(
                            Icons.close,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              if (state.loading)
                Semantics(
                  label: 'Hỗ trợ đang phản hồi',
                  liveRegion: true,
                  child: const LinearProgressIndicator(),
                ),
              Expanded(
                child: ListView(
                  controller: _scroll,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    if (state.messages.isEmpty && state.failure == null)
                      Container(
                        margin: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: const BoxDecoration(
                                color: AppColors.primarySoft,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.support_agent_rounded,
                                size: 28,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'TripMate có thể giúp gì cho bạn?',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            const Text(
                              'Hãy hỏi về tour, đơn đặt tour, hoàn tiền hoặc lịch trình.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: AppColors.muted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    for (final entry in state.messages)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Semantics(
                          container: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _messageBubble(entry),
                              ..._actions(entry.actions, state),
                            ],
                          ),
                        ),
                      ),
                    if (state.failure case final failure?)
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDEEEF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                failure.message,
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 13.5,
                                ),
                              ),
                              if (state.canRetry)
                                TextButton(
                                  onPressed: cubit.retry,
                                  child: const Text('Thử lại'),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColors.cardBackground,
                  border: Border(top: BorderSide(color: AppColors.line)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _message,
                          decoration: const InputDecoration(
                            labelText: 'Tin nhắn',
                            filled: true,
                            fillColor: AppColors.surface,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(20),
                              ),
                            ),
                          ),
                          minLines: 1,
                          maxLines: 3,
                          maxLength: 2000,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          enabled: !state.loading,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: IconButton.filled(
                          tooltip: 'Gửi tin nhắn',
                          onPressed: state.loading ? null : _send,
                          icon: const Icon(Icons.send_rounded, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
