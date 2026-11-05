import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/firestore_service.dart';
import '../services/profile_fields.dart';
import '../models/product_name.dart';
import '../widgets/inventory_ui.dart';
import '../widgets/profile_ui.dart';

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
  bool completed = false;
  bool get dirty =>
      name.text != widget.displayName ||
      phone.text != widget.phoneNumber ||
      photo != null;

  @override
  void initState() {
    super.initState();
    name.addListener(refresh);
    phone.addListener(refresh);
  }

  @override
  Widget build(BuildContext context) => ProfileFormPage(
    title: 'Edit Profile',
    dirty: dirty,
    busy: saving || picking,
    completed: completed,
    discardTitle: 'Discard profile changes?',
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          ProfilePanel(
            padding: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProfilePhoto(
                  name: name.text,
                  path: widget.photoPath,
                  preview: preview,
                  radius: 38,
                ),
                const SizedBox(height: 20),
                InventoryButton(
                  label: picking ? 'Loading photo...' : 'Change profile photo',
                  icon: Icons.image_outlined,
                  soft: true,
                  busy: picking,
                  onPressed: saving || picking ? null : _pickPhoto,
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
                const SizedBox(height: 24),
                TextFormField(
                  key: const ValueKey('profile-name'),
                  controller: name,
                  enabled: !saving && !picking,
                  maxLength: 80,
                  style: const TextStyle(fontSize: 13),
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'Full name',
                    counterText: '',
                  ),
                  validator: profileNameError,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('profile-phone'),
                  controller: phone,
                  enabled: !saving && !picking,
                  style: const TextStyle(fontSize: 13),
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (Optional)',
                    hintText: 'e.g. 012-345 6789',
                  ),
                  validator: profilePhoneError,
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: TextFormField(
                    initialValue: widget.email,
                    readOnly: true,
                    style: const TextStyle(
                      fontSize: 13,
                      color: InventoryColors.muted,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      fillColor: InventoryColors.background,
                      constraints: BoxConstraints(),
                      suffixIcon: Icon(
                        Icons.lock_outline_rounded,
                        size: 17,
                        color: InventoryColors.muted,
                      ),
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 18),
                  ProfileNotice(error!, error: true),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
    footer: ProfileFooter(
      label: saving ? 'Saving...' : 'Save Changes',
      busy: saving,
      onPressed: saving || picking ? null : _save,
    ),
  );
  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (saving || picking) return;
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
        displayName: capitalizeProductName(name.text.trim()),
        phoneNumber: phone.text.trim(),
        photo: photo,
      );
      if (mounted) {
        setState(() {
          saving = false;
          completed = true;
        });
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
}
