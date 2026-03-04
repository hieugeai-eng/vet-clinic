import 'dart:io';
import 'package:excel/excel.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../data/providers/local/database_provider.dart';

class ExcelExportService {
  final ReportRepository _reportRepository = ReportRepository();

  // Styles
  final CellStyle _headerStyle = CellStyle(
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    backgroundColorHex: ExcelColor.fromHexString('#E0E0E0'),
    topBorder: Border(borderStyle: BorderStyle.Thin),
    bottomBorder: Border(borderStyle: BorderStyle.Thin),
    leftBorder: Border(borderStyle: BorderStyle.Thin),
    rightBorder: Border(borderStyle: BorderStyle.Thin),
  );

  final CellStyle _dataStyle = CellStyle(
    verticalAlign: VerticalAlign.Center,
    topBorder: Border(borderStyle: BorderStyle.Thin),
    bottomBorder: Border(borderStyle: BorderStyle.Thin),
    leftBorder: Border(borderStyle: BorderStyle.Thin),
    rightBorder: Border(borderStyle: BorderStyle.Thin),
  );

  final CellStyle _dateStyle = CellStyle(
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    topBorder: Border(borderStyle: BorderStyle.Thin),
    bottomBorder: Border(borderStyle: BorderStyle.Thin),
    leftBorder: Border(borderStyle: BorderStyle.Thin),
    rightBorder: Border(borderStyle: BorderStyle.Thin),
  );

  final CellStyle _numberStyle = CellStyle(
    horizontalAlign: HorizontalAlign.Right,
    verticalAlign: VerticalAlign.Center,
    topBorder: Border(borderStyle: BorderStyle.Thin),
    bottomBorder: Border(borderStyle: BorderStyle.Thin),
    leftBorder: Border(borderStyle: BorderStyle.Thin),
    rightBorder: Border(borderStyle: BorderStyle.Thin),
    numberFormat: NumFormat.standard_3,
  );

  Future<String?> exportMonthlyReport(int year, int month) async {
    final excel = Excel.createExcel();

    final startOfMonth = DateTime(year, month, 1);
    final lastDay = (month < 12)
        ? DateTime(year, month + 1, 0)
        : DateTime(year + 1, 1, 0);
    final endOfMonth = DateTime(
      lastDay.year,
      lastDay.month,
      lastDay.day,
      23,
      59,
      59,
    );

    // 1. BC Thang
    await _buildBCThangSheet(excel['BC Thang'], startOfMonth, endOfMonth);

    // 2. So Giao Dich
    await _buildChiSheet(excel['Sổ Giao Dịch'], startOfMonth, endOfMonth);

    // 3. BC Vat Tu (Inventory)
    await _buildInventorySheet(excel['BC Vat Tu']);

    // 4. Petshop Report (Sales)
    await _buildPetshopSalesSheet(
      excel['Petshop T$month'],
      startOfMonth,
      endOfMonth,
    );

    // 5. Kho Petshop (Product Inventory)
    await _buildKhoPetshopSheet(excel['Kho Petshop']);

    // Remove default sheet if it exists and we have created other sheets
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    // Save file
    try {
      final directory = await getApplicationDocumentsDirectory();
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final fileBytes = excel.save();
      if (fileBytes == null) return null;

      final baseName = 'BaoCao_Thang${month}_$year';
      String path = '${directory.path}/$baseName.xlsx';

      try {
        await File(path).writeAsBytes(fileBytes);
      } catch (_) {
        final ts = DateTime.now().millisecondsSinceEpoch;
        path = '${directory.path}/${baseName}_$ts.xlsx';
        await File(path).writeAsBytes(fileBytes);
      }

      await OpenFile.open(path);
      return path;
    } catch (e) {
      print('Error saving excel: $e');
      rethrow;
    }
  }

