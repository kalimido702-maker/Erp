import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PrintingService {
  static Future<void> printDocument({
    required String title,
    required Future<Uint8List> Function(pw.Font arabicFont) buildPdf,
  }) async {
    final arabicFont = await PdfGoogleFonts.cairoRegular();

    await Printing.layoutPdf(
      name: title,
      onLayout: (_) => buildPdf(arabicFont),
    );
  }

  static Future<void> sharePdf({
    required String title,
    required Future<Uint8List> Function(pw.Font arabicFont) buildPdf,
  }) async {
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final bytes = await buildPdf(arabicFont);

    await Printing.sharePdf(bytes: bytes, filename: '$title.pdf');
  }

  static Future<void> previewPdf({
    required BuildContext context,
    required String title,
    required Future<Uint8List> Function(pw.Font arabicFont) buildPdf,
  }) async {
    final arabicFont = await PdfGoogleFonts.cairoRegular();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfPreviewPage(
          title: title,
          build: (_) => buildPdf(arabicFont),
        ),
      ),
    );
  }

  // Reusable PDF header for all documents
  static pw.Widget buildDocumentHeader({
    required String companyName,
    required String documentTitle,
    required String documentNumber,
    required String date,
    required pw.Font font,
  }) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(companyName, style: pw.TextStyle(font: font, fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text(documentTitle, style: pw.TextStyle(font: font, fontSize: 14, color: PdfColors.grey700)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('رقم: $documentNumber', style: pw.TextStyle(font: font, fontSize: 12)),
                pw.Text('التاريخ: $date', style: pw.TextStyle(font: font, fontSize: 12)),
              ],
            ),
          ],
        ),
        pw.Divider(thickness: 2, color: PdfColors.blueGrey800),
        pw.SizedBox(height: 8),
      ],
    );
  }

  // Reusable items table
  static pw.Widget buildItemsTable({
    required List<Map<String, dynamic>> items,
    required List<String> headers,
    required List<String> keys,
    required pw.Font font,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {for (var i = 0; i < headers.length; i++) i: const pw.FlexColumnWidth()},
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
          children: headers
              .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(h, style: pw.TextStyle(font: font, color: PdfColors.white, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                  ))
              .toList(),
        ),
        ...items.asMap().entries.map((e) => pw.TableRow(
              decoration: pw.BoxDecoration(color: e.key.isEven ? PdfColors.grey100 : PdfColors.white),
              children: keys
                  .map((k) => pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(e.value[k]?.toString() ?? '', style: pw.TextStyle(font: font), textAlign: pw.TextAlign.center),
                      ))
                  .toList(),
            )),
      ],
    );
  }
}

class PdfPreviewPage extends StatelessWidget {
  final String title;
  final LayoutCallback build;

  const PdfPreviewPage({super.key, required this.title, required this.build});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PdfPreview(build: build),
    );
  }
}
