import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/features/operator_check_in/domain/entities/operator_check_in_models.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/formatters/check_in_time_format.dart';

class CheckInResultBanner extends StatelessWidget {
  const CheckInResultBanner({this.result, this.failure, super.key});

  final CheckInResult? result;
  final CheckInFailure? failure;

  @override
  Widget build(BuildContext context) {
    if (result != null) {
      final res = result!;
      final timeStr = CheckInTimeFormat.dateTime(res.checkedInAtUtc);

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5F2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFB9E0DA)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Color(0xFF0E9F6E),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${res.ticketCode} đã được chấp nhận',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF075D53),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tên hành khách: ${res.passengerName} · ${res.participantCount} khách · điểm danh lúc $timeStr',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF065F46),
                    ),
                  ),
                  Text('Mã đơn đặt tour: ${res.bookingCode}'),
                  Text('Số lượng hành khách: ${res.participantCount}'),
                  const Text('Trạng thái vé: Đã sử dụng'),
                  const Text('Kết quả điểm danh: Thành công'),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (failure != null) {
      final fail = failure!;
      final isAlreadyUsed = fail.kind == CheckInFailureKind.alreadyUsed;

      if (isAlreadyUsed) {
        final timeStr = fail.checkedInAt != null
            ? CheckInTimeFormat.dateTime(fail.checkedInAt!)
            : '';
        final subtitle = [
          if (timeStr.isNotEmpty) 'đã điểm danh trước đó lúc $timeStr',
        ].join(' · ');

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFF5CFB9)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFFD97706),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.priority_high,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${fail.ticketCode ?? 'Vé'} đã được sử dụng',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle.isNotEmpty
                          ? subtitle
                          : (fail.message ??
                                'Vé này đã được điểm danh trước đó.'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB45309),
                      ),
                    ),
                    ..._failureFields(
                      fail,
                      ticketStatus: 'Đã sử dụng',
                      result: 'Đã sử dụng',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      final uncertain = switch (fail.kind) {
        CheckInFailureKind.network || CheckInFailureKind.system => true,
        _ => false,
      };
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0EE),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF2C3BC)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Color(0xFFDC2626),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    uncertain
                        ? 'Chưa thể xác nhận điểm danh'
                        : '${fail.ticketCode ?? 'Vé'} bị từ chối',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fail.message ??
                        (uncertain
                            ? 'Chưa thể xác nhận kết quả. Vui lòng kiểm tra lại trước khi thử tiếp.'
                            : 'Vé không hợp lệ cho chuyến khởi hành này.'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
                  ..._failureFields(
                    fail,
                    ticketStatus: 'Không xác định',
                    result: uncertain ? 'Chưa xác nhận' : 'Từ chối',
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  List<Widget> _failureFields(
    CheckInFailure failure, {
    required String ticketStatus,
    required String result,
  }) => [
    Text('Mã đơn đặt tour: ${failure.bookingCode ?? 'Không có thông tin'}'),
    Text('Tên hành khách: ${failure.passengerName ?? 'Không có thông tin'}'),
    const Text('Số lượng hành khách: Không có thông tin'),
    Text('Trạng thái vé: $ticketStatus'),
    Text('Kết quả điểm danh: $result'),
  ];
}
