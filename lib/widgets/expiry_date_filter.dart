import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExpiryDateFilter extends StatelessWidget {
  final DateTimeRange? range;
  final bool ascending;
  final VoidCallback onPickRange;
  final VoidCallback onClearRange;
  final VoidCallback onToggleSort;

  const ExpiryDateFilter({
    super.key,
    required this.range,
    required this.ascending,
    required this.onPickRange,
    required this.onClearRange,
    required this.onToggleSort,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: onPickRange,
          icon: const Icon(Icons.date_range_outlined),
          label: Text(
            range == null
                ? 'Filter expiry date'
                : '${DateFormat('dd/MM/yy').format(range!.start)} – ${DateFormat('dd/MM/yy').format(range!.end)}',
          ),
        ),
      ),
      if (range != null)
        IconButton(
          tooltip: 'Clear date filter',
          onPressed: onClearRange,
          icon: const Icon(Icons.close_rounded),
        ),
      const SizedBox(width: 8),
      Tooltip(
        message: ascending
            ? 'Earliest expiry first. Sort descending'
            : 'Latest expiry first. Sort ascending',
        child: OutlinedButton(
          onPressed: onToggleSort,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward),
              const SizedBox(width: 4),
              Text(ascending ? 'Asc' : 'Desc'),
            ],
          ),
        ),
      ),
    ],
  );
}
