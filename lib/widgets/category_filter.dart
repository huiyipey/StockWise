import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../models/category_label.dart';
import '../services/firestore_service.dart';

class CategoryFilter extends StatefulWidget {
  final List<String> categoryIds;
  final String selected;
  final ValueChanged<String> onChanged;
  final InputDecoration decoration;

  const CategoryFilter({
    super.key,
    required this.categoryIds,
    required this.selected,
    required this.onChanged,
    this.decoration = const InputDecoration(labelText: 'Category'),
  });

  @override
  State<CategoryFilter> createState() => _CategoryFilterState();
}

class _CategoryFilterState extends State<CategoryFilter> {
  late final categories = FirestoreService.instance.watchCategoryRecords();

  @override
  Widget build(BuildContext context) => StreamBuilder<List<StoreCategory>>(
    stream: categories,
    builder: (context, snapshot) {
      final available = widget.categoryIds.toSet();
      final records = snapshot.data ?? const <StoreCategory>[];
      final known = records.where((c) => available.contains(c.id)).toList();
      final names = {for (final c in known) c.id: c.name};
      final unknown = available.where((id) => !names.containsKey(id)).toList()
        ..sort();
      final ids = [...known.map((c) => c.id), ...unknown];
      final selected = available.contains(widget.selected)
          ? widget.selected
          : 'all';
      return DropdownButtonFormField<String>(
        key: ValueKey(selected),
        initialValue: selected,
        isExpanded: true,
        decoration: widget.decoration,
        items: [
          const DropdownMenuItem(value: 'all', child: Text('All categories')),
          ...ids.map(
            (id) => DropdownMenuItem(
              value: id,
              child: Text(
                categoryTitleCase(names[id] ?? id.replaceAll('-', ' ')),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
        onChanged: (value) => widget.onChanged(value ?? 'all'),
      );
    },
  );
}
