import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/report_data.dart';
import 'inventory_ui.dart';

class ReportPeriodFilter extends StatelessWidget {
  const ReportPeriodFilter({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final ReportPeriod selected;
  final ValueChanged<ReportPeriod> onSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: constraints.maxWidth),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final value in ReportPeriod.values) ...[
              if (value != ReportPeriod.values.first) const SizedBox(width: 8),
              Semantics(
                selected: selected == value,
                child: TextButton(
                  key: ValueKey('report-period-${value.name}'),
                  onPressed: () => onSelected(value),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(76, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    tapTargetSize: MaterialTapTargetSize.padded,
                    backgroundColor: selected == value
                        ? InventoryColors.soft
                        : Colors.white,
                    foregroundColor: selected == value
                        ? InventoryColors.green
                        : InventoryColors.muted,
                    shape: const StadiumBorder(
                      side: BorderSide(color: InventoryColors.line),
                    ),
                    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      height: 1.2,
                    ),
                  ),
                  child: Text(
                    value == ReportPeriod.custom ? 'Custom' : value.label,
                    softWrap: false,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class ReportSwitch extends StatelessWidget {
  const ReportSwitch({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.soft = false,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final bool soft;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Semantics(
              selected: selected == i,
              child: InkWell(
                borderRadius: BorderRadius.circular(11),
                onTap: () => onSelected(i),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 38),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected == i
                        ? (soft ? InventoryColors.soft : InventoryColors.green)
                        : null,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: soft ? 11.5 : 13,
                      fontWeight: selected == i
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: selected == i
                          ? (soft ? InventoryColors.green : Colors.white)
                          : InventoryColors.muted,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class ReportMetrics extends StatelessWidget {
  const ReportMetrics({super.key, required this.data});
  final ReportSnapshot data;
  @override
  Widget build(BuildContext context) {
    if (data.kind == 'waste') {
      Widget metric(String title, String value, IconData icon, bool primary) =>
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: primary ? InventoryColors.ink : InventoryColors.soft,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: primary
                      ? const Color(0xFFC9DBCA)
                      : InventoryColors.green,
                  size: 21,
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: primary ? 37 : 29,
                    fontWeight: FontWeight.w700,
                    color: primary ? Colors.white : InventoryColors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: primary
                        ? const Color(0xFFC9DBCA)
                        : InventoryColors.muted,
                  ),
                ),
              ],
            ),
          );
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 6,
              child: metric(
                'Wasted Units',
                '${data.units}',
                Icons.delete_outline_rounded,
                true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: metric(
                'Waste Records',
                '${data.records.length}',
                Icons.description_outlined,
                false,
              ),
            ),
          ],
        ),
      );
    }
    final metrics = [
      ('Paid Orders', '${data.records.length}'),
      ('Delivery Fees', reportMoney(data.deliveryCents)),
      ('Total Collected', reportMoney(data.totalCents)),
    ];
    Widget small((String, String) metric) => Container(
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(minHeight: 80),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.$1,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: InventoryColors.muted,
            ),
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              metric.$2,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 116),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: InventoryColors.ink,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PRODUCT SALES',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFFC9DBCA),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  reportMoney(data.productCents),
                  style: const TextStyle(
                    fontSize: 32,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 290 ||
                MediaQuery.textScalerOf(context).scale(10) > 14) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final metric in metrics)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: small(metric),
                    ),
                ],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < metrics.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: small(metrics[i])),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class ReportChart extends StatefulWidget {
  const ReportChart({
    super.key,
    required this.data,
    required this.window,
    required this.today,
    required this.selected,
    required this.onSelected,
  });
  final ReportSnapshot data;
  final ReportWindow window;
  final DateTime today;
  final int selected;
  final ValueChanged<int> onSelected;
  @override
  State<ReportChart> createState() => _ReportChartState();
}

