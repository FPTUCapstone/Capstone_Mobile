import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/messaging/domain/messaging.dart';
import 'package:trip_mate_mobile/features/messaging/presentation/cubit/messenger_cubit.dart';
import 'package:trip_mate_mobile/features/messaging/presentation/widgets/chat_composer_sheet.dart';
import 'package:trip_mate_mobile/features/messaging/presentation/widgets/messaging_message_tile.dart';
import 'package:trip_mate_mobile/features/messaging/presentation/widgets/viet_qr_sheet.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/helpers/session_identity_helper.dart';
import 'package:trip_mate_mobile/shared/widgets/error_view.dart';

enum _ThreadFilter { all, group, direct }

/// Resolves the authoritative signed-in user ID before creating a route-scoped [MessengerCubit].
class MessengerRoutePage extends StatefulWidget {
  const MessengerRoutePage({super.key, this.initialGroupId, this.storage});

  final int? initialGroupId;
  final SecureStorageService? storage;

  @override
  State<MessengerRoutePage> createState() => _MessengerRoutePageState();
}

class _MessengerRoutePageState extends State<MessengerRoutePage> {
  late final Future<int?> _userIdFuture =
      SessionIdentityHelper.getCurrentUserId(widget.storage);

  @override
  Widget build(BuildContext context) {
    final role = context.select<AuthSessionCubit, UserRole?>(
      (cubit) => cubit.state.role,
    );

    return FutureBuilder<int?>(
      future: _userIdFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final userId = snapshot.data;
        if (userId == null || userId <= 0) {
          return Scaffold(
            appBar: AppBar(title: const Text('Tin nhắn')),
            body: ErrorView(
              message:
                  'Phiên đăng nhập không hợp lệ hoặc đã hết hạn. Vui lòng đăng nhập lại.',
              retryLabel: 'Đăng nhập',
              onRetry: () {
                final router = GoRouter.maybeOf(context);
                if (router != null) {
                  router.go(AppRoutes.login);
                }
              },
            ),
          );
        }

        return BlocProvider<MessengerCubit>(
          key: ValueKey(userId),
          create: (_) =>
              serviceLocator<MessengerCubit>(param1: userId)
                ..initialize(initialGroupId: widget.initialGroupId),
          child: MessengerPage(
            userId: userId,
            userRole: role,
            initialGroupId: widget.initialGroupId,
          ),
        );
      },
    );
  }
}

class MessengerPage extends StatefulWidget {
  const MessengerPage({
    super.key,
    required this.userId,
    this.userRole,
    this.displayName = 'Bạn',
    this.initialGroupId,
  });

  final int userId;
  final UserRole? userRole;
  final String displayName;
  final int? initialGroupId;

  @override
  State<MessengerPage> createState() => _MessengerPageState();
}

