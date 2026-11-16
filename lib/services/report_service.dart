import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import '../models/report_data.dart';
import 'store_session.dart';
import 'report_export.dart';

// Request store reports and save the selected export format.
class ReportService {
  static final _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );
  // Load all bounded request parts and merge their records.
  static Future<Map<String, dynamic>> load(
    String kind,
    String start,
    String end, {
    Future<Map<String, dynamic>> Function(String, String, String)? request,
  }) async {
    final storeId = StoreSession.instance.storeId;
    // Request this shop report from the backend.
    Future<Map<String, dynamic>> call(
      String kind,
      String start,
      String end,
    ) async {
      final result = await _functions
          .httpsCallable(
            'getStoreReport',
            options: HttpsCallableOptions(
              timeout: const Duration(seconds: 120),
            ),
          )
          .call({'storeId': storeId, 'kind': kind, 'start': start, 'end': end});
      return Map<String, dynamic>.from(result.data as Map);
    }

    final ranges = reportRequestRanges(
      DateTime.parse(start),
      DateTime.parse(end),
    );
    final parts = await Future.wait(
      ranges.map(
        (range) => (request ?? call)(
          kind,
          reportIso(range.start),
          reportIso(range.end),
        ),
      ),
    );
    return {
      'kind': kind,
      'start': start,
      'end': end,
      'storeName': parts.isEmpty
          ? 'StockWise'
          : parts.first['storeName'] ??
                StoreSession.instance.store?.name ??
                'StockWise',
      'rows': [for (final part in parts) ...(part['rows'] as List)],
    };
  }

  // Read the earliest shop history date for report limits.
  static Future<DateTime?> registeredAt() async {
    final known = StoreSession.instance.store?.reportingStartsAt;
    if (known != null) return known;
    final id = StoreSession.instance.storeId;
    if (id == null) return null;
    final data =
        (await FirebaseFirestore.instance.collection('stores').doc(id).get())
            .data();
    final created = data?['createdAt'];
    final imported = data?['reportingHistoryStartsAt'];
    final registeredAt = created is Timestamp ? created.toDate() : null;
    final historyAt = imported is Timestamp ? imported.toDate() : null;
    if (historyAt == null) return registeredAt;
    return registeredAt == null || historyAt.isBefore(registeredAt)
        ? historyAt
        : registeredAt;
  }

  // Build and save the selected report export.
  static Future<bool> download(Map<String, dynamic> data) async {
    final output = await ReportExportFile.build(data);
    final file = await FlutterFileDialog.saveFile(
      params: SaveFileDialogParams(
        data: output.bytes,
        fileName:
            'StockWise-${StoreSession.instance.storeId}-${data['kind']}-${data['start']}-${data['end']}.${output.extension}',
        mimeTypesFilter: [output.mimeType],
      ),
    );
    return file != null;
  }
}
