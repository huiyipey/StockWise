import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/image_upload.dart';
import '../services/profile_service.dart';
import '../widgets/profile_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> initial;
  final String email;
  const EditProfileScreen({
    super.key,
    required this.initial,
    required this.email,
  });
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(
    text: widget.initial['displayName'] as String? ?? '',
  );
  late final phone = TextEditingController(
    text: widget.initial['phone'] as String? ?? '',
  );
  XFile? image;
  Uint8List? preview;
  bool removeImage = false, busy = false;
  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> pick() async {
    setState(() => busy = true);
    try {
      final selected = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (selected == null) return;
      final upload = await ImageUpload.read(selected);
      if (mounted) {
        setState(() {
          image = selected;
          preview = upload.bytes;
          removeImage = false;
        });
      }
    } catch (e) {
      if (mounted) message('Could not select image: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await ProfileService.save(
        name: name.text,
        phone: phone.text,
        image: image,
        removeImage: removeImage,
      );
      if (mounted) {
        message('Profile updated.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) message('Could not save profile: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: preview != null
                    ? ClipOval(
                        child: Image.memory(
                          preview!,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                        ),
                      )
                    : ProfileAvatar(
                        path: removeImage
                            ? null
                            : widget.initial['photoPath'] as String?,
                      ),
              ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                children: [
                  TextButton.icon(
                    onPressed: busy ? null : pick,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Choose image'),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            image = null;
                            preview = null;
                            removeImage = true;
                          }),
                    child: const Text('Remove image'),
                  ),
                ],
              ),
              TextFormField(
                controller: name,
                enabled: !busy,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? 'Enter a username.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                initialValue: widget.email,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Sign-in email',
                  helperText: 'Your account email cannot be changed here.',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: phone,
                enabled: !busy,
                maxLength: 30,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Contact phone (optional)',
                  helperText:
                      'Profile contact only; not a verified sign-in number.',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy ? null : save,
                child: Text(busy ? 'Saving…' : 'Save profile'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ChangePasswordScreen(),
                        ),
                      ),
                icon: const Icon(Icons.lock_outline),
                label: const Text('Change password'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final form = GlobalKey<FormState>();
  final current = TextEditingController(),
      next = TextEditingController(),
      confirm = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await ProfileService.changePassword(current.text, next.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Password changed. Use the new password next time you sign in.',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      final message = e is FirebaseAuthException
          ? switch (e.code) {
              'wrong-password' ||
              'invalid-credential' => 'Current password is incorrect.',
              'weak-password' => 'Choose a stronger password.',
              'too-many-requests' =>
                'Too many attempts. Please try again later.',
              'requires-recent-login' => 'Please sign in again and retry.',
              _ =>
                'Could not change password. Check your connection and try again.',
            }
          : 'Could not change password. Please try again.';
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: SafeArea(
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Confirm your current password to protect your account. Passwords are handled by Firebase Authentication, never saved in your profile.',
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: current,
                enabled: !busy,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                ),
                validator: (v) => (v?.isEmpty ?? true)
                    ? 'Enter your current password.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: next,
                enabled: !busy,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(labelText: 'New password'),
                validator: (v) => (v?.length ?? 0) < 8
                    ? 'Use at least 8 characters.'
                    : v == current.text
                    ? 'Choose a different password.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirm,
                enabled: !busy,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                ),
                validator: (v) =>
                    v != next.text ? 'Passwords do not match.' : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: busy ? null : save,
                child: Text(busy ? 'Updating…' : 'Update password'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