class _MessengerPageState extends State<MessengerPage>
    with WidgetsBindingObserver {
  final _threadSearchController = TextEditingController();
  final _messageSearchController = TextEditingController();
  final _draftController = TextEditingController();
  final _scrollController = ScrollController();
  String? _scrolledThreadKey;

  _ThreadFilter _filter = _ThreadFilter.all;
  String _threadQuery = '';
  String _messageQuery = '';
  bool _showMessageSearch = false;
  late bool _showThreadOnlyOnMobile = widget.initialGroupId != null;

  MessengerCubit get _cubit => context.read<MessengerCubit>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _threadSearchController.dispose();
    _messageSearchController.dispose();
    _draftController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    unawaited(_cubit.setAppActive(active));
  }

  List<ChatThread> _filteredThreads(List<ChatThread> all) {
    final q = _threadQuery.trim().toLowerCase();
    return all.where((t) {
      final matchesFilter = switch (_filter) {
        _ThreadFilter.all => true,
        _ThreadFilter.group => t.kind == ChatKind.group,
        _ThreadFilter.direct => t.kind == ChatKind.direct,
      };
      if (!matchesFilter) return false;
      if (q.isEmpty) return true;
      return t.title.toLowerCase().contains(q) ||
          (t.lastMessage?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<ChatMessage> _filteredMessages(List<ChatMessage> all) {
    final q = _messageQuery.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((m) => m.content.toLowerCase().contains(q)).toList();
  }

  bool _canManageNotices(ChatThread selected) {
    return widget.userRole == UserRole.tourOperator ||
        (selected.kind == ChatKind.group &&
            selected.hostUserId == widget.userId);
  }

  String _currentSenderName(MessengerState state) {
    for (final m in state.members) {
      if (m.userId == widget.userId && m.displayName.trim().isNotEmpty) {
        return m.displayName;
      }
    }
    return widget.displayName;
  }

  Future<void> _openNewDirectDialog() async {
    _cubit.cancelContactSearch();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => BlocProvider.value(
        value: _cubit,
        child: _NewDirectSheet(
          onSelectUser: (user) async {
            final thread = await _cubit.openDirect(user.userId);
            if (!mounted || thread == null) return;
            await _cubit.select(thread);
            if (!mounted) return;
            if (sheetContext.mounted && Navigator.canPop(sheetContext)) {
              Navigator.pop(sheetContext);
            }
            setState(() {
              _showThreadOnlyOnMobile = true;
              _messageQuery = '';
              _showMessageSearch = false;
            });
          },
        ),
      ),
    );
  }

  void _openToolsMenu(MessengerState state) {
    final selected = state.selected;
    if (selected == null ||
        selected.kind != ChatKind.group ||
        state.blocked ||
        state.busy) {
      return;
    }
    final canManage = _canManageNotices(selected);

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const Key('tool_create_poll'),
                leading: const Icon(Icons.poll_outlined),
                title: const Text('Tạo bình chọn'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openComposerSheet(state, GroupComposerKind.poll);
                },
              ),
              ListTile(
                key: const Key('tool_create_expense'),
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('Chia tiền (VietQR)'),
                enabled: state.members.isNotEmpty,
                subtitle: state.members.isEmpty
                    ? const Text('Đang tải danh sách thành viên…')
                    : null,
                onTap: state.members.isEmpty
                    ? null
                    : () {
                        Navigator.pop(sheetContext);
                        _openComposerSheet(state, GroupComposerKind.splitBill);
                      },
              ),
              if (canManage) ...[
                ListTile(
                  key: const Key('tool_create_broadcast'),
                  leading: const Icon(Icons.campaign_outlined),
                  title: const Text('Phát thông báo nhóm'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openComposerSheet(state, GroupComposerKind.broadcast);
                  },
                ),
                ListTile(
                  key: const Key('tool_create_roll_call'),
                  leading: const Icon(Icons.how_to_reg_outlined),
                  title: const Text('Tạo điểm danh'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openComposerSheet(state, GroupComposerKind.rollCall);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openGroupDetails(ChatThread selected) async {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    await router.push('${AppRoutes.travelerTravelGroups}/${selected.id}');
    if (!mounted) return;
    await _cubit.refresh();
    final updated = _cubit.state.selected;
    if (mounted &&
        updated != null &&
        updated.kind == ChatKind.group &&
        !updated.isReadOnly) {
      unawaited(_cubit.select(updated));
    }
  }

  void _openComposerSheet(MessengerState state, GroupComposerKind kind) {
    final participants = state.members
        .map<ChatParticipant>(
          (m) => (userId: m.userId, displayName: m.displayName),
        )
        .toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChatComposerSheet(
        kind: kind,
        participants: participants,
        senderName: _currentSenderName(state),
        onSubmit: (typeName, content, rawMeta) async {
          final msgType = switch (typeName) {
            'poll' => ChatMessageType.poll,
            'broadcast' => ChatMessageType.broadcast,
            'roll_call' => ChatMessageType.rollCall,
            'split_bill' => ChatMessageType.splitBill,
            _ => ChatMessageType.text,
          };
          final metadata = _mapComposerMetadata(msgType, rawMeta);
          final ok = await _cubit.send(msgType, content, metadata);
          if (ok) return null;
          return _cubit.state.error ??
              'Chưa lưu được nội dung. Vui lòng thử lại.';
        },
      ),
    );
  }

  ChatMetadata _mapComposerMetadata(
    ChatMessageType type,
    Map<String, Object?> raw,
  ) {
    final pollOptions = switch (raw['options']) {
      final List<dynamic> list =>
        list
            .whereType<Map>()
            .map((item) => item['text']?.toString() ?? '')
            .where((t) => t.trim().isNotEmpty)
            .toList(),
      _ => const <String>[],
    };
    final shares = switch (raw['participants']) {
      final List<dynamic> list => list.whereType<Map>().map((item) {
        return ChatExpenseShare(
          userId: item['userId'] as int,
          displayName: item['displayName'] as String,
          amountVnd: item['amount'] as int,
        );
      }).toList(),
      _ => const <ChatExpenseShare>[],
    };
    return ChatMetadata(
      pollOptions: pollOptions,
      totalAmountVnd: raw['totalAmount'] as int?,
      shares: shares,
      bankCode: raw['payerBankName'] as String?,
      accountNumber: raw['payerBankAccount'] as String?,
      accountName: raw['payerName'] as String?,
      title: raw['title'] as String?,
      content: raw['content'] as String?,
    );
  }

  void _openVietQrSheet(ChatMessage message, bool readOnly) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => VietQrSheet(
        message: message,
        userId: widget.userId,
        readOnly: readOnly,
        onMarkPaid: () async {
          final ok = await _cubit.interact(
            message,
            ChatInteraction.togglePayment,
            isPaid: true,
          );
          if (ok) return null;
          return _cubit.state.error ??
              'Không thể cập nhật trạng thái thanh toán.';
        },
      ),
    );
  }

  Future<void> _sendTextDraft() async {
    final text = _draftController.text;
    final ok = await _cubit.send(ChatMessageType.text, text);
    if (ok && mounted) {
      _draftController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        unawaited(
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MessengerCubit, MessengerState>(
      listenWhen: (prev, curr) =>
          prev.selected?.key != curr.selected?.key ||
          prev.draft != curr.draft ||
          (prev.loadingMessages && !curr.loadingMessages),
      listener: (context, state) {
        if (_draftController.text != state.draft) {
          _draftController.value = TextEditingValue(
            text: state.draft,
            selection: TextSelection.collapsed(offset: state.draft.length),
          );
        }
        if (!state.loadingMessages &&
            state.selected != null &&
            state.messages.isNotEmpty &&
            _scrolledThreadKey != state.selected!.key) {
          _scrolledThreadKey = state.selected!.key;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _scrollController.hasClients) {
              _scrollController.jumpTo(0);
            }
          });
        }
      },
      builder: (context, state) {
        if (state.needsSignIn) {
          return Scaffold(
            appBar: AppBar(title: const Text('Tin nhắn')),
            body: ErrorView(
              message:
                  state.error ??
                  'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
              retryLabel: 'Đăng nhập lại',
              onRetry: () {
                final router = GoRouter.maybeOf(context);
                if (router != null) {
                  router.go(AppRoutes.login);
                }
              },
            ),
          );
        }

        final isWide = MediaQuery.sizeOf(context).width >= 760;
        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: 340,
                  child: _buildListPane(state, isSplitView: true),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _buildThreadPane(state, isSplitView: true)),
              ],
            ),
          );
        }

        return _showThreadOnlyOnMobile
            ? _buildThreadPane(state, isSplitView: false)
            : _buildListPane(state, isSplitView: false);
      },
    );
  }

  Widget _buildListPane(MessengerState state, {required bool isSplitView}) {
    final threads = _filteredThreads(state.threads);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        automaticallyImplyLeading: !isSplitView,
        title: const Text('Tin nhắn'),
        backgroundColor: AppColors.cardBackground,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppColors.line),
        ),
        actions: [
          IconButton(
            key: const Key('new_dm_button'),
            tooltip: 'Cuộc trò chuyện mới',
            icon: const Icon(Icons.edit_square),
            onPressed: _openNewDirectDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.cardBackground,
              border: Border(bottom: BorderSide(color: AppColors.line)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  child: TextField(
                    key: const Key('thread_search_input'),
                    controller: _threadSearchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 20),
                      hintText: 'Tìm hội thoại đã tải…',
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.line),
                      ),
                    ),
                    onChanged: (value) => setState(() => _threadQuery = value),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
                    child: Row(
                      children: [
                        for (final item in const [
                          (_ThreadFilter.all, 'Tất cả'),
                          (_ThreadFilter.group, 'Nhóm'),
                          (_ThreadFilter.direct, 'Riêng tư'),
                        ]) ...[
                          ChoiceChip(
                            label: Text(item.$2),
                            selected: _filter == item.$1,
                            onSelected: (_) =>
                                setState(() => _filter = item.$1),
                          ),
                          if (item.$1 != _ThreadFilter.direct)
                            const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (state.listError != null)
            MaterialBanner(
              content: Text(state.listError!),
              actions: [
                TextButton(
                  onPressed: () => unawaited(_cubit.refresh()),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          Expanded(
            child: state.loading && state.threads.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _cubit.refresh,
                    child: threads.isEmpty
                        ? ListView(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  _threadQuery.trim().isNotEmpty
                                      ? 'Không tìm thấy hội thoại phù hợp.'
                                      : 'Chưa có cuộc trò chuyện. Tham gia nhóm hoặc bắt đầu tin nhắn riêng.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            itemCount:
                                threads.length + (state.hasMoreThreads ? 1 : 0),
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              if (index >= threads.length) {
                                return Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: OutlinedButton(
                                    onPressed: state.loadingMoreThreads
                                        ? null
                                        : () => unawaited(
                                            _cubit.loadMoreThreads(),
                                          ),
                                    child: Text(
                                      state.loadingMoreThreads
                                          ? 'Đang tải…'
                                          : 'Tải thêm hội thoại',
                                    ),
                                  ),
                                );
                              }
                              final t = threads[index];
                              final selected = state.selected?.key == t.key;
                              return ListTile(
                                key: Key('thread_${t.key}'),
                                tileColor: selected
                                    ? AppColors.primarySoft
                                    : AppColors.cardBackground,
                                selected: selected,
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primarySoft,
                                  child: Icon(
                                    t.kind == ChatKind.direct
                                        ? Icons.person_outline
                                        : Icons.groups_outlined,
                                    color: AppColors.primary,
                                  ),
                                ),
                                title: Text(
                                  t.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                                ),
                                subtitle: Text(
                                  '${t.lastMessage ?? 'Chưa có tin nhắn'}${t.isReadOnly ? ' · Đã đóng' : ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                  ),
                                ),
                                trailing: t.unreadCount > 0
                                    ? Badge.count(
                                        count: t.unreadCount,
                                        backgroundColor: AppColors.accent,
                                      )
                                    : null,
                                onTap: () {
                                  unawaited(_cubit.select(t));
                                  setState(() {
                                    _showThreadOnlyOnMobile = true;
                                    _messageQuery = '';
                                    _showMessageSearch = false;
                                  });
                                },
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadPane(MessengerState state, {required bool isSplitView}) {
    final selected = state.selected;
    if (selected == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Chọn một cuộc trò chuyện để xem tin nhắn.',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }

    final messages = _filteredMessages(state.messages);
    final cannotSend = selected.isReadOnly || state.blocked;
    final canOpenGroupDetails =
        selected.kind == ChatKind.group && !selected.isReadOnly;
    final memberCount = state.members.isNotEmpty
        ? state.members.length
        : (selected.memberCount ?? 0);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppColors.line),
        ),
        leading: isSplitView
            ? null
            : IconButton(
                key: const Key('back_to_threads_button'),
                tooltip: 'Quay lại danh sách',
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (widget.initialGroupId != null &&
                      Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    setState(() => _showThreadOnlyOnMobile = false);
                  }
                },
              ),
        title: canOpenGroupDetails
            ? InkWell(
                key: const Key('group_chat_header_button'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => unawaited(_openGroupDetails(selected)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$memberCount thành viên',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.chevron_right,
                            size: 15,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selected.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    selected.kind == ChatKind.group
                        ? '$memberCount thành viên'
                        : 'Tin nhắn riêng 1–1',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
        actions: [
          if (canOpenGroupDetails)
            IconButton(
              key: const Key('open_group_details_button'),
              tooltip: 'Thông tin & thành viên nhóm',
              icon: const Icon(Icons.group_outlined),
              onPressed: () => unawaited(_openGroupDetails(selected)),
            ),
          if (!isSplitView && widget.initialGroupId != null)
            IconButton(
              tooltip: 'Danh sách hội thoại',
              icon: const Icon(Icons.forum_outlined),
              onPressed: () => setState(() => _showThreadOnlyOnMobile = false),
            ),
          IconButton(
            key: const Key('toggle_message_search_button'),
            tooltip: 'Tìm tin nhắn',
            icon: Icon(_showMessageSearch ? Icons.search_off : Icons.search),
            onPressed: () => setState(() {
              _showMessageSearch = !_showMessageSearch;
              if (!_showMessageSearch) {
                _messageSearchController.clear();
                _messageQuery = '';
              }
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showMessageSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                key: const Key('message_search_input'),
                controller: _messageSearchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Tìm trong các tin đã tải…',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _messageQuery = v),
              ),
            ),
          if (selected.isReadOnly)
            Container(
              width: double.infinity,
              color: AppColors.primarySoft,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: const Text(
                'Nhóm đã đóng. Bạn chỉ có thể xem lịch sử.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          if (state.error != null)
            Container(
              width: double.infinity,
              color: const Color(0xFFFEE2E2),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      state.error!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => unawaited(_cubit.select(selected)),
                    child: const Text('Tải lại'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: state.loadingMessages && state.messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                ? Center(
                    child: Text(
                      _messageQuery.trim().isNotEmpty
                          ? 'Không có tin nhắn phù hợp trong các tin đã tải.'
                          : 'Chưa có tin nhắn. Hãy bắt đầu cuộc trò chuyện.',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: messages.length + (state.hasOlder ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (state.hasOlder && index == messages.length) {
                        return Padding(
                          padding: const EdgeInsets.all(8),
                          child: Center(
                            child: OutlinedButton(
                              onPressed: state.loadingOlder
                                  ? null
                                  : () => unawaited(_cubit.loadOlder()),
                              child: Text(
                                state.loadingOlder
                                    ? 'Đang tải…'
                                    : 'Tải tin nhắn trước',
                              ),
                            ),
                          ),
                        );
                      }
                      final msg = messages[messages.length - 1 - index];
                      return MessagingMessageTile(
                        message: msg,
                        thread: selected,
                        userId: widget.userId,
                        busy: state.busy,
                        onOpenQr: (m) =>
                            _openVietQrSheet(m, selected.isReadOnly),
                        onInteract: (action, optionIndex) async {
                          final ok = await _cubit.interact(
                            msg,
                            action,
                            optionIndex: optionIndex,
                            isPaid: action == ChatInteraction.togglePayment
                                ? true
                                : null,
                          );
                          if (ok) return null;
                          return _cubit.state.error ??
                              'Không thể hoàn tất thao tác.';
                        },
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Row(
                  children: [
                    if (selected.kind == ChatKind.group)
                      IconButton(
                        key: const Key('chat_tools_button'),
                        tooltip: 'Thêm tiện ích',
                        onPressed: state.busy || cannotSend
                            ? null
                            : () => _openToolsMenu(state),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    Expanded(
                      child: TextField(
                        key: const Key('chat_draft_input'),
                        controller: _draftController,
                        enabled: !cannotSend,
                        maxLength: 4000,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Nhập tin nhắn...',
                          counterText: '',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: _cubit.setDraft,
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      key: const Key('chat_send_button'),
                      tooltip: 'Gửi tin nhắn',
                      onPressed:
                          cannotSend ||
                              state.busy ||
                              state.loadingMessages ||
                              _draftController.text.trim().isEmpty
                          ? null
                          : _sendTextDraft,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewDirectSheet extends StatefulWidget {
  const _NewDirectSheet({required this.onSelectUser});

  final Future<void> Function(ChatUser user) onSelectUser;

  @override
  State<_NewDirectSheet> createState() => _NewDirectSheetState();
}

class _NewDirectSheetState extends State<_NewDirectSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  bool _opening = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        unawaited(context.read<MessengerCubit>().searchUsers(value));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: BlocBuilder<MessengerCubit, MessengerState>(
          builder: (context, state) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Cuộc trò chuyện mới',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('dm_user_search_input'),
                  controller: _controller,
                  enabled: !_opening,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Nhập ít nhất 2 ký tự tên…',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: _onQueryChanged,
                ),
                const SizedBox(height: 8),
                if (state.searching)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (state.searchError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      state.searchError!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  )
                else if (_controller.text.trim().length >= 2 &&
                    state.searchResults.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Không tìm thấy người dùng phù hợp.'),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: state.searchResults.length,
                      itemBuilder: (context, index) {
                        final user = state.searchResults[index];
                        return ListTile(
                          key: Key('dm_user_${user.userId}'),
                          leading: const CircleAvatar(
                            child: Icon(Icons.person_outline),
                          ),
                          title: Text(user.displayName),
                          trailing: const Text('Nhắn tin'),
                          onTap: _opening
                              ? null
                              : () async {
                                  setState(() => _opening = true);
                                  try {
                                    await widget.onSelectUser(user);
                                  } finally {
                                    if (mounted) {
                                      setState(() => _opening = false);
                                    }
                                  }
                                },
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
