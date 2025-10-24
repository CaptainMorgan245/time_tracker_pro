import 'package:flutter/foundation.dart';

class ImportError {
  final String workerName;
  final String entryData;
  final String errorReason;
  final DateTime timestamp;

  ImportError({
    required this.workerName,
    required this.entryData,
    required this.errorReason,
    required this.timestamp,
  });
}

class ImportErrorsNotifier extends ValueNotifier<List<ImportError>> {
  ImportErrorsNotifier() : super([]);

  static final ImportErrorsNotifier instance = ImportErrorsNotifier();

  void addError(String workerName, String entryData, String errorReason) {
    value = [...value, ImportError(
      workerName: workerName,
      entryData: entryData,
      errorReason: errorReason,
      timestamp: DateTime.now(),
    )];
  }

  void clearErrors() {
    value = [];
  }

  int get errorCount => value.length;
}