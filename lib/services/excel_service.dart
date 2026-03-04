import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart' as ex; // Rename for Export
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart'; // For Import
import 'package:path_provider/path_provider.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../core/services/auth_service.dart';
import '../core/sync/sync_engine.dart';
import '../core/sync/sync_queue.dart';
import '../data/models/customer_model.dart';
import '../data/models/pet_model.dart';
import '../data/models/medicine_model.dart';
import '../data/models/product_model.dart';
import '../data/models/service_model.dart';
import '../data/providers/local/database_provider.dart';
import '../data/repositories/pet_repository.dart';

class ImportedCustomerPet {
  final CustomerModel customer;
  final PetModel? pet;
  ImportedCustomerPet({required this.customer, this.pet});
}

/// Service for importing and exporting Excel files
class ExcelService extends GetxService {
  static const uuid = Uuid();
  final PetRepository _petRepository = PetRepository();

  /// Export customers to Excel (Using 'excel' package)
  /// Revised: 2 distinct sheets ('Khách hàng', 'Thú cưng') for clarity.
  Future<String?> exportCustomers(List<CustomerModel> customers) async {
    try {
      final excel = ex.Excel.createExcel();

      // --- SHEET 1: CUSTOMERS ---
      final sheet1 = excel['Khách hàng'];
      sheet1.appendRow([
        ex.TextCellValue('SĐT (Bắt buộc)'), // Key
        ex.TextCellValue('Tên khách hàng'),
        ex.TextCellValue('Địa chỉ'),
        ex.TextCellValue('Ngày tạo'),
      ]);

      // --- SHEET 2: PETS ---
      final sheet2 = excel['Thú cưng'];
      sheet2.appendRow([
        ex.TextCellValue('SĐT Chủ (Trùng bên Khách hàng)'), // FK
        ex.TextCellValue('Tên Thú Cưng'),
        ex.TextCellValue('Loài (Chó/Mèo)'),
        ex.TextCellValue('Giống'),
        ex.TextCellValue('Tuổi'),
        ex.TextCellValue('Giới Tính (Đực/Cái)'),
        ex.TextCellValue('Cân Nặng (kg)'),
      ]);

      for (final customer in customers) {
        // Add Customer Row
        sheet1.appendRow([
          ex.TextCellValue(customer.phone),
          ex.TextCellValue(customer.name),
          ex.TextCellValue(customer.address ?? ''),
          ex.TextCellValue(customer.createdAt.toString().split(' ')[0]),
        ]);

        // Fetch and Add Pets
        final pets = await _petRepository.getByCustomerId(customer.id);
        for (final pet in pets) {
          sheet2.appendRow([
            ex.TextCellValue(customer.phone), // Link via Phone
            ex.TextCellValue(pet.name),
            ex.TextCellValue(pet.species),
            ex.TextCellValue(pet.breed ?? ''),
            ex.TextCellValue(pet.displayAge),
            ex.TextCellValue(pet.gender ?? ''),
            pet.weight != null
                ? ex.DoubleCellValue(pet.weight!)
                : ex.TextCellValue(''),
          ]);
        }
      }

      // Remove default sheet
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      return await _saveExcel(excel, 'khach_hang_va_thu_cung');
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể xuất file: $e');
      return null;
    }
  }

  /// Generate Empty Template for Users
  Future<String?> generateCustomerTemplate() async {
    return await exportCustomers([]); // Reuse export logic with empty list
  }

