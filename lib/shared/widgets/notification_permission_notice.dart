import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/platform/device_window.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';

/// Explains a denied notification permission once per screen visit and offers
/// the settings page. It never prompts and never blocks the app: alerts remain
/// available in the app without notifications.
class NotificationPermissionNotice extends StatefulWidget {
  const NotificationPermissionNotice({
    required this.denied,
    required this.window,
    super.key,
  });

  final ValueListenable<bool> denied;
  final DeviceWindow window;

  @override
  State<NotificationPermissionNotice> createState() =>
      _NotificationPermissionNoticeState();
}

class _NotificationPermissionNoticeState
    extends State<NotificationPermissionNotice> {
  bool _dismissed = false;
  bool _settingsFailed = false;

  Future<void> _openSettings() async {
    final opened = await widget.window.openNotificationSettings();
    if (mounted) setState(() => _settingsFailed = !opened);
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: widget.denied,
    builder: (context, denied, _) {
      if (!denied || _dismissed) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          key: const Key('notification-permission-notice'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAlert(
              message: _settingsFailed
                  ? 'Không mở được Cài đặt. Bạn có thể bật thông báo trong cài đặt của thiết bị.'
                  : 'Thông báo đang tắt. Cập nhật an toàn vẫn hiện trong ứng dụng.',
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: const Key('notification-permission-dismiss'),
                  onPressed: () => setState(() => _dismissed = true),
                  child: const Text('Để sau'),
                ),
                TextButton(
                  key: const Key('notification-permission-settings'),
                  onPressed: _openSettings,
                  child: const Text('Mở cài đặt'),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
