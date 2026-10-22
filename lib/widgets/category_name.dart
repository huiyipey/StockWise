import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/store_session.dart';

class CategoryName extends StatelessWidget {
  final String id;
  final TextStyle? style;
  const CategoryName(this.id, {super.key, this.style});
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('stores')
            .doc(StoreSession.instance.storeId)
            .collection('categories')
            .doc(id)
            .snapshots(),
        builder: (context, snapshot) => Text(
          snapshot.data?.data()?['name'] as String? ?? id.replaceAll('-', ' '),
          style: style,
          overflow: TextOverflow.ellipsis,
        ),
      );
}
