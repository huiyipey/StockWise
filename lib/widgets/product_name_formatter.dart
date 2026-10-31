import 'package:flutter/services.dart';

import '../models/product_name.dart';

class ProductNameFormatter extends TextInputFormatter {
  const ProductNameFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    final text = capitalizeProductName(newValue.text);
    if (text == newValue.text) return newValue;
    int offset(int value) => value < 0
        ? value
        : capitalizeProductName(newValue.text.substring(0, value)).length;
    return newValue.copyWith(
      text: text,
      selection: newValue.selection.copyWith(
        baseOffset: offset(newValue.selection.baseOffset),
        extentOffset: offset(newValue.selection.extentOffset),
      ),
      composing: TextRange.empty,
    );
  }
}
