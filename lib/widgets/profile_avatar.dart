import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

class ProfileAvatar extends StatelessWidget {
  final String? path;
  const ProfileAvatar({super.key, this.path});
  Widget _placeholder() => const CircleAvatar(
    radius: 48,
    backgroundColor: AppColors.primarySoft,
    child: Icon(Icons.person_rounded, size: 46, color: AppColors.primaryDark),
  );
  @override
  Widget build(BuildContext context) {
    if (path == null || path!.isEmpty) return _placeholder();
    return FutureBuilder<String?>(
      future: FirestoreService.instance.imageUrl(path),
      builder: (context, snapshot) {
        if (snapshot.data == null) return _placeholder();
        return ClipOval(
          child: Image.network(
            snapshot.data!,
            width: 96,
            height: 96,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _placeholder(),
          ),
        );
      },
    );
  }
}
