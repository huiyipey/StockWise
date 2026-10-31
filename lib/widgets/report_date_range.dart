import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/report_data.dart';
import 'inventory_ui.dart';

Future<DateTimeRange?> showReportDateRange({
  required BuildContext context,
  required DateTime firstDate,
  required DateTime lastDate,
  required DateTimeRange initial,
}) => Navigator.push<DateTimeRange>(
  context,
  MaterialPageRoute(
    builder: (_) => ReportDateRangePage(
      firstDate: firstDate,
      lastDate: lastDate,
      initial: initial,
    ),
  ),
);

class ReportDateRangePage extends StatefulWidget {
  const ReportDateRangePage({
    super.key,
    required this.firstDate,
    required this.lastDate,
    required this.initial,
  });
  final DateTime firstDate, lastDate;
  final DateTimeRange initial;
  @override
  State<ReportDateRangePage> createState() => _ReportDateRangePageState();
}

class _ReportDateRangePageState extends State<ReportDateRangePage> {
  DateTime? start, end;
  late DateTime month;
  bool years = false;
  @override
  void initState() {
    super.initState();
    start = widget.initial.start;
    end = widget.initial.end;
    month = DateTime(start!.year, start!.month);
  }

  bool get tooLong =>
      start != null && end != null && reportDayCount(start!, end!) > 366;
  void pick(DateTime value) => setState(() {
    if (start == null || end != null) {
      start = value;
      end = null;
    } else if (value.isBefore(start!)) {
      end = start;
      start = value;
    } else {
      end = value;
    }
  });
  Future<void> manual() async {
    final picked = await showDialog<DateTimeRange>(
      context: context,
      builder: (_) => InventoryTheme(
        child: _ReportDateEntry(
          first: widget.firstDate,
          last: widget.lastDate,
          start: start,
          end: end,
        ),
      ),
    );
    if (picked != null && mounted) Navigator.pop(context, picked);
  }

