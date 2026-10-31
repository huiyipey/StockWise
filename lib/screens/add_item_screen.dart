import 'package:flutter/material.dart';
import '../widgets/item_editor.dart';

class AddItemScreen extends StatelessWidget {
  const AddItemScreen({super.key, this.onSaved});
  final ValueChanged<String>? onSaved;

  @override
  Widget build(BuildContext context) => ItemEditor(onSaved: onSaved);
}
