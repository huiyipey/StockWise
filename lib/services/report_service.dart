import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'store_session.dart';

class ReportService {
  static final _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );
  static Future<Map<String, dynamic>> load(
    String kind,
    String start,
    String end,
  ) async {
    final result = await _functions
        .httpsCallable(
          'getStoreReport',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
        )
        .call({
          'storeId': StoreSession.instance.storeId,
          'kind': kind,
          'start': start,
          'end': end,
        });
    return Map<String, dynamic>.from(result.data as Map);
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
