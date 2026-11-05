import 'dart:convert';
import 'dart:math' as math;
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// One save operation. Both formats are packaged together so no export is lost
/// if Android dismisses a second file picker.
class ReportExportFile {
  const ReportExportFile(this.bytes, this.extension, this.mimeType);
  final Uint8List bytes;
  final String extension, mimeType;

  static Future<ReportExportFile> build(Map<String, dynamic> data) async {
    final format = data['format'] ?? 'data';
    final csv = Uint8List.fromList(utf8.encode(data['csv'] as String));
    if (format == 'data') return ReportExportFile(csv, 'csv', 'text/csv');
    final pdf = await _pdf(data, includeData: format == 'both');
    if (format == 'chart') {
      return ReportExportFile(pdf, 'pdf', 'application/pdf');
    }
    final archive = Archive()
      ..addFile(
        ArchiveFile('StockWise-${data['kind']}-chart.pdf', pdf.length, pdf),
      )
      ..addFile(
        ArchiveFile('StockWise-${data['kind']}-data.csv', csv.length, csv),
      );
    return ReportExportFile(
      Uint8List.fromList(ZipEncoder().encode(archive)),
      'zip',
      'application/zip',
    );
  }

  static Future<Uint8List> _pdf(
    Map<String, dynamic> data, {
    required bool includeData,
  }) async {
    final doc = pw.Document();
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/StockWiseNotoSansSC-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/StockWiseNotoSansSC-BoldLatin.ttf'),
    );
    final isSales = data['kind'] == 'sales';
    final chart = List<Map<String, dynamic>>.from(
      (data['chart'] as List? ?? []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    final categories = Map<String, dynamic>.from(
      data['categories'] as Map? ?? {},
    );
    final green = PdfColor.fromHex('#247653');
    pw.Widget title(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: green,
        ),
      ),
    );
    doc.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(
          base: regular,
          bold: bold,
          italic: regular,
          boldItalic: bold,
          fontFallback: [regular],
        ),
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        maxPages: 1000,
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'StockWise | Page ${context.pageNumber}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
        build: (_) => [
          pw.Text(
            '${data['storeName'] ?? 'StockWise'}',
            style: pw.TextStyle(
              fontSize: 20,
              color: green,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          title(isSales ? 'Sales Report' : 'Waste Report'),
          pw.Text(
            'Chart: ${data['chartRange'] ?? ''}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Malaysia time | ${isSales ? 'Product sales (MYR)' : 'Waste (Units)'}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          if (data['calendarNote'] != null)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 5),
              child: pw.Text(
                '${data['calendarNote']}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          for (var offset = 0; offset < chart.length; offset += 12) ...[
            pw.SizedBox(height: 18),
            _chart(
              chart.sublist(offset, math.min(offset + 12, chart.length)),
              isSales,
              chart.fold<double>(
                1,
                (a, b) => math.max(a, (b['value'] as num).toDouble()),
              ),
              regular,
            ),
          ],
          if (chart.isEmpty) pw.Text('No chart data.'),
          title('Selected records: ${data['selectionLabel'] ?? ''}'),
          pw.Text(
            'Data through ${data['end']}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          if (!isSales) ...[
            title('Waste by Category'),
            pw.TableHelper.fromTextArray(
              headers: ['Category', 'Units'],
              data: [
                for (final e in categories.entries) [e.key, '${e.value}'],
                ['TOTAL', '${data['selectedUnits'] ?? 0}'],
              ],
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#E1EBDD'),
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
          if (includeData) ...[
            title('Order / Product Data'),
            pw.TableHelper.fromTextArray(
              headers: List<String>.from(data['headers'] as List),
              data: List<List<dynamic>>.from(
                (data['rows'] as List).map(
                  (row) => List<dynamic>.from(row as List),
                ),
              ),
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#E1EBDD'),
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerStyle: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _chart(
    List<Map<String, dynamic>> points,
    bool sales,
    double maximum,
    pw.Font font,
  ) {
    final bars = StringBuffer();
    const plotHeight = 125.0, left = 12.0, step = 40.0;
    for (var i = 0; i < points.length; i++) {
      final value = (points[i]['value'] as num).toDouble();
      final height = value / maximum * plotHeight;
      final x = left + i * step;
      final text = sales
          ? (value / 100).toStringAsFixed(2)
          : value.toStringAsFixed(0);
      bars.write(
        '<rect x="$x" y="${plotHeight + 20 - height}" width="23" height="${math.max(height, value == 0 ? 1 : 2)}" fill="#247653"/>',
      );
      bars.write(
        '<text x="${x + 11.5}" y="${plotHeight + 14 - height}" font-size="7" text-anchor="middle">$text</text>',
      );
      bars.write(
        '<text x="${x + 11.5}" y="163" font-size="7" text-anchor="middle">${i + 1}</text>',
      );
    }
    final width = math.max(250.0, points.length * step + 24);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.SvgImage(
          customFontLookup: (family, style, weight) => font,
          svg:
              '<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="175" viewBox="0 0 $width 175"><line x1="6" y1="146" x2="$width" y2="146" stroke="#D1DAD0"/>$bars</svg>',
          height: 175,
        ),
        pw.Wrap(
          spacing: 12,
          runSpacing: 5,
          children: [
            for (var i = 0; i < points.length; i++)
              pw.Text(
                '${i + 1}: ${points[i]['label']}',
                style: const pw.TextStyle(fontSize: 8),
              ),
          ],
        ),
      ],
    );
  }
}
