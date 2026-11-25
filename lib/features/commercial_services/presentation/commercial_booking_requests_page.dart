import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/commercial_booking_repository.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/commercial_booking_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';

final class CommercialBookingRequestsPage extends StatefulWidget {
  const CommercialBookingRequestsPage({super.key});

  @override
  State<CommercialBookingRequestsPage> createState() =>
      _CommercialBookingRequestsPageState();
}

final class _CommercialBookingRequestsPageState
    extends State<CommercialBookingRequestsPage> {
  final _requests = <TravelerServiceRequest>[];
  bool _loading = false;
  bool _more = true;
  bool _loadingFailed = false;
  int? _cancelling;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _loadingFailed = false;
    });
    try {
      final page = await context.read<CommercialBookingCubit>().requests(
        beforeId: reset || _requests.isEmpty ? null : _requests.last.id,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _requests.clear();
        _requests.addAll(page);
        _more = page.length == 20;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingFailed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel(TravelerServiceRequest request) async {
    if (_cancelling != null || _loading) return;
    setState(() => _cancelling = request.id);
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text('Hủy yêu cầu ${request.requestCode}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Quay lại'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Xác nhận hủy'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
      try {
        await context.read<CommercialBookingCubit>().cancel(request.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã hủy yêu cầu đặt dịch vụ.')),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Không thể hủy yêu cầu. Hệ thống sẽ tải lại trạng thái.',
              ),
            ),
          );
        }
      }
      if (mounted) await _load(reset: true);
    } finally {
      if (mounted) setState(() => _cancelling = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Yêu cầu đặt dịch vụ')),
    body: RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_loadingFailed)
            TextButton(
              onPressed: () => _load(reset: true),
              child: const Text('Không tải được yêu cầu · Thử lại'),
            ),
          if (_requests.isEmpty && !_loading && !_loadingFailed)
            const ListTile(title: Text('Bạn chưa có yêu cầu đặt dịch vụ.')),
          for (final request in _requests)
            ListTile(
              key: ValueKey(request.id),
              title: Text('${request.requestCode} · ${request.serviceName}'),
              subtitle: Text(
                '${TripFormatters.formatVietnamDateTime(request.startsAt)} · Số lượng ${request.quantity}\n${_status(request.status)}',
              ),
              trailing: request.status == 'PendingConfirmation'
                  ? TextButton(
                      onPressed: _loading || _cancelling != null
                          ? null
                          : () => _cancel(request),
                      child: const Text('Hủy yêu cầu'),
                    )
                  : null,
            ),
          if (_requests.isNotEmpty && _more && !_loading)
            TextButton(
              onPressed: () => _load(reset: false),
              child: const Text('Tải thêm'),
            ),
        ],
      ),
    ),
  );

  String _status(String status) => switch (status) {
    'PendingConfirmation' => 'Chờ xác nhận',
    'Confirmed' => 'Đã xác nhận',
    'Rejected' => 'Đã từ chối',
    'Expired' => 'Đã hết hạn',
    'Cancelled' => 'Đã hủy',
    'Completed' => 'Đã hoàn tất',
    'NoShow' => 'Không đến',
    _ => status,
  };
}
