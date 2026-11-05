import 'package:flutter/material.dart';
import '../models/store_hours.dart';
import 'inventory_ui.dart';

class StoreHoursEditor extends StatelessWidget {
  const StoreHoursEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });
  final StoreHours value;
  final ValueChanged<StoreHours> onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) => FormField<StoreHours>(
    initialValue: value,
    validator: (_) => value.valid
        ? null
        : 'Closing time must be more than 30 minutes after opening.',
    builder: (field) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Operating Hours',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: InventoryColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final opening in [true, false]) ...[
                if (!opening) const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: !enabled
                        ? null
                        : () async {
                            final current = opening
                                ? value.opens
                                : value.closes;
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: current ~/ 60 % 24,
                                minute: current % 60,
                              ),
                            );
                            if (time == null) return;
                            final minutes = time.hour * 60 + time.minute;
                            final next = opening
                                ? StoreHours(
                                    opens: minutes,
                                    closes: value.closes,
                                    closedDays: value.closedDays,
                                  )
                                : StoreHours(
                                    opens: value.opens,
                                    closes: minutes == 0 ? 1440 : minutes,
                                    closedDays: value.closedDays,
                                  );
                            field.didChange(next);
                            onChanged(next);
                          },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 15,
                      ),
                      side: const BorderSide(color: InventoryColors.line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          opening ? 'Opens' : 'Closes',
                          style: const TextStyle(fontSize: 11),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          value.clock(opening ? value.opens : value.closes),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Hours apply on open days. Orders close 30 minutes before closing.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: InventoryColors.muted,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Closed Days',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: InventoryColors.ink,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Choose any days the store is closed, or leave all unselected for no closed days.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: InventoryColors.muted,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 6,
            children: [
              for (var day = 1; day <= 7; day++)
                FilterChip(
                  key: ValueKey('store-closed-day-$day'),
                  label: Text(StoreHours.dayNames[day - 1]),
                  selected: value.closedDays.contains(day),
                  onSelected: !enabled
                      ? null
                      : (selected) {
                          final next = StoreHours(
                            opens: value.opens,
                            closes: value.closes,
                            closedDays: {...value.closedDays}..remove(day),
                          );
                          final days = {...next.closedDays, if (selected) day};
                          final updated = StoreHours(
                            opens: next.opens,
                            closes: next.closes,
                            closedDays: days,
                          );
                          field.didChange(updated);
                          onChanged(updated);
                        },
                ),
            ],
          ),
          Wrap(
            spacing: 10,
            children: [
              TextButton(
                onPressed: !enabled
                    ? null
                    : () {
                        final next = StoreHours(
                          opens: value.opens,
                          closes: value.closes,
                        );
                        field.didChange(next);
                        onChanged(next);
                      },
                child: const Text('No Closed Days'),
              ),
              TextButton(
                onPressed: !enabled
                    ? null
                    : () {
                        final next = StoreHours(
                          opens: value.opens,
                          closes: value.closes,
                          closedDays: {1, 2, 3, 4, 5, 6, 7},
                        );
                        field.didChange(next);
                        onChanged(next);
                      },
                child: const Text('Closed Every Day'),
              ),
            ],
          ),
          Text(
            value.closedDaysLabel,
            key: const ValueKey('store-closed-days-summary'),
            style: const TextStyle(
              fontSize: 11.5,
              color: InventoryColors.muted,
            ),
          ),
          if (field.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                field.errorText!,
                style: const TextStyle(
                  fontSize: 12,
                  color: InventoryColors.error,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