  /// Import customers and pets from Excel (Using 'spreadsheet_decoder')
  /// Supports 2 formats:
  /// - Format 1: 2 sheets (Khách hàng, Thú cưng) linked by phone
  /// - Format 2: 1 sheet with combined data [SĐT, Tên KH, Địa chỉ, Tên Pet, Loài, Giống, Tuổi, Giới tính, Cân nặng]
  Future<List<ImportedCustomerPet>> importCustomersWithPets(
    String filePath,
  ) async {
    final results = <ImportedCustomerPet>[];
    try {
      final bytes = File(filePath).readAsBytesSync();
      final decoder = SpreadsheetDecoder.decodeBytes(bytes);

      if (decoder.tables.isEmpty) {
        Get.defaultDialog(
          title: 'Lỗi File',
          middleText: 'File excel này trống!',
        );
        return [];
      }

      // --- 1. Identify Sheets ---
      String customerSheetName = '';
      String petSheetName = '';

      // Try to find by name
      for (final name in decoder.tables.keys) {
        final lower = name.toLowerCase();
        if (lower.contains('khách') ||
            lower.contains('khach') ||
            lower.contains('hàng') ||
            lower.contains('hang')) {
          customerSheetName = name;
        }
        if (lower.contains('thú') ||
            lower.contains('thu') ||
            lower.contains('cưng') ||
            lower.contains('cung') ||
            lower.contains('pet')) {
          petSheetName = name;
        }
      }

      // Fallback: If not found, use index 0 and 1
      if (customerSheetName.isEmpty && decoder.tables.isNotEmpty) {
        customerSheetName = decoder.tables.keys.elementAt(0);
      }
      if (petSheetName.isEmpty && decoder.tables.length > 1) {
        petSheetName = decoder.tables.keys.elementAt(1);
      }

      final customerMap = <String, CustomerModel>{}; // Phone -> Customer
      int petCount = 0;

      // --- CASE A: Single Sheet (Combined Format) ---
      if (decoder.tables.length == 1 ||
          petSheetName.isEmpty ||
          petSheetName == customerSheetName) {
        debugPrint('ExcelService: Detected SINGLE SHEET format');

        final table = decoder.tables[customerSheetName];
        if (table != null && table.maxRows > 1) {
          for (int i = 1; i < table.rows.length; i++) {
            final row = table.rows[i];
            if (row.isEmpty) continue;

            // Expected: [SĐT, Tên KH, Địa chỉ, Tên Pet, Loài, Giống, Tuổi, Giới tính, Cân nặng]
            // Or with STT: [STT, SĐT, Tên KH, Địa chỉ, Tên Pet, ...]

            int phoneCol = -1;
            int offset = 0;

            // Find phone column
            for (int c = 0; c < row.length && c < 3; c++) {
              if (_isPhoneNumber(row[c]?.toString() ?? '')) {
                phoneCol = c;
                offset = c;
                break;
              }
            }

            if (phoneCol == -1) continue;

            final phone = _cleanPhone(row[phoneCol]?.toString() ?? '');
            final customerName = (row.length > offset + 1)
                ? row[offset + 1]?.toString()?.trim() ?? ''
                : '';
            final address = (row.length > offset + 2)
                ? row[offset + 2]?.toString()?.trim() ?? ''
                : '';

            if (phone.isEmpty || customerName.isEmpty) continue;

            // Get or create customer
            CustomerModel customer;
            if (customerMap.containsKey(phone)) {
              customer = customerMap[phone]!;
            } else {
              customer = CustomerModel(
                id: uuid.v4(),
                phone: phone,
                name: customerName,
                address: address.isNotEmpty ? address : null,
              );
              customerMap[phone] = customer;
              results.add(ImportedCustomerPet(customer: customer, pet: null));
            }

            // Check if pet data exists in same row (columns after address)
            final petName = (row.length > offset + 3)
                ? row[offset + 3]?.toString()?.trim() ?? ''
                : '';

            if (petName.isNotEmpty) {
              final species = (row.length > offset + 4)
                  ? _normalizeSpecies(row[offset + 4]?.toString() ?? '')
                  : 'Cho';
              final breed = (row.length > offset + 5)
                  ? row[offset + 5]?.toString()?.trim()
                  : null;
              final age = (row.length > offset + 6)
                  ? _parseInt(row[offset + 6])
                  : null;
              final gender = (row.length > offset + 7)
                  ? _normalizeGender(row[offset + 7]?.toString() ?? '')
                  : '';
              final weight = (row.length > offset + 8)
                  ? _parseDouble(row[offset + 8])
                  : null;

              final pet = PetModel(
                id: uuid.v4(),
                customerId: customer.id, // Link immediately
                name: petName,
                species: species,
                breed: breed,
                age: age,
                gender: gender.isNotEmpty ? gender : null,
                weight: weight,
                notes: 'Imported',
              );

              results.add(ImportedCustomerPet(customer: customer, pet: pet));
              petCount++;
            }
          }
        }
      }
      // --- CASE B: Two Sheets (Original Format) ---
      else {
        debugPrint('ExcelService: Detected TWO SHEET format');

        // Process Sheet 1: Customers
        if (customerSheetName.isNotEmpty) {
          final table = decoder.tables[customerSheetName];
          if (table != null && table.maxRows > 1) {
            for (int i = 1; i < table.rows.length; i++) {
              final row = table.rows[i];
              if (row.isEmpty) continue;

              final col0 = row.length > 0 ? row[0]?.toString() ?? '' : '';
              final col1 = row.length > 1 ? row[1]?.toString() ?? '' : '';
              final col2 = row.length > 2 ? row[2]?.toString() ?? '' : '';

              String phone = '';
              String name = '';
              String address = '';

              if (_isPhoneNumber(col0)) {
                phone = _cleanPhone(col0);
                name = col1.trim();
                address = col2.trim();
              } else if (_isPhoneNumber(col1)) {
                phone = _cleanPhone(col1);
                name = col2.trim();
                address = (row.length > 3) ? row[3]?.toString() ?? '' : '';
              }

              if (phone.isNotEmpty && name.isNotEmpty) {
                if (!customerMap.containsKey(phone)) {
                  customerMap[phone] = CustomerModel(
                    id: uuid.v4(),
                    phone: phone,
                    name: name,
                    address: address.isNotEmpty ? address : null,
                  );
                }
              }
            }
          }
        }

        // Add customers without pets initially
        for (final cust in customerMap.values) {
          results.add(ImportedCustomerPet(customer: cust, pet: null));
        }

        // Process Sheet 2: Pets
        if (petSheetName.isNotEmpty && petSheetName != customerSheetName) {
          final table = decoder.tables[petSheetName];
          if (table != null && table.maxRows > 1) {
            for (int i = 1; i < table.rows.length; i++) {
              final row = table.rows[i];
              if (row.isEmpty) continue;

              final col0 = row.length > 0 ? row[0]?.toString() ?? '' : '';
              final col1 = row.length > 1 ? row[1]?.toString() ?? '' : '';

              String ownerPhone = '';
              String petName = '';
              int offset = 0;

              if (_isPhoneNumber(col0)) {
                ownerPhone = _cleanPhone(col0);
                petName = col1.trim();
                offset = 0;
              } else if (_isPhoneNumber(col1)) {
                ownerPhone = _cleanPhone(col1);
                petName = (row.length > 2) ? row[2]?.toString() ?? '' : '';
                offset = 1;
              }

              if (ownerPhone.isNotEmpty && petName.isNotEmpty) {
                CustomerModel? owner = customerMap[ownerPhone];

                if (owner == null) {
                  owner = CustomerModel(
                    id: '',
                    phone: ownerPhone,
                    name: 'Unknown',
                  );
                }

                final species = (row.length > 2 + offset)
                    ? _normalizeSpecies(row[2 + offset]?.toString() ?? '')
                    : 'Cho';
                final breed = (row.length > 3 + offset)
                    ? row[3 + offset]?.toString() ?? ''
                    : null;
                final age = (row.length > 4 + offset)
                    ? _parseInt(row[4 + offset])
                    : null;
                final gender = (row.length > 5 + offset)
                    ? _normalizeGender(row[5 + offset]?.toString() ?? '')
                    : '';
                final weight = (row.length > 6 + offset)
                    ? _parseDouble(row[6 + offset])
                    : null;

                final pet = PetModel(
                  id: uuid.v4(),
                  customerId: '',
                  name: petName,
                  species: species,
                  breed: breed,
                  age: age,
                  gender: gender.isNotEmpty ? gender : null,
                  weight: weight,
                  notes: 'Imported',
                );

                results.add(ImportedCustomerPet(customer: owner, pet: pet));
                petCount++;
              }
            }
          }
        }
      }

      Get.defaultDialog(
        title: 'Kết quả Import',
        middleText:
            'Đã tìm thấy ${customerMap.length} khách hàng và $petCount thú cưng.',
        textConfirm: 'OK',
        onConfirm: () => Get.back(),
      );
    } catch (e, s) {
      Get.defaultDialog(
        title: 'Lỗi Critical',
        middleText:
            'Lỗi: $e\n\nStack: ${s.toString().split('\n').take(3).join('\n')}',
        textConfirm: 'OK',
        onConfirm: () => Get.back(),
      );
    }
    return results;
  }

