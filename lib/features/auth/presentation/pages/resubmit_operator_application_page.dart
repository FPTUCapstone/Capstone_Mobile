import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/operator_document_upload.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/operator_application_repository.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/operator_application_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/services/operator_document_picker.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';
import 'package:trip_mate_mobile/shared/widgets/app_section_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_text_field.dart';

class ResubmitOperatorApplicationPage extends StatefulWidget {
  const ResubmitOperatorApplicationPage({required this.picker, super.key});
  final OperatorDocumentPicker picker;
  @override
  State<ResubmitOperatorApplicationPage> createState() =>
      _ResubmitOperatorApplicationPageState();
}

class _ResubmitOperatorApplicationPageState
    extends State<ResubmitOperatorApplicationPage> {
  final _formKey = GlobalKey<FormState>();
  final _company = TextEditingController();
  final _licenceNo = TextEditingController();
  final _taxCode = TextEditingController();
  final _contact = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  OperatorDocumentUpload? _licence;
  List<OperatorDocumentUpload> _supporting = const [];
  String? _pickerError;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    context.read<OperatorApplicationCubit>().loadApplication();
  }

  @override
  void dispose() {
    for (final controller in [
      _company,
      _licenceNo,
      _taxCode,
      _contact,
      _address,
      _phone,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _prefill(OperatorApplicationState state) {
    final application = state.application;
    if (application == null) return;
    if (!application.isRejected) {
      context.go(AppRoutes.operatorApplication);
      return;
    }
    if (_initialized) return;
    _company.text = application.companyName;
    _licenceNo.text = application.businessLicenseNo;
    _taxCode.text = application.taxCode;
    _contact.text = application.contactPerson;
    _address.text = application.businessAddress ?? '';
    _phone.text = application.contactPhone ?? '';
    _initialized = true;
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<OperatorApplicationCubit, OperatorApplicationState>(
    listener: (context, state) => _prefill(state),
    builder: (context, state) {
      final c = context.tmColors;
      final application = state.application;
      if (state.status == OperatorApplicationStatus.loading ||
          !_initialized ||
          application == null) {
        return AppPageScaffold(
          title: 'Nộp lại hồ sơ đối tác',
          content: [
            const SizedBox(height: AppSpacing.xl),
            Center(child: CircularProgressIndicator(color: c.brandTeal)),
          ],
        );
      }
      final hasExistingLicence = application.documents.any(
        (document) => document.documentType == 'BusinessLicense',
      );
      return AppPageScaffold(
        title: 'Nộp lại hồ sơ đối tác',
        content: [
          AppAlert(
            title: 'Lý do từ chối',
            message: application.rejectionReason ?? 'Chưa có lý do cụ thể.',
            type: AppAlertType.error,
          ),
          const SizedBox(height: AppSpacing.md),
          AppSectionCard(
            title: 'Thông tin doanh nghiệp',
            subtitle: 'Cập nhật các thông tin cần chỉnh sửa trước khi nộp lại.',
            icon: Icons.business_outlined,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  AppTextField(
                    controller: _company,
                    label: 'Tên doanh nghiệp',
                    errorText: state.fieldErrors['companyName'],
                    validator: (value) => _required(value, 200),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _licenceNo,
                    label: 'Số giấy phép kinh doanh lữ hành',
                    errorText: state.fieldErrors['businessLicenseNo'],
                    validator: _validateLicence,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _taxCode,
                    label: 'Mã số thuế',
                    errorText: state.fieldErrors['taxCode'],
                    validator: _validateTax,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _contact,
                    label: 'Người liên hệ',
                    errorText: state.fieldErrors['contactPerson'],
                    validator: (value) => _required(value, 150),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _address,
                    label: 'Địa chỉ kinh doanh (không bắt buộc)',
                    errorText: state.fieldErrors['businessAddress'],
                    validator: (value) => (value?.trim().length ?? 0) > 300
                        ? 'Không được vượt quá 300 ký tự.'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _phone,
                    label: 'Số điện thoại liên hệ (không bắt buộc)',
                    errorText: state.fieldErrors['contactPhone'],
                    keyboardType: TextInputType.phone,
                    validator: _validatePhone,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppSectionCard(
            title: 'Hồ sơ đính kèm',
            subtitle: hasExistingLicence
                ? 'Để trống nếu muốn giữ nguyên bản giấy phép gần nhất để xét duyệt lại.'
                : 'Cần tải lên giấy phép kinh doanh để nộp lại hồ sơ.',
            icon: Icons.upload_file_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (application.documents.isNotEmpty) ...[
                  for (var i = 0; i < application.documents.length; i++) ...[
                    if (i > 0) Divider(height: 14, color: c.borderSubtle),
                    Row(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 18,
                          color: c.brandTeal,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_documentTypeLabel(application.documents[i].documentType)} #${application.documents[i].documentId}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: c.textPrimary,
                                ),
                              ),
                              Text(
                                _documentStatusLabel(
                                  application.documents[i].status,
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: c.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                ],
                OutlinedButton.icon(
                  onPressed: state.isSubmitting ? null : _pickLicence,
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    _licence?.fileName ??
                        (hasExistingLicence
                            ? 'Thay giấy phép kinh doanh (không bắt buộc)'
                            : 'Tải lên giấy phép kinh doanh (bắt buộc)'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: state.isSubmitting ? null : _pickSupporting,
                  icon: const Icon(Icons.attach_file),
                  label: Text(
                    _supporting.isEmpty
                        ? 'Thêm tài liệu bổ sung (tối đa 5 tệp)'
                        : 'Đã chọn ${_supporting.length} tài liệu bổ sung',
                  ),
                ),
              ],
            ),
          ),
          if (_pickerError != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: AppAlert(message: _pickerError!, type: AppAlertType.error),
            ),
          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: AppAlert(
                message: state.errorMessage!,
                type: AppAlertType.error,
              ),
            ),
        ],
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(
              label: 'Nộp lại hồ sơ',
              isLoading: state.isSubmitting,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: state.isSubmitting ? null : () => context.pop(),
              child: const Text('Hủy'),
            ),
          ],
        ),
      );
    },
  );

  Future<void> _pickLicence() async {
    try {
      final selected = await widget.picker.pick(multiple: false);
      if (selected != null && selected.isNotEmpty && mounted) {
        setState(() {
          _licence = selected.first;
          _pickerError = null;
        });
      }
    } on OperatorDocumentReadFailure {
      if (mounted) {
        setState(
          () => _pickerError =
              'Định dạng tệp không được hỗ trợ hoặc vượt quá dung lượng cho phép.',
        );
      }
    }
  }

  Future<void> _pickSupporting() async {
    try {
      final selected = await widget.picker.pick(multiple: true);
      if (selected != null && mounted) {
        setState(() {
          _supporting = selected;
          _pickerError = null;
        });
      }
    } on OperatorDocumentReadFailure {
      if (mounted) {
        setState(
          () => _pickerError =
              'Chỉ chọn tối đa 5 tệp PDF, JPG hoặc PNG, mỗi tệp tối đa 5 MB.',
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final application = context
        .read<OperatorApplicationCubit>()
        .state
        .application;
    final hasExistingLicence =
        application?.documents.any(
          (document) => document.documentType == 'BusinessLicense',
        ) ??
        false;
    if (!hasExistingLicence && _licence == null) {
      setState(() {
        _pickerError = 'Vui lòng tải lên bản sao giấy phép kinh doanh.';
      });
      return;
    }
    final success = await context.read<OperatorApplicationCubit>().resubmit(
      ResubmitOperatorApplication(
        companyName: _company.text,
        businessLicenseNo: _licenceNo.text,
        taxCode: _taxCode.text,
        contactPerson: _contact.text,
        businessAddress: _address.text,
        contactPhone: _phone.text,
        businessLicenseDocument: _licence,
        supportingDocuments: _supporting,
      ),
    );
    if (!success || !mounted) return;
    await context
        .read<AuthSessionCubit>()
        .markOperatorApplicationPendingApproval();
    if (mounted) context.go(AppRoutes.operatorApplication);
  }

  String? _required(String? value, int max) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Vui lòng nhập thông tin này.';
    return text.length > max ? 'Không được vượt quá $max ký tự.' : null;
  }

  String? _validateTax(String? value) =>
      _required(value, 50) ??
      (RegExp(r'^\d{10}(?:-\d{3})?$').hasMatch(value!.trim())
          ? null
          : 'Mã số thuế phải gồm 10 chữ số, hoặc 10 chữ số kèm dấu gạch ngang và 3 chữ số chi nhánh.');
  String? _validateLicence(String? value) =>
      _required(value, 100) ??
      (RegExp(
            r'^\d{2}-\d+/\d{4}/(?:TCDL-GPLHQT|SDL-GPLHND)$',
          ).hasMatch(value!.trim())
          ? null
          : 'Vui lòng nhập số giấy phép lữ hành nội địa hoặc quốc tế hợp lệ.');
  String? _validatePhone(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty || RegExp(r'^0\d{9}$').hasMatch(text)
        ? null
        : 'Số điện thoại phải gồm 10 chữ số và bắt đầu bằng số 0.';
  }
}

String _documentTypeLabel(String type) => switch (type) {
  'BusinessLicense' => 'Giấy phép kinh doanh',
  'InternationalTourLicense' => 'Giấy phép lữ hành quốc tế',
  'DomesticTourLicense' => 'Giấy phép lữ hành nội địa',
  'SupportingDocument' => 'Tài liệu bổ sung',
  _ => type,
};

String _documentStatusLabel(String status) => switch (status) {
  'Approved' => 'Đã phê duyệt',
  'Rejected' => 'Bị từ chối',
  'Submitted' => 'Đã nộp',
  'Pending' || 'PendingApproval' || 'PendingReview' => 'Chờ phê duyệt',
  _ => status,
};
