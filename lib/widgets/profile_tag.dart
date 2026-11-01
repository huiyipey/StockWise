import 'package:flutter/material.dart';
import 'inventory_ui.dart';

class ProfileTag extends StatelessWidget {
  const ProfileTag(this.label, {super.key, this.pending = false});
  final String label;
  final bool pending;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: pending ? const Color(0xFFFBECD6) : InventoryColors.soft,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: pending ? InventoryColors.amber : InventoryColors.green,
      ),
    ),
  );
}
