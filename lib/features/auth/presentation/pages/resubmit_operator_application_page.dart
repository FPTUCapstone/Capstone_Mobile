import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/operator_document_upload.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/operator_application_repository.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/operator_application_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/services/operator_document_picker.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';
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
    if (_initialized || application == null) return;
    if (!application.isRejected) {
      context.go(AppRoutes.operatorApplication);
      return;
    }
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
      final application = state.application;
      if (state.status == OperatorApplicationStatus.loading ||
          !_initialized ||
          application == null) {
        return const AppPageScaffold(
          title: 'Resubmit Application',
          content: [Center(child: CircularProgressIndicator())],
        );
      }
      return AppPageScaffold(
        title: 'Resubmit Application',
        content: [
          AppAlert(
            title: 'Rejection reason',
            message: application.rejectionReason ?? 'No reason recorded.',
            type: AppAlertType.error,
          ),
          const SizedBox(height: AppSpacing.lg),
          Form(
            key: _formKey,
            child: Column(
              children: [
                AppTextField(
                  controller: _company,
                  label: 'Company name',
                  errorText: state.fieldErrors['companyName'],
                  validator: (value) => _required(value, 200),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _licenceNo,
                  label: 'Business licence number',
                  errorText: state.fieldErrors['businessLicenseNo'],
                  validator: _validateLicence,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _taxCode,
                  label: 'Tax code',
                  errorText: state.fieldErrors['taxCode'],
                  validator: _validateTax,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _contact,
                  label: 'Contact person',
                  errorText: state.fieldErrors['contactPerson'],
                  validator: (value) => _required(value, 150),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _address,
                  label: 'Business address (optional)',
                  errorText: state.fieldErrors['businessAddress'],
                  validator: (value) => (value?.trim().length ?? 0) > 300
                      ? 'Must not exceed 300 characters.'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _phone,
                  label: 'Contact phone (optional)',
                  errorText: state.fieldErrors['contactPhone'],
                  keyboardType: TextInputType.phone,
                  validator: _validatePhone,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('DOCUMENTS', style: Theme.of(context).textTheme.labelSmall),
          ...application.documents.map(
            (document) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: Text('${document.documentType} #${document.documentId}'),
              subtitle: Text(document.status),
            ),
          ),
          OutlinedButton.icon(
            onPressed: state.isSubmitting ? null : _pickLicence,
            icon: const Icon(Icons.upload_file),
            label: Text(
              _licence?.fileName ?? 'Replace business licence (optional)',
            ),
          ),
          const Text(
            'Leave empty to submit the latest existing licence for review again.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: state.isSubmitting ? null : _pickSupporting,
            icon: const Icon(Icons.attach_file),
            label: Text(
              _supporting.isEmpty
                  ? 'Add supporting documents (up to 5)'
                  : '${_supporting.length} supporting document(s) selected',
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
              label: 'Resubmit application',
              isLoading: state.isSubmitting,
              onPressed: _submit,
            ),
            TextButton(
              onPressed: state.isSubmitting ? null : () => context.pop(),
              child: const Text('Cancel'),
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
              'The uploaded file type is not supported or the file exceeds the size limit.',
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
              'Select up to 5 PDF, JPG or PNG files, maximum 5 MB each.',
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
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
    if (text.isEmpty) return 'This field is required.';
    return text.length > max ? 'Must not exceed $max characters.' : null;
  }

  String? _validateTax(String? value) =>
      _required(value, 50) ??
      (RegExp(r'^\d{10}(?:-\d{3})?$').hasMatch(value!.trim())
          ? null
          : 'Tax Code must be 10 digits or 10 digits followed by a hyphen and 3 digits.');
  String? _validateLicence(String? value) =>
      _required(value, 100) ??
      (RegExp(
            r'^\d{2}-\d+/\d{4}/(?:TCDL-GPLHQT|SDL-GPLHND)$',
          ).hasMatch(value!.trim())
          ? null
          : 'Enter a valid domestic or international travel licence number.');
  String? _validatePhone(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty || RegExp(r'^0\d{9}$').hasMatch(text)
        ? null
        : 'Phone number must be 10 digits starting with 0.';
  }
}
