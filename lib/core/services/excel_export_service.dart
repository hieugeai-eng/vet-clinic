import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../../data/repositories/report_repository.dart';
import 'package:flutter/material.dart';

class ExcelExportService {
  final ReportRepository _reportRepository = ReportRepository();

  Future<void> exportMonthlyReport(int year, int month) async {
    final excel = Excel.createExcel();

    // Load data
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 0);

    // 1. BC Thang (Monthly Report)
    // Structure based on template:
    // Row 1: ['CSDL khách hàng', 'Số tiền CBC', '...', 'Số ca CBC', '...', 'Total', '...', '...', '...', '...']
    // Row 3: Headers ['Ngày', 'MS ca', 'SDT', 'Gia chủ', 'Địa chỉ', 'Loài', 'Tên thú', 'TL(Kg)', 'Bệnh lý/Thủ thuật/thuốc', 'Phí thu', 'Số lượng', 'Thành tiền', 'Tổng thu', 'Người thu ', 'Chú ý', 'Ngày ra viện', 'Tổng thu Tuần']

    final sheetBCThang = excel['BC Thang'];
    // TODO: Populate BC Thang headers and data
    _buildBCThangSheet(sheetBCThang, startOfMonth, endOfMonth);

    // 2. Danh muc Chi (Expenses)
    // Row 2: Headers ['Ngày', 'Nội dung', 'Số lượng', 'Đơn vị tính', 'Đơn giá', 'Thuộc hạng mục', 'Số tiền', 'Người chi', 'Chú ý', 'Tổng chi theo tuần/tháng']
    final sheetChi = excel['Danh muc Chi'];
    _buildChiSheet(sheetChi, startOfMonth, endOfMonth);

    // 3. Chi petshop
    // Similar to Expenses but for Petshop specific expenses if distinguished
    final sheetChiPetshop = excel['Chi petshop'];
    _buildChiPetshopSheet(sheetChiPetshop, startOfMonth, endOfMonth);

    // 4. Can doi thu chi (Income Statement)
    final sheetCanDoi = excel['Can doi thu chi'];
    // TODO: Build summary

    // Save
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'BaoCao_Thang${month}_$year.xlsx';
    final path = '${directory.path}/$fileName';

    final fileBytes = excel.save();
    if (fileBytes != null) {
      File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);

      await OpenFile.open(path);
    }
  }

  Future<void> _buildBCThangSheet(
    Sheet sheet,
    DateTime start,
    DateTime end,
  ) async {
    // Add headers
    List<String> headers = [
      'Ngày',
      'MS ca',
      'SDT',
      'Gia chủ',
      'Địa chỉ',
      'Loài',
      'Tên thú',
      'TL(Kg)',
      'Bệnh lý/Thủ thuật/thuốc',
      'Phí thu',
      'Số lượng',
      'Thành tiền',
      'Tổng thu',
      'Người thu',
      'Chú ý',
      'Ngày ra viện',
    ];

    // Insert headers at row 3 (index 2)
    for (var i = 0; i < headers.length; i++) {
      var cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(bold: true);
    }

    // Fetch cases
    final cases = await _reportRepository.getCases(
      fromDate: start,
      toDate: end,
    );

    int rowIndex = 3;
    for (var c in cases) {
      // Basic info
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(
        DateFormat('yyyy-MM-dd').format(c.admissionDate),
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = TextCellValue(
        c.id,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
          .value = TextCellValue(
        c.phone ?? '',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
          .value = TextCellValue(
        c.customerName ?? '',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
          .value = TextCellValue(
        c.address ?? '',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
          .value = TextCellValue(
        c.species ?? '',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex))
          .value = TextCellValue(
        c.petName ?? '',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex))
          .value = DoubleCellValue(
        c.vitalSigns?.weight ?? 0,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex))
          .value = TextCellValue(
        c.visitReasons.join(', '),
      );

      // Financials
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: rowIndex))
          .value = DoubleCellValue(
        c.advancePayment,
      );

      rowIndex++;
    }
  }

  Future<void> _buildChiSheet(Sheet sheet, DateTime start, DateTime end) async {
    List<String> headers = [
      'Ngày',
      'Nội dung',
      'Số lượng',
      'Đơn vị tính',
      'Đơn giá',
      'Thuộc hạng mục',
      'Số tiền',
      'Người chi',
      'Chú ý',
    ];

    for (var i = 0; i < headers.length; i++) {
      var cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(bold: true);
    }

    final expenses = await _reportRepository.getExpenses(
      fromDate: start,
      toDate: end,
    );

    int rowIndex = 2;
    for (var e in expenses) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(
        DateFormat('yyyy-MM-dd').format(e.date),
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = TextCellValue(
        e.content,
      );
      // Assuming amount is total, if quantity/unit price exists in model use them, else put total in Amount column
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex))
          .value = DoubleCellValue(
        e.amount,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
          .value = TextCellValue(
        e.category,
      );

      rowIndex++;
    }
  }

  Future<void> _buildChiPetshopSheet(
    Sheet sheet,
    DateTime start,
    DateTime end,
  ) async {
    // Similar structure if you have separate petshop expenses
  }
}
