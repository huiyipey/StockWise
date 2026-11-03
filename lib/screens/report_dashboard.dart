import 'package:flutter/material.dart';

import '../models/report_data.dart';
import '../services/report_service.dart';
import '../services/store_session.dart';
import '../widgets/inventory_ui.dart';
import '../widgets/report_date_range.dart';
import '../widgets/report_ui.dart';

class ReportDashboard extends StatefulWidget {
  const ReportDashboard({
    super.key,
    this.loader,
    this.emailStatus,
    this.downloader,
    this.today,
    this.storeOpenedAt,
  });
  final Future<Map<String, dynamic>> Function(String, String, String)? loader;
  final Future<bool> Function(Map<String, dynamic>)? downloader;
  final Widget? emailStatus;
  final DateTime? today, storeOpenedAt;
  @override
  State<ReportDashboard> createState() => _ReportDashboardState();
}

class _ReportDashboardState extends State<ReportDashboard> {
  String kind = 'sales';
  ReportPeriod period = ReportPeriod.monthly;
  bool graph = true, downloading = false, loading = true, failed = false;
  int page = 0, selected = 0, generation = 0;
  ReportSnapshot? data;
  DateTime? opened, customStart, customEnd;
  late final DateTime today;
  late ReportWindow window;
  Future<DateTime?>? registration;
  final contentAnchor = GlobalKey();

  @override
  void initState() {
    super.initState();
    today = widget.today == null
        ? malaysiaReportDay(DateTime.now())
        : reportDay(widget.today!);
    opened = widget.storeOpenedAt == null
        ? null
        : reportDay(widget.storeOpenedAt!);
    registration = readRegistration();
    window = makeWindow();
    load();
  }

  Future<DateTime?> readRegistration() => opened != null
      ? Future.value(opened)
      : widget.loader != null
      ? Future.value(null)
      : ReportService.registeredAt().then(
          (value) => value == null ? null : malaysiaReportDay(value),
        );

  ReportWindow makeWindow() => ReportWindow.forPeriod(
    period,
    today,
    openedAt: opened,
    customStart: customStart,
    customEnd: customEnd,
  );

  Future<void> load() async {
    final token = ++generation;
    loading = true;
    failed = false;
    selected = 0;
    page = 0;
    try {
      final registered = await (registration ??= readRegistration());
      if (!mounted || token != generation) return;
      opened ??= registered;
      final current = makeWindow();
      final currentKind = kind;
      final first = opened != null && opened!.isAfter(current.start)
          ? opened!
          : current.start;
      final last = current.end.isAfter(today) ? today : current.end;
      final raw = first.isAfter(last)
          ? <String, dynamic>{
              'rows': <List<dynamic>>[],
              'storeName': StoreSession.instance.store?.name ?? 'StockWise',
            }
          : await (widget.loader ?? ReportService.load)(
              currentKind,
              reportIso(first),
              reportIso(last),
            );
      if (!mounted || token != generation) return;
      setState(() {
        window = current;
        data = ReportSnapshot.fromMap(
          currentKind,
          raw,
          firstDate: first,
          lastDate: last,
        );
        loading = false;
      });
    } catch (_) {
      if (mounted && token == generation) {
        setState(() {
          registration = null;
          loading = false;
          failed = true;
          data = null;
        });
      }
    }
  }

  Future<void> choosePeriod(ReportPeriod picked) async {
    if (picked == period && picked != ReportPeriod.custom) return;
    if (picked == ReportPeriod.custom) {
      final first = opened ?? DateTime(2020);
      var initialStart = window.start.isBefore(first) ? first : window.start;
      final initialEnd = window.end.isAfter(today) ? today : window.end;
      if (initialStart.isAfter(initialEnd)) initialStart = initialEnd;
      if (reportDayCount(initialStart, initialEnd) > 366) {
        initialStart = DateTime(initialEnd.year, initialEnd.month);
      }
      final range = await showReportDateRange(
        context: context,
        firstDate: first,
        lastDate: today,
        initial: DateTimeRange(start: initialStart, end: initialEnd),
      );
      if (!mounted || range == null) return;
      customStart = range.start;
      customEnd = range.end;
    }
    setState(() {
      period = picked;
      window = makeWindow();
      load();
    });
  }

