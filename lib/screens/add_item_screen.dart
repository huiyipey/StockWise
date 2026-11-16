import 'package:flutter/material.dart';
import '../widgets/item_editor.dart';

// Open the shared editor for a new inventory batch.
class AddItemScreen extends StatelessWidget {
  const AddItemScreen({super.key, this.onSaved});
  final ValueChanged<String>? onSaved;

  // Build the add item screen layout.
  @override
  Widget build(BuildContext context) => ItemEditor(onSaved: onSaved);
}
