import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../utils/printing_service.dart';

class ReportSummaryCard {
  final String label;
  final String value;
  final PdfColor? color;
  const ReportSummaryCard({required this.label, required this.value, this.color});
}

class ReportData {
  final String title;
  final String? period;
  final String companyName;
  final List<String> columns;
  final List<List<String>> rows;
  final List<ReportSummaryCard> summary;
  final String? notes;

  const ReportData({
    required this.title,
    required this.companyName,
    required this.columns,
    required this.rows,
    this.period,
    this.summary = const [],
    this.notes,
  });
}

/// Builds a generic tabular report PDF with optional summary cards.
class ReportBuilder {
  static Future<Uint8List> build(ReportData report) async {
    final regular = await PrintingService.loadArabicFont();
    final bold = await PrintingService.loadArabicFont(bold: true);

    final doc = pw.Document(title: report.title);

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      margin: const pw.EdgeInsets.all(30),
      build: (ctx) => [
        PrintingService.buildDocumentHeader(
          companyName: report.companyName,
          documentTitle: report.title,
          documentNumber: report.period ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
          date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
          regular: regular,
          bold: bold,
        ),
        if (report.summary.isNotEmpty) ...[
          _summaryCards(report.summary, regular, bold),
          pw.SizedBox(height: 14),
        ],
        PrintingService.buildItemsTable(
          headers: report.columns,
          keys: List.generate(report.columns.length, (i) => '$i'),
          items: report.rows.map((row) {
            return {for (var i = 0; i < row.length; i++) '$i': row[i]};
          }).toList(),
          regular: regular,
          bold: bold,
        ),
        if (report.notes != null) ...[
          pw.SizedBox(height: 14),
          pw.Divider(color: PdfColors.grey300),
          pw.Text(report.notes!,
              style: pw.TextStyle(font: regular, fontSize: 9, color: PdfColors.grey600)),
        ],
      ],
    ));

    return doc.save();
  }

  static pw.Widget _summaryCards(
    List<ReportSummaryCard> cards,
    pw.Font regular,
    pw.Font bold,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
      children: cards.map((c) {
        return pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.symmetric(horizontal: 4),
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border(
                top: pw.BorderSide(
                  color: c.color ?? PdfColors.blueGrey900,
                  width: 3,
                ),
              ),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(c.label,
                    style: pw.TextStyle(
                        font: regular, fontSize: 9, color: PdfColors.grey700)),
                pw.SizedBox(height: 3),
                pw.Text(c.value,
                    style: pw.TextStyle(
                        font: bold,
                        fontSize: 16,
                        color: c.color ?? PdfColors.blueGrey900)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
