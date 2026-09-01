import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/utils/validators.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';
import 'package:trip_mate_mobile/shared/widgets/app_text_field.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

class TravelerProfilePage extends StatefulWidget {
  const TravelerProfilePage({super.key});

  @override
  State<TravelerProfilePage> createState() => _TravelerProfilePageState();
}

class _TravelerProfilePageState extends State<TravelerProfilePage> {
  static const _initialName = 'Nguyen Minh Phuc';
  static const _initialPhone = '0905 123 456';
  static const _initialBirthDate = '26/09/2004';
  static const _initialCity = 'Da Nang';

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: _initialName);
  final _phoneController = TextEditingController(text: _initialPhone);
  final _birthDateController = TextEditingController(text: _initialBirthDate);
  final _cityController = TextEditingController(text: _initialCity);
  var _avatarChanged = false;
  var _isSaving = false;
  var _phoneVerified = false;

  @override
  void dispose() {
    _birthDateController.dispose();
    _cityController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Edit Profile',
      actions: [
        IconButton(
          onPressed: _isSaving ? null : _save,
          tooltip: 'Save changes',
          icon: const Icon(Icons.check),
        ),
      ],
      content: [
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 42,
                child: _avatarChanged
                    ? const Icon(Icons.landscape, size: 38)
                    : const Text(
                        'PN',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              Positioned(
                right: -4,
                bottom: -2,
                child: IconButton.filled(
                  onPressed: _changePhoto,
                  tooltip: 'Change photo demo',
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                ),
              ),
            ],
          ),
        ),
        Center(
          child: TextButton(
            onPressed: _changePhoto,
            child: Text(
              _avatarChanged ? 'Demo photo selected' : 'Change photo',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Form(
          key: _formKey,
          child: Column(
            children: [
              AppTextField(
                controller: _nameController,
                label: 'Full name',
                validator: (value) =>
                    Validators.requiredField(value, fieldName: 'Full name'),
              ),
              const SizedBox(height: AppSpacing.md),
              const AppTextField(
                enabled: false,
                initialValue: 'traveler@tripmate.demo',
                label: 'Email address',
                suffix: Padding(
                  padding: EdgeInsets.all(12),
                  child: StatusBadge(
                    label: 'Verified',
                    type: StatusBadgeType.success,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                label: 'Phone number',
                suffix: TextButton(
                  onPressed: _verifyPhone,
                  child: Text(_phoneVerified ? 'Verified' : 'Verify'),
                ),
                validator: Validators.phone,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _birthDateController,
                label: 'Date of birth',
                onTap: _selectBirthDate,
                readOnly: true,
                suffix: const Icon(Icons.calendar_today_outlined),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _cityController,
                label: 'Home city',
                onTap: _selectCity,
                readOnly: true,
                suffix: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'Your account role is assigned by TripMate and cannot be changed from this screen.',
        ),
      ],
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton(
            isLoading: _isSaving,
            label: 'Save changes',
            onPressed: _save,
          ),
          TextButton(onPressed: _discard, child: const Text('Discard changes')),
        ],
      ),
    );
  }

  void _changePhoto() {
    setState(() => _avatarChanged = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Demo avatar selected. No gallery was opened.'),
      ),
    );
  }

  void _discard() {
    setState(() {
      _avatarChanged = false;
      _birthDateController.text = _initialBirthDate;
      _cityController.text = _initialCity;
      _nameController.text = _initialName;
      _phoneController.text = _initialPhone;
      _phoneVerified = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile demo changes discarded.')),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSaving = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) {
      return;
    }
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile changes saved locally for the demo.'),
      ),
    );
  }

  Future<void> _selectBirthDate() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(1940),
      initialDate: DateTime(2004, 9, 26),
      lastDate: DateTime.now(),
    );
    if (selected != null) {
      _birthDateController.text =
          '${selected.day.toString().padLeft(2, '0')}/'
          '${selected.month.toString().padLeft(2, '0')}/${selected.year}';
    }
  }

  void _selectCity() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Da Nang', 'Ha Noi', 'Ho Chi Minh City', 'Hue']
              .map(
                (city) => ListTile(
                  title: Text(city),
                  onTap: () {
                    _cityController.text = city;
                    Navigator.pop(sheetContext);
                  },
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }

  void _verifyPhone() {
    setState(() => _phoneVerified = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Phone verification simulated locally.')),
    );
  }
}
