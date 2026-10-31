import 'package:flutter/material.dart';

import 'inventory_ui.dart';

Future<DateTimeRange?> showInventoryExpiryRange({
  required BuildContext context,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTimeRange? initialDateRange,
}) => showDialog<DateTimeRange>(
  context: context,
  builder: (_) => InventoryTheme(
    child: _ExpiryRangeDialog(
      first: DateUtils.dateOnly(firstDate),
      last: DateUtils.dateOnly(lastDate),
      initial: initialDateRange,
    ),
  ),
);

class _ExpiryRangeDialog extends StatefulWidget {
  const _ExpiryRangeDialog({
    required this.first,
    required this.last,
    this.initial,
  });
  final DateTime first, last;
  final DateTimeRange? initial;
  @override
  State<_ExpiryRangeDialog> createState() => _ExpiryRangeDialogState();
}

class _ExpiryRangeDialogState extends State<_ExpiryRangeDialog> {
  final start = TextEditingController(), end = TextEditingController();
  String? startError, endError;
  bool initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    initialized = true;
    final locale = MaterialLocalizations.of(context);
    if (widget.initial != null) {
      start.text = locale.formatCompactDate(widget.initial!.start);
      end.text = locale.formatCompactDate(widget.initial!.end);
    }
  }

  @override
  void dispose() {
    start.dispose();
    end.dispose();
    super.dispose();
  }

  bool inBounds(DateTime day) =>
      !day.isBefore(widget.first) && !day.isAfter(widget.last);
  DateTime? parse(String text) =>
      MaterialLocalizations.of(context).parseCompactDate(text.trim());

  void apply() {
    final first = parse(start.text), last = parse(end.text);
    setState(() {
      startError = first == null
          ? 'Enter a valid start date.'
          : !inBounds(first)
          ? 'Date is outside the allowed range.'
          : null;
      endError = last == null
          ? 'Enter a valid end date.'
          : !inBounds(last)
          ? 'Date is outside the allowed range.'
          : first != null && last.isBefore(first)
          ? 'End date must be on or after start date.'
          : null;
    });
    if (startError == null && endError == null) {
      Navigator.pop(context, DateTimeRange(start: first!, end: last!));
    }
  }

  Future<void> calendar() async {
    FocusScope.of(context).unfocus();
    final first = parse(start.text), last = parse(end.text);
    final initial =
        first != null &&
            last != null &&
            inBounds(first) &&
            inBounds(last) &&
            !last.isBefore(first)
        ? DateTimeRange(start: first, end: last)
        : null;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: widget.first,
      lastDate: widget.last,
      initialDateRange: initial,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (_, child) => InventoryTheme(child: child!),
    );
    if (picked != null && mounted) Navigator.pop(context, picked);
  }

  @override
  Widget build(BuildContext context) {
    final help = MaterialLocalizations.of(context).dateHelpText.toUpperCase();
    return Dialog(
      alignment: const Alignment(0, .35),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SizedBox(
        key: const ValueKey('expiry-range-surface'),
        width: 350,
        height: 480,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Enter expiry range',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: InventoryColors.ink,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Select the first and last expiry dates.',
                      style: TextStyle(
                        fontSize: 12,
                        color: InventoryColors.muted,
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      key: const ValueKey('expiry-range-start'),
                      controller: start,
                      style: const TextStyle(
                        fontSize: 13,
                        color: InventoryColors.ink,
                      ),
                      keyboardType: TextInputType.datetime,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() => startError = null),
                      decoration: InputDecoration(
                        labelText: 'Start date / $help',
                        hintText: help,
                        errorText: startError,
                        suffixIcon: IconButton(
                          onPressed: calendar,
                          tooltip: 'Choose start on calendar',
                          icon: const Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      key: const ValueKey('expiry-range-end'),
                      controller: end,
                      style: const TextStyle(
                        fontSize: 13,
                        color: InventoryColors.ink,
                      ),
                      keyboardType: TextInputType.datetime,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => apply(),
                      onChanged: (_) => setState(() => endError = null),
                      decoration: InputDecoration(
                        labelText: 'End date / $help',
                        hintText: help,
                        errorText: endError,
                        suffixIcon: IconButton(
                          onPressed: calendar,
                          tooltip: 'Choose end on calendar',
                          icon: const Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
              child: Theme(
                data: Theme.of(context).copyWith(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  key: const ValueKey('expiry-range-actions'),
                  children: [
                    Expanded(
                      child: InventoryButton(
                        label: 'Cancel',
                        height: 46,
                        soft: true,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: InventoryButton(
                        label: 'OK',
                        height: 46,
                        onPressed: apply,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
