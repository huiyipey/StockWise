import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../widgets/item_editor.dart';

// Open the shared editor with the selected item.
class EditItemScreen extends StatelessWidget {
  final InventoryBatch item;

  const EditItemScreen({super.key, required this.item});

  // Build the edit item screen layout.
  @override
  Widget build(BuildContext context) => ItemEditor(item: item);
}
