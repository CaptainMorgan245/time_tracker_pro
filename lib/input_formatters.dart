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
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');

    // Preserve the cursor position
    final newSelection = newValue.selection.copyWith(
      baseOffset: newValue.selection.baseOffset + (formattedText.length - newValue.text.length),
      extentOffset: newValue.selection.extentOffset + (formattedText.length - newValue.text.length),
    );

    return newValue.copyWith(
      text: formattedText,
      selection: newSelection,
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

    // Preserve the cursor position
    final newSelection = newValue.selection.copyWith(
      baseOffset: newValue.selection.baseOffset + (formattedText.length - newValue.text.length),
      extentOffset: newValue.selection.extentOffset + (formattedText.length - newValue.text.length),
    );

    return newValue.copyWith(
      text: formattedText,
      selection: newSelection,
    );
  }
}