  Future<void> _buildBCThangSheet(
    Sheet sheet,
    DateTime start,
    DateTime end,
  ) async {
    // --- Header ---
    final headers = [
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
      'Tiền mặt',
      'Chuyển khoản',
      'Người thu ',
      'Chú ý',
      'Ngày ra viện',
    ];

    for (var i = 0; i < headers.length; i++) {
      var cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = _headerStyle;
    }

    // --- Data ---
    final cases = await _reportRepository.getCases(
      fromDate: start,
      toDate: end,
    );
    final db = await DatabaseProvider.instance.database;
    final staffRecords = await db.query('staff');
    final Map<String, String> staffMap = {
      for (var s in staffRecords)
        s['id'] as String: s['name'] as String? ?? 'Unknown',
    };

    int rowIndex = 3;
    double sumThanhTien = 0;
    double sumTongThu = 0;
    double sumTienMat = 0;
    double sumChuyenKhoan = 0;

    for (var c in cases) {
      double tienMat = 0;
      double chuyenKhoan = 0;

      if (c.advancePaymentHistory.isNotEmpty) {
        for (var p in c.advancePaymentHistory) {
          if (p.method == 'transfer')
            chuyenKhoan += p.amount;
          else
            tienMat += p.amount;
        }
      } else if (c.advancePayment > 0) {
        if (c.advancePaymentMethod == 'transfer')
          chuyenKhoan += c.advancePayment;
        else
          tienMat += c.advancePayment;
      }

      if (c.status == 'completed' || c.dischargeDate != null) {
        final remaining = c.totalEstimate - c.advancePayment;
        if (remaining > 0) {
          if (c.paymentMethod == 'transfer')
            chuyenKhoan += remaining;
          else
            tienMat += remaining;
        }
      }

      final tongThu = tienMat + chuyenKhoan;
      sumTongThu += tongThu;
      sumTienMat += tienMat;
      sumChuyenKhoan += chuyenKhoan;

      final services = await db.query(
        'case_services',
        where: 'case_id = ?',
        whereArgs: [c.id],
      );

      if (services.isEmpty) {
        _writeCaseRow(
          sheet,
          rowIndex,
          c,
          null,
          staffMap,
          tongThu,
          tienMat,
          chuyenKhoan,
        );
        rowIndex++;
      } else {
        for (var i = 0; i < services.length; i++) {
          final s = services[i];
          sumThanhTien += (s['total'] as num?)?.toDouble() ?? 0;
          if (i == 0) {
            _writeCaseRow(
              sheet,
              rowIndex,
              c,
              s,
              staffMap,
              tongThu,
              tienMat,
              chuyenKhoan,
            );
          } else {
            _writeServiceRow(sheet, rowIndex, s);
          }
          rowIndex++;
        }
      }
    }

    // Add total row
    _writeCell(sheet, 0, rowIndex, TextCellValue('TỔNG CỘNG'), _headerStyle);
    for (int i = 1; i <= 10; i++)
      _writeCell(sheet, i, rowIndex, TextCellValue(''), _headerStyle);
    _writeCell(
      sheet,
      11,
      rowIndex,
      DoubleCellValue(sumThanhTien),
      _headerStyle,
    );
    _writeCell(sheet, 12, rowIndex, DoubleCellValue(sumTongThu), _headerStyle);
    _writeCell(sheet, 13, rowIndex, DoubleCellValue(sumTienMat), _headerStyle);
    _writeCell(
      sheet,
      14,
      rowIndex,
      DoubleCellValue(sumChuyenKhoan),
      _headerStyle,
    );
    for (int i = 15; i <= 17; i++)
      _writeCell(sheet, i, rowIndex, TextCellValue(''), _headerStyle);

    // Auto-fit columns
    sheet.setColumnWidth(0, 12.0); // Date
    sheet.setColumnWidth(1, 10.0); // MS
    sheet.setColumnWidth(2, 12.0); // Phone
    sheet.setColumnWidth(3, 15.0); // Owner
    sheet.setColumnWidth(4, 25.0); // Address
    sheet.setColumnWidth(8, 30.0); // Description
    sheet.setColumnWidth(12, 12.0); // Total
    sheet.setColumnWidth(13, 12.0); // Tien Mat
    sheet.setColumnWidth(14, 12.0); // Chuyen khoan
  }

