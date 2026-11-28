import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/utils/calendar_date_format.dart';
import 'package:trip_mate_mobile/core/utils/validators.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/traveler_profile_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/traveler_profile_cubit.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_coastal_app_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/app_section_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_text_field.dart';

class TravelerProfilePage extends StatefulWidget {
  const TravelerProfilePage({super.key});
  @override
  State<TravelerProfilePage> createState() => _TravelerProfilePageState();
}

class _TravelerProfilePageState extends State<TravelerProfilePage> {
  final cubit = serviceLocator<TravelerProfileCubit>();
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final phone = TextEditingController();
  final birth = TextEditingController();
  DateTime? selectedBirth;
  Uint8List? avatar;
  String? avatarName;
  String? avatarMime;

  @override
  void initState() {
    super.initState();
    cubit.load();
  }

  void fill(TravelerProfile profile) {
    name.text = profile.fullName;
    phone.text = (profile.phoneNumber ?? '').replaceAll(RegExp(r'\s+'), '');
    selectedBirth = DateTime.tryParse(profile.dateOfBirth ?? '');
    birth.text = selectedBirth == null
        ? ''
        : formatCalendarDate(selectedBirth!);
    avatar = null;
  }

  @override
  void dispose() {
    cubit.close();
    name.dispose();
    phone.dispose();
    birth.dispose();
    super.dispose();
  }

  Future<void> pickAvatar() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      if (result == null || !mounted) return;
      final file = result.files.single;
      final mime = switch (file.extension?.toLowerCase()) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => null,
      };
      if (file.bytes == null ||
          file.size == 0 ||
          file.size > 5 * 1024 * 1024 ||
          mime == null) {
        throw const FormatException();
      }
      setState(() {
        avatar = file.bytes;
        avatarName = file.name;
        avatarMime = mime;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng chọn ảnh JPG, PNG hoặc WEBP tối đa 5 MB.'),
          ),
        );
      }
    }
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    cubit.save(
      fullName: name.text,
      phoneNumber: phone.text,
      dateOfBirth: selectedBirth == null
          ? null
          : '${selectedBirth!.year.toString().padLeft(4, '0')}-'
                '${selectedBirth!.month.toString().padLeft(2, '0')}-'
                '${selectedBirth!.day.toString().padLeft(2, '0')}',
      avatar: avatar,
      avatarName: avatarName,
      avatarMime: avatarMime,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return BlocConsumer<TravelerProfileCubit, TravelerProfileState>(
      bloc: cubit,
      listener: (context, state) {
        if (state.profile != null && !state.busy && state.error == null) {
          setState(() => fill(state.profile!));
        }
        if (state.saved) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cập nhật hồ sơ thành công.')),
          );
        }
      },
      builder: (context, state) => Scaffold(
        backgroundColor: c.canvas,
        appBar: const AppCoastalAppBar(title: 'Chỉnh sửa hồ sơ'),
        body: state.profile == null
            ? Center(
                child: state.busy
                    ? CircularProgressIndicator(color: c.brandTeal)
                    : TextButton(
                        onPressed: cubit.load,
                        child: Text(state.error ?? 'Thử lại'),
                      ),
              )
            : Form(
                key: formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: c.brandTeal.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 34,
                                backgroundColor: c.tealSoftContainer,
                                backgroundImage: avatar != null
                                    ? MemoryImage(avatar!)
                                    : state.profile!.avatarUrl != null
                                    ? NetworkImage(state.profile!.avatarUrl!)
                                    : null,
                                child:
                                    avatar == null &&
                                        state.profile!.avatarUrl == null
                                    ? Icon(
                                        Icons.person,
                                        size: 32,
                                        color: c.brandTeal,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ảnh đại diện',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(color: c.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'JPG, PNG hoặc WEBP tối đa 5 MB',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: c.textMuted),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.sm,
                                        vertical: AppSpacing.xs,
                                      ),
                                      minimumSize: const Size(0, 36),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: state.busy ? null : pickAvatar,
                                    icon: const Icon(
                                      Icons.photo_camera_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('Đổi ảnh'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppSectionCard(
                        title: 'Thông tin cá nhân',
                        icon: Icons.badge_outlined,
                        child: Column(
                          children: [
                            AppTextField(
                              label: 'Họ và tên',
                              controller: name,
                              enabled: !state.busy,
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Vui lòng nhập họ và tên.'
                                  : value.trim().length > 100
                                  ? 'Sử dụng tối đa 100 ký tự.'
                                  : null,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppTextField(
                              label: 'Địa chỉ email',
                              initialValue: state.profile!.email,
                              enabled: false,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppTextField(
                              label: 'Số điện thoại',
                              controller: phone,
                              enabled: !state.busy,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              validator: Validators.phone,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppTextField(
                              label: 'Ngày sinh',
                              controller: birth,
                              readOnly: true,
                              enabled: !state.busy,
                              suffix: Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                                color: c.textMuted,
                              ),
                              onTap: () async {
                                final now = DateTime.now();
                                final limit = DateTime(
                                  now.year - 16,
                                  now.month,
                                  now.day,
                                );
                                final parsed = selectedBirth;
                                final selected = await showDatePicker(
                                  context: context,
                                  firstDate: DateTime(1900),
                                  lastDate: limit,
                                  initialDate:
                                      parsed != null &&
                                          !parsed.isAfter(limit) &&
                                          parsed.year >= 1900
                                      ? parsed
                                      : limit,
                                );
                                if (selected != null) {
                                  selectedBirth = selected;
                                  birth.text = formatCalendarDate(selected);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      if (state.error != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        AppAlert(
                          type: AppAlertType.error,
                          message: state.error!,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton(
                        onPressed: state.busy ? null : save,
                        child: Text(state.busy ? 'Đang lưu…' : 'Lưu thay đổi'),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      TextButton(
                        onPressed: state.busy
                            ? null
                            : () => setState(() => fill(state.profile!)),
                        child: const Text('Hủy thay đổi'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
