import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class HospitalizationPdfGenerator {
  static Future<Uint8List> generateDischargePaper({
    required String petName,
    required String customerName,
    required String species,
    required DateTime admissionDate,
    required DateTime dischargeDate,
    required String diagnosis,
    required List<Map<String, dynamic>> services, // name, quantity, total
    required double totalCost,
    String? clinicName = "PETCLINIC",
    String? clinicAddress = "Hà Nội, Việt Nam",
    String? clinicPhone = "0912.345.678",
  }) async {
    final pdf = pw.Document();

    // Load font if needed (Roboto usually standard, but for Vietnamese/Unicode we might need custom font)
    // printing package handles fonts well usually, but let's try standard first.
    // For Vietnamese, we often need a font like Roboto or OpenSans.
    // We'll rely on Printing.layoutPdf or standard theme.
    // If we return bytes, we need to embed font.
    // Let's assume the system font or bundled font.
    // To be safe for Vietnamese, let's use a standard font loader if possible, or default.
    // Printing package's `font` param in `Printing.layoutPdf` helps.
    // Here we generate the Document.

    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5, // A5 is common for receipts/summaries
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      clinicName!,
                      style: pw.TextStyle(font: fontBold, fontSize: 18),
                    ),
                    pw.Text(
                      clinicAddress!,
                      style: pw.TextStyle(font: font, fontSize: 10),
                    ),
                    pw.Text(
                      'Hotline: $clinicPhone',
                      style: pw.TextStyle(font: font, fontSize: 10),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'PHIẾU XUẤT VIỆN',
                      style: pw.TextStyle(font: fontBold, fontSize: 20),
                    ),
                    pw.Text(
                      '(DISCHARGE SUMMARY)',
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 10,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Patient Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Chủ vật nuôi: $customerName',
                        style: pw.TextStyle(font: font),
                      ),
                      pw.Text(
                        'Thú cưng: $petName ($species)',
                        style: pw.TextStyle(font: fontBold),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Ngày vào: ${dateFormat.format(admissionDate)}',
                        style: pw.TextStyle(font: font),
                      ),
                      pw.Text(
                        'Ngày ra: ${dateFormat.format(dischargeDate)}',
                        style: pw.TextStyle(font: font),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),

              // Diagnosis
              pw.Text(
                'Chẩn đoán / Lý do nhập viện:',
                style: pw.TextStyle(font: fontBold),
              ),
              pw.Text(diagnosis, style: pw.TextStyle(font: font)),
              pw.SizedBox(height: 10),

              // Service List Table
              pw.Text(
                'Tổng hợp dịch vụ & điều trị:',
                style: pw.TextStyle(font: fontBold),
              ),
              pw.SizedBox(height: 5),
              pw.Table.fromTextArray(
                context: context,
                border: null,
                headerStyle: pw.TextStyle(font: fontBold, fontSize: 10),
                cellStyle: pw.TextStyle(font: font, fontSize: 10),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                data: [
                  ['Dịch vụ / Thuốc', 'SL', 'Thành tiền'],
                  ...services
                      .map(
                        (s) => [
                          s['name'],
                          s['quantity'].toString(),
                          currencyFormat.format(s['total']),
                        ],
                      )
                      .toList(),
                ],
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(2),
                },
              ),
              pw.Divider(),

              // Total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'Tổng cộng: ',
                    style: pw.TextStyle(font: fontBold, fontSize: 14),
                  ),
                  pw.Text(
                    currencyFormat.format(totalCost),
                    style: pw.TextStyle(font: fontBold, fontSize: 16),
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('Khách hàng', style: pw.TextStyle(font: font)),
                      pw.SizedBox(height: 40),
                      pw.Text(
                        customerName,
                        style: pw.TextStyle(font: font, fontSize: 10),
                      ),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text(
                        'Bác sĩ điều trị',
                        style: pw.TextStyle(font: font),
                      ),
                      pw.SizedBox(height: 40),
                      pw.Text(
                        'PetClinic',
                        style: pw.TextStyle(font: font, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
