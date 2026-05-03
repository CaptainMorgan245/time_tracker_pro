// lib/invoice_pdf_service.dart

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:time_tracker_pro/models/invoice.dart';

class InvoicePdfService {
  static const _dyconnOrange = PdfColor.fromInt(0xFFE8720C);
  static const _pageMargin = 40.0;

  static String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},')}';
  }

  static String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  static pw.Widget _totalsRow(
    String label,
    String amount, {
    bool bold = false,
    double fontSize = 10,
    PdfColor? color,
  }) {
    final style = pw.TextStyle(
      fontSize: fontSize,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color,
    );
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text(amount, style: style),
      ],
    );
  }

  static Future<Uint8List> generateInvoicePdf({
    required Invoice invoice,
    required Map<String, dynamic> companySettings,
    required String clientName,
    required String clientCity,
    required String clientPhone,
    required String projectName,
    required String projectStreetAddress,
    required String projectCity,
    required String projectRegion,
    required String projectPostalCode,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(_pageMargin),
        build: (context) => [
          // SECTION 1: HEADER
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // LEFT COLUMN
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    companySettings['company_name'] ?? '',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: _dyconnOrange,
                    ),
                  ),
                  pw.Text(companySettings['company_address'] ?? '',
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(
                    [
                      companySettings['company_city'] ?? '',
                      '${companySettings['company_province'] ?? ''} ${companySettings['company_postal_code'] ?? ''}'.trim(),
                    ].where((s) => s.isNotEmpty).join(', '),
                    style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Tel: ' + (companySettings['company_phone'] ?? ''),
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(companySettings['company_email'] ?? '',
                      style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              // RIGHT COLUMN
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'INVOICE',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                  pw.Text('Invoice #: ' + invoice.invoiceNumber,
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Date: ' + _formatDate(invoice.invoiceDate),
                      style: const pw.TextStyle(fontSize: 10)),
                  if (invoice.poNumber != null && invoice.poNumber!.trim().isNotEmpty)
                    pw.Text('PO #: ' + invoice.poNumber!.trim(),
                        style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ],
          ),
          pw.Divider(color: _dyconnOrange, height: 24),

          // SECTION 2 & 3: BILL TO + PROJECT
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // LEFT: BILL TO
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      color: const PdfColor.fromInt(0xFF2D2D2D),
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: pw.Text(
                        'BILL TO',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(clientName, style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(clientCity, style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(clientPhone, style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.SizedBox(width: 24),
              // RIGHT: PROJECT
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      color: const PdfColor.fromInt(0xFF2D2D2D),
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: pw.Text(
                        'PROJECT',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(projectName, style: const pw.TextStyle(fontSize: 10)),
                    if (projectStreetAddress.trim().isNotEmpty)
                      pw.Text(projectStreetAddress, style: const pw.TextStyle(fontSize: 10)),
                    if (projectCity.trim().isNotEmpty)
                      pw.Text(projectCity, style: const pw.TextStyle(fontSize: 10)),
                    if (projectRegion.trim().isNotEmpty || projectPostalCode.trim().isNotEmpty)
                      pw.Text('${projectRegion}  ${projectPostalCode}'.trim(), style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          // SECTION 4: WORK PERFORMED
          pw.Text(
            'WORK PERFORMED',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: _dyconnOrange,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
            ),
            padding: const pw.EdgeInsets.all(8),
            width: double.infinity,
            child: pw.Paragraph(
              text: (invoice.workDescription != null && invoice.workDescription!.trim().isNotEmpty)
                  ? invoice.workDescription!
                  : (invoice.notes != null && invoice.notes!.trim().isNotEmpty)
                      ? invoice.notes!
                      : 'No description provided.',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
          pw.SizedBox(height: 20),

          // SECTION 5: TOTALS
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 260,
              child: pw.Column(
                children: [
                  if (invoice.invoiceType == 'progress' ||
                      invoice.invoiceType == 'deposit') ...[
                    _totalsRow(
                      'Subtotal',
                      _formatCurrency(invoice.subtotal),
                      bold: true,
                    ),
                  ] else ...[
                    if (invoice.labourSubtotal > 0)
                      _totalsRow(
                        'Labour',
                        _formatCurrency(invoice.labourSubtotal),
                      ),
                    pw.SizedBox(height: 4),
                    if (invoice.materialsSubtotal > 0)
                      _totalsRow(
                        'Materials',
                        _formatCurrency(invoice.materialsSubtotal),
                      ),
                    pw.SizedBox(height: 4),
                    pw.Divider(color: _dyconnOrange, height: 8),
                    _totalsRow(
                      'Subtotal',
                      _formatCurrency(
                          invoice.labourSubtotal + invoice.materialsSubtotal),
                      bold: true,
                    ),
                    if (invoice.discountAmount > 0) ...[
                      pw.SizedBox(height: 4),
                      _totalsRow(
                        invoice.discountDescription ?? 'Discount',
                        '-' + _formatCurrency(invoice.discountAmount),
                        color: PdfColors.red,
                      ),
                      pw.SizedBox(height: 4),
                      _totalsRow(
                        'Discounted Subtotal',
                        _formatCurrency(invoice.subtotal),
                        bold: true,
                      ),
                    ],
                  ],
                  pw.SizedBox(height: 4),
                  _totalsRow(
                    (invoice.tax1Name ?? 'GST') +
                        ' (' +
                        (invoice.tax1Rate ?? 0.0).toStringAsFixed(1) +
                        '%)' +
                        (invoice.tax1RegistrationNumber != null
                            ? '  Reg# ' + invoice.tax1RegistrationNumber!
                            : ''),
                    _formatCurrency(invoice.tax1Amount),
                  ),
                  if (invoice.tax2Rate != null && invoice.tax2Amount > 0) ...[
                    pw.SizedBox(height: 4),
                    _totalsRow(
                      (invoice.tax2Name ?? 'PST') +
                          ' (' +
                          invoice.tax2Rate!.toStringAsFixed(1) +
                          '%)',
                      _formatCurrency(invoice.tax2Amount),
                    ),
                  ],
                  pw.Divider(color: _dyconnOrange, height: 12),
                  pw.Container(
                    color: _dyconnOrange,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'TOTAL DUE',
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.Text(
                          _formatCurrency(invoice.totalAmount),
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 24),

          // SECTION 6: FOOTER
          pw.Divider(color: _dyconnOrange, height: 20),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Center(
                child: pw.Text(
                  'Thank you for your business.',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Center(
                child: pw.Text(
                  'Payment Terms: ' + invoice.terms,
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
              if (((companySettings['payment_etransfer_email'] as String?) ?? '').trim().isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    'E-Transfer: ' + ((companySettings['payment_etransfer_email'] as String?) ?? ''),
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              if (((invoice.tax1RegistrationNumber ?? companySettings['default_tax1_registration_number']) as String?) != null)
                pw.Center(
                  child: pw.Text(
                    'GST Registration #: ' +
                        ((invoice.tax1RegistrationNumber ??
                            companySettings['default_tax1_registration_number']) as String),
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    return await pdf.save();
  }
}
