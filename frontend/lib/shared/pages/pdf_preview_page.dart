import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

/// Full-screen PDF preview with built-in print/share actions.
/// Works on all platforms supported by the `printing` package.
class PdfPreviewPage extends StatelessWidget {
  final String title;
  final Future<Uint8List> Function() pdfBytes;

  const PdfPreviewPage({
    super.key,
    required this.title,
    required this.pdfBytes,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'مشاركة',
            onPressed: () async {
              final bytes = await pdfBytes();
              await Printing.sharePdf(
                bytes: bytes,
                filename: '$title.pdf',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'طباعة',
            onPressed: () async {
              await Printing.layoutPdf(
                name: title,
                onLayout: (_) => pdfBytes(),
              );
            },
          ),
        ],
      ),
      body: PdfPreview(
        useActions: false,
        build: (_) => pdfBytes(),
      ),
    );
  }
}
