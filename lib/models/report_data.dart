import 'package:intl/intl.dart';

import 'category_label.dart';
import 'product_name.dart';

// Define the weekday labels used by report calendars.
int calendarWeekDays(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

// Remove the time part from a report date.
DateTime reportDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);
// Count inclusive calendar days in the report interval.
int reportDayCount(DateTime first, DateTime last) =>
    DateTime.utc(
      last.year,
      last.month,
      last.day,
    ).difference(DateTime.utc(first.year, first.month, first.day)).inDays +
    1;
// Convert the instant to a Malaysia calendar date.
DateTime malaysiaReportDay(DateTime instant) =>
    reportDay(instant.toUtc().add(const Duration(hours: 8)));
// Format the report date as year-month-day.
String reportIso(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
// Format a date for report labels.
String reportDate(DateTime value) => DateFormat('d MMMM yyyy').format(value);
// Format integer cents as a MYR amount.
String reportMoney(int cents) =>
    'RM ${NumberFormat('#,##0.00', 'en').format(cents / 100)}';

// Choose daily, weekly, monthly, yearly, or custom reporting.
enum ReportPeriod {
  daily('Daily'),
  weekly('Weekly'),
  monthly('Monthly'),
  yearly('Yearly'),
  custom('Custom range');

  const ReportPeriod(this.label);
  final String label;
}

// Represent one selectable day, ISO week, month, or year.
class ReportBucket {
  const ReportBucket({
    required this.start,
    required this.end,
    required this.label,
    required this.axisLabel,
  });
  final DateTime start, end;
  final String label, axisLabel;
  // Check whether the date belongs to this report bucket.
  bool contains(DateTime date) => !date.isBefore(start) && !date.isAfter(end);
  // Check whether this bucket falls after today.
  bool upcoming(DateTime today) => start.isAfter(today);
}

// Define the calendar buckets and request boundaries for a report.
class ReportWindow {
  const ReportWindow({
    required this.period,
    required this.start,
    required this.end,
    required this.buckets,
  });
  final ReportPeriod period;
  final DateTime start, end;
  final List<ReportBucket> buckets;

  // Build the calendar buckets for the selected report period.
  factory ReportWindow.forPeriod(
    ReportPeriod period,
    DateTime today, {
    DateTime? openedAt,
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    today = reportDay(today);
    late DateTime start, end;
    switch (period) {
      case ReportPeriod.daily:
        start = DateTime(today.year, today.month);
        end = DateTime(today.year, today.month + 1, 0);
      case ReportPeriod.monthly:
        start = DateTime(today.year);
        end = DateTime(today.year, 12, 31);
      case ReportPeriod.yearly:
        final earliest = today.year - 4;
        final firstYear = openedAt == null
            ? earliest
            : openedAt.year.clamp(earliest, today.year);
        start = openedAt != null && openedAt.year == firstYear
            ? reportDay(openedAt)
            : DateTime(firstYear);
        end = DateTime(today.year, 12, 31);
      case ReportPeriod.weekly:
        // Find Monday of ISO week one for the given year.
        DateTime firstIsoMonday(int year) {
          final jan4 = DateTime(year, 1, 4);
          return DateTime(year, 1, 5 - jan4.weekday);
        }
        // The Thursday identifies the ISO week-year at New Year boundaries.
        final weekYear = DateTime(
          today.year,
          today.month,
          today.day + DateTime.thursday - today.weekday,
        ).year;
        start = firstIsoMonday(weekYear);
        final nextYear = firstIsoMonday(weekYear + 1);
        end = DateTime(nextYear.year, nextYear.month, nextYear.day - 1);
      case ReportPeriod.custom:
        if (customStart == null || customEnd == null) {
          throw ArgumentError('Choose a date range.');
        }
        start = reportDay(customStart);
        end = reportDay(customEnd);
        if (end.isBefore(start) || reportDayCount(start, end) > 366) {
          throw ArgumentError('Choose a range of 1 to 366 days.');
        }
    }
    final buckets = <ReportBucket>[];
    for (var cursor = start; !cursor.isAfter(end);) {
      late DateTime last, next;
      late String label, axis;
      if (period == ReportPeriod.yearly) {
        last = DateTime(cursor.year, 12, 31);
        next = DateTime(cursor.year + 1);
        label = axis = '${cursor.year}';
      } else if (period == ReportPeriod.monthly) {
        last = DateTime(cursor.year, cursor.month + 1, 0);
        next = DateTime(cursor.year, cursor.month + 1);
        label = axis = DateFormat('MMMM yyyy').format(cursor);
      } else if (period == ReportPeriod.weekly) {
        next = DateTime(cursor.year, cursor.month, cursor.day + 7);
        last = DateTime(cursor.year, cursor.month, cursor.day + 6);
        final weekYear = DateTime(start.year, start.month, start.day + 3).year;
        final week = calendarWeekDays(start, cursor) ~/ 7 + 1;
        axis = 'W${week.toString().padLeft(2, '0')} $weekYear';
        label =
            'Week $week, $weekYear · ${DateFormat("d MMM yyyy").format(cursor)} - ${DateFormat("d MMM yyyy").format(last)}';
      } else {
        last = cursor;
        next = DateTime(cursor.year, cursor.month, cursor.day + 1);
        label = reportDate(cursor);
        axis = DateFormat('d MMM').format(cursor);
      }
      buckets.add(
        ReportBucket(start: cursor, end: last, label: label, axisLabel: axis),
      );
      cursor = next;
    }
    return ReportWindow(
      period: period,
      start: start,
      end: end,
      buckets: buckets,
    );
  }

  // Build the displayed report date-range label.
  String get dateLabel => '${reportDate(start)} - ${reportDate(end)}';
  // Choose daily, weekly, monthly, or yearly grouping.
  String get granularity => switch (period) {
    ReportPeriod.monthly => 'Monthly',
    ReportPeriod.yearly => 'Yearly',
    ReportPeriod.weekly => 'Weekly',
    _ => 'Daily',
  };
}

/// The existing callable accepts at most 366 inclusive days per request.
/// Splitting on calendar years also preserves leap days and Malaysia date labels.
List<({DateTime start, DateTime end})> reportRequestRanges(
  DateTime start,
  DateTime end,
) {
  final result = <({DateTime start, DateTime end})>[];
  for (var cursor = reportDay(start); !cursor.isAfter(end);) {
    final yearEnd = DateTime(cursor.year, 12, 31);
    final last = yearEnd.isAfter(end) ? reportDay(end) : yearEnd;
    result.add((start: cursor, end: last));
    cursor = DateTime(last.year, last.month, last.day + 1);
  }
  return result;
}

// Represent one sales or waste record in the selected period.
class ReportRecord {
  const ReportRecord({
    required this.date,
    required this.reference,
    this.category = '',
    this.reason = '',
    this.productCents = 0,
    this.deliveryCents = 0,
    this.units = 0,
  });
  final DateTime date;
  final String reference, category, reason;
  final int productCents, deliveryCents, units;
  // Add the product sales and delivery fees.
  int get totalCents => productCents + deliveryCents;

  // Read one normalized sales or waste report record.
  factory ReportRecord.fromRow(String kind, List<dynamic> row) {
    if (row.length < 5) {
      throw const FormatException('Incomplete report record.');
    }
    final date = reportDay(DateTime.parse('${row[0]}'));
    if (kind == 'sales') {
      return ReportRecord(
        date: date,
        reference: '${row[1]}',
        productCents: ((row[2] as num) * 100).round(),
        deliveryCents: ((row[3] as num) * 100).round(),
      );
    }
    return ReportRecord(
      date: date,
      reference: capitalizeProductName('${row[1]}'),
      category: categoryTitleCase('${row[2]}'),
      reason: categoryTitleCase('${row[3]}'),
      units: (row[4] as num).round(),
    );
  }

  // Build the values shown in a report record row.
  List<String> cells(String kind) => kind == 'sales'
      ? [
          '${DateFormat('d MMM yyyy').format(date)}\n$reference',
          (productCents / 100).toStringAsFixed(2),
          (deliveryCents / 100).toStringAsFixed(2),
          (totalCents / 100).toStringAsFixed(2),
        ]
      : [
          '${DateFormat('d MMM yyyy').format(date)}\n$reference',
          category,
          reason,
          '$units',
        ];
}

// Calculate totals and exports for the selected chart bucket.
class ReportSelection {
  const ReportSelection(this.kind, this.bucket, this.records);
  final String kind;
  final ReportBucket bucket;
  final List<ReportRecord> records;
  // Sum the selected product sales in cents.
  int get productCents => records.fold(0, (sum, row) => sum + row.productCents);
  // Sum the selected delivery fees in cents.
  int get deliveryCents =>
      records.fold(0, (sum, row) => sum + row.deliveryCents);
  // Add the product sales and delivery fees.
  int get totalCents => productCents + deliveryCents;
  // Sum the selected waste quantities.
  int get units => records.fold(0, (sum, row) => sum + row.units);
  // Choose the value plotted for this report type.
  int get value => kind == 'sales' ? productCents : units;
  // Group the selected waste units by category.
  Map<String, int> get categories {
    final result = <String, int>{};
    for (final row in records) {
      result.update(
        row.category,
        (value) => value + row.units,
        ifAbsent: () => row.units,
      );
    }
    return result;
  }

  // Choose the data columns for this report type.
  List<String> get headers => kind == 'sales'
      ? [
          'Date / Order',
          'Product Sales (MYR)',
          'Delivery Fees (MYR)',
          'Total (MYR)',
        ]
      : ['Date / Product', 'Category', 'Reason', 'Units'];

  // Collect the selected chart, records, and CSV export data.
  Map<String, dynamic> export({
    required String storeName,
    required DateTime today,
    DateTime? openedAt,
  }) {
    final first = openedAt != null && openedAt.isAfter(bucket.start)
        ? openedAt
        : bucket.start;
    final last = bucket.end.isAfter(today) ? today : bucket.end;
    final rows = <List<dynamic>>[
      [storeName, kind == 'sales' ? 'Sales report' : 'Waste report'],
      ['Selection', bucket.label],
      [
        'From',
        reportDate(first.isAfter(last) ? bucket.start : first),
        'Through',
        reportDate(last),
      ],
      ['Timezone', 'Asia/Kuala_Lumpur'],
      if (kind == 'sales') ['Currency', 'MYR'],
      ['Records', records.length],
      [],
      headers,
      ...records.map((row) => row.cells(kind)),
      kind == 'sales'
          ? [
              'TOTAL',
              (productCents / 100).toStringAsFixed(2),
              (deliveryCents / 100).toStringAsFixed(2),
              (totalCents / 100).toStringAsFixed(2),
            ]
          : ['TOTAL', '', '', units],
      if (kind == 'waste') ...[
        [],
        ['Waste by category', bucket.label],
        ['Category', 'Units'],
        ...categories.entries.map((entry) => [entry.key, entry.value]),
        ['TOTAL', units],
      ],
    ];
    // Read one formatted report cell.
    String cell(dynamic value) {
      var text = '$value';
      if (value is String && RegExp(r'^\s*[=+@-]').hasMatch(text)) {
        text = "'$text";
      }
      return '"${text.replaceAll('"', '""')}"';
    }

    return {
      'kind': kind,
      'start': reportIso(first.isAfter(last) ? bucket.start : first),
      'end': reportIso(last),
      'csv': '\uFEFF${rows.map((row) => row.map(cell).join(',')).join('\r\n')}',
    };
  }
}

// Keep the loaded report records and calendar window.
class ReportSnapshot {
  const ReportSnapshot({
    required this.kind,
    required this.storeName,
    required this.records,
  });
  final String kind, storeName;
  final List<ReportRecord> records;
  // Read stored values with safe defaults.
  factory ReportSnapshot.fromMap(
    String kind,
    Map<String, dynamic> data, {
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    final rows =
        (data['rows'] as List)
            .map(
              (row) =>
                  ReportRecord.fromRow(kind, List<dynamic>.from(row as List)),
            )
            .where(
              (row) =>
                  (firstDate == null || !row.date.isBefore(firstDate)) &&
                  (lastDate == null || !row.date.isAfter(lastDate)),
            )
            .toList()
          ..sort((a, b) {
            final date = a.date.compareTo(b.date);
            return date == 0 ? a.reference.compareTo(b.reference) : date;
          });
    return ReportSnapshot(
      kind: kind,
      storeName: '${data['storeName'] ?? 'StockWise'}',
      records: rows,
    );
  }
  // Select one chart bucket and its matching report records.
  ReportSelection select(ReportBucket bucket) => ReportSelection(
    kind,
    bucket,
    records.where((row) => bucket.contains(row.date)).toList(),
  );
  // Sum the selected product sales in cents.
  int get productCents => records.fold(0, (sum, row) => sum + row.productCents);
  // Sum the selected delivery fees in cents.
  int get deliveryCents =>
      records.fold(0, (sum, row) => sum + row.deliveryCents);
  // Add the product sales and delivery fees.
  int get totalCents => productCents + deliveryCents;
  // Sum the selected waste quantities.
  int get units => records.fold(0, (sum, row) => sum + row.units);
}