  void _writeCaseRow(
    Sheet sheet,
    int rowIndex,
    var c,
    Map<String, dynamic>? service,
    Map<String, String> staffMap,
    double tongThu,
    double tienMat,
    double chuyenKhoan,
  ) {
    _writeCell(
      sheet,
      0,
      rowIndex,
      TextCellValue(DateFormat('dd/MM/yyyy').format(c.admissionDate)),
      _dateStyle,
    );
    _writeCell(
      sheet,
      1,
      rowIndex,
      TextCellValue(c.caseCode.split('-').last),
      _dataStyle,
    ); // Simplify MS ca
    _writeCell(sheet, 2, rowIndex, TextCellValue(c.phone ?? ''), _dataStyle);
    _writeCell(
      sheet,
      3,
      rowIndex,
      TextCellValue(c.customerName ?? ''),
      _dataStyle,
    );
    _writeCell(sheet, 4, rowIndex, TextCellValue(c.address ?? ''), _dataStyle);
    _writeCell(sheet, 5, rowIndex, TextCellValue(c.species ?? ''), _dataStyle);
    _writeCell(sheet, 6, rowIndex, TextCellValue(c.petName ?? ''), _dataStyle);
    _writeCell(
      sheet,
      7,
      rowIndex,
      DoubleCellValue(c.vitalSigns?.weight ?? 0),
      _numberStyle,
    );

    if (service != null) {
      _writeCell(
        sheet,
        8,
        rowIndex,
        TextCellValue(service['service_name'] ?? ''),
        _dataStyle,
      );
      _writeCell(
        sheet,
        9,
        rowIndex,
        DoubleCellValue((service['unit_price'] as num?)?.toDouble() ?? 0),
        _numberStyle,
      );
      _writeCell(
        sheet,
        10,
        rowIndex,
        IntCellValue((service['quantity'] as int?) ?? 1),
        _numberStyle,
      );
      _writeCell(
        sheet,
        11,
        rowIndex,
        DoubleCellValue((service['total'] as num?)?.toDouble() ?? 0),
        _numberStyle,
      );
    } else {
      _writeCell(
        sheet,
        8,
        rowIndex,
        TextCellValue(
          c.visitReasons.isNotEmpty
              ? c.visitReasons.join(', ')
              : (c.reasonNotes ?? ''),
        ),
        _dataStyle,
      );
      _writeCell(sheet, 9, rowIndex, TextCellValue(''), _dataStyle);
      _writeCell(sheet, 10, rowIndex, TextCellValue(''), _dataStyle);
      _writeCell(sheet, 11, rowIndex, TextCellValue(''), _dataStyle);
    }

    _writeCell(sheet, 12, rowIndex, DoubleCellValue(tongThu), _numberStyle);
    _writeCell(sheet, 13, rowIndex, DoubleCellValue(tienMat), _numberStyle);
    _writeCell(sheet, 14, rowIndex, DoubleCellValue(chuyenKhoan), _numberStyle);

    // Fetch staff name if ID is available
    String staffName = c.staffId != null
        ? (staffMap[c.staffId] ?? c.staffId!)
        : '';
    _writeCell(sheet, 15, rowIndex, TextCellValue(staffName), _dataStyle);
    _writeCell(sheet, 16, rowIndex, TextCellValue(c.notes ?? ''), _dataStyle);
    _writeCell(
      sheet,
      17,
      rowIndex,
      c.dischargeDate != null
          ? TextCellValue(DateFormat('dd/MM/yyyy').format(c.dischargeDate!))
          : TextCellValue(''),
      _dateStyle,
    );
  }

