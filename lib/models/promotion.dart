class Promotion {
  const Promotion(this.data);
  final Map<String, dynamic> data;
  factory Promotion.fromMap(dynamic data) =>
      Promotion(data is Map ? Map<String, dynamic>.from(data) : const {});
  String get type => data['type'] as String? ?? 'fixed';
  bool get isBundle => type == 'bundle';
  int get giftQuantity => (data['giftQuantity'] as num?)?.toInt() ?? 1;
  String get targetProductId => data['targetProductId'] as String? ?? '';
  String get label {
    if (!isBundle) return '';
    final buy = data['requirement'] == 'spend'
        ? 'Spend RM ${((data['thresholdSpendCents'] as num? ?? 0) / 100).toStringAsFixed(2)}'
        : 'Buy ${data['thresholdQuantity'] ?? 1}';
    final target = data['targetProductName'] ?? 'Selected Items';
    final reward = switch (data['reward']) {
      'percentage' => '${data['rewardPercentage']}% Off',
      'fixed' =>
        'RM ${((data['rewardAmountCents'] as num? ?? 0) / 100).toStringAsFixed(2)} Off',
      _ => 'Free',
    };
    return '$buy, Get $giftQuantity $target $reward';
  }
}
