import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/utils/calendar_date_format.dart';
import 'package:trip_mate_mobile/core/utils/validators.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/traveler_profile_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/traveler_profile_cubit.dart';
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
            content: Text('Choose a JPG, PNG or WEBP image up to 5 MB.'),
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
  Widget build(
    BuildContext context,
  ) => BlocConsumer<TravelerProfileCubit, TravelerProfileState>(
    bloc: cubit,
    listener: (context, state) {
      if (state.profile != null && !state.busy && state.error == null) {
        setState(() => fill(state.profile!));
      }
      if (state.saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully.')),
        );
      }
    },
    builder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: state.profile == null
          ? Center(
              child: state.busy
                  ? const CircularProgressIndicator()
                  : TextButton(
                      onPressed: cubit.load,
                      child: Text(state.error ?? 'Retry'),
                    ),
            )
          : Form(
              key: formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 44,
                      backgroundImage: avatar != null
                          ? MemoryImage(avatar!)
                          : state.profile!.avatarUrl != null
                          ? NetworkImage(state.profile!.avatarUrl!)
                          : null,
                      child: avatar == null && state.profile!.avatarUrl == null
                          ? const Icon(Icons.person, size: 40)
                          : null,
                    ),
                  ),
                  TextButton(
                    onPressed: state.busy ? null : pickAvatar,
                    child: const Text('Change photo'),
                  ),
                  AppTextField(
                    label: 'Full name',
                    controller: name,
                    enabled: !state.busy,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Full name is required.'
                        : value.trim().length > 100
                        ? 'Use at most 100 characters.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Email address',
                    initialValue: state.profile!.email,
                    enabled: false,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Phone number',
                    controller: phone,
                    enabled: !state.busy,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: Validators.phone,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Date of birth',
                    controller: birth,
                    readOnly: true,
                    enabled: !state.busy,
                    onTap: () async {
                      final now = DateTime.now();
                      final limit = DateTime(now.year - 16, now.month, now.day);
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
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        state.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: state.busy ? null : save,
                    child: Text(state.busy ? 'Saving…' : 'Save changes'),
                  ),
                  TextButton(
                    onPressed: state.busy
                        ? null
                        : () => setState(() => fill(state.profile!)),
                    child: const Text('Discard changes'),
                  ),
                ],
              ),
            ),
    ),
  );
}
