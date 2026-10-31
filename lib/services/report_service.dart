import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import '../models/report_data.dart';
import 'store_session.dart';

class ReportService {
  static final _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );
  static Future<Map<String, dynamic>> load(
    String kind,
    String start,
    String end, {
    Future<Map<String, dynamic>> Function(String, String, String)? request,
  }) async {
    final storeId = StoreSession.instance.storeId;
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

  static Future<DateTime?> registeredAt() async {
    final known = StoreSession.instance.store?.createdAt;
    if (known != null) return known;
    final id = StoreSession.instance.storeId;
    if (id == null) return null;
    final data =
        (await FirebaseFirestore.instance.collection('stores').doc(id).get())
            .data();
    final value = data?['createdAt'];
    return value is Timestamp ? value.toDate() : null;
  }

  static Future<bool> download(Map<String, dynamic> data) async {
    final file = await FlutterFileDialog.saveFile(
      params: SaveFileDialogParams(
        data: Uint8List.fromList(utf8.encode(data['csv'] as String)),
        fileName:
            'StockWise-${StoreSession.instance.storeId}-${data['kind']}-${data['start']}-${data['end']}.csv',
        mimeTypesFilter: const ['text/csv'],
      ),
    );
    return file != null;
  }
}