  @override
  Widget build(BuildContext context) => InventoryTheme(
    child: Builder(
      builder: (context) {
        final locale = MaterialLocalizations.of(context);
        final firstMonth = DateTime(
          widget.firstDate.year,
          widget.firstDate.month,
        );
        final lastMonth = DateTime(widget.lastDate.year, widget.lastDate.month);
        final offset = (month.weekday % 7 - locale.firstDayOfWeekIndex + 7) % 7;
        final days = DateUtils.getDaysInMonth(month.year, month.month);
        final rows = (offset + days + 6) ~/ 7;
        final rowHeight = (MediaQuery.textScalerOf(context).scale(16) + 24)
            .clamp(48.0, double.infinity);
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                InventoryHeader(
                  title: 'Report date range',
                  back: true,
                  onBack: () => Navigator.pop(context),
                  trailing: IconButton(
                    tooltip: 'Enter report range',
                    onPressed: manual,
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: InventoryColors.green,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Select a range',
                          style: TextStyle(
                            fontSize: 12,
                            color: InventoryColors.muted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${start == null ? 'Start date' : DateFormat('d MMM yyyy').format(start!)} - ${end == null ? 'End date' : DateFormat('d MMM yyyy').format(end!)}',
                          key: const ValueKey('report-range-selection'),
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Divider(height: 1),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => setState(() => years = !years),
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        DateFormat('MMMM yyyy').format(month),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      years
                                          ? Icons.arrow_drop_up
                                          : Icons.arrow_drop_down,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: locale.previousMonthTooltip,
                              onPressed: years || month == firstMonth
                                  ? null
                                  : () => setState(
                                      () => month = DateTime(
                                        month.year,
                                        month.month - 1,
                                      ),
                                    ),
                              icon: const Icon(Icons.chevron_left),
                            ),
                            IconButton(
                              tooltip: locale.nextMonthTooltip,
                              onPressed: years || month == lastMonth
                                  ? null
                                  : () => setState(
                                      () => month = DateTime(
                                        month.year,
                                        month.month + 1,
                                      ),
                                    ),
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                        if (years)
                          SizedBox(
                            height: 280,
                            child: YearPicker(
                              firstDate: widget.firstDate,
                              lastDate: widget.lastDate,
                              selectedDate: month,
                              onChanged: (value) => setState(() {
                                final target = DateTime(
                                  value.year,
                                  month.month,
                                );
                                month = target.isBefore(firstMonth)
                                    ? firstMonth
                                    : target.isAfter(lastMonth)
                                    ? lastMonth
                                    : target;
                                years = false;
                              }),
                            ),
                          )
                        else ...[
                          SizedBox(
                            height: rowHeight,
                            child: Row(
                              children: [
                                for (var i = 0; i < 7; i++)
                                  Expanded(
                                    child: Center(
                                      child: Text(
                                        locale.narrowWeekdays[(i +
                                                locale.firstDayOfWeekIndex) %
                                            7],
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: InventoryColors.muted,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 7,
                                  mainAxisExtent: rowHeight,
                                ),
                            itemCount: rows * 7,
                            itemBuilder: (context, index) {
                              final number = index - offset + 1;
                              if (number < 1 || number > days) {
                                return const SizedBox.shrink();
                              }
                              final date = DateTime(
                                month.year,
                                month.month,
                                number,
                              );
                              final enabled =
                                  !date.isBefore(widget.firstDate) &&
                                  !date.isAfter(widget.lastDate);
                              final edge =
                                  DateUtils.isSameDay(start, date) ||
                                  DateUtils.isSameDay(end, date);
                              final inside =
                                  start != null &&
                                  end != null &&
                                  !date.isBefore(start!) &&
                                  !date.isAfter(end!);
                              return Semantics(
                                label: locale.formatFullDate(date),
                                selected: edge || inside,
                                enabled: enabled,
                                button: true,
                                onTap: enabled ? () => pick(date) : null,
                                child: ExcludeSemantics(
                                  child: InkWell(
                                    key: ValueKey('report-range-day-$number'),
                                    onTap: enabled ? () => pick(date) : null,
                                    child: Center(
                                      child: Container(
                                        height: rowHeight - 8,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: inside
                                              ? InventoryColors.soft
                                              : null,
                                        ),
                                        child: Container(
                                          width: rowHeight - 8,
                                          height: rowHeight - 8,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: edge
                                                ? InventoryColors.green
                                                : null,
                                            shape: BoxShape.circle,
                                          ),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              '$number',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: !enabled
                                                    ? InventoryColors.muted
                                                          .withValues(alpha: .4)
                                                    : edge
                                                    ? Colors.white
                                                    : InventoryColors.ink,
                                              ),
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
                        const SizedBox(height: 22),
                        Text(
                          tooLong ? 'Choose up to 366 days.' : 'Up to 366 days',
                          style: TextStyle(
                            fontSize: 11,
                            color: tooLong
                                ? InventoryColors.error
                                : InventoryColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InventoryButton(
                        key: const ValueKey('report-range-apply'),
                        label: 'Apply range',
                        onPressed: start == null || end == null || tooLong
                            ? null
                            : () => Navigator.pop(
                                context,
                                DateTimeRange(start: start!, end: end!),
                              ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _ReportDateEntry extends StatefulWidget {
  const _ReportDateEntry({
    required this.first,
    required this.last,
    this.start,
    this.end,
  });
  final DateTime first, last;
  final DateTime? start, end;
  @override
  State<_ReportDateEntry> createState() => _ReportDateEntryState();
}

class _ReportDateEntryState extends State<_ReportDateEntry> {
  final form = GlobalKey<FormState>();
  final format = DateFormat('dd/MM/yyyy');
  late final start = TextEditingController(
    text: widget.start == null ? '' : format.format(widget.start!),
  );
  late final end = TextEditingController(
    text: widget.end == null ? '' : format.format(widget.end!),
  );
  @override
  void dispose() {
    start.dispose();
    end.dispose();
    super.dispose();
  }

  DateTime? parse(String value) {
    try {
      return reportDay(format.parseStrict(value.trim()));
    } catch (_) {
      return null;
    }
  }

  String? validate(String? value, bool last) {
    final date = parse(value ?? '');
    if (date == null) return 'Enter a valid date.';
    if (date.isBefore(widget.first) || date.isAfter(widget.last)) {
      return 'Choose a date in the available range.';
    }
    final first = parse(start.text);
    if (last && first != null) {
      if (date.isBefore(first)) {
        return 'End date must be on or after start date.';
      }
      if (reportDayCount(first, date) > 366) return 'Choose up to 366 days.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    child: SizedBox(
      width: 350,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Enter report range',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'DD/MM/YYYY',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: InventoryColors.muted,
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextFormField(
                      key: const ValueKey('report-range-start'),
                      controller: start,
                      keyboardType: TextInputType.datetime,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Start date',
                        hintText: 'DD/MM/YYYY',
                      ),
                      validator: (value) => validate(value, false),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      key: const ValueKey('report-range-end'),
                      controller: end,
                      keyboardType: TextInputType.datetime,
                      decoration: const InputDecoration(
                        labelText: 'End date',
                        hintText: 'DD/MM/YYYY',
                      ),
                      validator: (value) => validate(value, true),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
            child: Row(
              children: [
                Expanded(
                  child: InventoryButton(
                    label: 'Cancel',
                    soft: true,
                    height: 46,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: InventoryButton(
                    label: 'Apply',
                    height: 46,
                    onPressed: () {
                      if (form.currentState!.validate()) {
                        Navigator.pop(
                          context,
                          DateTimeRange(
                            start: parse(start.text)!,
                            end: parse(end.text)!,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
