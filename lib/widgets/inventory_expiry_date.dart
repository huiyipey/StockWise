import 'package:flutter/material.dart';

import 'inventory_ui.dart';

Future<DateTime?> showInventoryExpiryDate({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) => showDialog<DateTime>(
  context: context,
  builder: (_) => InventoryTheme(
    child: _ExpiryDateDialog(
      initial: DateUtils.dateOnly(initialDate),
      first: DateUtils.dateOnly(firstDate),
      last: DateUtils.dateOnly(lastDate),
    ),
  ),
);

class _ExpiryDateDialog extends StatefulWidget {
  const _ExpiryDateDialog({
    required this.initial,
    required this.first,
    required this.last,
  });

  final DateTime initial, first, last;

  @override
  State<_ExpiryDateDialog> createState() => _ExpiryDateDialogState();
}

class _ExpiryDateDialogState extends State<_ExpiryDateDialog> {
  final form = GlobalKey<FormState>();
  late DateTime selected = widget.initial;
  bool input = false;

  void confirm() {
    if (input) {
      if (!form.currentState!.validate()) return;
      form.currentState!.save();
    }
    Navigator.pop(context, selected);
  }

  void toggleEntry() {
    if (input && form.currentState!.validate()) form.currentState!.save();
    FocusScope.of(context).unfocus();
    setState(() => input = !input);
  }

  @override
  Widget build(BuildContext context) {
    final locale = MaterialLocalizations.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        key: const ValueKey('expiry-date-surface'),
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 22, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Choose expiry date',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (!input) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    locale.formatMediumDate(selected),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: InventoryColors.green,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: input
                                ? locale.calendarModeButtonLabel
                                : locale.inputDateModeButtonLabel,
                            onPressed: toggleEntry,
                            color: InventoryColors.green,
                            icon: Icon(
                              input
                                  ? Icons.calendar_today_outlined
                                  : Icons.edit_outlined,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    if (input)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                        child: Form(
                          key: form,
                          child: InputDatePickerFormField(
                            initialDate: selected,
                            firstDate: widget.first,
                            lastDate: widget.last,
                            autofocus: true,
                            fieldLabelText: 'Expiry Date',
                            fieldHintText: locale.dateHelpText,
                            onDateSaved: (value) => selected = value,
                            onDateSubmitted: (value) =>
                                setState(() => selected = value),
                          ),
                        ),
                      )
                    else
                      _ExpiryCalendar(
                        key: const ValueKey('expiry-date-calendar'),
                        selected: selected,
                        firstDate: widget.first,
                        lastDate: widget.last,
                        onDateChanged: (value) =>
                            setState(() => selected = value),
                      ),
                  ],
                ),
              ),
            ),
            InventoryDateActions(
              topPadding: input ? 12 : 8,
              onCancel: () => Navigator.pop(context),
              onConfirm: confirm,
            ),
          ],
        ),
      ),
    );
  }
}

/// Uses the displayed month's actual week count so no empty week sits above
/// the dialog actions. Date cells retain their normal touch height.
class _ExpiryCalendar extends StatefulWidget {
  const _ExpiryCalendar({
    super.key,
    required this.selected,
    required this.firstDate,
    required this.lastDate,
    required this.onDateChanged,
  });

  final DateTime selected, firstDate, lastDate;
  final ValueChanged<DateTime> onDateChanged;

  @override
  State<_ExpiryCalendar> createState() => _ExpiryCalendarState();
}

class _ExpiryCalendarState extends State<_ExpiryCalendar> {
  late DateTime month = DateTime(widget.selected.year, widget.selected.month);
  bool choosingYear = false;

  DateTime get firstMonth =>
      DateTime(widget.firstDate.year, widget.firstDate.month);
  DateTime get lastMonth =>
      DateTime(widget.lastDate.year, widget.lastDate.month);

  void showMonth(DateTime value) {
    if (value.isBefore(firstMonth) || value.isAfter(lastMonth)) return;
    setState(() => month = value);
  }

