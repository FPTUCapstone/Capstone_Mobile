import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';

enum ChatMessageType {
  text,
  broadcast,
  rollCall,
  splitBill,
  poll,
  meetingPoint,
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.isCurrentUser,
    required this.text,
    required this.timestamp,
    required this.type,
    this.senderRole = 'member',
    this.metadata = const {},
  });

  final String id;
  final int senderId;
  final String senderName;
  final bool isCurrentUser;
  final String text;
  final DateTime timestamp;
  final ChatMessageType type;
  final String senderRole; // 'guide', 'host', 'member'
  Map<String, dynamic> metadata;
}

class TravelGroupChatPage extends StatefulWidget {
  const TravelGroupChatPage({
    super.key,
    required this.groupId,
    this.group,
    this.currentUserId = 1,
    this.currentUserName = 'Bạn',
  });

  final int groupId;
  final TravelGroup? group;
  final int currentUserId;
  final String currentUserName;

  @override
  State<TravelGroupChatPage> createState() => _TravelGroupChatPageState();
}

class _TravelGroupChatPageState extends State<TravelGroupChatPage> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isSearching = false;
  String _searchQuery = '';
  bool _isPinnedDismissed = false;

  late List<ChatMessage> _messages;

  @override
  void initState() {
    super.initState();
    _initSeedMessages();
  }

  @override
  void dispose() {
    _textController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initSeedMessages() {
    final now = DateTime.now();
    _messages = [
      ChatMessage(
        id: 'msg-1',
        senderId: 99,
        senderName: 'Nguyễn Tuấn (HDV)',
        senderRole: 'guide',
        isCurrentUser: false,
        text: 'Chào mừng cả đoàn đến với hành trình Đà Nẵng - Hội An! Mọi người có mặt đầy đủ vui lòng đọc thông báo bên dưới nhé.',
        timestamp: now.subtract(const Duration(hours: 3)),
        type: ChatMessageType.text,
      ),
      ChatMessage(
        id: 'msg-2',
        senderId: 99,
        senderName: 'Nguyễn Tuấn (HDV)',
        senderRole: 'guide',
        isCurrentUser: false,
        text: '',
        timestamp: now.subtract(const Duration(hours: 2, minutes: 45)),
        type: ChatMessageType.broadcast,
        metadata: {
          'title': 'THÔNG BÁO TẬP TRUNG SÁNG MAI',
          'content': 'Xe đón đoàn lúc 07:30 tại sảnh Khách sạn Mường Thanh. Xin vui lòng ăn sáng sớm và mang theo mũ, kem chống nắng.',
          'urgent': true,
          'readByCount': 3,
          'totalMembers': 4,
          'isReadByMe': false,
        },
      ),
      ChatMessage(
        id: 'msg-3',
        senderId: 99,
        senderName: 'Nguyễn Tuấn (HDV)',
        senderRole: 'guide',
        isCurrentUser: false,
        text: '',
        timestamp: now.subtract(const Duration(hours: 2, minutes: 30)),
        type: ChatMessageType.rollCall,
        metadata: {
          'title': 'Điểm danh: Tập trung xe buýt số 1',
          'deadline': '07:45 hôm nay',
          'presentCount': 3,
          'totalMembers': 4,
          'isPresent': false,
        },
      ),
      ChatMessage(
        id: 'msg-4',
        senderId: 2,
        senderName: 'Hoàng Minh',
        senderRole: 'member',
        isCurrentUser: false,
        text: 'Em vừa đến khách sạn rồi ạ, sảnh đẹp quá cả nhà ơi!',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 15)),
        type: ChatMessageType.text,
      ),
      ChatMessage(
        id: 'msg-5',
        senderId: 1,
        senderName: widget.currentUserName,
        senderRole: 'member',
        isCurrentUser: true,
        text: 'Mình cũng vừa check-in xong, hẹn gặp mọi người lát nữa!',
        timestamp: now.subtract(const Duration(minutes: 50)),
        type: ChatMessageType.text,
      ),
      ChatMessage(
        id: 'msg-6',
        senderId: 3,
        senderName: 'Lê Hương (Trưởng nhóm)',
        senderRole: 'host',
        isCurrentUser: false,
        text: '',
        timestamp: now.subtract(const Duration(minutes: 35)),
        type: ChatMessageType.splitBill,
        metadata: {
          'title': 'Tiền ăn trưa Bánh tráng cuốn thịt heo Đại Lộc',
          'totalAmount': 600000,
          'currency': 'VND',
          'perPersonAmount': 150000,
          'paidCount': 2,
          'totalPersons': 4,
          'bankName': 'MB Bank',
          'accountNumber': '0987654321',
          'accountName': 'LE THI HUONG',
          'isPaidByMe': false,
        },
      ),
      ChatMessage(
        id: 'msg-7',
        senderId: 2,
        senderName: 'Hoàng Minh',
        senderRole: 'member',
        isCurrentUser: false,
        text: '',
        timestamp: now.subtract(const Duration(minutes: 20)),
        type: ChatMessageType.poll,
        metadata: {
          'question': 'Tối nay cả nhóm mình đi ăn gì ở Phố cổ Hội An?',
          'options': [
            {'text': 'Cao lầu Bà Bé & Chè Hội An', 'votes': 2},
            {'text': 'Cơm gà Bà Buội', 'votes': 1},
            {'text': 'Bánh mì Phượng + Dạo thuyền đèn hoa đăng', 'votes': 1},
          ],
          'myVoteIndex': -1,
        },
      ),
    ];
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(
        ChatMessage(
          id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
          senderId: widget.currentUserId,
          senderName: widget.currentUserName,
          isCurrentUser: true,
          text: text,
          timestamp: DateTime.now(),
          type: ChatMessageType.text,
        ),
      );
      _textController.clear();
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatCurrency(int amount) {
    final buffer = StringBuffer();
    final str = amount.toString();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return '${buffer.toString()} đ';
  }

  void _openActionDrawer() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Tiện ích nhóm du lịch',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  key: const Key('action_create_poll'),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE0E7FF),
                    child: Icon(Icons.poll_rounded, color: Color(0xFF4338CA)),
                  ),
                  title: const Text('Tạo bình chọn (Voting)'),
                  subtitle: const Text('Bình chọn điểm đến, quán ăn, lịch trình'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showCreatePollDialog();
                  },
                ),
                ListTile(
                  key: const Key('action_create_expense'),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFDCFCE7),
                    child: Icon(Icons.receipt_long_rounded, color: Color(0xFF15803D)),
                  ),
                  title: const Text('Chia tiền hóa đơn (VietQR)'),
                  subtitle: const Text('Tự động chia đều và tạo mã thanh toán VietQR'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showCreateExpenseDialog();
                  },
                ),
                ListTile(
                  key: const Key('action_create_broadcast'),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFEE2E2),
                    child: Icon(Icons.campaign_rounded, color: Color(0xFFB91C1C)),
                  ),
                  title: const Text('Thông báo khẩn (Dành cho HDV)'),
                  subtitle: const Text('Gửi thông báo có xác nhận "Tôi đã đọc"'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showCreateBroadcastDialog();
                  },
                ),
                ListTile(
                  key: const Key('action_create_roll_call'),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE6F4F1),
                    child: Icon(Icons.how_to_reg_rounded, color: AppColors.secondary),
                  ),
                  title: const Text('Điểm danh đoàn (Dành cho HDV)'),
                  subtitle: const Text('Kiểm tra danh sách thành viên có mặt'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showCreateRollCallDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCreatePollDialog() {
    final questionController = TextEditingController();
    final option1Controller = TextEditingController();
    final option2Controller = TextEditingController();
    final option3Controller = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Tạo bình chọn mới'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('poll_question_input'),
                controller: questionController,
                decoration: const InputDecoration(
                  labelText: 'Câu hỏi bình chọn *',
                  hintText: 'Ví dụ: Tối nay ăn gì ở Hội An?',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('poll_option_1_input'),
                controller: option1Controller,
                decoration: const InputDecoration(
                  labelText: 'Lựa chọn 1 *',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('poll_option_2_input'),
                controller: option2Controller,
                decoration: const InputDecoration(
                  labelText: 'Lựa chọn 2 *',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('poll_option_3_input'),
                controller: option3Controller,
                decoration: const InputDecoration(
                  labelText: 'Lựa chọn 3 (không bắt buộc)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('submit_poll_button'),
            onPressed: () {
              final question = questionController.text.trim();
              final opt1 = option1Controller.text.trim();
              final opt2 = option2Controller.text.trim();
              final opt3 = option3Controller.text.trim();

              if (question.isEmpty || opt1.isEmpty || opt2.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng nhập câu hỏi và ít nhất 2 lựa chọn.'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              final optionsList = [
                {'text': opt1, 'votes': 0},
                {'text': opt2, 'votes': 0},
              ];
              if (opt3.isNotEmpty) {
                optionsList.add({'text': opt3, 'votes': 0});
              }

              setState(() {
                _messages.add(
                  ChatMessage(
                    id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
                    senderId: widget.currentUserId,
                    senderName: widget.currentUserName,
                    isCurrentUser: true,
                    text: '',
                    timestamp: DateTime.now(),
                    type: ChatMessageType.poll,
                    metadata: {
                      'question': question,
                      'options': optionsList,
                      'myVoteIndex': -1,
                    },
                  ),
                );
              });

              Navigator.pop(dialogCtx);
              _scrollToBottom();
            },
            child: const Text('Tạo bình chọn'),
          ),
        ],
      ),
    );
  }

  void _showCreateExpenseDialog() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final bankController = TextEditingController(text: 'MB Bank');
    final accountController = TextEditingController(text: '0987654321');
    final nameController = TextEditingController(text: widget.currentUserName.toUpperCase());

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Chia tiền chi tiêu (VietQR)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('expense_title_input'),
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Nội dung chi tiêu *',
                  hintText: 'Ví dụ: Tiền taxi, Tiền ăn tối',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('expense_amount_input'),
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tổng số tiền (VND) *',
                  hintText: 'Ví dụ: 600000',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bankController,
                decoration: const InputDecoration(labelText: 'Ngân hàng nhận tiền'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: accountController,
                decoration: const InputDecoration(labelText: 'Số tài khoản'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('submit_expense_button'),
            onPressed: () {
              final title = titleController.text.trim();
              final amount = int.tryParse(amountController.text.trim()) ?? 0;

              if (title.isEmpty || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng nhập nội dung và số tiền hợp lệ (> 0).'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              const totalMembers = 4;
              final perPerson = (amount / totalMembers).round();

              setState(() {
                _messages.add(
                  ChatMessage(
                    id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
                    senderId: widget.currentUserId,
                    senderName: widget.currentUserName,
                    isCurrentUser: true,
                    text: '',
                    timestamp: DateTime.now(),
                    type: ChatMessageType.splitBill,
                    metadata: {
                      'title': title,
                      'totalAmount': amount,
                      'currency': 'VND',
                      'perPersonAmount': perPerson,
                      'paidCount': 1,
                      'totalPersons': totalMembers,
                      'bankName': bankController.text.trim(),
                      'accountNumber': accountController.text.trim(),
                      'accountName': nameController.text.trim(),
                      'isPaidByMe': true,
                    },
                  ),
                );
              });

              Navigator.pop(dialogCtx);
              _scrollToBottom();
            },
            child: const Text('Chia tiền'),
          ),
        ],
      ),
    );
  }

  void _showCreateBroadcastDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Gửi thông báo khẩn (HDV)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('broadcast_title_input'),
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề thông báo *',
                  hintText: 'Ví dụ: Thay đổi giờ xuất phát',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('broadcast_content_input'),
                controller: contentController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Nội dung thông báo *',
                  hintText: 'Nhập nội dung cần lưu ý cho toàn bộ du khách...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('submit_broadcast_button'),
            onPressed: () {
              final title = titleController.text.trim();
              final content = contentController.text.trim();

              if (title.isEmpty || content.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng nhập đầy đủ tiêu đề và nội dung thông báo.'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              setState(() {
                _messages.add(
                  ChatMessage(
                    id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
                    senderId: widget.currentUserId,
                    senderName: '${widget.currentUserName} (HDV)',
                    senderRole: 'guide',
                    isCurrentUser: true,
                    text: '',
                    timestamp: DateTime.now(),
                    type: ChatMessageType.broadcast,
                    metadata: {
                      'title': title,
                      'content': content,
                      'urgent': true,
                      'readByCount': 1,
                      'totalMembers': 4,
                      'isReadByMe': true,
                    },
                  ),
                );
              });

              Navigator.pop(dialogCtx);
              _scrollToBottom();
            },
            child: const Text('Gửi thông báo'),
          ),
        ],
      ),
    );
  }

  void _showCreateRollCallDialog() {
    final titleController = TextEditingController(text: 'Điểm danh xe di chuyển');
    final deadlineController = TextEditingController(text: '15 phút nữa');

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Tạo điểm danh đoàn'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Mục đích điểm danh'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: deadlineController,
              decoration: const InputDecoration(labelText: 'Thời hạn điểm danh'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _messages.add(
                  ChatMessage(
                    id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
                    senderId: widget.currentUserId,
                    senderName: '${widget.currentUserName} (HDV)',
                    senderRole: 'guide',
                    isCurrentUser: true,
                    text: '',
                    timestamp: DateTime.now(),
                    type: ChatMessageType.rollCall,
                    metadata: {
                      'title': titleController.text.trim(),
                      'deadline': deadlineController.text.trim(),
                      'presentCount': 1,
                      'totalMembers': 4,
                      'isPresent': true,
                    },
                  ),
                );
              });
              Navigator.pop(dialogCtx);
              _scrollToBottom();
            },
            child: const Text('Bắt đầu điểm danh'),
          ),
        ],
      ),
    );
  }

  void _showVietQrModal(Map<String, dynamic> metadata) {
    final bankName = metadata['bankName'] as String? ?? 'MB Bank';
    final accountNumber = metadata['accountNumber'] as String? ?? '0987654321';
    final accountName = metadata['accountName'] as String? ?? 'LE THI HUONG';
    final amount = metadata['perPersonAmount'] as int? ?? 150000;
    final title = metadata['title'] as String? ?? 'Chi tieu nhom';

    // VietQR URL format: https://img.vietqr.io/image/<BANK>-<ACCOUNT>-compact2.png?amount=<AMOUNT>&addInfo=<INFO>&accountName=<NAME>
    final safeInfo = Uri.encodeComponent(title);
    final safeName = Uri.encodeComponent(accountName);
    final qrUrl = 'https://img.vietqr.io/image/MB-$accountNumber-compact2.png?amount=$amount&addInfo=$safeInfo&accountName=$safeName';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final currentPaid = metadata['isPaidByMe'] as bool? ?? false;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Thanh toán qua VietQR',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.line),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            width: 180,
                            height: 180,
                            child: Image.network(
                              qrUrl,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade100,
                                  alignment: Alignment.center,
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.qr_code_2, size: 64, color: AppColors.primary),
                                      SizedBox(height: 4),
                                      Text(
                                        'Mã VietQR Chuẩn NAPAS',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatCurrency(amount),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.muted,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Ngân hàng:', style: TextStyle(color: AppColors.muted)),
                              Text(bankName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Số tài khoản:', style: TextStyle(color: AppColors.muted)),
                              Row(
                                children: [
                                  Text(accountNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: accountNumber));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Đã sao chép STK: $accountNumber'),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                    child: const Icon(Icons.copy_rounded, size: 16, color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Chủ tài khoản:', style: TextStyle(color: AppColors.muted)),
                              Text(accountName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const Key('toggle_paid_button'),
                        style: FilledButton.styleFrom(
                          backgroundColor: currentPaid ? AppColors.success : AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          setState(() {
                            metadata['isPaidByMe'] = !currentPaid;
                            if (!currentPaid) {
                              metadata['paidCount'] = ((metadata['paidCount'] as int? ?? 0) + 1);
                            } else {
                              metadata['paidCount'] = ((metadata['paidCount'] as int? ?? 1) - 1);
                            }
                          });
                          setSheetState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                !currentPaid
                                    ? 'Đã đánh dấu đã chuyển khoản thành công!'
                                    : 'Đã hủy đánh dấu thanh toán.',
                              ),
                              backgroundColor: !currentPaid ? AppColors.success : AppColors.muted,
                            ),
                          );
                          Navigator.pop(sheetCtx);
                        },
                        icon: Icon(currentPaid ? Icons.check_circle : Icons.payment_rounded),
                        label: Text(
                          currentPaid ? 'Đã thanh toán (Chạm để đổi)' : 'Xác nhận tôi đã chuyển khoản',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBroadcastCard(ChatMessage msg) {
    final meta = msg.metadata;
    final title = meta['title'] as String? ?? 'Thông báo';
    final content = meta['content'] as String? ?? '';
    final urgent = meta['urgent'] as bool? ?? false;
    final readByCount = meta['readByCount'] as int? ?? 0;
    final totalMembers = meta['totalMembers'] as int? ?? 4;
    final isReadByMe = meta['isReadByMe'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: urgent ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: urgent ? const Color(0xFFFCA5A5) : const Color(0xFFBFDBFE),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: urgent ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: urgent ? const Color(0xFF991B1B) : const Color(0xFF1E40AF),
                  ),
                ),
              ),
              if (urgent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'QUAN TRỌNG',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(fontSize: 14, height: 1.4, color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.visibility_outlined, size: 14, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Text(
                    '$readByCount/$totalMembers đã đọc',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
              OutlinedButton.icon(
                key: Key('broadcast_ack_${msg.id}'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: isReadByMe ? const Color(0xFFDCFCE7) : Colors.white,
                  foregroundColor: isReadByMe ? const Color(0xFF15803D) : AppColors.primary,
                  side: BorderSide(color: isReadByMe ? const Color(0xFF86EFAC) : AppColors.line),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  setState(() {
                    if (!isReadByMe) {
                      meta['isReadByMe'] = true;
                      meta['readByCount'] = readByCount + 1;
                    }
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Bạn đã xác nhận đã đọc thông báo này.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: Icon(isReadByMe ? Icons.check_circle_rounded : Icons.mark_email_read_rounded, size: 16),
                label: Text(isReadByMe ? 'Đã đọc' : 'Tôi đã đọc'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRollCallCard(ChatMessage msg) {
    final meta = msg.metadata;
    final title = meta['title'] as String? ?? 'Điểm danh';
    final deadline = meta['deadline'] as String? ?? '';
    final presentCount = meta['presentCount'] as int? ?? 0;
    final totalMembers = meta['totalMembers'] as int? ?? 4;
    final isPresent = meta['isPresent'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFF16A34A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.how_to_reg_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF166534),
                  ),
                ),
              ),
            ],
          ),
          if (deadline.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Hạn chót: $deadline',
              style: const TextStyle(fontSize: 12, color: Color(0xFF15803D)),
            ),
          ],
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: totalMembers > 0 ? (presentCount / totalMembers) : 0,
              backgroundColor: const Color(0xFFDCFCE7),
              color: const Color(0xFF16A34A),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Có mặt: $presentCount/$totalMembers thành viên',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
              ),
              FilledButton.icon(
                key: Key('roll_call_button_${msg.id}'),
                style: FilledButton.styleFrom(
                  backgroundColor: isPresent ? const Color(0xFF15803D) : const Color(0xFF16A34A),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  setState(() {
                    if (!isPresent) {
                      meta['isPresent'] = true;
                      meta['presentCount'] = presentCount + 1;
                    }
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Xác nhận điểm danh thành công!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: Icon(isPresent ? Icons.check_circle : Icons.check, size: 16),
                label: Text(isPresent ? 'Đã có mặt' : 'Xác nhận có mặt'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSplitBillCard(ChatMessage msg) {
    final meta = msg.metadata;
    final title = meta['title'] as String? ?? 'Chia tiền';
    final totalAmount = meta['totalAmount'] as int? ?? 0;
    final perPersonAmount = meta['perPersonAmount'] as int? ?? 0;
    final paidCount = meta['paidCount'] as int? ?? 0;
    final totalPersons = meta['totalPersons'] as int? ?? 4;
    final isPaidByMe = meta['isPaidByMe'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFF0284C7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tổng chi phí:', style: TextStyle(fontSize: 13, color: AppColors.muted)),
              Text(
                _formatCurrency(totalAmount),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Mỗi người:', style: TextStyle(fontSize: 13, color: AppColors.muted)),
              Text(
                _formatCurrency(perPersonAmount),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: totalPersons > 0 ? (paidCount / totalPersons) : 0,
              backgroundColor: const Color(0xFFE2E8F0),
              color: const Color(0xFF0284C7),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Đã thanh toán: $paidCount/$totalPersons',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              FilledButton.icon(
                key: Key('open_vietqr_button_${msg.id}'),
                style: FilledButton.styleFrom(
                  backgroundColor: isPaidByMe ? AppColors.success : AppColors.secondary,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _showVietQrModal(meta),
                icon: Icon(isPaidByMe ? Icons.check_circle : Icons.qr_code_scanner_rounded, size: 16),
                label: Text(isPaidByMe ? 'Đã trả • VietQR' : 'Xem VietQR'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPollCard(ChatMessage msg) {
    final meta = msg.metadata;
    final question = meta['question'] as String? ?? 'Bình chọn';
    final options = (meta['options'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final myVoteIndex = meta['myVoteIndex'] as int? ?? -1;

    int totalVotes = 0;
    for (final opt in options) {
      totalVotes += (opt['votes'] as int? ?? 0);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9D5FF), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFF7E22CE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.poll_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF581C87),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...options.asMap().entries.map((entry) {
            final idx = entry.key;
            final opt = entry.value;
            final text = opt['text'] as String? ?? '';
            final votes = opt['votes'] as int? ?? 0;
            final isMyVote = myVoteIndex == idx;
            final percentage = totalVotes > 0 ? (votes / totalVotes) : 0.0;

            return InkWell(
              key: Key('poll_option_${msg.id}_$idx'),
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                setState(() {
                  if (myVoteIndex == idx) {
                    // Retract vote
                    opt['votes'] = votes - 1;
                    meta['myVoteIndex'] = -1;
                  } else {
                    if (myVoteIndex >= 0 && myVoteIndex < options.length) {
                      options[myVoteIndex]['votes'] = (options[myVoteIndex]['votes'] as int) - 1;
                    }
                    opt['votes'] = votes + 1;
                    meta['myVoteIndex'] = idx;
                  }
                });
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isMyVote ? const Color(0xFFF3E8FF) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isMyVote ? const Color(0xFFA855F7) : const Color(0xFFE2E8F0),
                    width: isMyVote ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isMyVote ? Icons.radio_button_checked : Icons.radio_button_off,
                          size: 16,
                          color: isMyVote ? const Color(0xFF7E22CE) : AppColors.muted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            text,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isMyVote ? FontWeight.bold : FontWeight.normal,
                              color: isMyVote ? const Color(0xFF581C87) : Colors.black87,
                            ),
                          ),
                        ),
                        Text(
                          '$votes phiếu',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: percentage,
                        backgroundColor: const Color(0xFFF1F5F9),
                        color: const Color(0xFFA855F7),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Tổng cộng: $totalVotes lượt bình chọn',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage msg) {
    if (msg.type == ChatMessageType.broadcast) {
      return _buildBroadcastCard(msg);
    }
    if (msg.type == ChatMessageType.rollCall) {
      return _buildRollCallCard(msg);
    }
    if (msg.type == ChatMessageType.splitBill) {
      return _buildSplitBillCard(msg);
    }
    if (msg.type == ChatMessageType.poll) {
      return _buildPollCard(msg);
    }

    // Default text bubble
    final isMe = msg.isCurrentUser;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    msg.senderName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: msg.senderRole == 'guide' ? AppColors.secondary : AppColors.ink,
                    ),
                  ),
                  if (msg.senderRole == 'guide') ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'HDV',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
              border: Border.all(
                color: isMe ? AppColors.primary : AppColors.line,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              msg.text,
              style: TextStyle(
                fontSize: 14,
                color: isMe ? Colors.white : Colors.black87,
                height: 1.35,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 4, left: 4),
            child: Text(
              '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupName = widget.group?.name ?? 'Nhóm du lịch #${widget.groupId}';

    final filteredMessages = _searchQuery.isEmpty
        ? _messages
        : _messages.where((m) {
            final query = _searchQuery.toLowerCase();
            if (m.text.toLowerCase().contains(query)) return true;
            if (m.senderName.toLowerCase().contains(query)) return true;
            final meta = m.metadata;
            final title = (meta['title'] as String? ?? '').toLowerCase();
            final content = (meta['content'] as String? ?? '').toLowerCase();
            final question = (meta['question'] as String? ?? '').toLowerCase();
            return title.contains(query) || content.contains(query) || question.contains(query);
          }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primarySoft,
              child: const Icon(Icons.groups_rounded, color: AppColors.secondary, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    groupName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    '4 thành viên • Đang hoạt động',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('toggle_search_button'),
            icon: Icon(
              _isSearching ? Icons.close : Icons.search_rounded,
              color: AppColors.ink,
            ),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isSearching)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              child: TextField(
                key: const Key('chat_search_input'),
                controller: _searchController,
                autofocus: true,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm tin nhắn, thông báo, bình chọn...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                ),
              ),
            ),
          if (!_isPinnedDismissed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: const Color(0xFFFEF3C7),
              child: Row(
                children: [
                  const Icon(Icons.push_pin_rounded, color: Color(0xFFD97706), size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Ghim: Tập trung lúc 07:30 sáng mai tại sảnh KS Mường Thanh.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    key: const Key('dismiss_pinned_button'),
                    onTap: () {
                      setState(() {
                        _isPinnedDismissed = true;
                      });
                    },
                    child: const Icon(Icons.close, size: 16, color: Color(0xFF92400E)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: filteredMessages.isEmpty
                ? const Center(
                    child: Text(
                      'Không tìm thấy tin nhắn nào',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: filteredMessages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageItem(filteredMessages[index]);
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    key: const Key('open_action_drawer_button'),
                    icon: const Icon(Icons.add_circle_rounded, color: AppColors.primary, size: 28),
                    onPressed: _openActionDrawer,
                  ),
                  Expanded(
                    child: TextField(
                      key: const Key('chat_message_input'),
                      controller: _textController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn...',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    key: const Key('send_message_button'),
                    icon: const Icon(Icons.send_rounded, color: AppColors.secondary),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
