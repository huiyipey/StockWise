import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../widgets/item_editor.dart';

class EditItemScreen extends StatelessWidget {
  final InventoryBatch item;

  const EditItemScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) => ItemEditor(item: item);
}
