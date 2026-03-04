/// App route names
abstract class Routes {
  Routes._();

  static const String initial = '/';
  static const String home = '/home';
  static const String splash = '/splash';

  // Auth
  static const String login = '/login';

  static const String staffSelect = '/staff-select';

  // Appointments
  static const String appointments = '/appointments';
  static const String appointmentDetail = '/appointments/:id';
  static const String appointmentForm = '/appointments/form';

  // Medical Cases
  static const String cases = '/cases';
  static const String caseDetail = '/cases/:id';
  static const String caseCreate = '/cases/create';
  static const String caseClinicalExam = '/cases/clinical-exam';
  static const String caseDiagnosis = '/cases/diagnosis';
  static const String casePayment = '/cases/payment';

  // Customers
  static const String customers = '/customers';
  static const String customerDetail = '/customers/:id';
  static const String customerForm = '/customers/form';

  // Pets
  static const String pets = '/pets';
  static const String petDetail = '/pets/:id';
  static const String petForm = '/pets/form';

  // Petshop
  static const String petshop = '/petshop';
  static const String petshopProducts = '/petshop/products';
  static const String petshopSales = '/petshop/sales';
  static const String petshopInventory = '/petshop/inventory';

  // Pharmacy
  static const String pharmacy = '/pharmacy';
  static const String pharmacyImport = '/pharmacy/import';
  static const String pharmacyUsage = '/pharmacy/usage';

  // Reports
  static const String reports = '/reports';
  static const String reportsDaily = '/reports/daily';
  static const String reportsMonthly = '/reports/monthly';

  // Expenses
  static const String expenses = '/expenses';

  // Settings
  static const String settings = '/settings';
  static const String staffManagement = '/staff-management';
  static const String hospitalization = '/hospitalization';

  // Library (Import/Export)
  static const String library = '/library';
}
