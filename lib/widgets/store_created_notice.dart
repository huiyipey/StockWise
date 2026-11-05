import 'package:flutter/material.dart';

import 'inventory_ui.dart';

/// Returns true when the new owner wants to review the default settings now.
Future<bool> showStoreCreatedNotice(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        title: const Text('Your Store Is Ready'),
        content: const Text(
          'Delivery fees and admin settings are using their defaults. '
          'Go to Profile whenever you want to review or edit them.',
          style: TextStyle(color: InventoryColors.muted, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Got It'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open Profile'),
          ),
        ],
      ),
    ) ??
    false;
