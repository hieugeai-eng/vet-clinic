import '../models/medical_case_model.dart';
import '../models/expense_model.dart';
import '../providers/local/database_provider.dart';
import '../../core/services/auth_service.dart';
import 'package:get/get.dart';

/// Repository for Reports and Statistics
class ReportRepository {
  /// Get daily report
  Future<Map<String, dynamic>> getDailyReport(DateTime date) async {
    final db = await DatabaseProvider.instance.database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Clinic Filter
    final clinicId = Get.isRegistered<AuthService>()
        ? AuthService.to.currentProfile.value?.clinicId
        : null;
    final whereSuffix = clinicId != null ? " AND clinic_id = '$clinicId'" : "";
    final mcWhereSuffix = clinicId != null
        ? " AND mc.clinic_id = '$clinicId'"
        : "";

    // Cases count
    final caseResult = await db.rawQuery(
      '''
      SELECT 
        COUNT(*) as total_cases,
        COALESCE(SUM(total_estimate), 0) as total_estimate,
        COALESCE(SUM(advance_payment), 0) as advance_payment
      FROM medical_cases
      WHERE admission_date >= ? AND admission_date < ?$whereSuffix
    ''',
      [
        startOfDay.toUtc().toIso8601String(),
        endOfDay.toUtc().toIso8601String(),
      ],
    );

    // Service revenue (actual charges from case_services)
    final serviceRevResult = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(cs.total), 0) as service_revenue
      FROM case_services cs
      JOIN medical_cases mc ON cs.case_id = mc.id
      WHERE mc.admission_date >= ? AND mc.admission_date < ?$mcWhereSuffix
    ''',
      [
        startOfDay.toUtc().toIso8601String(),
        endOfDay.toUtc().toIso8601String(),
      ],
    );

    // Expenses
    final expenseResult = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) as total_expenses
      FROM expenses
      WHERE date >= ? AND date < ? AND type = 'expense'$whereSuffix
    ''',
      [
        startOfDay.toUtc().toIso8601String(),
        endOfDay.toUtc().toIso8601String(),
      ],
    );

    // Other Incomes
    final incomeResult = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) as total_income
      FROM expenses
      WHERE date >= ? AND date < ? AND type = 'income'$whereSuffix
    ''',
      [
        startOfDay.toUtc().toIso8601String(),
        endOfDay.toUtc().toIso8601String(),
      ],
    );

    // Petshop revenue
    final petshopResult = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(total), 0) as petshop_revenue
      FROM product_sales
      WHERE sale_date >= ? AND sale_date < ?$whereSuffix
    ''',
      [
        startOfDay.toUtc().toIso8601String(),
        endOfDay.toUtc().toIso8601String(),
      ],
    );

    final serviceRevenue =
        (serviceRevResult.first['service_revenue'] as num?)?.toDouble() ?? 0;
    final totalEstimate =
        (caseResult.first['total_estimate'] as num?)?.toDouble() ?? 0;

    return {
      'date': date,
      'total_cases': caseResult.first['total_cases'] ?? 0,
      'total_estimate': totalEstimate,
      'total_collected': serviceRevenue > 0 ? serviceRevenue : totalEstimate,
      'advance_payment':
          (caseResult.first['advance_payment'] as num?)?.toDouble() ?? 0,
      'service_revenue': serviceRevenue,
      'total_expenses':
          (expenseResult.first['total_expenses'] as num?)?.toDouble() ?? 0,
      'other_income':
          (incomeResult.first['total_income'] as num?)?.toDouble() ?? 0,
      'petshop_revenue':
          (petshopResult.first['petshop_revenue'] as num?)?.toDouble() ?? 0,
    };
  }

  /// Get monthly report
  Future<Map<String, dynamic>> getMonthlyReport(int year, int month) async {
    final db = await DatabaseProvider.instance.database;
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 1);

    // Clinic Filter
    final clinicId = Get.isRegistered<AuthService>()
        ? AuthService.to.currentProfile.value?.clinicId
        : null;
    final whereSuffix = clinicId != null ? " AND clinic_id = '$clinicId'" : "";
    final mcWhereSuffix = clinicId != null
        ? " AND mc.clinic_id = '$clinicId'"
        : "";

    // Cases
    final caseResult = await db.rawQuery(
      '''
      SELECT 
        COUNT(*) as total_cases,
        COALESCE(SUM(total_estimate), 0) as total_estimate,
        COALESCE(SUM(advance_payment), 0) as advance_payment,
        COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_cases
      FROM medical_cases
      WHERE admission_date >= ? AND admission_date < ?$whereSuffix
    ''',
      [
        startOfMonth.toUtc().toIso8601String(),
        endOfMonth.toUtc().toIso8601String(),
      ],
    );

    // Service revenue (actual charges from case_services)
    final serviceRevResult = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(cs.total), 0) as service_revenue
      FROM case_services cs
      JOIN medical_cases mc ON cs.case_id = mc.id
      WHERE mc.admission_date >= ? AND mc.admission_date < ?$mcWhereSuffix
    ''',
      [
        startOfMonth.toUtc().toIso8601String(),
        endOfMonth.toUtc().toIso8601String(),
      ],
    );

    // Expenses by category
    final expenseResult = await db.rawQuery(
      '''
      SELECT category, COALESCE(SUM(amount), 0) as total
      FROM expenses
      WHERE date >= ? AND date < ? AND type = 'expense'$whereSuffix
      GROUP BY category
    ''',
      [
        startOfMonth.toUtc().toIso8601String(),
        endOfMonth.toUtc().toIso8601String(),
      ],
    );

    // Other Incomes
    final incomeResult = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) as total_income
      FROM expenses
      WHERE date >= ? AND date < ? AND type = 'income'$whereSuffix
    ''',
      [
        startOfMonth.toUtc().toIso8601String(),
        endOfMonth.toUtc().toIso8601String(),
      ],
    );

    // Petshop
    final petshopResult = await db.rawQuery(
      '''
      SELECT 
        COALESCE(SUM(total), 0) as revenue,
        COALESCE(SUM(quantity), 0) as items_sold
      FROM product_sales
      WHERE sale_date >= ? AND sale_date < ?$whereSuffix
    ''',
      [
        startOfMonth.toUtc().toIso8601String(),
        endOfMonth.toUtc().toIso8601String(),
      ],
    );

    // Service statistics
    final serviceResult = await db.rawQuery(
      '''
      SELECT service_name, SUM(quantity) as total_quantity, SUM(total) as total_revenue
      FROM case_services cs
      JOIN medical_cases mc ON cs.case_id = mc.id
      WHERE mc.admission_date >= ? AND mc.admission_date < ?$mcWhereSuffix
      GROUP BY service_name
      ORDER BY total_revenue DESC
    ''',
      [
        startOfMonth.toUtc().toIso8601String(),
        endOfMonth.toUtc().toIso8601String(),
      ],
    );

    double totalExpenses = 0;
    final expensesByCategory = <String, double>{};
    for (final e in expenseResult) {
      final amount = (e['total'] as num?)?.toDouble() ?? 0;
      expensesByCategory[e['category'] as String] = amount;
      totalExpenses += amount;
    }

    final serviceRevenue =
        (serviceRevResult.first['service_revenue'] as num?)?.toDouble() ?? 0;
    final totalEstimate =
        (caseResult.first['total_estimate'] as num?)?.toDouble() ?? 0;
    // Use service revenue if available, otherwise fall back to total_estimate
    final revenue = serviceRevenue > 0 ? serviceRevenue : totalEstimate;
    final petshopRevenue =
        (petshopResult.first['revenue'] as num?)?.toDouble() ?? 0;
    final otherIncome =
        (incomeResult.first['total_income'] as num?)?.toDouble() ?? 0;

    return {
      'year': year,
      'month': month,
      'total_cases': caseResult.first['total_cases'] ?? 0,
      'completed_cases': caseResult.first['completed_cases'] ?? 0,
      'total_estimate': totalEstimate,
      'total_collected': revenue,
      'advance_payment':
          (caseResult.first['advance_payment'] as num?)?.toDouble() ?? 0,
      'service_revenue': serviceRevenue,
      'total_expenses': totalExpenses,
      'other_income': otherIncome,
      'expenses_by_category': expensesByCategory,
      'petshop_revenue': petshopRevenue,
      'petshop_items_sold': petshopResult.first['items_sold'] ?? 0,
      'net_profit': revenue + petshopRevenue + otherIncome - totalExpenses,
      'service_stats': serviceResult,
    };
  }

  /// Get cases by date range
  Future<List<MedicalCaseModel>> getCases({
    required DateTime fromDate,
    required DateTime toDate,
    String? status,
  }) async {
    final db = await DatabaseProvider.instance.database;
    final where = [
      'medical_cases.admission_date >= ?',
      'medical_cases.admission_date <= ?',
    ];
    final args = [
      fromDate.toUtc().toIso8601String(),
      toDate.toUtc().toIso8601String(),
    ];

    // Clinic Filter
    if (Get.isRegistered<AuthService>()) {
      final clinicId = AuthService.to.currentProfile.value?.clinicId;
      if (clinicId != null) {
        where.add("medical_cases.clinic_id = ?");
        args.add(clinicId);
      }
    }

    if (status != null) {
      where.add('medical_cases.status = ?');
      args.add(status);
    }

    final query =
        '''
      SELECT 
        medical_cases.*,
        customers.name as customer_name,
        customers.phone as phone,
        customers.address as address,
        pets.name as pet_name,
        pets.species as species
      FROM medical_cases
      LEFT JOIN customers ON medical_cases.customer_id = customers.id
      LEFT JOIN pets ON medical_cases.pet_id = pets.id
      WHERE ${where.join(' AND ')}
      ORDER BY medical_cases.admission_date DESC
    ''';

    final results = await db.rawQuery(query, args);
    return results.map((c) => MedicalCaseModel.fromJson(c)).toList();
  }

  /// Get expenses by date range
  Future<List<ExpenseModel>> getExpenses({
    required DateTime fromDate,
    required DateTime toDate,
    String? category,
  }) async {
    final db = await DatabaseProvider.instance.database;
    final where = ['date >= ?', 'date <= ?'];
    final args = [
      fromDate.toUtc().toIso8601String(),
      toDate.toUtc().toIso8601String(),
    ];

    // Clinic Filter
    if (Get.isRegistered<AuthService>()) {
      final clinicId = AuthService.to.currentProfile.value?.clinicId;
      if (clinicId != null) {
        where.add("clinic_id = ?");
        args.add(clinicId);
      }
    }

    if (category != null) {
      where.add('category = ?');
      args.add(category);
    }

    final results = await db.query(
      'expenses',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'date DESC',
    );
    return results.map((e) => ExpenseModel.fromJson(e)).toList();
  }

  /// Get service statistics
  Future<List<Map<String, dynamic>>> getServiceStats({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final db = await DatabaseProvider.instance.database;
    final args = [
      fromDate.toUtc().toIso8601String(),
      toDate.toUtc().toIso8601String(),
    ];
    String whereSuffix = "";

    // Clinic Filter
    final clinicId = Get.isRegistered<AuthService>()
        ? AuthService.to.currentProfile.value?.clinicId
        : null;
    if (clinicId != null) {
      whereSuffix = " AND mc.clinic_id = ?";
      args.add(clinicId);
    }

    return await db.rawQuery('''
      SELECT 
        service_name,
        SUM(quantity) as total_quantity,
        SUM(total) as total_revenue
      FROM case_services cs
      JOIN medical_cases mc ON cs.case_id = mc.id
      WHERE mc.admission_date >= ? AND mc.admission_date <= ?$whereSuffix
      GROUP BY service_name
      ORDER BY total_revenue DESC
    ''', args);
  }

  /// Get inventory report
  Future<Map<String, dynamic>> getInventoryReport() async {
    final db = await DatabaseProvider.instance.database;

    // Clinic Filter
    final clinicId = Get.isRegistered<AuthService>()
        ? AuthService.to.currentProfile.value?.clinicId
        : null;
    final whereSuffix = clinicId != null ? " AND clinic_id = '$clinicId'" : "";

    // Medicine inventory
    final medicineResult = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_items,
        COALESCE(SUM(stock * avg_price), 0) as total_value,
        COUNT(CASE WHEN stock <= COALESCE(min_stock, 10) THEN 1 END) as low_stock_items
      FROM medicines WHERE is_active = 1$whereSuffix
    ''');

    // Product inventory
    final productResult = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_items,
        COALESCE(SUM(stock * cost_price), 0) as total_value,
        COUNT(CASE WHEN stock <= 5 THEN 1 END) as low_stock_items
      FROM products WHERE is_active = 1$whereSuffix
    ''');

    return {
      'medicine': {
        'total_items': medicineResult.first['total_items'] ?? 0,
        'total_value':
            (medicineResult.first['total_value'] as num?)?.toDouble() ?? 0,
        'low_stock_items': medicineResult.first['low_stock_items'] ?? 0,
      },
      'products': {
        'total_items': productResult.first['total_items'] ?? 0,
        'total_value':
            (productResult.first['total_value'] as num?)?.toDouble() ?? 0,
        'low_stock_items': productResult.first['low_stock_items'] ?? 0,
      },
    };
  }

  /// Get Petshop expenses (Category contains 'petshop')
  Future<List<ExpenseModel>> getPetshopExpenses({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final db = await DatabaseProvider.instance.database;
    final where = [
      'date >= ?',
      'date <= ?',
      "LOWER(category) LIKE '%petshop%'",
    ];
    final args = [
      fromDate.toUtc().toIso8601String(),
      toDate.toUtc().toIso8601String(),
    ];

    // Clinic Filter
    if (Get.isRegistered<AuthService>()) {
      final clinicId = AuthService.to.currentProfile.value?.clinicId;
      if (clinicId != null) {
        where.add("clinic_id = ?");
        args.add(clinicId);
      }
    }

    final results = await db.query(
      'expenses',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'date DESC',
    );
    return results.map((e) => ExpenseModel.fromJson(e)).toList();
  }

  /// Get product sales with details
  Future<List<Map<String, dynamic>>> getProductSales({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final db = await DatabaseProvider.instance.database;
    final args = <dynamic>[
      fromDate.toUtc().toIso8601String(),
      toDate.toUtc().toIso8601String(),
    ];

    // Clinic filter via products table (product_sales may not have clinic_id populated)
    String clinicWhere = '';
    if (Get.isRegistered<AuthService>()) {
      final clinicId = AuthService.to.currentProfile.value?.clinicId;
      if (clinicId != null) {
        clinicWhere = " AND (ps.clinic_id = ? OR p.clinic_id = ?)";
        args.addAll([clinicId, clinicId]);
      }
    }

    final query =
        '''
      SELECT 
        ps.*,
        c.name as customer_name,
        s.name as staff_name
      FROM product_sales ps
      LEFT JOIN customers c ON ps.customer_id = c.id
      LEFT JOIN staff s ON ps.staff_id = s.id
      LEFT JOIN products p ON ps.product_id = p.id
      WHERE ps.sale_date >= ? AND ps.sale_date <= ?
      $clinicWhere
      ORDER BY ps.sale_date DESC
    ''';

    return await db.rawQuery(query, args);
  }
}