class _ReportChartState extends State<ReportChart> {
  final scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients || widget.selected == 0) return;
      final width = widget.window.period == ReportPeriod.monthly
          ? 96.0
          : widget.window.period == ReportPeriod.yearly
          ? 70.0
          : 48.0;
      final offset =
          (widget.selected * width -
                  scroll.position.viewportDimension / 2 +
                  width / 2)
              .clamp(0.0, scroll.position.maxScrollExtent);
      scroll.jumpTo(offset);
    });
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sales = widget.data.kind == 'sales';
    final selections = widget.window.buckets.map(widget.data.select).toList();
    final values = selections
        .map(
          (value) => sales ? value.productCents / 100 : value.units.toDouble(),
        )
        .toList();
    final largest = values.fold<double>(0, math.max);
    final power = math
        .pow(10, largest > 0 ? (math.log(largest) / math.ln10).floor() : 0)
        .toDouble();
    var maximum = largest <= 0 ? 2.0 : (largest / power).ceil() * power;
    if (sales) {
      maximum = math.max(2, (maximum * 100 / 2).ceil() * 2) / 100;
    } else {
      maximum = math.max(2, (maximum / 2).ceil() * 2).toDouble();
    }
    final scaler = MediaQuery.textScalerOf(context);
    final baseline = 160 + scaler.scale(10) * 1.4 + 8;
    final labelHeight = math.max(38.0, scaler.scale(11) * 2.6);
    final height = baseline + 8 + labelHeight;
    final width = widget.window.period == ReportPeriod.monthly
        ? 96.0
        : widget.window.period == ReportPeriod.yearly
        ? 70.0
        : 48.0;
    final compact = NumberFormat.compact(locale: 'en');
    final selected = selections[widget.selected];
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.window.granularity} ${sales ? 'product sales (MYR)' : 'waste (Units)'}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '${selected.bucket.label} · ${sales ? reportMoney(selected.productCents) : '${selected.units} units'}',
              style: const TextStyle(
                fontSize: 11,
                color: InventoryColors.muted,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final overflowing =
                    widget.window.buckets.length * width >
                    constraints.maxWidth - 34;
                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 34,
                          height: baseline,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              for (var i = 0; i < 3; i++)
                                Positioned(
                                  right: 8,
                                  bottom: i * 80 - 5,
                                  child: Text(
                                    compact.format(maximum * i / 2),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: InventoryColors.muted,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Scrollbar(
                            controller: scroll,
                            thumbVisibility: overflowing,
                            child: SingleChildScrollView(
                              key: const ValueKey('report-chart-scroll'),
                              controller: scroll,
                              scrollDirection: Axis.horizontal,
                              child: CustomPaint(
                                painter: _ReportGrid(baseline),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    for (var i = 0; i < selections.length; i++)
                                      Builder(
                                        builder: (context) {
                                          final bucket = selections[i].bucket;
                                          final upcoming = bucket.upcoming(
                                            widget.today,
                                          );
                                          final barHeight = math.max(
                                            2.0,
                                            math.max(0, values[i]) /
                                                maximum *
                                                160,
                                          );
                                          final color = sales
                                              ? InventoryColors.green
                                              : InventoryColors.amber;
                                          return Tooltip(
                                            message:
                                                '${bucket.label}: ${upcoming
                                                    ? 'Upcoming'
                                                    : sales
                                                    ? reportMoney(selections[i].productCents)
                                                    : '${selections[i].units} units'}',
                                            child: Semantics(
                                              selected: widget.selected == i,
                                              enabled: !upcoming,
                                              child: InkWell(
                                                key: ValueKey('report-bar-$i'),
                                                onTap: upcoming
                                                    ? null
                                                    : () =>
                                                          widget.onSelected(i),
                                                borderRadius:
                                                    BorderRadius.circular(9),
                                                child: Container(
                                                  width: width,
                                                  height: height,
                                                  decoration: BoxDecoration(
                                                    color: widget.selected == i
                                                        ? InventoryColors.soft
                                                              .withValues(
                                                                alpha: .5,
                                                              )
                                                        : null,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          9,
                                                        ),
                                                  ),
                                                  child: Column(
                                                    children: [
                                                      SizedBox(
                                                        height: baseline,
                                                        child: Stack(
                                                          alignment: Alignment
                                                              .bottomCenter,
                                                          clipBehavior:
                                                              Clip.none,
                                                          children: [
                                                            Container(
                                                              width: 20,
                                                              height: barHeight,
                                                              decoration: BoxDecoration(
                                                                color: upcoming
                                                                    ? InventoryColors
                                                                          .line
                                                                    : color,
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      5,
                                                                    ),
                                                              ),
                                                            ),
                                                            Positioned(
                                                              bottom:
                                                                  barHeight + 4,
                                                              left: 1,
                                                              right: 1,
                                                              child: FittedBox(
                                                                fit: BoxFit
                                                                    .scaleDown,
                                                                child: Text(
                                                                  upcoming
                                                                      ? '—'
                                                                      : sales
                                                                      ? values[i]
                                                                            .toStringAsFixed(
                                                                              2,
                                                                            )
                                                                      : '${selections[i].units}',
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        10,
                                                                    color:
                                                                        upcoming
                                                                        ? InventoryColors
                                                                              .muted
                                                                        : InventoryColors
                                                                              .ink,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Expanded(
                                                        child: Align(
                                                          alignment: Alignment
                                                              .topCenter,
                                                          child: Text(
                                                            widget
                                                                        .window
                                                                        .period ==
                                                                    ReportPeriod
                                                                        .monthly
                                                                ? bucket
                                                                      .axisLabel
                                                                      .replaceFirst(
                                                                        ' ',
                                                                        '\n',
                                                                      )
                                                                : bucket
                                                                      .axisLabel,
                                                            textAlign: TextAlign
                                                                .center,
                                                            style: TextStyle(
                                                              fontSize: 10.5,
                                                              color: upcoming
                                                                  ? InventoryColors
                                                                        .muted
                                                                        .withValues(
                                                                          alpha:
                                                                              .6,
                                                                        )
                                                                  : widget.selected ==
                                                                        i
                                                                  ? InventoryColors
                                                                        .green
                                                                  : InventoryColors
                                                                        .muted,
                                                              fontWeight:
                                                                  widget.selected ==
                                                                      i
                                                                  ? FontWeight
                                                                        .w700
                                                                  : FontWeight
                                                                        .w400,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
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
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      overflowing
                          ? 'Swipe for more dates'
                          : 'Tap a bar to view records',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        color: InventoryColors.muted,
                      ),
                    ),
                  ],
                );
              },
            ),
            const Text(
              'Tap a bar to view records in data',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9.5, color: InventoryColors.muted),
            ),
            if (widget.data.records.isEmpty) ...[
              const SizedBox(height: 20),
              Text(
                sales ? 'No sales in this range' : 'No waste in this range',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportGrid extends CustomPainter {
  const _ReportGrid(this.baseline);
  final double baseline;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = InventoryColors.line
      ..strokeWidth = .6;
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(0, baseline - i * 80),
        Offset(size.width, baseline - i * 80),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ReportGrid old) => old.baseline != baseline;
}

class ReportRecords extends StatefulWidget {
  const ReportRecords({
    super.key,
    required this.selection,
    required this.page,
    required this.onPage,
  });
  final ReportSelection selection;
  final int page;
  final ValueChanged<int> onPage;
  @override
  State<ReportRecords> createState() => _ReportRecordsState();
}

class _ReportRecordsState extends State<ReportRecords> {
  final scroll = ScrollController();
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.selection;
    final sales = data.kind == 'sales';
    final rows = data.records.skip(widget.page * 25).take(25).toList();
    final pages = (data.records.length / 25).ceil();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              sales ? 'Sales records' : 'Waste records',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              data.bucket.label,
              key: const ValueKey('report-selected-period'),
              style: const TextStyle(
                fontSize: 12,
                color: InventoryColors.green,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (rows.isNotEmpty)
              Text(
                'Records ${widget.page * 25 + 1}-${widget.page * 25 + rows.length} of ${data.records.length}',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: InventoryColors.muted,
                ),
              ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Column(
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      size: 38,
                      color: InventoryColors.muted,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No records for this ${data.bucket.start == data.bucket.end ? "date" : "period"}.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: InventoryColors.muted,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              const SizedBox(height: 12),
              Scrollbar(
                controller: scroll,
                thumbVisibility: true,
                trackVisibility: true,
                thickness: 3,
                child: SingleChildScrollView(
                  key: const ValueKey('report-records-scroll'),
                  controller: scroll,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 14),
                  child: DataTable(
                    horizontalMargin: 0,
                    columnSpacing: 18,
                    headingRowHeight: math.max(
                      64,
                      MediaQuery.textScalerOf(context).scale(10) * 4.5,
                    ),
                    dataRowMinHeight: 66,
                    dataRowMaxHeight: double.infinity,
                    dividerThickness: .6,
                    headingTextStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: InventoryColors.muted,
                    ),
                    columns: [
                      for (var i = 0; i < data.headers.length; i++)
                        DataColumn(
                          numeric: sales ? i > 0 : i == 3,
                          label: SizedBox(
                            width: i == 0
                                ? 148
                                : i == 3
                                ? 94
                                : 115,
                            child: Text(
                              data.headers[i],
                              textAlign: (sales && i > 0) || (!sales && i == 3)
                                  ? TextAlign.right
                                  : TextAlign.left,
                            ),
                          ),
                        ),
                    ],
                    rows: rows.map((row) {
                      final cells = row.cells(data.kind);
                      return DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 148,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormat('d MMM yyyy').format(row.date),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: InventoryColors.muted,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      row.reference,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          for (var i = 1; i < cells.length; i++)
                            DataCell(
                              SizedBox(
                                width: i == 3 ? 94 : 115,
                                child: Text(
                                  cells[i],
                                  textAlign: sales || i == 3
                                      ? TextAlign.right
                                      : TextAlign.left,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: sales || i == 3
                                        ? InventoryColors.green
                                        : InventoryColors.muted,
                                    fontWeight: sales || i == 3
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Swipe to see all columns',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: InventoryColors.muted),
              ),
              const SizedBox(height: 16),
              Text(
                sales
                    ? 'Selected total: ${reportMoney(data.totalCents)}'
                    : 'Selected total: ${data.units} units',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (pages > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Previous records',
                      onPressed: widget.page == 0
                          ? null
                          : () => widget.onPage(widget.page - 1),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        '${widget.page + 1} / $pages',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next records',
                      onPressed: widget.page + 1 >= pages
                          ? null
                          : () => widget.onPage(widget.page + 1),
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class ReportCategories extends StatelessWidget {
  const ReportCategories({super.key, required this.selection});
  final ReportSelection selection;
  @override
  Widget build(BuildContext context) {
    final entries = selection.categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maximum = entries.isEmpty ? 1 : math.max(1, entries.first.value);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Waste by category',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              selection.bucket.label,
              style: const TextStyle(
                fontSize: 11,
                color: InventoryColors.green,
              ),
            ),
            const SizedBox(height: 20),
            if (entries.isEmpty)
              const Text(
                'No waste recorded for this period.',
                style: TextStyle(fontSize: 12, color: InventoryColors.muted),
              ),
            for (var i = 0; i < entries.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entries[i].key,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${entries[i].value} units',
                          style: const TextStyle(
                            fontSize: 11,
                            color: InventoryColors.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: entries[i].value / maximum,
                        minHeight: 5,
                        backgroundColor: const Color(0xFFEDF0EC),
                        color: i == 0
                            ? InventoryColors.green
                            : const Color(0xFF9AAF96),
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
}

class ReportEmailCard extends StatelessWidget {
  const ReportEmailCard({super.key, required this.status});
  final Widget status;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: InventoryColors.soft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.mail_outline_rounded,
                      color: InventoryColors.green,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Team email reports',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Scheduled automatically',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: InventoryColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(height: 1),
              ),
              for (final row in [
                ('Weekly', 'Monday / 9 AM', 'Previous Monday - Sunday'),
                ('Monthly', '1st day / 9 AM', 'Previous month'),
              ]) ...[
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Text(
                      row.$1,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      row.$2,
                      style: const TextStyle(
                        fontSize: 12,
                        color: InventoryColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  row.$3,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: InventoryColors.muted,
                  ),
                ),
                const SizedBox(height: 20),
              ],
              const Text(
                'Store owner and active staff / Malaysia time',
                style: TextStyle(fontSize: 10, color: InventoryColors.muted),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      status,
    ],
  );
}

class ReportNotice extends StatelessWidget {
  const ReportNotice({super.key, required this.message, this.error = false});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: error ? const Color(0xFFFAE7E0) : InventoryColors.soft,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 17,
          color: error ? InventoryColors.error : InventoryColors.green,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: error ? InventoryColors.error : InventoryColors.green,
            ),
          ),
        ),
      ],
    ),
  );
}
