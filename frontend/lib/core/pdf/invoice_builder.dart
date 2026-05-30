import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../utils/printing_service.dart';

/// Data model for building an invoice PDF.
class InvoiceData {
  final String number;
  final DateTime date;
  final DateTime? dueDate;
  final String status;

  final String companyName;
  final String? companyAddress;
  final String? companyPhone;
  final String? companyTaxNumber;

  final String customerName;
  final String? customerAddress;
  final String? customerPhone;

  final List<InvoiceLineItem> items;
  final String currency;
  final double taxRate;
  final String? notes;

  const InvoiceData({
    required this.number,
    required this.date,
    required this.companyName,
    required this.customerName,
    required this.items,
    this.dueDate,
    this.status = 'pending',
    this.companyAddress,
    this.companyPhone,
    this.companyTaxNumber,
    this.customerAddress,
    this.customerPhone,
    this.currency = 'SAR',
    this.taxRate = 15.0,
    this.notes,
  });

  double get subtotal =>
      items.fold(0, (s, i) => s + i.qty * i.unitPrice - i.discount);
  double get taxAmount => subtotal * (taxRate / 100);
  double get total => subtotal + taxAmount;
}

class InvoiceLineItem {
  final String name;
  final String? description;
  final double qty;
  final double unitPrice;
  final double discount;

  const InvoiceLineItem({
    required this.name,
    required this.qty,
    required this.unitPrice,
    this.description,
    this.discount = 0,
  });

  double get lineTotal => qty * unitPrice - discount;
}

/// Builds a complete Arabic RTL invoice PDF using the shared PrintingService.
class InvoiceBuilder {
  static Future<Uint8List> build(InvoiceData invoice) async {
    final regular = await PrintingService.loadArabicFont();
    final bold = await PrintingService.loadArabicFont(bold: true);
    return _buildBytes(invoice, regular, bold);
  }

  static Future<Uint8List> _buildBytes(
    InvoiceData invoice,
    pw.Font regular,
    pw.Font bold,
  ) async {
    final doc = pw.Document(title: 'فاتورة # ${invoice.number}');
    final fmt = DateFormat('yyyy-MM-dd');

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      margin: const pw.EdgeInsets.all(30),
      build: (ctx) => [
        PrintingService.buildDocumentHeader(
          companyName: invoice.companyName,
          documentTitle: 'فاتورة',
          documentNumber: invoice.number,
          date: fmt.format(invoice.date),
          regular: regular,
          bold: bold,
          companySubtitle: [
            if (invoice.companyAddress != null) invoice.companyAddress!,
            if (invoice.companyPhone != null) 'هاتف: ${invoice.companyPhone}',
            if (invoice.companyTaxNumber != null) 'الرقم الضريبي: ${invoice.companyTaxNumber}',
          ].join('  ·  ').ifEmpty(null),
        ),
        _metaRow(invoice, regular, bold, fmt),
        pw.SizedBox(height: 12),
        _itemsTable(invoice, regular, bold),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (invoice.notes != null)
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('ملاحظات:',
                        style: pw.TextStyle(font: bold, fontSize: 10)),
                    pw.SizedBox(height: 4),
                    pw.Text(invoice.notes!,
                        style: pw.TextStyle(font: regular, fontSize: 10,
                            color: PdfColors.grey700)),
                  ],
                ),
              )
            else
              pw.Spacer(),
            PrintingService.buildTotalsBlock(
              subtotal: invoice.subtotal,
              total: invoice.total,
              taxRate: invoice.taxRate,
              taxAmount: invoice.taxAmount,
              currency: invoice.currency,
              regular: regular,
              bold: bold,
            ),
          ],
        ),
      ],
    ));

    return doc.save();
  }

  static pw.Widget _metaRow(
    InvoiceData invoice,
    pw.Font regular,
    pw.Font bold,
    DateFormat fmt,
  ) {
    final labelStyle = pw.TextStyle(font: regular, fontSize: 9, color: PdfColors.grey600);
    final valueStyle = pw.TextStyle(font: bold, fontSize: 10);

    pw.Widget col(String label, List<String> lines) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: labelStyle),
            ...lines.map((l) => pw.Text(l, style: valueStyle)),
          ],
        );

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          col('العميل', [
            invoice.customerName,
            if (invoice.customerAddress != null) invoice.customerAddress!,
            if (invoice.customerPhone != null) 'هاتف: ${invoice.customerPhone!}',
          ]),
          col('تواريخ', [
            'الإصدار: ${fmt.format(invoice.date)}',
            if (invoice.dueDate != null) 'الاستحقاق: ${fmt.format(invoice.dueDate!)}',
          ]),
          _statusBadge(invoice.status, regular, bold),
        ],
      ),
    );
  }

  static pw.Widget _statusBadge(String status, pw.Font regular, pw.Font bold) {
    final (label, bg, fg) = switch (status) {
      'paid' => ('مدفوعة', PdfColors.green100, PdfColors.green900),
      'overdue' => ('متأخرة', PdfColors.red100, PdfColors.red900),
      _ => ('معلقة', PdfColors.orange100, PdfColors.orange900),
    };

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(20)),
      ),
      child: pw.Text(label,
          style: pw.TextStyle(font: bold, fontSize: 11, color: fg)),
    );
  }

  static pw.Widget _itemsTable(
    InvoiceData invoice,
    pw.Font regular,
    pw.Font bold,
  ) {
    return PrintingService.buildItemsTable(
      headers: ['#', 'الصنف', 'الكمية', 'سعر الوحدة', 'الخصم', 'الإجمالي'],
      keys: ['num', 'name', 'qty', 'unit_price', 'discount', 'total'],
      items: invoice.items.asMap().entries.map((e) {
        final i = e.value;
        return {
          'num': '${e.key + 1}',
          'name': i.name + (i.description != null ? '\n${i.description}' : ''),
          'qty': i.qty.toStringAsFixed(2),
          'unit_price': '${i.unitPrice.toStringAsFixed(2)} ${invoice.currency}',
          'discount': '${i.discount.toStringAsFixed(2)} ${invoice.currency}',
          'total': '${i.lineTotal.toStringAsFixed(2)} ${invoice.currency}',
        };
      }).toList(),
      regular: regular,
      bold: bold,
      currency: invoice.currency,
    );
  }
}

extension _StringX on String {
  String? ifEmpty(String? fallback) => isEmpty ? fallback : this;
}
