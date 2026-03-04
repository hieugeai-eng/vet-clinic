import 'dart:typed_data';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';

import '../data/models/medical_case_model.dart';
import '../data/models/customer_model.dart';
import '../data/models/pet_model.dart';
import '../data/models/service_model.dart';
import '../data/models/case_attachment_model.dart';
import '../data/repositories/case_attachment_repository.dart';
import '../core/utils/formatters.dart';
import '../data/providers/local/database_provider.dart';

/// Service for generating PDF documents
class PdfService extends GetxService {
  Future<Map<String, String>> _loadSettings() async {
    try {
      final db = await DatabaseProvider.instance.database;
      final List<Map<String, dynamic>> maps = await db.query('settings');
      return {
        for (var item in maps) item['key'] as String: item['value'] as String,
      };
    } catch (e) {
      return {};
    }
  }

  Future<pw.MemoryImage?> _loadLogo(String? path) async {
    if (path == null) return null;
    try {
      final file = File(path);
      if (await file.exists()) {
        return pw.MemoryImage(await file.readAsBytes());
      }
    } catch (e) {
      // ignore error
    }
    return null;
  }

  /// Generate medical case PDF
  Future<Uint8List> generateMedicalCasePdf({
    required MedicalCaseModel medicalCase,
    required CustomerModel customer,
    required PetModel pet,
    required List<CaseServiceModel> services,
  }) async {
    final pdf = pw.Document();

    // Load settings
    final settings = await _loadSettings();
    final logo = await _loadLogo(settings['clinic_logo_path']);

    // Load Vietnamese font (handle offline/error)
    pw.Font font;
    pw.Font fontBold;
    pw.Font fontItalic;
    pw.Font fontBoldItalic;

    try {
      font = await PdfGoogleFonts.robotoRegular();
      fontBold = await PdfGoogleFonts.robotoBold();
      fontItalic = await PdfGoogleFonts.robotoItalic();
      fontBoldItalic = await PdfGoogleFonts.robotoBoldItalic();
    } catch (e) {
      Get.snackbar(
        'Cảnh báo',
        'Không tải được font tiếng Việt. PDF có thể bị lỗi hiển thị.',
      );
      // Fallback to standard fonts (Unicode might fail)
      font = pw.Font.courier();
      fontBold = pw.Font.courierBold();
      fontItalic = pw.Font.courierOblique();
      fontBoldItalic = pw.Font.courierBoldOblique();
    }

    final theme = pw.ThemeData.withFont(
      base: font,
      bold: fontBold,
      italic: fontItalic,
      boldItalic: fontBoldItalic,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: theme,
        header: (context) => _buildHeader(medicalCase, settings, logo),
        footer: (context) => _buildFooter(medicalCase),
        build: (context) {
          return [
            // Customer & Pet info
            pw.SizedBox(height: 20),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: _buildCustomerInfo(customer)),
                pw.SizedBox(width: 20),
                pw.Expanded(child: _buildPetInfo(pet)),
              ],
            ),
            pw.SizedBox(height: 15),

            // Visit reasons
            _buildVisitReasons(medicalCase),
            pw.SizedBox(height: 15),

            // Vital signs
            _buildVitalSigns(medicalCase),
            pw.SizedBox(height: 15),

            // Diagnosis
            _buildDiagnosis(medicalCase),
            pw.SizedBox(height: 15),

            // Services
            ..._buildServices(services, medicalCase),
            pw.SizedBox(height: 15),

            // Payment
            _buildPayment(medicalCase),

            pw.SizedBox(height: 15),

            // Notes
            _buildNotes(medicalCase),

            pw.SizedBox(height: 30),

            // Signatures
            _buildSignatures(medicalCase),
          ];
        },
      ),
    );

    // ===== ATTACHMENT PAGES =====
    try {
      final attachmentRepo = CaseAttachmentRepository();
      final attachments = await attachmentRepo.getByCase(medicalCase.id);
      debugPrint(
        '📄 PDF: Loading attachments for case ${medicalCase.id} — found ${attachments.length}',
      );

      if (attachments.isNotEmpty) {
        final attachmentWidgets = await _buildAttachmentWidgets(
          attachments,
          medicalCase,
          services,
        );
        debugPrint(
          '📄 PDF: Built ${attachmentWidgets.length} attachment widgets',
        );

        if (attachmentWidgets.isNotEmpty) {
          pdf.addPage(
            pw.MultiPage(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(40),
              theme: theme,
              header: (context) => pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 10),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey400),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'PHỤ LỤC — KẾT QUẢ CẬN LÂM SÀNG & HÌNH ẢNH',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Ca: ${medicalCase.caseCode}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
              footer: (context) => pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Phụ lục trang ${context.pageNumber}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey500,
                  ),
                ),
              ),
              build: (context) => attachmentWidgets,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('PdfService: Could not load attachments - $e');
    }

    return pdf.save();
  }

  pw.Widget _buildHeader(
    MedicalCaseModel medicalCase,
    Map<String, String> settings,
    pw.MemoryImage? logo,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              if (logo != null) ...[
                pw.Image(logo, width: 50, height: 50),
                pw.SizedBox(width: 10),
              ],
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    settings['clinic_name']?.toUpperCase() ?? 'PETCLINIC',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (settings['clinic_address'] != null)
                    pw.Text(
                      settings['clinic_address']!,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  if (settings['clinic_phone'] != null)
                    pw.Text(
                      'SĐT: ${settings['clinic_phone']}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'BỆNH ÁN THÚ Y',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Ca số: ${medicalCase.caseCode}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Ngày: ${Formatters.formatDateTime(medicalCase.admissionDate)}',
                style: const pw.TextStyle(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildCustomerInfo(CustomerModel customer) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'CHỦ BỆNH SÚC',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(),
          _buildInfoRow('Họ tên:', customer.name),
          _buildInfoRow('SĐT:', Formatters.formatPhone(customer.phone)),
          _buildInfoRow('Địa chỉ:', customer.address ?? 'N/A'),
        ],
      ),
    );
  }

  pw.Widget _buildPetInfo(PetModel pet) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'THÚ CƯNG',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(),
          _buildInfoRow('Tên:', pet.name),
          _buildInfoRow('Loài:', pet.species.tr),
          _buildInfoRow('Giống:', (pet.breed ?? 'N/A').tr),
          // ... (inside _buildPetInfo)
          pw.Row(
            children: [
              pw.Expanded(child: _buildInfoRow('Tuổi:', pet.displayAge)),
              pw.Expanded(
                child: _buildInfoRow('Giới tính:', (pet.gender ?? '').tr),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildVitalSigns(MedicalCaseModel medicalCase) {
    final vs = medicalCase.vitalSigns;

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'KHÁM LÂM SÀNG / SINH HIỆU',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildInfoRow(
                  'Nhiệt độ:',
                  vs?.temperature != null ? '${vs!.temperature}°C' : '',
                ),
              ),
              pw.Expanded(
                child: _buildInfoRow(
                  'Cân nặng:',
                  vs?.weight != null ? '${vs!.weight} kg' : '',
                ),
              ),
              pw.Expanded(
                child: _buildInfoRow(
                  'Thể trạng:',
                  (vs?.bodyCondition != null && vs!.bodyCondition!.isNotEmpty)
                      ? vs.bodyCondition!.tr
                      : '',
                ),
              ),
            ],
          ),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildInfoRow(
                  'Phân:',
                  (vs?.stoolCondition != null && vs!.stoolCondition!.isNotEmpty)
                      ? vs.stoolCondition!.tr
                      : '',
                ),
              ),
              pw.Expanded(
                child: _buildInfoRow(
                  'Tinh thần:',
                  (vs?.mentalStatus != null && vs!.mentalStatus!.isNotEmpty)
                      ? vs.mentalStatus!.tr
                      : '',
                ),
              ),
              pw.Expanded(
                child: _buildInfoRow(
                  'Nôn:',
                  (vs?.vomitingCount ?? 0) > 0 ? 'Có' : 'Không',
                ),
              ),
            ],
          ),
          _buildInfoRow(
            'Da & Niêm mạc:',
            (vs?.skinMucosa != null && vs!.skinMucosa!.isNotEmpty)
                ? vs.skinMucosa!
                : '',
          ),
          _buildInfoRow(
            'Thông tin khác:',
            (vs?.otherInfo != null && vs!.otherInfo!.isNotEmpty)
                ? vs.otherInfo!
                : '',
          ),
        ],
      ),
    );
  }

  pw.Widget _buildVisitReasons(MedicalCaseModel medicalCase) {
    final reasonsStr = medicalCase.visitReasons.isNotEmpty
        ? medicalCase.visitReasons.map((e) => e.tr).join(', ')
        : '';
    final notesStr =
        (medicalCase.reasonNotes != null && medicalCase.reasonNotes!.isNotEmpty)
        ? medicalCase.reasonNotes!
        : '';

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'LÝ DO VÀO VIỆN & TRIỆU CHỨNG',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(),
          _buildInfoRow('Lý do chính:', reasonsStr),
          _buildInfoRow('Ghi chú chi tiết:', notesStr),
        ],
      ),
    );
  }

  pw.Widget _buildDiagnosis(MedicalCaseModel medicalCase) {
    String prognosisText;
    switch (medicalCase.prognosis) {
      case 'good':
        prognosisText = 'Tốt';
        break;
      case 'bad':
        prognosisText = 'Xấu';
        break;
      case 'uncertain':
        prognosisText = 'Nghi ngờ';
        break;
      default:
        prognosisText = 'Nghi ngờ';
    }

    final diagStr =
        (medicalCase.diagnosis != null && medicalCase.diagnosis!.isNotEmpty)
        ? medicalCase.diagnosis!
        : '';
    final planStr =
        (medicalCase.treatmentPlan != null &&
            medicalCase.treatmentPlan!.isNotEmpty)
        ? medicalCase.treatmentPlan!
        : '';

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'CHẨN ĐOÁN & HƯỚNG ĐIỀU TRỊ',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(),
          _buildInfoRow('Kết luận chẩn đoán:', diagStr),
          _buildInfoRow('Tiên lượng:', prognosisText),
          _buildInfoRow('Phác đồ điều trị:', planStr),
        ],
      ),
    );
  }

  pw.Widget _buildNotes(MedicalCaseModel medicalCase) {
    final notesStr =
        (medicalCase.notes != null && medicalCase.notes!.isNotEmpty)
        ? medicalCase.notes!
        : '';

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'LỜI DẶN / GHI CHÚ',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(),
          pw.Text(notesStr),
        ],
      ),
    );
  }

  List<pw.Widget> _buildServices(
    List<CaseServiceModel> services,
    MedicalCaseModel medicalCase,
  ) {
    return [
      pw.Text(
        'DỊCH VỤ / ĐIỀU TRỊ',
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      ),
      pw.Divider(),
      pw.SizedBox(height: 5),

      // Using Table.fromTextArray for automatic pagination and header repetition
      pw.Table.fromTextArray(
        border: const pw.TableBorder(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
          horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
        columnWidths: {
          0: const pw.FlexColumnWidth(3), // Service Name
          1: const pw.FlexColumnWidth(0.7), // Quantity
          2: const pw.FlexColumnWidth(1.5), // Unit Price
          3: const pw.FlexColumnWidth(1.5), // Discount
          4: const pw.FlexColumnWidth(1.8), // Total
        },
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        cellStyle: const pw.TextStyle(fontSize: 10),
        cellPadding: const pw.EdgeInsets.all(5),
        cellAlignments: {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.center,
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
          4: pw.Alignment.centerRight,
        },
        headers: ['Dịch vụ', 'SL', 'Đơn giá', 'Giảm giá', 'Thành tiền'],
        data: services.expand((s) {
          final rows = <List<String>>[];
          // Service Row
          rows.add([
            s.serviceName,
            '${s.quantity}',
            Formatters.formatCurrency(s.unitPrice),
            s.discount > 0 ? Formatters.formatCurrency(s.discount) : '-',
            Formatters.formatCurrency(s.total),
          ]);
          // Attached Medicines Rows
          for (final m in s.attachedMedicines) {
            rows.add([
              '  • ${m.name} (${m.dosage}) ${m.note.isNotEmpty ? '- ${m.note}' : ''} [SL: ${m.quantity}]',
              '',
              '',
              '',
              '',
            ]);
          }
          return rows;
        }).toList(),
      ),

      pw.SizedBox(height: 10),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(
            'TỔNG DỰ KIẾN: ',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            Formatters.formatCurrency(medicalCase.totalEstimate),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    ];
  }

  pw.Widget _buildPayment(MedicalCaseModel medicalCase) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'THANH TOÁN',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildInfoRow(
                  'Ứng trước:',
                  Formatters.formatCurrency(medicalCase.advancePayment),
                ),
              ),
              pw.Expanded(
                child: _buildInfoRow(
                  'Phương thức:',
                  medicalCase.paymentMethod == 'cash'
                      ? 'Tiền mặt'
                      : 'Chuyển khoản',
                ),
              ),
              pw.Expanded(
                child: _buildInfoRow(
                  'Còn lại:',
                  Formatters.formatCurrency(medicalCase.remainingBalance),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSignatures(MedicalCaseModel medicalCase) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'CAM KẾT CỦA KHÁCH HÀNG:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
          pw.SizedBox(height: 5),
          pw.Row(
            children: [
              pw.Container(
                width: 12,
                height: 12,
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: medicalCase.agreeTreatment
                    ? pw.Center(
                        child: pw.Icon(const pw.IconData(0xe5ca), size: 10),
                      )
                    : null, // check icon
              ),
              pw.SizedBox(width: 5),
              pw.Text(
                'Tôi đồng ý với phác đồ điều trị và chi phí dự kiến',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Row(
            children: [
              pw.Container(
                width: 12,
                height: 12,
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: medicalCase.agreeNoComplaint
                    ? pw.Center(
                        child: pw.Icon(const pw.IconData(0xe5ca), size: 10),
                      )
                    : null, // check icon
              ),
              pw.SizedBox(width: 5),
              pw.Text(
                'Cam kết không khiếu nại về sau',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  children: [
                    pw.Text('Khách hàng ký tên'),
                    pw.SizedBox(height: 50),
                    pw.Container(width: 150, height: 1, color: PdfColors.black),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  children: [
                    pw.Text('Đại diện phòng khám'),
                    pw.SizedBox(height: 50),
                    pw.Container(width: 150, height: 1, color: PdfColors.black),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(MedicalCaseModel medicalCase) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text('Kết quả: ', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Khỏi / Không khỏi / Chết / Không rõ / Khác: ..........'),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ATTACHMENT PAGES ====================

  /// Build attachment widgets grouped by category for PDF appendix
  Future<List<pw.Widget>> _buildAttachmentWidgets(
    List<CaseAttachmentModel> attachments,
    MedicalCaseModel medicalCase,
    List<CaseServiceModel> services,
  ) async {
    final widgets = <pw.Widget>[];

    // Group by category
    final grouped = <String, List<CaseAttachmentModel>>{};
    for (final att in attachments) {
      if (!att.isImage) continue; // Only include images in PDF

      // Filter out attachments belonging to services that have been removed
      // from the UI before the case is saved.
      if (att.caseServiceId != null && att.caseServiceId!.isNotEmpty) {
        final serviceExists = services.any((s) => s.id == att.caseServiceId);
        if (!serviceExists) continue;
      }

      final cat = att.category;
      grouped.putIfAbsent(cat, () => []).add(att);
    }

    if (grouped.isEmpty) return [];

    // Category display order
    const categoryOrder = [
      'xray',
      'ultrasound',
      'lab_result',
      'photo',
      'other',
    ];
    final categoryLabels = {
      'xray': 'X-QUANG',
      'ultrasound': 'SIÊU ÂM',
      'lab_result': 'XÉT NGHIỆM',
      'photo': 'ẢNH CHỤP',
      'other': 'TÀI LIỆU KHÁC',
    };

    for (final cat in categoryOrder) {
      final catAttachments = grouped[cat];
      if (catAttachments == null || catAttachments.isEmpty) continue;

      // Category header
      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 15, bottom: 8),
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey200,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(
            children: [
              pw.Text(
                categoryLabels[cat] ?? cat.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                '  (${catAttachments.length} tệp)',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ),
      );

      // Build image rows (2 columns)
      for (int i = 0; i < catAttachments.length; i += 2) {
        final row = <pw.Widget>[];

        for (int j = i; j < i + 2 && j < catAttachments.length; j++) {
          final att = catAttachments[j];
          pw.Widget imageWidget;

          try {
            final file = File(att.localPath);
            if (await file.exists()) {
              final bytes = await file.readAsBytes();
              imageWidget = pw.Image(
                pw.MemoryImage(bytes),
                fit: pw.BoxFit.contain,
                height: 220,
              );
            } else if (att.remoteUrl != null && att.remoteUrl!.isNotEmpty) {
              // Fallback: download from cloud URL
              try {
                debugPrint(
                  '📄 PDF: Local file not found, downloading from cloud: ${att.remoteUrl}',
                );
                final response = await HttpClient()
                    .getUrl(Uri.parse(att.remoteUrl!))
                    .then((req) => req.close());
                final bytes = await consolidateHttpClientResponseBytes(
                  response,
                );
                imageWidget = pw.Image(
                  pw.MemoryImage(Uint8List.fromList(bytes)),
                  fit: pw.BoxFit.contain,
                  height: 220,
                );
              } catch (downloadError) {
                debugPrint('📄 PDF: Cloud download failed: $downloadError');
                imageWidget = pw.Container(
                  height: 220,
                  color: PdfColors.grey100,
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'Không tải được ảnh\n${att.fileName}',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey500,
                    ),
                  ),
                );
              }
            } else {
              imageWidget = pw.Container(
                height: 220,
                color: PdfColors.grey100,
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'Không tìm thấy file\n${att.fileName}',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey500,
                  ),
                ),
              );
            }
          } catch (e) {
            imageWidget = pw.Container(
              height: 220,
              color: PdfColors.grey100,
              alignment: pw.Alignment.center,
              child: pw.Text(
                'Lỗi đọc file\n${att.fileName}',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.red),
              ),
            );
          }

          // Find linked service name
          String? serviceName;
          if (att.caseServiceId != null) {
            final matchedService = services.where(
              (s) => s.id == att.caseServiceId,
            );
            if (matchedService.isNotEmpty) {
              serviceName = matchedService.first.serviceName;
            }
          }

          row.add(
            pw.Expanded(
              child: pw.Container(
                margin: const pw.EdgeInsets.all(4),
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Center(child: imageWidget),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      att.fileName,
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      maxLines: 1,
                    ),
                    if (serviceName != null)
                      pw.Text(
                        'DV: $serviceName',
                        style: const pw.TextStyle(
                          fontSize: 7,
                          color: PdfColors.blue800,
                        ),
                        maxLines: 1,
                      ),
                    if (att.note != null && att.note!.isNotEmpty)
                      pw.Text(
                        att.note!,
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey700,
                        ),
                        maxLines: 2,
                      ),
                  ],
                ),
              ),
            ),
          );
        }

        // Pad with empty expanded if only 1 item in row
        if (row.length == 1) {
          row.add(pw.Expanded(child: pw.SizedBox()));
        }

        widgets.add(
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: row,
          ),
        );
      }
    }

    return widgets;
  }

  pw.Widget _tableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  /// Print PDF
  Future<void> printMedicalCase({
    required MedicalCaseModel medicalCase,
    required CustomerModel customer,
    required PetModel pet,
    required List<CaseServiceModel> services,
  }) async {
    final pdfBytes = await generateMedicalCasePdf(
      medicalCase: medicalCase,
      customer: customer,
      pet: pet,
      services: services,
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: 'Benh_an_${medicalCase.caseCode}',
    );
  }

  /// Share/Save PDF
  Future<void> shareMedicalCase({
    required MedicalCaseModel medicalCase,
    required CustomerModel customer,
    required PetModel pet,
    required List<CaseServiceModel> services,
  }) async {
    final pdfBytes = await generateMedicalCasePdf(
      medicalCase: medicalCase,
      customer: customer,
      pet: pet,
      services: services,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Benh_an_${medicalCase.caseCode}.pdf',
    );
  }

  // ==================== INVOICE PDF ====================

  /// Generate invoice PDF (Hóa đơn)
  Future<Uint8List> generateInvoicePdf({
    required MedicalCaseModel medicalCase,
    required CustomerModel customer,
    required PetModel pet,
    required List<CaseServiceModel> services,
  }) async {
    final pdf = pw.Document();

    // Load settings
    final settings = await _loadSettings();
    final logo = await _loadLogo(settings['clinic_logo_path']);

    // Load Vietnamese font (handle offline/error)
    pw.Font font;
    pw.Font fontBold;
    pw.Font fontItalic;
    pw.Font fontBoldItalic;

    try {
      font = await PdfGoogleFonts.robotoRegular();
      fontBold = await PdfGoogleFonts.robotoBold();
      fontItalic = await PdfGoogleFonts.robotoItalic();
      fontBoldItalic = await PdfGoogleFonts.robotoBoldItalic();
    } catch (e) {
      Get.snackbar(
        'Cảnh báo',
        'Không tải được font tiếng Việt. PDF có thể bị lỗi hiển thị.',
      );
      font = pw.Font.courier();
      fontBold = pw.Font.courierBold();
      fontItalic = pw.Font.courierOblique();
      fontBoldItalic = pw.Font.courierBoldOblique();
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a5, // Smaller size for invoice
        margin: const pw.EdgeInsets.all(30),
        theme: pw.ThemeData.withFont(
          base: font,
          bold: fontBold,
          italic: fontItalic,
          boldItalic: fontBoldItalic,
        ),
        header: (context) => _buildInvoiceHeader(medicalCase, settings, logo),
        footer: (context) => _buildInvoiceFooter(settings),
        build: (context) {
          return [
            pw.SizedBox(height: 15),

            // Customer info (brief)
            _buildInvoiceCustomerInfo(customer, pet),
            pw.SizedBox(height: 15),

            // Services table
            ..._buildInvoiceServices(services),
            pw.SizedBox(height: 15),

            // Payment summary
            _buildInvoicePaymentSummary(medicalCase),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildInvoiceHeader(
    MedicalCaseModel medicalCase,
    Map<String, String> settings,
    pw.MemoryImage? logo,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          if (logo != null)
            pw.Container(
              margin: const pw.EdgeInsets.only(right: 10),
              child: pw.Image(logo, width: 40, height: 40),
            ),
          pw.Expanded(
            child: pw.Column(
              children: [
                pw.Text(
                  settings['clinic_name']?.toUpperCase() ?? 'PETCLINIC',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'HÓA ĐƠN THANH TOÁN',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Số: ${medicalCase.caseCode}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      'Ngày: ${Formatters.formatDateTime(medicalCase.admissionDate)}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInvoiceFooter(Map<String, String> settings) {
    final address = settings['clinic_address'] ?? '...';
    final phone = settings['clinic_phone'] ?? '...';

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'Cảm ơn quý khách đã sử dụng dịch vụ!',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            '${settings['clinic_name']?.toUpperCase() ?? 'PETCLINIC'} - Địa chỉ: $address - SĐT: $phone',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInvoiceCustomerInfo(CustomerModel customer, PetModel pet) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Khách hàng: ${customer.name}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'SĐT: ${Formatters.formatPhone(customer.phone)}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Thú cưng: ${pet.name}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '${pet.species} - ${pet.breed ?? "N/A"}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _buildInvoiceServices(List<CaseServiceModel> services) {
    // Define column widths
    const col1 = 4;
    const col2 = 1;
    const col3 = 2;
    const col4 = 1; // Discount
    const col5 = 2;

    return [
      pw.Text(
        'CHI TIẾT DỊCH VỤ',
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
      ),
      pw.SizedBox(height: 5),

      // Using Table.fromTextArray for proper pagination
      pw.Table.fromTextArray(
        border: const pw.TableBorder(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
          horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
        columnWidths: {
          0: const pw.FlexColumnWidth(4),
          1: const pw.FlexColumnWidth(1),
          2: const pw.FlexColumnWidth(2),
          3: const pw.FlexColumnWidth(1),
          4: const pw.FlexColumnWidth(2),
        },
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        headerDecoration: const pw.BoxDecoration(
          color: PdfColors.grey200,
          border: pw.Border(
            top: pw.BorderSide(color: PdfColors.grey400),
            bottom: pw.BorderSide(color: PdfColors.grey400),
          ),
        ),
        cellStyle: const pw.TextStyle(fontSize: 9),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        cellAlignments: {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.center,
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
          4: pw.Alignment.centerRight,
        },
        headers: ['Dịch vụ / Thuốc', 'SL', 'Đơn giá', 'Giảm giá', 'Thành tiền'],
        data: services
            .map(
              (s) => [
                s.serviceName,
                '${s.quantity}',
                Formatters.formatCurrency(s.unitPrice),
                s.discount > 0 ? Formatters.formatCurrency(s.discount) : '-',
                Formatters.formatCurrency(s.total),
              ],
            )
            .toList(),
      ),
    ];
  }

  pw.Widget _buildInvoicePaymentSummary(MedicalCaseModel medicalCase) {
    final remaining = medicalCase.totalEstimate - medicalCase.advancePayment;

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Tổng cộng:', style: const pw.TextStyle(fontSize: 10)),
              pw.Text(
                Formatters.formatCurrency(medicalCase.totalEstimate),
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Đã thanh toán (${medicalCase.advancePaymentMethod == 'transfer' ? 'CK' : 'TM'}):',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                Formatters.formatCurrency(medicalCase.advancePayment),
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.green700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                remaining <= 0 ? 'ĐÃ THANH TOÁN ĐỦ' : 'CÒN LẠI:',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: remaining <= 0 ? PdfColors.green700 : PdfColors.red700,
                ),
              ),
              pw.Text(
                remaining <= 0 ? '0 đ' : Formatters.formatCurrency(remaining),
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: remaining <= 0 ? PdfColors.green700 : PdfColors.red700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Text(
                'Phương thức quyết toán: ',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Text(
                medicalCase.paymentMethod == 'cash'
                    ? 'Tiền mặt'
                    : 'Chuyển khoản',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _invoiceTableCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  /// Print Invoice
  Future<void> printInvoice({
    required MedicalCaseModel medicalCase,
    required CustomerModel customer,
    required PetModel pet,
    required List<CaseServiceModel> services,
  }) async {
    final pdfBytes = await generateInvoicePdf(
      medicalCase: medicalCase,
      customer: customer,
      pet: pet,
      services: services,
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: 'Hoa_don_${medicalCase.caseCode}',
    );
  }

  /// Share/Save Invoice
  Future<void> shareInvoice({
    required MedicalCaseModel medicalCase,
    required CustomerModel customer,
    required PetModel pet,
    required List<CaseServiceModel> services,
  }) async {
    final pdfBytes = await generateInvoicePdf(
      medicalCase: medicalCase,
      customer: customer,
      pet: pet,
      services: services,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Hoa_don_${medicalCase.caseCode}.pdf',
    );
  }
}
