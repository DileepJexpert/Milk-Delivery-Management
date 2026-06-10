import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../data/local/local_store.dart';
import '../../../data/models/flat.dart';
import '../../../data/models/product.dart';
import '../../../data/models/society.dart';
import '../../../data/repositories/delivery_repository.dart';

class BillPdf {
  static Future<void> shareInvoice({
    required Flat flat,
    required Society? society,
    required MonthlySummary summary,
    required DateTime month,
  }) async {
    // Map product id → display name/unit for the line-items table.
    final productsById = <String, Product>{};
    for (final raw in LocalStore.instance.products.values.whereType<Map>()) {
      final p = Product.fromJson(raw);
      productsById[p.id] = p;
    }

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
              pw.Text(
                  'Billing mode: ${flat.billingMode == BillingMode.prepaid ? "Prepaid" : "Postpaid"}'),
              if (flat.billingMode == BillingMode.prepaid)
                pw.Text(
                    'Wallet balance: ₹${flat.walletBalance.toStringAsFixed(2)}'),
              pw.SizedBox(height: 16),
              if (summary.products.isNotEmpty) ...[
                pw.Text('Per-product breakdown',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Table.fromTextArray(
                  headers: const ['Product', 'Days', 'Quantity', 'Subtotal'],
                  data: [
                    for (final line in summary.products)
                      [
                        productsById[line.productId]?.name ?? '—',
                        '${line.days}',
                        '${line.quantity.toStringAsFixed(2)} ${productsById[line.productId]?.unit.short ?? ''}',
                        '₹${line.subtotal.toStringAsFixed(2)}',
                      ],
                  ],
                ),
                pw.SizedBox(height: 12),
              ],
              pw.Table.fromTextArray(
                headers: const ['Metric', 'Value'],
                data: [
                  ['Days delivered (billable)', '${summary.daysDelivered}'],
                  [
                    'Days subscriber paused (not billable)',
                    '${summary.daysSubscriberPaused}'
                  ],
                  [
                    'Days milkman absent (not billable)',
                    '${summary.daysMilkmanAbsent}'
                  ],
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                'Amount due: ₹${summary.totalAmount.toStringAsFixed(2)}',
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
