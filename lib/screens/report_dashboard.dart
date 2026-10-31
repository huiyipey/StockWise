import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/report_service.dart';
import '../models/product_name.dart';
import '../theme/app_theme.dart';

class ReportDashboard extends StatefulWidget {
  final Future<Map<String, dynamic>> Function(String, String, String)? loader;
  final Widget? emailStatus;
  const ReportDashboard({super.key, this.loader, this.emailStatus});
  @override
  State<ReportDashboard> createState() => _ReportDashboardState();
}

class _ReportDashboardState extends State<ReportDashboard> {
  String kind = 'sales', period = 'Monthly';
  bool graph = true, downloading = false;
  int page = 0;
  late DateTime start, end;
  late Future<Map<String, dynamic>> result;
  final dateFormat = DateFormat('yyyy-MM-dd');
  @override
  void initState() {
    super.initState();
    _period('Monthly');
  }

  void _load() {
    page = 0;
    result = (widget.loader ?? ReportService.load)(
      kind,
      dateFormat.format(start),
      dateFormat.format(end),
    );
    // Handle immediate failures until FutureBuilder subscribes on the next frame.
    result.ignore();
  }

  void _period(String value) {
    period = value;
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    end = DateTime(now.year, now.month, now.day);
    start = switch (value) {
      'Daily' => end,
      'Weekly' => end.subtract(Duration(days: end.weekday - 1)),
      'Yearly' => DateTime(end.year),
      _ => DateTime(end.year, end.month),
    };
    _load();
  }

