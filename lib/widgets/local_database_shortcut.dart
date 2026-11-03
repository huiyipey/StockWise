import 'dart:async';

import 'package:flutter/material.dart';

import 'inventory_ui.dart';

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

class _LocalDatabaseShortcutState extends State<LocalDatabaseShortcut> {
  Timer? reset;
  int taps = 0;
  bool opening = false;
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

  @override
  void dispose() {
    reset?.cancel();
    super.dispose();
  }

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
