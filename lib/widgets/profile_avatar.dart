import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

// Build the shared profile avatar component.
class ProfileAvatar extends StatefulWidget {
  final String? photoPath;
  final Uint8List? preview;
  final double radius;

  const ProfileAvatar({
    super.key,
    this.photoPath,
    this.preview,
    this.radius = 48,
  });

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

// Manage the profile avatar values and actions.
class _ProfileAvatarState extends State<ProfileAvatar> {
  // Keep this component's values, selections, and request state.
  late Future<String?> url;

  // Set up the initial values and screen state.
  @override
  void initState() {
    super.initState();
    _load();
  }

  // Refresh values when the parent supplies new data.
  @override
  void didUpdateWidget(ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoPath != widget.photoPath) _load();
  }

  // Load the stored image or attachment for display.
  void _load() {
    final path = widget.photoPath;
    url = path == null || path.isEmpty
        ? Future.value(null)
        : path.startsWith('http')
        ? Future.value(path)
        : FirestoreService.instance.imageUrl(path);
  }

  // Render the profile avatar component.
  @override
  Widget build(BuildContext context) => Center(
    child: ClipOval(
      child: SizedBox(
        width: widget.radius * 2,
        height: widget.radius * 2,
        child: widget.preview != null
            ? Image.memory(
                widget.preview!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(),
              )
            : FutureBuilder<String?>(
                future: url,
                builder: (context, snapshot) => snapshot.data == null
                    ? _placeholder()
                    : Image.network(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _placeholder(),
                      ),
              ),
      ),
    ),
  );

  // Show fallback artwork when no image is available.
  Widget _placeholder() => ColoredBox(
    color: AppColors.primarySoft,
    child: Icon(
      Icons.person_rounded,
      size: widget.radius,
      color: AppColors.primaryDark,
    ),
  );
}
