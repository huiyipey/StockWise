import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/firestore_service.dart';
import '../services/profile_fields.dart';
import '../theme/app_theme.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/stockwise_ui.dart';

class EditProfileScreen extends StatefulWidget {
  final String displayName;
  final String phoneNumber;
  final String email;
  final String? photoPath;
  final ProfileSaver? onSave;
  final Future<XFile?> Function()? pickPhoto;

  const EditProfileScreen({
    super.key,
    required this.displayName,
    required this.email,
    this.phoneNumber = '',
    this.photoPath,
    this.onSave,
    this.pickPhoto,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.displayName);
  late final phone = TextEditingController(text: widget.phoneNumber);
  XFile? photo;
  Uint8List? preview;
  bool saving = false;
  bool picking = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    setState(() => picking = true);
    try {
      final selected =
          await (widget.pickPhoto ??
              () => ImagePicker().pickImage(
                source: ImageSource.gallery,
                imageQuality: 82,
                maxWidth: 1024,
                maxHeight: 1024,
              ))();
      if (selected == null) return;
      final bytes = await selected.readAsBytes();
      if (bytes.length >= 5 * 1024 * 1024) {
        throw ArgumentError('Choose a photo smaller than 5 MB.');
      }
      if (mounted) {
        setState(() {
          photo = selected;
          preview = bytes;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Could not load the photo. Choose an image smaller than 5 MB.',
        );
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> _save() async {
    if (saving || picking || !(form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await (widget.onSave ?? FirestoreService.instance.updateUserProfile)(
        displayName: name.text.trim(),
        phoneNumber: phone.text.trim(),
        photo: photo,
      );
      if (mounted) {
        setState(() => saving = false);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ArgumentError
              ? '${e.message}'
              : 'Could not save your profile. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            StockWiseHeader(
              title: 'Edit Profile',
              leading: saving ? null : const BackCircleButton(),
            ),
            Expanded(
              child: Form(
                key: form,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    ProfileAvatar(
                      photoPath: widget.photoPath,
                      preview: preview,
                      radius: 56,
                    ),
                    TextButton.icon(
                      onPressed: saving || picking ? null : _pickPhoto,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(
                        picking ? 'Loading photo...' : 'Change profile photo',
                      ),
                    ),
                    if (photo != null)
                      TextButton(
                        onPressed: saving
                            ? null
                            : () => setState(() {
                                photo = null;
                                preview = null;
                              }),
                        child: const Text('Undo photo change'),
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('profile-name'),
                      controller: name,
                      enabled: !saving,
                      maxLength: 80,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: profileNameError,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('profile-phone'),
                      controller: phone,
                      enabled: !saving,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone number (optional)',
                      ),
                      validator: profilePhoneError,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: widget.email,
                      readOnly: true,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          error!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ),
                    const SizedBox(height: 22),
                    ElevatedButton(
                      onPressed: saving || picking ? null : _save,
                      child: Text(saving ? 'SAVING...' : 'SAVE CHANGES'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