  void _writeServiceRow(
    Sheet sheet,
    int rowIndex,
    Map<String, dynamic> service,
  ) {
    // Empty cells for case info
    for (int i = 0; i <= 7; i++)
      _writeCell(sheet, i, rowIndex, TextCellValue(''), _dataStyle);

    _writeCell(
      sheet,
      8,
      rowIndex,
      TextCellValue(service['service_name'] ?? ''),
      _dataStyle,
    );
    _writeCell(
      sheet,
      9,
      rowIndex,
      DoubleCellValue((service['unit_price'] as num?)?.toDouble() ?? 0),
      _numberStyle,
    );
    _writeCell(
      sheet,
      10,
      rowIndex,
      IntCellValue((service['quantity'] as int?) ?? 1),
      _numberStyle,
    );
    _writeCell(
      sheet,
      11,
      rowIndex,
      DoubleCellValue((service['total'] as num?)?.toDouble() ?? 0),
      _numberStyle,
    );

    // Empty cells for totals
    for (int i = 12; i <= 17; i++)
      _writeCell(sheet, i, rowIndex, TextCellValue(''), _dataStyle);
  }

  void _writeCell(
    Sheet sheet,
    int col,
    int row,
    CellValue value,
    CellStyle style,
  ) {
    var cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    cell.value = value;
    cell.cellStyle = style;
  }

