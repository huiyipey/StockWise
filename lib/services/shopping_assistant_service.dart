import 'package:cloud_functions/cloud_functions.dart';

typedef AssistantRequester =
    Future<Map<String, dynamic>> Function({
      required String question,
      required List<String> productIds,
      required List<Map<String, String>> conversation,
    });

/// Four recent exchanges, bounded to the backend's message and total limits.
List<Map<String, String>> recentAssistantConversation(
  List<Map<String, String>> turns,
) {
  final result = <Map<String, String>>[];
  int length = 0;
  for (
    var index = turns.length - 2;
    index >= 0 && result.length < 8;
    index -= 2
  ) {
    final user = turns[index];
    final model = turns[index + 1];
    if (user['role'] != 'user' || model['role'] != 'model') continue;
    final userText = user['text'] ?? '';
    final modelText = model['text'] ?? '';
    final clipped = modelText.length > 4000
        ? modelText.substring(0, 4000)
        : modelText;
    if (length + userText.length + clipped.length > 12000) break;
    result.insertAll(0, [
      {'role': 'user', 'text': userText},
      {'role': 'model', 'text': clipped},
    ]);
    length += userText.length + clipped.length;
  }
  return result;
}

Future<Map<String, dynamic>> askShoppingAssistant({
  required String storeId,
  required String question,
  required List<String> productIds,
  required List<Map<String, String>> conversation,
}) async {
  final response =
      await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
          .httpsCallable(
            'shoppingAssistant',
            options: HttpsCallableOptions(
              timeout: const Duration(seconds: 120),
            ),
          )
          .call({
            'storeId': storeId,
            'question': question,
            'productIds': productIds,
            'conversation': conversation,
          });
  return Map<String, dynamic>.from(response.data as Map);
}
