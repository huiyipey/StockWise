import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

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

class _ProfileAvatarState extends State<ProfileAvatar> {
  late Future<String?> url;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoPath != widget.photoPath) _load();
  }

  void _load() {
    final path = widget.photoPath;
    url = path == null || path.isEmpty
        ? Future.value(null)
        : path.startsWith('http')
        ? Future.value(path)
        : FirestoreService.instance.imageUrl(path);
  }

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

  Widget _placeholder() => ColoredBox(
    color: AppColors.primarySoft,
    child: Icon(
      Icons.person_rounded,
      size: widget.radius,
      color: AppColors.primaryDark,
    ),
  );
}
