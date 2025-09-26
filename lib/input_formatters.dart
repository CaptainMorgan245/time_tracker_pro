// lib/input_formatters.dart

import 'package:flutter/services.dart';

class CapitalizeEachWordInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final formattedText = newValue.text.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');

    return newValue.copyWith(
      text: formattedText,
      selection: newValue.selection.copyWith(
        baseOffset: formattedText.length,
        extentOffset: formattedText.length,
      ),
    );
  }
}

class CapitalizeFirstWordInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final formattedText = newValue.text[0].toUpperCase() + newValue.text.substring(1);

    return newValue.copyWith(
      text: formattedText,
      selection: newValue.selection.copyWith(
        baseOffset: formattedText.length,
        extentOffset: formattedText.length,
      ),
    );
  }
}