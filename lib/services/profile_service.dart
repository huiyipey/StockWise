import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'image_upload.dart';

class ProfileService {
  static User get user => FirebaseAuth.instance.currentUser!;
  static DocumentReference<Map<String, dynamic>> get profile =>
      FirebaseFirestore.instance.collection('users').doc(user.uid);
  static DocumentReference<Map<String, dynamic>> preference(String storeId) =>
      profile.collection('storePreferences').doc(storeId);

  static Future<void> save({
    required String name,
    required String phone,
    XFile? image,
    bool removeImage = false,
  }) async {
    final displayName = name.trim();
    if (displayName.isEmpty || displayName.length > 60) {
      throw ArgumentError('Username must be 1–60 characters.');
    }
    if (phone.trim().length > 30) {
      throw ArgumentError('Phone number is too long.');
    }
    final fields = <String, dynamic>{
      'displayName': displayName,
      'phone': phone.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (image != null) {
      final upload = await ImageUpload.read(image);
      final ref = FirebaseStorage.instance.ref(
        'user-avatars/${user.uid}/${DateTime.now().microsecondsSinceEpoch}.${upload.extension}',
      );
      await ref.putData(
        upload.bytes,
        SettableMetadata(contentType: upload.contentType),
      );
      fields['photoPath'] = ref.fullPath;
    } else if (removeImage) {
      fields['photoPath'] = '';
    }
    await profile.set(fields, SetOptions(merge: true));
    // Firestore remains authoritative if the optional Auth mirror is unavailable.
    try {
      await user.updateDisplayName(displayName);
    } on FirebaseAuthException {
      /* Profile already saved. */
    }
  }

  static Future<void> changePassword(String current, String next) async {
    if (next.length < 8) throw ArgumentError('Use at least 8 characters.');
    final email = user.email;
    if (email == null) {
      throw StateError('This account has no password sign-in email.');
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: current),
    );
    await user.updatePassword(next);
    await user.getIdToken(true);
  }
}
