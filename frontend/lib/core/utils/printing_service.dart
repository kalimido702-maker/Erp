import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Central printing service — all PDF generation goes through here.
/// Uses Google Fonts online (or cached), with a local-asset fallback.
class PrintingService {
  // ── Font loading ──────────────────────────────────────────────────────

  static Future<pw.Font> loadArabicFont({bool bold = false}) async {
    try {
      return bold
          ? await PdfGoogleFonts.cairoBold()
          : await PdfGoogleFonts.cairoRegular();
    } catch (_) {
      // Offline fallback: load the Cairo font we bundle in assets/fonts/
      final data = await rootBundle.load(
        bold ? 'assets/fonts/Cairo-Bold.ttf' : 'assets/fonts/Cairo-Regular.ttf',
      );
      return pw.Font.ttf(data);
    }
  }

  // ── Rendering actions ─────────────────────────────────────────────────

  static Future<void> printDocument({
    required String title,
    required Future<Uint8List> Function(pw.Font regular, pw.Font bold) buildPdf,
  }) async {
    final regular = await loadArabicFont();
    final bold = await loadArabicFont(bold: true);

    await Printing.layoutPdf(
      name: title,
      onLayout: (_) => buildPdf(regular, bold),
    );
  }

  static Future<void> sharePdf({
    required String title,
    required Future<Uint8List> Function(pw.Font regular, pw.Font bold) buildPdf,
  }) async {
    final regular = await loadArabicFont();
    final bold = await loadArabicFont(bold: true);
    final bytes = await buildPdf(regular, bold);

    await Printing.sharePdf(bytes: bytes, filename: '$title.pdf');
  }

  static Future<void> previewPdf({
    required BuildContext context,
    required String title,
    required Future<Uint8List> Function(pw.Font regular, pw.Font bold) buildPdf,
  }) async {
    final regular = await loadArabicFont();
    final bold = await loadArabicFont(bold: true);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfPreviewPage(
          title: title,
          build: (_) => buildPdf(regular, bold),
        ),
      ),
    );
  }

  // ── Shared layout widgets ─────────────────────────────────────────────

  static pw.Widget buildDocumentHeader({
    required String companyName,
    required String documentTitle,
    required String documentNumber,
    required String date,
    required pw.Font regular,
    required pw.Font bold,
    String? companySubtitle,
  }) {
    final headerStyle = pw.TextStyle(font: bold, fontSize: 16, color: PdfColors.blueGrey900);
    final subStyle = pw.TextStyle(font: regular, fontSize: 10, color: PdfColors.grey700);
    final metaStyle = pw.TextStyle(font: regular, fontSize: 11);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(companyName, style: headerStyle),
                if (companySubtitle != null)
                  pw.Text(companySubtitle, style: subStyle),
              ],
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey900,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(documentTitle,
                      style: pw.TextStyle(font: bold, fontSize: 14, color: PdfColors.white)),
                  pw.Text('# $documentNumber',
                      style: pw.TextStyle(font: regular, fontSize: 10, color: PdfColors.grey300)),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text('التاريخ: $date', style: metaStyle),
          ],
        ),
        pw.Divider(thickness: 2, color: PdfColors.blueGrey900),
        pw.SizedBox(height: 8),
      ],
    );
  }

  static pw.Widget buildItemsTable({
    required List<Map<String, dynamic>> items,
    required List<String> headers,
    required List<String> keys,
    required pw.Font regular,
    required pw.Font bold,
    String currency = 'SAR',
  }) {
    final headerTextStyle =
        pw.TextStyle(font: bold, fontSize: 10, color: PdfColors.white);
    final cellStyle = pw.TextStyle(font: regular, fontSize: 10);

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {for (var i = 0; i < headers.length; i++) i: const pw.FlexColumnWidth()},
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
          children: headers
              .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.all(7),
                    child: pw.Text(h, style: headerTextStyle, textAlign: pw.TextAlign.center),
                  ))
              .toList(),
        ),
        ...items.asMap().entries.map(
          (entry) => pw.TableRow(
            decoration: pw.BoxDecoration(
              color: entry.key.isEven ? PdfColors.grey100 : PdfColors.white,
            ),
            children: keys
                .map((k) => pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        entry.value[k]?.toString() ?? '',
                        style: cellStyle,
                        textAlign: pw.TextAlign.center,
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  static pw.Widget buildTotalsBlock({
    required double subtotal,
    required double total,
    required pw.Font regular,
    required pw.Font bold,
    double discount = 0,
    double taxRate = 0,
    double taxAmount = 0,
    String currency = 'SAR',
  }) {
    final labelStyle = pw.TextStyle(font: regular, fontSize: 10);
    final valueStyle = pw.TextStyle(font: regular, fontSize: 10);
    final totalStyle = pw.TextStyle(font: bold, fontSize: 12, color: PdfColors.white);

    pw.TableRow row(String label, String value, {bool isTotal = false}) =>
        pw.TableRow(
          decoration: isTotal
              ? const pw.BoxDecoration(color: PdfColors.blueGrey900)
              : null,
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: pw.Text(label, style: isTotal ? totalStyle : labelStyle),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: pw.Text(value, style: isTotal ? totalStyle : valueStyle,
                  textAlign: pw.TextAlign.right),
            ),
          ],
        );

    return pw.Container(
      alignment: pw.Alignment.centerLeft,
      child: pw.SizedBox(
        width: 220,
        child: pw.Table(
          columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(1.5)},
          children: [
            row('المجموع الفرعي', '${subtotal.toStringAsFixed(2)} $currency'),
            if (discount > 0)
              row('الخصم', '- ${discount.toStringAsFixed(2)} $currency'),
            if (taxRate > 0)
              row('ضريبة القيمة المضافة ($taxRate%)',
                  '${taxAmount.toStringAsFixed(2)} $currency'),
            row('الإجمالي', '${total.toStringAsFixed(2)} $currency',
                isTotal: true),
          ],
        ),
      ),
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