  @override
  Widget build(BuildContext context) {
    final locale = MaterialLocalizations.of(context);
    final offset = (month.weekday % 7 - locale.firstDayOfWeekIndex + 7) % 7;
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final weeks = (offset + days + 6) ~/ 7;
    final rowHeight = (MediaQuery.textScalerOf(context).scale(16) + 24).clamp(
      48.0,
      double.infinity,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    key: const ValueKey('expiry-calendar-year'),
                    onPressed: () =>
                        setState(() => choosingYear = !choosingYear),
                    style: TextButton.styleFrom(
                      foregroundColor: InventoryColors.muted,
                    ),
                    child: Row(
                      children: [
                        Flexible(child: Text(locale.formatMonthYear(month))),
                        Icon(
                          choosingYear
                              ? Icons.arrow_drop_up
                              : Icons.arrow_drop_down,
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: locale.previousMonthTooltip,
                  onPressed: choosingYear || month == firstMonth
                      ? null
                      : () => showMonth(DateTime(month.year, month.month - 1)),
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  tooltip: locale.nextMonthTooltip,
                  onPressed: choosingYear || month == lastMonth
                      ? null
                      : () => showMonth(DateTime(month.year, month.month + 1)),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        ),
        if (choosingYear)
          SizedBox(
            height: 280,
            child: YearPicker(
              firstDate: widget.firstDate,
              lastDate: widget.lastDate,
              selectedDate: month,
              onChanged: (value) {
                final target = DateTime(value.year, month.month);
                setState(() {
                  month = target.isBefore(firstMonth)
                      ? firstMonth
                      : target.isAfter(lastMonth)
                      ? lastMonth
                      : target;
                  choosingYear = false;
                });
              },
            ),
          )
        else
          GestureDetector(
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity.abs() < 150) return;
              final forward =
                  (velocity < 0) ==
                  (Directionality.of(context) == TextDirection.ltr);
              showMonth(DateTime(month.year, month.month + (forward ? 1 : -1)));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  SizedBox(
                    height: rowHeight,
                    child: Row(
                      children: [
                        for (var i = 0; i < 7; i++)
                          Expanded(
                            child: Center(
                              child: ExcludeSemantics(
                                child: Text(
                                  locale.narrowWeekdays[(i +
                                          locale.firstDayOfWeekIndex) %
                                      7],
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  GridView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisExtent: rowHeight,
                    ),
                    itemCount: weeks * 7,
                    itemBuilder: (context, index) {
                      final number = index - offset + 1;
                      if (number < 1 || number > days) {
                        return const SizedBox.shrink();
                      }
                      final date = DateTime(month.year, month.month, number);
                      final enabled =
                          !date.isBefore(widget.firstDate) &&
                          !date.isAfter(widget.lastDate);
                      final selected = DateUtils.isSameDay(
                        date,
                        widget.selected,
                      );
                      final today = DateUtils.isSameDay(date, DateTime.now());
                      return Semantics(
                        key: ValueKey(
                          'expiry-day-${date.year}-${date.month}-${date.day}',
                        ),
                        label: locale.formatFullDate(date),
                        selected: selected,
                        enabled: enabled,
                        button: true,
                        onTap: enabled
                            ? () => widget.onDateChanged(date)
                            : null,
                        child: ExcludeSemantics(
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: enabled
                                ? () => widget.onDateChanged(date)
                                : null,
                            child: Center(
                              child: Container(
                                width: rowHeight - 8,
                                height: rowHeight - 8,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selected
                                      ? InventoryColors.green
                                      : null,
                                  border: today && !selected
                                      ? Border.all(color: InventoryColors.green)
                                      : null,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    locale.formatDecimal(number),
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: !enabled
                                          ? InventoryColors.muted.withValues(
                                              alpha: .4,
                                            )
                                          : selected
                                          ? Colors.white
                                          : InventoryColors.ink,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