  bool _isPhoneNumber(String s) {
    if (s.length < 8) return false;
    final digits = s.replaceAll(RegExp(r'[^\d]'), '');
    return digits.length >= 9;
  }

  String _cleanPhone(String s) {
    return s.replaceAll(RegExp(r'[^\d]'), '');
  }

  String _normalizeSpecies(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('mèo') || lower.contains('meo') || lower.contains('cat'))
      return 'Meo';
    return 'Cho';
  }

  String _normalizeGender(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('cái') ||
        lower.contains('cai') ||
        lower.contains('female') ||
        lower.contains('nữ') ||
        lower.contains('nu'))
      return 'female';
    if (lower.contains('đực') ||
        lower.contains('duc') ||
        lower.contains('male') ||
        lower.contains('nam'))
      return 'male';
    // Return null or leave empty if unknown to avoid constraint failure
    return '';
  }

  /// Export pets to Excel
  Future<String?> exportPets(List<PetModel> pets) async {
    try {
      final excel = ex.Excel.createExcel();
      final sheet = excel['Thú cưng'];

      sheet.appendRow([
        ex.TextCellValue('STT'),
        ex.TextCellValue('Tên'),
        ex.TextCellValue('Loài'),
        ex.TextCellValue('Giống'),
        ex.TextCellValue('Tuổi'),
        ex.TextCellValue('Giới tính'),
        ex.TextCellValue('Cân nặng (kg)'),
      ]);

      for (int i = 0; i < pets.length; i++) {
        final p = pets[i];
        sheet.appendRow([
          ex.IntCellValue(i + 1),
          ex.TextCellValue(p.name),
          ex.TextCellValue(p.species),
          ex.TextCellValue(p.breed ?? ''),
          p.age != null ? ex.IntCellValue(p.age!) : ex.TextCellValue(''),
          ex.TextCellValue(p.gender ?? ''),
          p.weight != null
              ? ex.DoubleCellValue(p.weight!)
              : ex.TextCellValue(''),
        ]);
      }

      excel.delete('Sheet1');
      return await _saveExcel(excel, 'thu_cung');
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể xuất file: $e');
      return null;
    }
  }

  /// Export medicines to Excel
  Future<String?> exportMedicines(List<MedicineModel> medicines) async {
    try {
      final excel = ex.Excel.createExcel();
      final sheet = excel['Kho thuốc'];

      sheet.appendRow([
        ex.TextCellValue('Mã hàng'),
        ex.TextCellValue('Tên hàng'),
        ex.TextCellValue('Đơn vị tính'),
        ex.TextCellValue('Giá nhập TB'),
        ex.TextCellValue('Số lượng tồn'),
        ex.TextCellValue('Tồn tối thiểu'),
        ex.TextCellValue('Nhà cung cấp'),
        ex.TextCellValue('Số lô'),
        ex.TextCellValue('Hạn dùng'),
      ]);

      for (final m in medicines) {
        sheet.appendRow([
          ex.TextCellValue(m.code),
          ex.TextCellValue(m.name),
          ex.TextCellValue(m.unit ?? ''),
          ex.DoubleCellValue(m.avgPrice),
          ex.DoubleCellValue(m.stock),
          m.minStock != null
              ? ex.DoubleCellValue(m.minStock!)
              : ex.TextCellValue(''),
          ex.TextCellValue(m.supplier ?? ''),
          ex.TextCellValue(m.lotNumber ?? ''),
          ex.TextCellValue(
            m.expiryDate?.toUtc().toIso8601String().split('T')[0] ?? '',
          ),
        ]);
      }

      excel.delete('Sheet1');
      return await _saveExcel(excel, 'kho_thuoc');
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể xuất file: $e');
      return null;
    }
  }

  /// Import medicines from Excel (Using spreadsheet_decoder)
  Future<List<MedicineModel>> importMedicines(String filePath) async {
    final medicines = <MedicineModel>[];
    try {
      final bytes = File(filePath).readAsBytesSync();
      final decoder = SpreadsheetDecoder.decodeBytes(bytes);

      if (decoder.tables.isEmpty) {
        Get.defaultDialog(
          title: 'Debug Error',
          middleText: 'File excel này không có Sheet nào cả!',
        );
        return [];
      }

      for (final tableName in decoder.tables.keys) {
        final table = decoder.tables[tableName];
        if (table == null) continue;

        if (table.maxRows == 0) {
          Get.defaultDialog(
            title: 'Debug Sheet',
            middleText: 'Sheet "$tableName" có 0 dòng.',
          );
          continue;
        }

        final rows = table.rows;

        // Skip header row
        for (int i = 1; i < rows.length; i++) {
          final row = rows[i];
          if (row.isEmpty) continue;

          final code = row.length > 0 ? row[0]?.toString() ?? '' : '';
          final name = row.length > 1 ? row[1]?.toString() ?? '' : '';

          if (code.isEmpty || name.isEmpty) continue;

          final unit = row.length > 2 ? row[2]?.toString() : null;
          final avgPrice = row.length > 3 ? _parseDouble(row[3]) : 0.0;
          final stock = row.length > 4 ? _parseDouble(row[4]) : 0.0;
          final minStock = row.length > 5 ? _parseDouble(row[5]) : null;
          final supplier = row.length > 6 ? row[6]?.toString() : null;
          final lotNumber = row.length > 7 ? row[7]?.toString() : null;

          DateTime? expiryDate;
          if (row.length > 8) {
            final val = row[8];
            if (val != null) {
              if (val is DateTime) {
                expiryDate = val;
              } else {
                final str = val.toString();
                if (str.isNotEmpty) expiryDate = DateTime.tryParse(str);
              }
            }
          }

          medicines.add(
            MedicineModel(
              id: uuid.v4(),
              code: code,
              name: name,
              unit: unit?.isNotEmpty == true ? unit : null,
              avgPrice: avgPrice,
              stock: stock,
              minStock: minStock,
              lotNumber: lotNumber?.isNotEmpty == true ? lotNumber : null,
              expiryDate: expiryDate,
              supplier: supplier?.isNotEmpty == true ? supplier : null,
            ),
          );
        }
        break;
      }

      Get.defaultDialog(
        title: 'Kết quả',
        middleText: 'Đã đọc thành công ${medicines.length} mặt hàng thuốc.',
      );
    } catch (e, s) {
      Get.defaultDialog(
        title: 'Lỗi Critical',
        middleText:
            'Lỗi: $e\n\nStack: ${s.toString().split('\n').take(3).join('\n')}',
        textConfirm: 'OK',
        onConfirm: () => Get.back(),
      );
    }
    return medicines;
  }

  /// Export products to Excel
  Future<String?> exportProducts(List<ProductModel> products) async {
    try {
      final excel = ex.Excel.createExcel();
      final sheet = excel['Sản phẩm'];

      sheet.appendRow([
        ex.TextCellValue('Tên sản phẩm'),
        ex.TextCellValue('Thương hiệu'),
        ex.TextCellValue('Giá bán'),
        ex.TextCellValue('Giá vốn'),
        ex.TextCellValue('Tồn kho'),
        ex.TextCellValue('Danh mục'),
      ]);

      for (final p in products) {
        sheet.appendRow([
          ex.TextCellValue(p.name),
          ex.TextCellValue(p.brand ?? ''),
          ex.DoubleCellValue(p.salePrice),
          ex.DoubleCellValue(p.costPrice),
          ex.IntCellValue(p.stock),
          ex.TextCellValue(p.category ?? ''),
        ]);
      }

      excel.delete('Sheet1');
      return await _saveExcel(excel, 'san_pham');
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể xuất file: $e');
      return null;
    }
  }

  /// Import products from Excel (Using spreadsheet_decoder)
  Future<List<ProductModel>> importProducts(String filePath) async {
    final products = <ProductModel>[];
    try {
      final bytes = File(filePath).readAsBytesSync();
      final decoder = SpreadsheetDecoder.decodeBytes(bytes);

      if (decoder.tables.isEmpty) {
        Get.defaultDialog(
          title: 'Debug Error',
          middleText: 'File excel này không có Sheet nào cả!',
        );
        return [];
      }

      for (final tableName in decoder.tables.keys) {
        final table = decoder.tables[tableName];
        if (table == null) continue;

        if (table.maxRows == 0) {
          Get.defaultDialog(
            title: 'Debug Sheet',
            middleText: 'Sheet "$tableName" có 0 dòng.',
          );
          continue;
        }

        final rows = table.rows;

        if (rows.isNotEmpty) {
          final firstCell = rows.first.isNotEmpty ? rows.first.first : 'Empty';
          await Get.defaultDialog(
            title: 'Debug Data',
            middleText:
                'Đọc được Sheet: "$tableName"\nSố dòng: ${rows.length}\nÔ đầu tiên: $firstCell\n\nBấm OK để tiếp tục xử lý.',
            textConfirm: 'OK',
            onConfirm: () => Get.back(),
          );
        }

        // Iterate rows (Skip header at index 0)
        for (int i = 1; i < rows.length; i++) {
          final row = rows[i];
          if (row.isEmpty) continue;

          final name = row.length > 0 ? row[0]?.toString() ?? '' : '';
          if (name.isEmpty) continue;

          final brand = row.length > 1 ? row[1]?.toString() ?? '' : null;
          final salePrice = row.length > 2 ? _parseDouble(row[2]) : 0.0;
          final costPrice = row.length > 3 ? _parseDouble(row[3]) : 0.0;
          final stock = row.length > 4 ? _parseInt(row[4]) : 0;
          final category = row.length > 5 ? row[5]?.toString() ?? '' : null;

          products.add(
            ProductModel(
              id: uuid.v4(),
              name: name,
              brand: brand,
              salePrice: salePrice,
              costPrice: costPrice,
              stock: stock,
              category: category,
            ),
          );
        }
        break;
      }

      Get.defaultDialog(
        title: 'Kết quả',
        middleText: 'Đã đọc thành công ${products.length} sản phẩm.',
      );
    } catch (e, s) {
      Get.defaultDialog(
        title: 'Lỗi Critical',
        middleText:
            'Lỗi: $e\n\nStack: ${s.toString().split('\n').take(3).join('\n')}',
        textConfirm: 'OK',
        onConfirm: () => Get.back(),
      );
    }
    return products;
  }

  /// Export services to Excel
  Future<String?> exportServices(List<ServiceModel> services) async {
    try {
      final excel = ex.Excel.createExcel();
      final sheet = excel['Dịch vụ'];

      sheet.appendRow([
        ex.TextCellValue('Tên dịch vụ'),
        ex.TextCellValue('Danh mục'),
        ex.TextCellValue('Giá'),
        ex.TextCellValue('Đơn vị'),
      ]);

      for (final s in services) {
        sheet.appendRow([
          ex.TextCellValue(s.name),
          ex.TextCellValue(s.category ?? ''),
          ex.DoubleCellValue(s.basePrice),
          ex.TextCellValue(s.unit ?? ''),
        ]);
      }

      return await _saveExcel(excel, 'dich_vu');
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể xuất file: $e');
      return null;
    }
  }

  /// Import services from Excel (Using spreadsheet_decoder)
  Future<List<ServiceModel>> importServices(String filePath) async {
    final services = <ServiceModel>[];
    try {
      final bytes = File(filePath).readAsBytesSync();
      final decoder = SpreadsheetDecoder.decodeBytes(bytes);

      if (decoder.tables.isEmpty) {
        Get.defaultDialog(
          title: 'Debug Error',
          middleText: 'File excel này không có Sheet nào cả!',
        );
        return [];
      }

      for (final tableName in decoder.tables.keys) {
        final table = decoder.tables[tableName];
        if (table == null) continue;

        final rows = table.rows;

        for (int i = 1; i < rows.length; i++) {
          final row = rows[i];
          if (row.isEmpty) continue;

          final name = row.length > 0 ? row[0]?.toString() ?? '' : '';

          if (name.isNotEmpty) {
            final category = row.length > 1
                ? row[1]?.toString() ?? ''
                : 'general';
            final basePrice = row.length > 2 ? _parseDouble(row[2]) : 0.0;
            final unit = row.length > 3 ? row[3]?.toString() : null;

            services.add(
              ServiceModel(
                id: uuid.v4(),
                name: name,
                category: category.isNotEmpty ? category : 'general',
                basePrice: basePrice,
                unit: unit?.isNotEmpty == true ? unit : null,
                isActive: true,
              ),
            );
          }
        }
        break;
      }

      if (services.isEmpty) {
        Get.defaultDialog(
          title: 'Kết quả',
          middleText: 'Không tìm thấy dịch vụ nào hợp lệ.',
        );
      } else {
        Get.defaultDialog(
          title: 'Kết quả',
          middleText: 'Đã đọc thành công ${services.length} dịch vụ.',
        );
      }
    } catch (e, s) {
      debugPrint('Error importing services: $e');
      debugPrint(s.toString());
      Get.defaultDialog(
        title: 'Lỗi Critical',
        middleText:
            'Lỗi: $e\n\nStack: ${s.toString().split('\n').take(3).join('\n')}',
        textConfirm: 'OK',
        onConfirm: () => Get.back(),
      );
    }
    return services;
  }

  /// Generate Empty Template for Medicines
  Future<String?> generateMedicineTemplate() async {
    return await exportMedicines([]);
  }

  /// Generate Empty Template for Products
  Future<String?> generateProductTemplate() async {
    return await exportProducts([]);
  }

  /// Generate Empty Template for Services
  Future<String?> generateServiceTemplate() async {
    return await exportServices([]);
  }

  /// Export report data to Excel
  Future<String?> exportReport({
    required String title,
    required List<String> headers,
    required List<List<dynamic>> data,
  }) async {
    try {
      final excel = ex.Excel.createExcel();
      final sheet = excel[title];

      // Headers
      sheet.appendRow(headers.map((h) => ex.TextCellValue(h)).toList());

      // Data
      for (final row in data) {
        sheet.appendRow(
          row.map((cell) {
            if (cell is int) return ex.IntCellValue(cell);
            if (cell is double) return ex.DoubleCellValue(cell);
            return ex.TextCellValue(cell?.toString() ?? '');
          }).toList(),
        );
      }

      excel.delete('Sheet1');
      return await _saveExcel(excel, title.toLowerCase().replaceAll(' ', '_'));
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể xuất file: $e');
      return null;
    }
  }

  /// Helper to track sync changes after bulk import
  Future<void> _trackSyncChange(
    String table,
    String recordId,
    ChangeOperation op,
    Map<String, dynamic> data,
  ) async {
    if (Get.isRegistered<SyncEngine>()) {
      await Get.find<SyncEngine>().trackChange(
        table: table,
        recordId: recordId,
        operation: op,
        newData: data,
      );
    }
  }

  /// Add sync metadata and clinic_id to data map
  /// Uses _sync_status (underscore prefix) matching base_sync_repository convention
  Map<String, dynamic> _withSyncStatus(Map<String, dynamic> data) {
    data['_sync_status'] = 'pending';
    data['updated_at'] = DateTime.now().toUtc().toIso8601String();

    // Inject clinic_id so queryActive() can find this data
    if (data['clinic_id'] == null && Get.isRegistered<AuthService>()) {
      data['clinic_id'] = AuthService.to.currentProfile.value?.clinicId;
    }
    return data;
  }

  Future<int> saveCustomersToDb(List<CustomerModel> customers) async {
    final db = await DatabaseProvider.instance.database;
    int count = 0;

    for (final customer in customers) {
      try {
        final existing = await db.query(
          'customers',
          where: 'phone = ?',
          whereArgs: [customer.phone],
        );

        if (existing.isEmpty) {
          final data = _withSyncStatus(customer.toJson());
          await db.insert('customers', data);
          await _trackSyncChange(
            'customers',
            customer.id,
            ChangeOperation.insert,
            data,
          );
        } else {
          final old = CustomerModel.fromJson(existing.first);
          final data = _withSyncStatus(
            customer
                .copyWith(
                  id: old.id,
                  createdAt: old.createdAt,
                  updatedAt: DateTime.now(),
                )
                .toJson(),
          );
          await db.update(
            'customers',
            data,
            where: 'id = ?',
            whereArgs: [old.id],
          );
          await _trackSyncChange(
            'customers',
            old.id,
            ChangeOperation.update,
            data,
          );
        }
        count++;
      } catch (e) {
        debugPrint('Error upserting customer ${customer.phone}: $e');
      }
    }
    return count;
  }

  Future<int> saveMedicinesToDb(List<MedicineModel> medicines) async {
    final db = await DatabaseProvider.instance.database;
    int count = 0;

    for (final medicine in medicines) {
      try {
        List<Map<String, dynamic>> existing = await db.query(
          'medicines',
          where: 'code = ?',
          whereArgs: [medicine.code],
        );

        if (existing.isEmpty) {
          existing = await db.query(
            'medicines',
            where: 'name = ?',
            whereArgs: [medicine.name],
          );
        }

        if (existing.isEmpty) {
          final data = _withSyncStatus(medicine.toJson());
          await db.insert('medicines', data);
          await _trackSyncChange(
            'medicines',
            medicine.id,
            ChangeOperation.insert,
            data,
          );
        } else {
          final old = MedicineModel.fromJson(existing.first);
          final updated = medicine.copyWith(id: old.id);
          final data = _withSyncStatus(updated.toJson());
          await db.update(
            'medicines',
            data,
            where: 'id = ?',
            whereArgs: [old.id],
          );
          await _trackSyncChange(
            'medicines',
            old.id,
            ChangeOperation.update,
            data,
          );
        }
        count++;
      } catch (e) {
        debugPrint('Error upserting medicine ${medicine.code}: $e');
      }
    }
    return count;
  }

  Future<int> saveProductsToDb(List<ProductModel> products) async {
    final db = await DatabaseProvider.instance.database;
    int count = 0;

    for (final product in products) {
      try {
        final existing = await db.query(
          'products',
          where: 'name LIKE ?',
          whereArgs: [product.name],
        );

        if (existing.isNotEmpty) {
          final oldProduct = ProductModel.fromJson(existing.first);
          final updatedProduct = oldProduct.copyWith(
            stock: product.stock,
            salePrice: product.salePrice > 0
                ? product.salePrice
                : oldProduct.salePrice,
            costPrice: product.costPrice > 0
                ? product.costPrice
                : oldProduct.costPrice,
            category: product.category ?? oldProduct.category,
            brand: product.brand ?? oldProduct.brand,
          );
          final data = _withSyncStatus(updatedProduct.toJson());
          await db.update(
            'products',
            data,
            where: 'id = ?',
            whereArgs: [oldProduct.id],
          );
          await _trackSyncChange(
            'products',
            oldProduct.id,
            ChangeOperation.update,
            data,
          );
        } else {
          final data = _withSyncStatus(product.toJson());
          await db.insert('products', data);
          await _trackSyncChange(
            'products',
            product.id,
            ChangeOperation.insert,
            data,
          );
        }
        count++;
      } catch (e) {
        debugPrint('Error saving product ${product.name}: $e');
      }
    }
    return count;
  }

  Future<int> saveServicesToDb(List<ServiceModel> services) async {
    final db = await DatabaseProvider.instance.database;
    int count = 0;

    for (final service in services) {
      try {
        final existing = await db.query(
          'services',
          where: 'name = ?',
          whereArgs: [service.name],
        );

        if (existing.isEmpty) {
          final data = _withSyncStatus(service.toJson());
          await db.insert('services', data);
          await _trackSyncChange(
            'services',
            service.id,
            ChangeOperation.insert,
            data,
          );
        } else {
          final old = ServiceModel.fromJson(existing.first);
          final data = _withSyncStatus(service.copyWith(id: old.id).toJson());
          await db.update(
            'services',
            data,
            where: 'id = ?',
            whereArgs: [old.id],
          );
          await _trackSyncChange(
            'services',
            old.id,
            ChangeOperation.update,
            data,
          );
        }
        count++;
      } catch (e) {
        debugPrint('Error saving service ${service.name}: $e');
      }
    }
    return count;
  }

  // Helpers
  Future<String?> _saveExcel(ex.Excel excel, String fileName) async {
    final fileBytes = excel.save();
    if (fileBytes == null) return null;

    String? outputFile;
    if (Platform.isWindows) {
      final downloadDir = await getDownloadsDirectory();
      outputFile = '${downloadDir?.path}\\$fileName.xlsx';
    } else {
      // Android/iOS
      final dir = await getApplicationDocumentsDirectory();
      outputFile = '${dir.path}/$fileName.xlsx';
    }

    // Handle duplicate filename
    int i = 1;
    while (File(outputFile!).existsSync()) {
      if (Platform.isWindows) {
        final downloadDir = await getDownloadsDirectory();
        outputFile = '${downloadDir?.path}\\${fileName}_$i.xlsx';
      } else {
        final dir = await getApplicationDocumentsDirectory();
        outputFile = '${dir.path}/${fileName}_$i.xlsx';
      }
      i++;
    }

    File(outputFile)
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes);

    // Open file
    if (Platform.isWindows) {
      Process.run('explorer.exe', [outputFile]);
    }

    Get.snackbar(
      'Xuất file thành công',
      'Đã lưu tại: $outputFile',
      duration: const Duration(seconds: 4),
      onTap: (_) {
        // Open file logic if needed
      },
    );

    return outputFile;
  }

  // Helper Parsers
  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  int _parseInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is double) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }
}