  Future<void> _buildChiSheet(Sheet sheet, DateTime start, DateTime end) async {
    final headers = [
      'Ngày',
      'Loại GD',
      'Nội dung',
      'Số lượng',
      'Đơn vị tính',
      'Đơn giá',
      'Thuộc hạng mục',
      'Số tiền',
      'Hình thức',
      'Người GD',
      'Chú ý',
    ];

    for (var i = 0; i < headers.length; i++) {
      var cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = _headerStyle;
    }

    final expenses = await _reportRepository.getExpenses(
      fromDate: start,
      toDate: end,
    );
    final db = await DatabaseProvider.instance.database;
    final staffRecords = await db.query('staff');
    final Map<String, String> staffMap = {
      for (var s in staffRecords)
        s['id'] as String: s['name'] as String? ?? 'Unknown',
    };

    int rowIndex = 2;
    double sumThu = 0;
    double sumChi = 0;

    final Map<String, Map<String, Map<String, double>>> staffStats = {};

    for (var e in expenses) {
      if (e.type == 'income')
        sumThu += e.amount;
      else
        sumChi += e.amount;

      String transType = e.type == 'income' ? 'Khoản Thu' : 'Khoản Chi';
      String paymentMethod = e.paymentMethod == 'cash'
          ? 'Tiền mặt'
          : 'Chuyển khoản';
      String staffName = e.staffId != null
          ? (staffMap[e.staffId] ?? e.staffId!)
          : 'Chưa phân công';

      staffStats.putIfAbsent(staffName, () => {});
      staffStats[staffName]!.putIfAbsent(transType, () => {});
      staffStats[staffName]![transType]!.putIfAbsent(paymentMethod, () => 0.0);
      staffStats[staffName]![transType]![paymentMethod] =
          staffStats[staffName]![transType]![paymentMethod]! + e.amount;

      _writeCell(
        sheet,
        0,
        rowIndex,
        TextCellValue(DateFormat('dd/MM/yyyy').format(e.date)),
        _dateStyle,
      );
      _writeCell(sheet, 1, rowIndex, TextCellValue(transType), _dataStyle);
      _writeCell(sheet, 2, rowIndex, TextCellValue(e.content), _dataStyle);
      _writeCell(
        sheet,
        3,
        rowIndex,
        IntCellValue(e.quantity ?? 1),
        _numberStyle,
      );
      _writeCell(sheet, 4, rowIndex, TextCellValue(e.unit ?? ''), _dataStyle);
      _writeCell(
        sheet,
        5,
        rowIndex,
        DoubleCellValue(e.unitPrice ?? 0),
        _numberStyle,
      );
      _writeCell(sheet, 6, rowIndex, TextCellValue(e.category), _dataStyle);
      _writeCell(sheet, 7, rowIndex, DoubleCellValue(e.amount), _numberStyle);
      _writeCell(sheet, 8, rowIndex, TextCellValue(paymentMethod), _dataStyle);
      _writeCell(sheet, 9, rowIndex, TextCellValue(staffName), _dataStyle);
      _writeCell(sheet, 10, rowIndex, TextCellValue(e.notes ?? ''), _dataStyle);

      rowIndex++;
    }

    // Summary rows
    // 1. Tổng thu
    _writeCell(sheet, 0, rowIndex, TextCellValue('TỔNG THU'), _headerStyle);
    for (int i = 1; i <= 6; i++)
      _writeCell(sheet, i, rowIndex, TextCellValue(''), _headerStyle);
    _writeCell(sheet, 7, rowIndex, DoubleCellValue(sumThu), _headerStyle);
    _writeCell(sheet, 8, rowIndex, TextCellValue(''), _headerStyle);
    _writeCell(sheet, 9, rowIndex, TextCellValue(''), _headerStyle);
    _writeCell(sheet, 10, rowIndex, TextCellValue(''), _headerStyle);
    rowIndex++;

    // 2. Tổng chi
    _writeCell(sheet, 0, rowIndex, TextCellValue('TỔNG CHI'), _headerStyle);
    for (int i = 1; i <= 6; i++)
      _writeCell(sheet, i, rowIndex, TextCellValue(''), _headerStyle);
    _writeCell(sheet, 7, rowIndex, DoubleCellValue(sumChi), _headerStyle);
    _writeCell(sheet, 8, rowIndex, TextCellValue(''), _headerStyle);
    _writeCell(sheet, 9, rowIndex, TextCellValue(''), _headerStyle);
    _writeCell(sheet, 10, rowIndex, TextCellValue(''), _headerStyle);

    rowIndex += 2; // Space between tables

    // New Summary Table: Statistics by Staff
    _writeCell(
      sheet,
      0,
      rowIndex,
      TextCellValue('THỐNG KÊ THEO NHÂN VIÊN'),
      _headerStyle,
    );
    try {
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
        CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex),
      );
    } catch (_) {}
    rowIndex++;

    final summaryHeaders = [
      'Nhân viên',
      'Loại giao dịch',
      'Hình thức',
      'Tổng số tiền',
    ];
    for (var i = 0; i < summaryHeaders.length; i++) {
      _writeCell(
        sheet,
        i,
        rowIndex,
        TextCellValue(summaryHeaders[i]),
        _headerStyle,
      );
    }
    rowIndex++;

    for (var staff in staffStats.keys) {
      for (var type in staffStats[staff]!.keys) {
        for (var method in staffStats[staff]![type]!.keys) {
          final amount = staffStats[staff]![type]![method]!;
          _writeCell(sheet, 0, rowIndex, TextCellValue(staff), _dataStyle);
          _writeCell(sheet, 1, rowIndex, TextCellValue(type), _dataStyle);
          _writeCell(sheet, 2, rowIndex, TextCellValue(method), _dataStyle);
          _writeCell(sheet, 3, rowIndex, DoubleCellValue(amount), _numberStyle);
          rowIndex++;
        }
      }
    }

    sheet.setColumnWidth(0, 12.0);
    sheet.setColumnWidth(1, 15.0);
    sheet.setColumnWidth(2, 30.0);
    sheet.setColumnWidth(6, 15.0);
    sheet.setColumnWidth(8, 15.0);
  }

  Future<void> _buildInventorySheet(Sheet sheet) async {
    final headers = [
      'Mã Hàng',
      'Tên hàng',
      'Đơn vị Tính',
      'Giá nhập',
      'Tồn kho',
      'Giá trị kho',
    ];

    for (var i = 0; i < headers.length; i++) {
      var cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = _headerStyle;
    }

    final db = await DatabaseProvider.instance.database;
    int rowIndex = 1;
    double sumGiaTri = 0;

    // 1. Medicines
    final medicines = await db.query(
      'medicines',
      where: 'is_active = 1',
      orderBy: 'name',
    );
    for (var m in medicines) {
      final val =
          ((m['avg_price'] as num?)?.toDouble() ?? 0) *
          ((m['stock'] as num?)?.toDouble() ?? 0);
      sumGiaTri += val;
      _writeCell(
        sheet,
        0,
        rowIndex,
        TextCellValue('MED-${m['code'] ?? m['id']}'),
        _dataStyle,
      );
      _writeCell(
        sheet,
        1,
        rowIndex,
        TextCellValue(m['name'] as String? ?? ''),
        _dataStyle,
      );
      _writeCell(
        sheet,
        2,
        rowIndex,
        TextCellValue(m['unit'] as String? ?? ''),
        _dataStyle,
      );
      _writeCell(
        sheet,
        3,
        rowIndex,
        DoubleCellValue((m['avg_price'] as num?)?.toDouble() ?? 0),
        _numberStyle,
      );
      _writeCell(
        sheet,
        4,
        rowIndex,
        DoubleCellValue((m['stock'] as num?)?.toDouble() ?? 0),
        _numberStyle,
      );
      _writeCell(sheet, 5, rowIndex, DoubleCellValue(val), _numberStyle);
      rowIndex++;
    }

    // 2. Products
    final products = await db.query(
      'products',
      where: 'is_active = 1',
      orderBy: 'name',
    );
    for (var p in products) {
      final val =
          ((p['cost_price'] as num?)?.toDouble() ?? 0) *
          ((p['stock'] as num?)?.toDouble() ?? 0);
      sumGiaTri += val;
      _writeCell(
        sheet,
        0,
        rowIndex,
        TextCellValue('PROD-${p['id']}'),
        _dataStyle,
      );
      _writeCell(
        sheet,
        1,
        rowIndex,
        TextCellValue(p['name'] as String? ?? ''),
        _dataStyle,
      );
      _writeCell(
        sheet,
        2,
        rowIndex,
        TextCellValue(p['unit'] as String? ?? ''),
        _dataStyle,
      );
      _writeCell(
        sheet,
        3,
        rowIndex,
        DoubleCellValue((p['cost_price'] as num?)?.toDouble() ?? 0),
        _numberStyle,
      );
      _writeCell(
        sheet,
        4,
        rowIndex,
        DoubleCellValue((p['stock'] as num?)?.toDouble() ?? 0),
        _numberStyle,
      );
      _writeCell(sheet, 5, rowIndex, DoubleCellValue(val), _numberStyle);
      rowIndex++;
    }

    // Summary row
    _writeCell(sheet, 0, rowIndex, TextCellValue('TỔNG CỘNG'), _headerStyle);
    for (int i = 1; i <= 4; i++)
      _writeCell(sheet, i, rowIndex, TextCellValue(''), _headerStyle);
    _writeCell(sheet, 5, rowIndex, DoubleCellValue(sumGiaTri), _headerStyle);

    sheet.setColumnWidth(0, 15.0);
    sheet.setColumnWidth(1, 35.0);
    sheet.setColumnWidth(2, 10.0);
    sheet.setColumnWidth(5, 15.0);
  }

  Future<void> _buildPetshopSalesSheet(
    Sheet sheet,
    DateTime start,
    DateTime end,
  ) async {
    final headers = [
      'Ngày',
      'Tên hàng',
      'Số lượng',
      'Đơn giá',
      'Thành tiền',
      'Tiền mặt',
      'Chuyển khoản',
      'Khách hàng',
      'NV Bán',
    ];

    for (var i = 0; i < headers.length; i++) {
      var cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = _headerStyle;
    }

    final sales = await _reportRepository.getProductSales(
      fromDate: start,
      toDate: end,
    );
    final db = await DatabaseProvider.instance.database;
    final staffRecords = await db.query('staff');
    final Map<String, String> staffMap = {
      for (var s in staffRecords)
        s['id'] as String: s['name'] as String? ?? 'Unknown',
    };

    int rowIndex = 2;
    double sumDoanhThu = 0;
    double sumTienMat = 0;
    double sumChuyenKhoan = 0;

    for (var row in sales) {
      // row keys: ps.*, customer_name, staff_name
      // ps keys: sale_date, product_name, quantity, unit_price, total, customer_id, staff_id, payment_method

      final dateStr = row['sale_date'] as String? ?? '';
      final saleDate = DateTime.tryParse(dateStr);
      final total = (row['total'] as num?)?.toDouble() ?? 0;
      final paymentMethod = row['payment_method'] as String? ?? 'cash';

      double tienMat = paymentMethod == 'cash' ? total : 0;
      double chuyenKhoan = paymentMethod == 'transfer' ? total : 0;

      sumDoanhThu += total;
      sumTienMat += tienMat;
      sumChuyenKhoan += chuyenKhoan;

      _writeCell(
        sheet,
        0,
        rowIndex,
        saleDate != null
            ? TextCellValue(DateFormat('dd/MM/yyyy').format(saleDate))
            : TextCellValue(dateStr),
        _dateStyle,
      );
      _writeCell(
        sheet,
        1,
        rowIndex,
        TextCellValue(row['product_name'] as String? ?? ''),
        _dataStyle,
      );
      _writeCell(
        sheet,
        2,
        rowIndex,
        IntCellValue(row['quantity'] as int? ?? 0),
        _numberStyle,
      );
      _writeCell(
        sheet,
        3,
        rowIndex,
        DoubleCellValue((row['unit_price'] as num?)?.toDouble() ?? 0),
        _numberStyle,
      );
      _writeCell(sheet, 4, rowIndex, DoubleCellValue(total), _numberStyle);
      _writeCell(sheet, 5, rowIndex, DoubleCellValue(tienMat), _numberStyle);
      _writeCell(
        sheet,
        6,
        rowIndex,
        DoubleCellValue(chuyenKhoan),
        _numberStyle,
      );

      // Customer Name
      final custName =
          row['customer_name'] as String? ??
          row['customer_id'] as String? ??
          '';
      _writeCell(sheet, 7, rowIndex, TextCellValue(custName), _dataStyle);

      // Staff Name (use staffMap for fallback if SQL join didn't populate it)
      final staffId = row['staff_id'] as String?;
      String staffName = row['staff_name'] as String? ?? '';
      if (staffName.isEmpty && staffId != null) {
        staffName = staffMap[staffId] ?? staffId;
      }
      _writeCell(sheet, 8, rowIndex, TextCellValue(staffName), _dataStyle);

      rowIndex++;
    }

    // Summary row
    _writeCell(sheet, 0, rowIndex, TextCellValue('TỔNG CỘNG'), _headerStyle);
    for (int i = 1; i <= 3; i++)
      _writeCell(sheet, i, rowIndex, TextCellValue(''), _headerStyle);
    _writeCell(sheet, 4, rowIndex, DoubleCellValue(sumDoanhThu), _headerStyle);
    _writeCell(sheet, 5, rowIndex, DoubleCellValue(sumTienMat), _headerStyle);
    _writeCell(
      sheet,
      6,
      rowIndex,
      DoubleCellValue(sumChuyenKhoan),
      _headerStyle,
    );
    _writeCell(sheet, 7, rowIndex, TextCellValue(''), _headerStyle);
    _writeCell(sheet, 8, rowIndex, TextCellValue(''), _headerStyle);

    sheet.setColumnWidth(0, 12.0);
    sheet.setColumnWidth(1, 30.0); // Product Name
    sheet.setColumnWidth(5, 20.0); // Customer
  }

  Future<void> _buildKhoPetshopSheet(Sheet sheet) async {
    final headers = [
      'STT',
      'Tên sản phẩm',
      'Thương hiệu',
      'Danh mục',
      'Tồn kho',
      'Giá nhập',
      'Giá bán',
      'Giá trị tồn',
      'Trạng thái',
    ];

    for (var i = 0; i < headers.length; i++) {
      var cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = _headerStyle;
    }

    final db = await DatabaseProvider.instance.database;

    String where = 'is_active = 1';
    final clinicId = Get.isRegistered<AuthService>()
        ? AuthService.to.currentProfile.value?.clinicId
        : null;
    if (clinicId != null) where += " AND clinic_id = '$clinicId'";

    final products = await db.query(
      'products',
      where: where,
      orderBy: 'category, name',
    );

    int rowIndex = 2;
    double totalValue = 0;

    for (var i = 0; i < products.length; i++) {
      final p = products[i];
      final stock = (p['stock'] as num?)?.toInt() ?? 0;
      final costPrice = (p['cost_price'] as num?)?.toDouble() ?? 0;
      final salePrice = (p['sale_price'] as num?)?.toDouble() ?? 0;
      final stockValue = costPrice * stock;
      totalValue += stockValue;

      String status = 'Còn hàng';
      if (stock <= 0)
        status = 'Hết hàng';
      else if (stock <= 5)
        status = 'Sắp hết';

      _writeCell(sheet, 0, rowIndex, IntCellValue(i + 1), _numberStyle);
      _writeCell(
        sheet,
        1,
        rowIndex,
        TextCellValue(p['name'] as String? ?? ''),
        _dataStyle,
      );
      _writeCell(
        sheet,
        2,
        rowIndex,
        TextCellValue(p['brand'] as String? ?? ''),
        _dataStyle,
      );
      _writeCell(
        sheet,
        3,
        rowIndex,
        TextCellValue(p['category'] as String? ?? ''),
        _dataStyle,
      );
      _writeCell(sheet, 4, rowIndex, IntCellValue(stock), _numberStyle);
      _writeCell(sheet, 5, rowIndex, DoubleCellValue(costPrice), _numberStyle);
      _writeCell(sheet, 6, rowIndex, DoubleCellValue(salePrice), _numberStyle);
      _writeCell(sheet, 7, rowIndex, DoubleCellValue(stockValue), _numberStyle);
      _writeCell(sheet, 8, rowIndex, TextCellValue(status), _dataStyle);
      rowIndex++;
    }

    // Summary row
    rowIndex++;
    _writeCell(sheet, 0, rowIndex, TextCellValue('TỔNG CỘNG'), _headerStyle);
    for (int i = 1; i <= 3; i++)
      _writeCell(sheet, i, rowIndex, TextCellValue(''), _headerStyle);
    _writeCell(
      sheet,
      4,
      rowIndex,
      IntCellValue(products.length),
      _headerStyle,
    ); // Using for distinct items
    _writeCell(sheet, 5, rowIndex, TextCellValue(''), _headerStyle);
    _writeCell(sheet, 6, rowIndex, TextCellValue(''), _headerStyle);
    _writeCell(sheet, 7, rowIndex, DoubleCellValue(totalValue), _headerStyle);
    _writeCell(sheet, 8, rowIndex, TextCellValue(''), _headerStyle);

    sheet.setColumnWidth(0, 5.0);
    sheet.setColumnWidth(1, 30.0);
    sheet.setColumnWidth(2, 15.0);
    sheet.setColumnWidth(3, 12.0);
    sheet.setColumnWidth(5, 12.0);
    sheet.setColumnWidth(6, 12.0);
    sheet.setColumnWidth(7, 15.0);
    sheet.setColumnWidth(8, 12.0);
  }
}