  Future<void> _custom() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: start, end: end),
    );
    if (!mounted || picked == null) return;
    if (picked.end.difference(picked.start).inDays >= 366) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Choose up to 366 days.')));
      return;
    }
    setState(() {
      period = 'Custom';
      start = picked.start;
      end = picked.end;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(
            value: 'sales',
            label: Text('Sales'),
            icon: Icon(Icons.trending_up),
          ),
          ButtonSegment(
            value: 'waste',
            label: Text('Waste'),
            icon: Icon(Icons.recycling),
          ),
        ],
        selected: {kind},
        onSelectionChanged: (value) => setState(() {
          kind = value.first;
          _load();
        }),
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 7,
        children: ['Daily', 'Weekly', 'Monthly', 'Yearly', 'Custom']
            .map(
              (p) => ChoiceChip(
                label: Text(p),
                selected: period == p,
                onSelected: (_) =>
                    p == 'Custom' ? _custom() : setState(() => _period(p)),
              ),
            )
            .toList(),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          '${DateFormat('d MMM yyyy').format(start)} – ${DateFormat('d MMM yyyy').format(end)} • Malaysia time',
        ),
      ),
      FutureBuilder<Map<String, dynamic>>(
        future: result,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    const Text(
                      'Could not load the report. Check your connection and try again.',
                    ),
                    TextButton(
                      onPressed: () => setState(_load),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          final data = snapshot.data!;
          final rows = (data['rows'] as List)
              .map((r) => List<dynamic>.from(r as List))
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: kind == 'sales'
                    ? [
                        _metric('Product sales', _money(data['revenueCents'])),
                        _metric('Paid orders', '${data['count']}'),
                        _metric('Delivery fees', _money(data['deliveryCents'])),
                        _metric('Total collected', _money(data['totalCents'])),
                      ]
                    : [
                        _metric('Wasted units', '${data['units']}'),
                        _metric('Waste records', '${data['count']}'),
                      ],
              ),
              const SizedBox(height: 12),
              Text(
                kind == 'sales'
                    ? 'Paid, non-cancelled orders by order date. Delivery fees are separate from product sales.'
                    : 'Recorded discard and expiry events. Expired stock is counted only after it is recorded as waste.',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('Chart')),
                        ButtonSegment(value: false, label: Text('Data')),
                      ],
                      selected: {graph},
                      onSelectionChanged: (v) =>
                          setState(() => graph = v.first),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh report',
                    onPressed: () => setState(_load),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (graph) _chart(data) else _table(data, rows),
              if (kind == 'waste' && graph) ...[
                const SizedBox(height: 12),
                Text(
                  'Waste by category',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                ...Map<String, dynamic>.from(
                  data['categories'] as Map,
                ).entries.map(
                  (e) => ListTile(
                    title: Text(e.key),
                    trailing: Text('${e.value} units'),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: downloading
                    ? null
                    : () async {
                        setState(() => downloading = true);
                        try {
                          final saved = await ReportService.download(data);
                          if (context.mounted && saved) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Report saved.')),
                            );
                          }
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Could not save the report. Please try again.',
                                ),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => downloading = false);
                        }
                      },
                icon: const Icon(Icons.download),
                label: Text(
                  downloading
                      ? 'Saving…'
                      : 'Download ${kind == 'sales' ? 'sales' : 'waste'} report (CSV)',
                ),
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 22),
      const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Team email reports\nWeekly: Monday, 9 AM (previous Monday–Sunday)\nMonthly: 1st day, 9 AM (previous month)\nSales and waste reports go to the store owner and active staff.',
          ),
        ),
      ),
      widget.emailStatus ??
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('systemStatus')
                .doc('reportEmail')
                .snapshots(),
            builder: (context, snapshot) {
              final status = snapshot.data?.data()?['status'];
              return Text(
                status == 'ready'
                    ? 'Email service is configured.'
                    : status == 'delivery_errors'
                    ? 'Some emails need attention. Contact your app administrator.'
                    : 'Email delivery is awaiting sender setup or its first successful run.',
                style: const TextStyle(color: AppColors.muted),
              );
            },
          ),
    ],
  );
  String _money(dynamic n) => 'RM ${((n as num) / 100).toStringAsFixed(2)}';
  Widget _metric(String title, String value) => SizedBox(
    width: 155,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _chart(Map<String, dynamic> data) {
    final daily = (data['daily'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final maxValue = daily.fold<double>(
      1,
      (v, e) => math.max(v, (e['value'] as num).toDouble()),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              kind == 'sales'
                  ? 'Daily product sales (MYR)'
                  : 'Daily waste (units)',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const Text(
              'Swipe to explore dates',
              style: TextStyle(color: AppColors.muted),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: daily.map((d) {
                  final value = (d['value'] as num).toDouble();
                  return SizedBox(
                    width: 68,
                    height: 225,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          kind == 'sales'
                              ? (value / 100).toStringAsFixed(2)
                              : '${value.toInt()}',
                          style: const TextStyle(fontSize: 10),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 28,
                          height: math.max(2, value / maxValue * 155),
                          decoration: BoxDecoration(
                            color: kind == 'sales'
                                ? AppColors.primary
                                : AppColors.danger,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          (d['date'] as String).substring(5),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _table(Map<String, dynamic> data, List<List<dynamic>> rows) => Column(
    children: [
      if (rows.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('No records in this range.'),
        ),
      if (rows.isNotEmpty)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: (data['headers'] as List)
                .map((h) => DataColumn(label: Text('$h')))
                .toList(),
            rows: rows
                .skip(page * 25)
                .take(25)
                .map(
                  (r) => DataRow(
                    cells: r
                        .asMap()
                        .entries
                        .map(
                          (e) => DataCell(
                            Text(
                              kind == 'sales' && e.key >= 2
                                  ? (e.value as num).toStringAsFixed(2)
                                  : kind == 'waste' && e.key == 1
                                  ? capitalizeProductName('${e.value}')
                                  : '${e.value}',
                            ),
                          ),
                        )
                        .toList(),
                  ),
                )
                .toList(),
          ),
        ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: page == 0 ? null : () => setState(() => page--),
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            '${rows.isEmpty ? 0 : page + 1} / ${math.max(1, (rows.length / 25).ceil())}',
          ),
          IconButton(
            onPressed: (page + 1) * 25 >= rows.length
                ? null
                : () => setState(() => page++),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    ],
  );
}
