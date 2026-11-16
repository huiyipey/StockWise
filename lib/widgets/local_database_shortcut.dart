import 'dart:async';

import 'package:flutter/material.dart';

import 'inventory_ui.dart';

// Build the shared local database shortcut component.
class LocalDatabaseShortcut extends StatefulWidget {
  const LocalDatabaseShortcut({
    super.key,
    required this.onOpen,
    this.compact = false,
  });
  final Future<void> Function() onOpen;
  final bool compact;
  @override
  State<LocalDatabaseShortcut> createState() => _LocalDatabaseShortcutState();
}

// Manage the local database shortcut values and actions.
class _LocalDatabaseShortcutState extends State<LocalDatabaseShortcut> {
  // Keep this component's values, selections, and request state.
  Timer? reset;
  int taps = 0;
  bool opening = false;
  // Count quick taps and open the viewer after the sixth.
  Future<void> tap() async {
    if (opening) return;
    reset?.cancel();
    taps++;
    if (taps < 6) {
      reset = Timer(const Duration(seconds: 3), () => taps = 0);
      return;
    }
    taps = 0;
    opening = true;
    try {
      await widget.onOpen();
    } finally {
      opening = false;
    }
  }

  // Release controllers, timers, and subscriptions held by this component.
  @override
  void dispose() {
    reset?.cancel();
    super.dispose();
  }

  // Render the local database shortcut component.
  @override
  Widget build(BuildContext context) => Semantics(
    hint: 'Tap six times in a row to open the local database',
    child: IconButton(
      key: const ValueKey('local-database-shortcut'),
      tooltip: 'Store',
      onPressed: tap,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(
        width: widget.compact ? 15 : 32,
        height: widget.compact ? 15 : 32,
      ),
      style: IconButton.styleFrom(
        minimumSize: widget.compact ? const Size.square(15) : null,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: const Icon(
        Icons.storefront_outlined,
        size: 15,
        color: InventoryColors.green,
      ),
    ),
  );
}
