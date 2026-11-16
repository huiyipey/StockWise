// Keep the promotion values used by the app.
class Promotion {
  const Promotion(this.data);
  final Map<String, dynamic> data;
  // Read stored values with safe defaults.
  factory Promotion.fromMap(dynamic data) =>
      Promotion(data is Map ? Map<String, dynamic>.from(data) : const {});
  // Read the configured promotion type.
  String get type => data['type'] as String? ?? 'fixed';
  // Check whether this promotion is Buy X Get Y.
  bool get isBundle => type == 'bundle';
  // Read the number of units rewarded by the offer.
  int get giftQuantity => (data['giftQuantity'] as num?)?.toInt() ?? 1;
  // Read the product selected as the bundle reward.
  String get targetProductId => data['targetProductId'] as String? ?? '';
  // Build the label shown to the user.
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
