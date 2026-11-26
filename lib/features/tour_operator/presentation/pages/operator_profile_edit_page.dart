import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/tour_operator/domain/entities/operator_profile.dart';
import 'package:trip_mate_mobile/features/tour_operator/presentation/cubit/operator_profile_cubit.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';

typedef OperatorLogoPickerCallback = Future<OperatorLogoUploadData?> Function();

class OperatorProfileEditPage extends StatefulWidget {
  const OperatorProfileEditPage({
    this.initialProfile,
    this.isDemoMode = false,
    this.logoPicker,
    super.key,
  });

  final OperatorProfile? initialProfile;
  final bool isDemoMode;
  final OperatorLogoPickerCallback? logoPicker;

  @override
  State<OperatorProfileEditPage> createState() =>
      _OperatorProfileEditPageState();
}

class _OperatorProfileEditPageState extends State<OperatorProfileEditPage> {
  final _businessNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();

  OperatorLogoUploadData? _selectedLogo;
  bool _removeLogo = false;
  String? _localLogoError;
  bool _formSeeded = false;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<OperatorProfileCubit>();
    if (widget.initialProfile != null) {
      cubit.seedProfile(widget.initialProfile!);
      _seedForm(widget.initialProfile!);
    } else {
      cubit.load();
    }
  }

  void _seedForm(OperatorProfile profile) {
    _businessNameController.text = profile.businessName;
    _descriptionController.text = profile.businessDescription;
    _addressController.text = profile.businessAddress;
    _phoneController.text = profile.contactPhone;
    _emailController.text = profile.contactEmail;
    _websiteController.text = profile.website ?? '';
    _selectedLogo = null;
    _removeLogo = false;
    _localLogoError = null;
    _formSeeded = true;
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final cubit = context.read<OperatorProfileCubit>();
    if (cubit.state.isSubmitting) return;

    setState(() => _localLogoError = null);
    cubit.clearFieldError(logo: true);

    try {
      final picked = widget.logoPicker != null
          ? await widget.logoPicker!()
          : await _defaultPickLogo();
      if (!mounted || picked == null) return;

      if (!OperatorProfileValidator.isValidLogo(picked)) {
        setState(() => _localLogoError = OperatorProfileMessages.invalidLogo);
        return;
      }

      setState(() {
        _selectedLogo = picked;
        _removeLogo = false;
        _localLogoError = null;
      });
    } on FormatException {
      if (mounted) {
        setState(() => _localLogoError = OperatorProfileMessages.invalidLogo);
      }
    } on Object {
      if (mounted) {
        setState(() => _localLogoError = OperatorProfileMessages.invalidLogo);
      }
    }
  }

  Future<OperatorLogoUploadData?> _defaultPickLogo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    final mime = OperatorProfileValidator.mimeTypeFromExtension(file.extension);
    if (mime == null) {
      throw const FormatException('Unsupported logo extension');
    }

    Uint8List? bytes = file.bytes;
    if (bytes == null && !kIsWeb && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }
    if (bytes == null || bytes.isEmpty) {
      throw const FormatException('Empty logo file');
    }

    return OperatorLogoUploadData(
      bytes: bytes,
      fileName: file.name,
      mimeType: mime,
    );
  }

  void _handleRemoveLogo() {
    final cubit = context.read<OperatorProfileCubit>();
    if (cubit.state.isSubmitting) return;
    cubit.clearFieldError(logo: true);
    setState(() {
      _selectedLogo = null;
      _removeLogo = true;
      _localLogoError = null;
    });
  }

  void _handleCancel(OperatorProfile profile) {
    if (context.read<OperatorProfileCubit>().state.isSubmitting) return;
    setState(() => _seedForm(profile));
    context.pop();
  }

  void _handleSubmit() {
    final cubit = context.read<OperatorProfileCubit>();
    if (cubit.state.isSubmitting) return;
    setState(() => _localLogoError = null);

    final input = UpdateOperatorProfileInput(
      businessName: _businessNameController.text.trim(),
      businessDescription: _descriptionController.text.trim(),
      businessAddress: _addressController.text.trim(),
      contactPhone: _phoneController.text.trim(),
      contactEmail: _emailController.text.trim(),
      website: _websiteController.text.trim(),
      logo: _selectedLogo,
      removeLogo: _selectedLogo != null ? false : _removeLogo,
    );

    cubit.save(input);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chỉnh sửa hồ sơ doanh nghiệp',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: BlocConsumer<OperatorProfileCubit, OperatorProfileState>(
        listener: (context, state) {
          if (!_formSeeded && state.profile != null) {
            setState(() => _seedForm(state.profile!));
          }
          if (state.savedProfile != null) {
            final saved = state.savedProfile!;
            setState(() {
              _selectedLogo = null;
              _removeLogo = false;
              _localLogoError = null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  widget.isDemoMode
                      ? 'Bản xem trước DEMO: ${OperatorProfileMessages.updateSuccess}'
                      : OperatorProfileMessages.updateSuccess,
                ),
              ),
            );
            context.pop(saved);
          }
        },
        builder: (context, state) {
          if (state.status == OperatorProfileLoadStatus.loading &&
              state.profile == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == OperatorProfileLoadStatus.error &&
              state.profile == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppAlert(
                      message:
                          state.loadError ??
                          OperatorProfileMessages.systemFailure,
                      type: AppAlertType.error,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: () =>
                          context.read<OperatorProfileCubit>().load(),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          final profile = state.profile;
          if (profile == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final busy = state.isSubmitting;
          final fieldErrors = state.fieldErrors;
          final logoError = _localLogoError ?? fieldErrors.logoAreaError;
          final hasVisibleLogo =
              _selectedLogo != null ||
              (!_removeLogo &&
                  (profile.localLogoBytes != null ||
                      (profile.logoUrl != null &&
                          profile.logoUrl!.isNotEmpty)));

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                if (widget.isDemoMode) ...[
                  const AppAlert(
                    message:
                        'Bản xem trước DEMO: Thay đổi chỉ lưu tạm trong phiên hiện tại.',
                    type: AppAlertType.warning,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (state.submitError != null) ...[
                  AppAlert(
                    message: state.submitError!,
                    type: AppAlertType.error,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      Text(
                        'Logo doanh nghiệp',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'JPG, PNG, WebP · Tối đa 5MB (BR-16)',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _LogoPreview(
                        selectedBytes: _selectedLogo?.bytes,
                        localBytes: _removeLogo ? null : profile.localLogoBytes,
                        logoUrl: _removeLogo ? null : profile.logoUrl,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        alignment: WrapAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            key: const Key('operator_profile_pick_logo_button'),
                            onPressed: busy ? null : _pickLogo,
                            icon: const Icon(Icons.upload_outlined, size: 18),
                            label: Text(
                              hasVisibleLogo ? 'Thay đổi logo' : 'Tải lên logo',
                            ),
                          ),
                          if (hasVisibleLogo)
                            OutlinedButton.icon(
                              key: const Key(
                                'operator_profile_remove_logo_button',
                              ),
                              onPressed: busy ? null : _handleRemoveLogo,
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: AppColors.error,
                              ),
                              label: const Text(
                                'Xóa logo',
                                style: TextStyle(color: AppColors.error),
                              ),
                            ),
                        ],
                      ),
                      if (logoError != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          logoError,
                          key: const Key('operator_profile_logo_error'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thông tin doanh nghiệp',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        key: const Key('field_business_name'),
                        controller: _businessNameController,
                        enabled: !busy,
                        maxLength:
                            OperatorProfileValidator.maxBusinessNameLength,
                        decoration: InputDecoration(
                          labelText: 'Tên doanh nghiệp lữ hành *',
                          errorText: fieldErrors.businessName,
                          counterText: '',
                        ),
                        onChanged: (_) => context
                            .read<OperatorProfileCubit>()
                            .clearFieldError(businessName: true),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        key: const Key('field_contact_phone'),
                        controller: _phoneController,
                        enabled: !busy,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        decoration: InputDecoration(
                          labelText: 'Số điện thoại liên hệ',
                          hintText: '0905388123',
                          errorText: fieldErrors.contactPhone,
                          counterText: '',
                        ),
                        onChanged: (_) => context
                            .read<OperatorProfileCubit>()
                            .clearFieldError(contactPhone: true),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        key: const Key('field_contact_email'),
                        controller: _emailController,
                        enabled: !busy,
                        keyboardType: TextInputType.emailAddress,
                        maxLength: OperatorProfileValidator.maxEmailLength,
                        decoration: InputDecoration(
                          labelText: 'Email liên hệ doanh nghiệp',
                          hintText: 'contact@example.vn',
                          errorText: fieldErrors.contactEmail,
                          counterText: '',
                        ),
                        onChanged: (_) => context
                            .read<OperatorProfileCubit>()
                            .clearFieldError(contactEmail: true),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        key: const Key('field_business_address'),
                        controller: _addressController,
                        enabled: !busy,
                        maxLength: OperatorProfileValidator.maxAddressLength,
                        decoration: InputDecoration(
                          labelText: 'Địa chỉ trụ sở chính',
                          errorText: fieldErrors.businessAddress,
                          counterText: '',
                        ),
                        onChanged: (_) => context
                            .read<OperatorProfileCubit>()
                            .clearFieldError(businessAddress: true),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        key: const Key('field_website'),
                        controller: _websiteController,
                        enabled: !busy,
                        keyboardType: TextInputType.url,
                        maxLength: OperatorProfileValidator.maxWebsiteLength,
                        decoration: InputDecoration(
                          labelText: 'Website chính thức',
                          hintText: 'https://example.vn',
                          errorText: fieldErrors.website,
                          counterText: '',
                        ),
                        onChanged: (_) => context
                            .read<OperatorProfileCubit>()
                            .clearFieldError(website: true),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        key: const Key('field_business_description'),
                        controller: _descriptionController,
                        enabled: !busy,
                        maxLines: 4,
                        maxLength:
                            OperatorProfileValidator.maxDescriptionLength,
                        decoration: InputDecoration(
                          labelText: 'Mô tả giới thiệu doanh nghiệp',
                          alignLabelWithHint: true,
                          errorText: fieldErrors.businessDescription,
                        ),
                        onChanged: (_) => context
                            .read<OperatorProfileCubit>()
                            .clearFieldError(businessDescription: true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thông tin pháp lý & Tài khoản (Chỉ đọc · BR-08)',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _ReadOnlyRow(
                        label: 'Số GPKD lữ hành',
                        value: profile.businessLicenceNumber,
                      ),
                      _ReadOnlyRow(label: 'Mã số thuế', value: profile.taxCode),
                      _ReadOnlyRow(
                        label: 'Trạng thái duyệt',
                        value: profile.approvalStatus,
                      ),
                      _ReadOnlyRow(
                        label: 'Email tài khoản (BR-17)',
                        value: profile.accountEmail,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('operator_profile_cancel_button'),
                        onPressed: busy ? null : () => _handleCancel(profile),
                        child: const Text('Hủy'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        key: const Key('operator_profile_save_button'),
                        onPressed: busy ? null : _handleSubmit,
                        child: busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Lưu thông tin'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LogoPreview extends StatelessWidget {
  const _LogoPreview({
    required this.selectedBytes,
    required this.localBytes,
    required this.logoUrl,
  });

  final Uint8List? selectedBytes;
  final Uint8List? localBytes;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final bytes = selectedBytes ?? localBytes;
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: bytes != null
          ? Image.memory(
              bytes,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.business_center,
                size: 36,
                color: AppColors.muted,
              ),
            )
          : (logoUrl != null && logoUrl!.isNotEmpty)
          ? Image.network(
              logoUrl!,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.business_center,
                size: 36,
                color: AppColors.muted,
              ),
            )
          : const Icon(Icons.business_center, size: 36, color: AppColors.muted),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 3,
            child: Text(
              value.isNotEmpty ? value : 'Chưa có dữ liệu',
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