  Future<void> download() async {
    if (downloading || loading || data == null) return;
    final selection = data!.select(window.buckets[selected]);
    if (selection.bucket.upcoming(today)) return;
    final export = selection.export(
      storeName: data!.storeName,
      today: today,
      openedAt: opened,
    );
    setState(() => downloading = true);
    try {
      final saved = await (widget.downloader ?? ReportService.download)(export);
      if (mounted && saved) {
        feedback('Report saved.');
      }
    } catch (_) {
      if (mounted) {
        feedback('Could not save the report. Please try again.', error: true);
      }
    } finally {
      if (mounted) setState(() => downloading = false);
    }
  }

  void feedback(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(inventoryFeedback(message, error: error));
  }

  void openRecords(int index) => setState(() {
    selected = index;
    page = 0;
  });

  @override
  Widget build(BuildContext context) => InventoryTheme(
    child: Builder(
      builder: (context) {
        final selection = data?.select(window.buckets[selected]);
        return ListView(
          key: const ValueKey('report-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            ReportSwitch(
              labels: const ['Sales', 'Waste'],
              selected: kind == 'sales' ? 0 : 1,
              onSelected: (value) {
                if ((value == 0 ? 'sales' : 'waste') != kind) {
                  setState(() {
                    kind = value == 0 ? 'sales' : 'waste';
                    load();
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            ReportPeriodFilter(
              key: const ValueKey('report-period'),
              selected: period,
              onSelected: choosePeriod,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    window.dateLabel,
                    key: const ValueKey('report-date-range'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (loading) ...[
              for (final height in [116.0, 80.0, 218.0])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    height: height,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8ECE7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: height == 218
                        ? const Center(child: CircularProgressIndicator())
                        : null,
                  ),
                ),
            ] else if (failed) ...[
              const SizedBox(height: 60),
              const InventoryEmpty(
                title: 'Could not load the report',
                body: 'Check your connection and try again.',
                icon: Icons.bar_chart_rounded,
              ),
              const SizedBox(height: 20),
              InventoryButton(
                label: 'Retry',
                icon: Icons.refresh_rounded,
                onPressed: () => setState(() {
                  load();
                }),
              ),
            ] else if (data != null && selection != null) ...[
              ReportMetrics(data: data!),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ReportSwitch(
                      labels: const ['Chart', 'Data'],
                      selected: graph ? 0 : 1,
                      soft: true,
                      onSelected: (value) => setState(() => graph = value == 0),
                    ),
                  ),
                  const SizedBox(width: 14),
                  IconButton(
                    key: const ValueKey('report-refresh-icon'),
                    tooltip: 'Refresh report',
                    onPressed: loading
                        ? null
                        : () => setState(() {
                            load();
                          }),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: InventoryColors.green,
                      minimumSize: const Size.square(40),
                    ),
                    icon: loading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                key: contentAnchor,
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ClipRect(
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(child is ReportRecords ? 1 : -1, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                ),
                child: graph
                    ? ReportChart(
                        key: ValueKey('chart-$kind-${period.name}'),
                        data: data!,
                        window: window,
                        today: today,
                        selected: selected,
                        onSelected: openRecords,
                      )
                    : ReportRecords(
                        key: ValueKey(
                          'data-$kind-${reportIso(selection.bucket.start)}',
                        ),
                        selection: selection,
                        page: page,
                        onPage: (value) => setState(() => page = value),
                      ),
              ),
              if (kind == 'waste') ...[
                const SizedBox(height: 16),
                ReportCategories(selection: selection),
              ],
              const SizedBox(height: 20),
              InventoryButton(
                key: const ValueKey('report-download'),
                label: downloading ? 'Saving...' : 'Download CSV',
                busy: downloading,
                icon: Icons.download_rounded,
                onPressed: downloading ? null : download,
              ),
              const SizedBox(height: 10),
              Text(
                'All ${selection.bucket.label} records',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: InventoryColors.muted,
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
}
