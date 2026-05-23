// lib/screens/statement_pdf_preview_screen.dart
//
// In-app preview for the Client Statement PDF. Users can review pages,
// then print or share via the PdfPreview actions, or back out via the
// AppBar back button (which cancels without printing).

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'package:time_tracker_pro/models.dart';
import 'package:time_tracker_pro/models/client_statement.dart';
import 'package:time_tracker_pro/services/statement_pdf_service.dart';

class StatementPdfPreviewScreen extends StatelessWidget {
  final ClientStatement statement;
  final CompanySettings companySettings;

  const StatementPdfPreviewScreen({
    super.key,
    required this.statement,
    required this.companySettings,
  });

  String _pdfName() {
    final safe = statement.client.name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');
    final d = statement.statementDate;
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return 'Statement_${safe}_${d.year}-$m-$day';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statement PDF Preview')),
      body: PdfPreview(
        build: (format) => StatementPdfService.generateStatementPdfBytes(
          statement: statement,
          companySettings: companySettings,
        ),
        pdfFileName: _pdfName(),
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
      ),
    );
  }
}
