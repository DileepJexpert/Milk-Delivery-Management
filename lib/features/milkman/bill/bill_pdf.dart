import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../data/models/flat.dart';
import '../../../data/models/society.dart';
import '../../../data/repositories/delivery_repository.dart';

class BillPdf {
  static Future<void> shareInvoice({
    required Flat flat,
    required Society? society,
    required MonthlySummary summary,
    required DateTime month,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Milk Delivery — Monthly Bill',
                  style: pw.TextStyle(
                      fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text(
                  'Month: ${month.year}-${month.month.toString().padLeft(2, '0')}'),
              pw.Divider(),
              pw.Text('Flat: ${flat.flatNumber}'),
              pw.Text('Owner: ${flat.ownerName}'),
              pw.Text('Phone: ${flat.ownerPhone}'),
              if (society != null) pw.Text('Society: ${society.name}'),
              pw.SizedBox(height: 16),
              pw.Table.fromTextArray(
                headers: const ['Metric', 'Value'],
                data: [
                  ['Days delivered (billable)',
                      '${summary.daysDelivered}'],
                  ['Days subscriber paused (not billable)',
                      '${summary.daysSubscriberPaused}'],
                  ['Days milkman absent (not billable)',
                      '${summary.daysMilkmanAbsent}'],
                  ['Days with custom qty', '${summary.daysCustom}'],
                  ['Total litres delivered', '${summary.totalLitres}L'],
                  ['Price per litre',
                      '${summary.pricePerLitre.toStringAsFixed(2)}'],
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                'Amount due: ₹${summary.amountDue.toStringAsFixed(2)}',
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename:
          'milk-bill-${flat.flatNumber}-${month.year}-${month.month}.pdf',
    );
  }
}
