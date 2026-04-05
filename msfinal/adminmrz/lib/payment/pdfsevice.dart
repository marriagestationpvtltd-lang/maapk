import 'dart:typed_data';
import 'package:adminmrz/payment/paymentmodel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;


class PDFService {
  // Generate invoice for single payment with email
  Future<Uint8List> generateInvoicePDF(Payment payment) async {
    final pdf = pw.Document();

    // Add invoice content
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text('Invoice #: INV-${payment.id.toString().padLeft(6, '0')}'),
                      pw.Text('Date: ${payment.formattedPurchaseDate}'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'DigitalLami By MS',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text('Marriage Station'),
                      pw.Text('Kathmandu, Nepal'),
                      pw.Text('Phone: +977-1-5922276'),
                      pw.Text('Email: help@digitallami.com'),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 40),

              // Bill To section with email
              pw.Text(
                'BILL TO',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Customer ID: ${payment.userId}'),
              pw.Text('Name: ${payment.fullName}'),
              pw.Text('Email: ${payment.email}'),

              pw.SizedBox(height: 40),

              // Package Details
              pw.Text(
                'PACKAGE DETAILS',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),

              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Details', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Package Name'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(payment.packageName),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Price'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(payment.packagePrice),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Payment Method'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(payment.paidBy),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Purchase Date'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(payment.formattedPurchaseDate),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Expire Date'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(payment.formattedExpireDate),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Status'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          payment.packageStatus,
                          style: pw.TextStyle(
                            color: payment.isActive ? PdfColors.green : PdfColors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 40),

              // Total Amount
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'TOTAL AMOUNT',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 10),
                        pw.Text(
                          payment.packagePrice,
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          'Payment Status: PAID',
                          style: pw.TextStyle(
                            color: PdfColors.green,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 40),

              // Terms and Conditions
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Terms & Conditions:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      '1. This is an official invoice for the purchased package.',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      '2. Package validity starts from the purchase date.',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      '3. For any queries, contact support@digitallami.com',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Footer
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                child: pw.Center(
                  child: pw.Text(
                    'Thank you for choosing DigitalLami Service!',
                    style: pw.TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // Generate full report PDF with email
  Future<Uint8List> generateReportPDF({
    required PaymentSummary summary,
    required List<Payment> payments,
    required String title,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Text(
                title,
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
            ),

            // Company Info
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('DigitalLami BY MS'),
                    pw.Text('Kathmandu, Nepal'),
                    pw.Text('Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Report ID: REP-${DateTime.now().millisecondsSinceEpoch}'),
                    pw.Text('Total Records: ${payments.length}'),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 20),

            // Date Range
            if (startDate != null || endDate != null)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 20),
                child: pw.Text(
                  'Report Period: ${startDate != null ? DateFormat('yyyy-MM-dd').format(startDate) : 'Start'} to ${endDate != null ? DateFormat('yyyy-MM-dd').format(endDate) : 'End'}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ),

            // Summary Section
            pw.Header(
              level: 1,
              child: pw.Text('Summary'),
            ),

            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 20),
              child: pw.Table.fromTextArray(
                border: null,
                cellAlignment: pw.Alignment.centerLeft,
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headers: ['Metric', 'Value'],
                data: [
                  ['Total Packages Sold', summary.totalPackagesSold.toString()],
                  ['Total Earnings', summary.totalEarning],
                  ['Top Payment Method', summary.topPaymentMethod],
                  ['Active Packages', summary.activePackages.toString()],
                  ['Expired Packages', summary.expiredPackages.toString()],
                  ['Total Customers', payments.map((p) => p.userId).toSet().length.toString()],
                  ['Average per Package', 'Rs ${(summary.numericEarning / summary.totalPackagesSold).toStringAsFixed(2)}'],
                ],
              ),
            ),

            // Payment Details Section
            pw.Header(
              level: 1,
              child: pw.Text('Payment Details'),
            ),

            pw.Table.fromTextArray(
              context: context,
              border: pw.TableBorder.all(),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
              headers: ['ID', 'Customer', 'Email', 'Package', 'Amount', 'Method', 'Purchase Date', 'Status'],
              data: payments.map((payment) {
                return [
                  payment.id.toString(),
                  payment.fullName,
                  payment.email,
                  payment.packageName,
                  payment.packagePrice,
                  payment.paidBy,
                  DateFormat('yyyy-MM-dd HH:mm').format(payment.purchaseDateTime),
                  payment.packageStatus,
                ];
              }).toList(),
            ),

            // Statistics by Payment Method
            pw.Header(
              level: 1,
              child: pw.Text('Payment Method Breakdown'),
            ),

            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 20),
              child: _buildPaymentMethodStats(payments),
            ),

            // Total Section
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 30),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'REPORT TOTAL',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          'Rs ${payments.fold(0.0, (sum, payment) => sum + payment.numericPrice).toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          '${payments.length} transactions',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Footer
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 40),
              padding: const pw.EdgeInsets.all(12),
              decoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
              ),
              child: pw.Center(
                child: pw.Text(
                  'Confidential - For Internal Use Only',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPaymentMethodStats(List<Payment> payments) {
    final methodStats = <String, double>{};
    for (var payment in payments) {
      final method = payment.paidBy;
      methodStats[method] = (methodStats[method] ?? 0) + payment.numericPrice;
    }

    final sortedMethods = methodStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return pw.Table.fromTextArray(
      border: pw.TableBorder.all(),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.grey200,
      ),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headers: ['Payment Method', 'Transactions', 'Total Amount', 'Percentage'],
      data: sortedMethods.map((entry) {
        final method = entry.key;
        final amount = entry.value;
        final count = payments.where((p) => p.paidBy == method).length;
        final total = payments.fold(0.0, (sum, p) => sum + p.numericPrice);
        final percentage = total > 0 ? (amount / total * 100) : 0;

        return [
          method,
          count.toString(),
          'Rs ${amount.toStringAsFixed(2)}',
          '${percentage.toStringAsFixed(1)}%',
        ];
      }).toList(),
    );
  }

  // Generate CSV for download with email
  String generateCSV(List<Payment> payments) {
    final csv = StringBuffer();

    // Add headers
    csv.writeln('ID,Customer Name,Email,Customer ID,Package Name,Amount,Payment Method,Purchase Date,Expire Date,Status');

    // Add data
    for (var payment in payments) {
      csv.writeln([
        payment.id,
        '"${payment.fullName}"',
        '"${payment.email}"',
        payment.userId,
        '"${payment.packageName}"',
        payment.numericPrice,
        payment.paidBy,
        payment.purchaseDate,
        payment.expireDate,
        payment.packageStatus,
      ].join(','));
    }

    return csv.toString();
  }

  // Generate Excel report with email
  Future<Uint8List> generateExcelReport({
    required PaymentSummary summary,
    required List<Payment> payments,
  }) async {
    // For web, we'll generate CSV which can be opened in Excel
    final csvContent = generateCSV(payments);
    return Uint8List.fromList(csvContent.codeUnits);
  }
}