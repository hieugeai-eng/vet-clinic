import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../constants/app_colors.dart';

class PdfPreviewView extends StatelessWidget {
  final String title;
  final Future<Uint8List> Function() buildPdf;
  final PdfPageFormat? initialPageFormat;

  const PdfPreviewView({
    super.key,
    required this.title,
    required this.buildPdf,
    this.initialPageFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: PdfPreview(
        build: (format) => buildPdf(),
        initialPageFormat: initialPageFormat ?? PdfPageFormat.a4,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        allowSharing: true,
        allowPrinting: true,
        maxPageWidth:
            800, // Limit width to ensure vertical scrolling works better on large screens
        actions: [],
        onError: (context, error) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
