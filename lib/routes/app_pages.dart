import 'package:get/get.dart';

import 'app_routes.dart';

// Modules
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/customers/bindings/customer_binding.dart';
import '../modules/customers/views/customer_list_view.dart';
import '../modules/customers/views/customer_detail_view.dart';
import '../modules/pets/bindings/pet_binding.dart';
import '../modules/pets/views/pet_list_view.dart';
import '../modules/medical_cases/bindings/case_binding.dart';
import '../modules/medical_cases/views/case_list_view.dart';
import '../modules/medical_cases/views/create_case_view.dart';
import '../modules/medical_cases/views/clinical_exam_view.dart';
import '../modules/medical_cases/views/diagnosis_view.dart';
import '../modules/medical_cases/views/payment_view.dart';
import '../modules/appointments/bindings/appointment_binding.dart';
import '../modules/appointments/views/appointment_list_view.dart';
import '../modules/petshop/bindings/petshop_binding.dart';
import '../modules/petshop/views/petshop_view.dart';
import '../modules/pharmacy/bindings/pharmacy_binding.dart';
import '../modules/pharmacy/views/pharmacy_view.dart';
import '../modules/reports/bindings/report_binding.dart';
import '../modules/reports/views/report_view.dart';
import '../modules/expenses/bindings/expense_binding.dart';
import '../modules/expenses/views/expense_view.dart';
import '../modules/settings/bindings/settings_binding.dart';
import '../modules/settings/views/settings_view.dart';
import '../modules/library/bindings/library_binding.dart';
import '../modules/library/views/library_view.dart';
import '../modules/settings/controllers/staff_management_controller.dart';
import '../modules/settings/views/staff_management_view.dart';

/// App pages configuration
/// App pages configuration
import '../modules/hospitalization/views/hospitalization_view.dart';
import '../modules/auth/views/login_screen.dart';

import '../modules/auth/views/staff_select_view.dart';
import '../core/middleware/auth_middleware.dart';
import '../modules/splash/bindings/splash_binding.dart';
import '../modules/splash/views/splash_view.dart';

class AppPages {
  static const initial = Routes.splash;

  static final routes = [
    // Splash
    GetPage(
      name: Routes.splash,
      page: () => const SplashView(),
      binding: SplashBinding(),
      transition: Transition.fade,
    ),

    // Home
    GetPage(
      name: Routes.home,
      page: () => const HomeView(),
      binding: HomeBinding(),
      transition: Transition.fadeIn,
      middlewares: [AuthMiddleware()],
    ),

    // Auth
    GetPage(name: Routes.login, page: () => const LoginScreen()),

    GetPage(
      name: Routes.staffSelect,
      page: () => const StaffSelectView(),
      transition: Transition.fadeIn,
    ),

    // Appointments
    GetPage(
      name: Routes.appointments,
      page: () => const AppointmentListView(),
      binding: AppointmentBinding(),
      middlewares: [AuthMiddleware()],
    ),

    // Medical Cases
    GetPage(
      name: Routes.cases,
      page: () => const CaseListView(),
      binding: CaseListBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Routes.caseCreate,
      page: () => const CreateCaseView(),
      binding: CaseFormBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Routes.caseClinicalExam,
      page: () => const ClinicalExamView(),
      binding: CaseFormBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Routes.caseDiagnosis,
      page: () => const DiagnosisView(),
      binding: CaseFormBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Routes.casePayment,
      page: () => const PaymentView(),
      binding: CaseFormBinding(),
      middlewares: [AuthMiddleware()],
    ),

    // Customers
    GetPage(
      name: Routes.customers,
      page: () => const CustomerListView(),
      binding: CustomerBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Routes.customerDetail,
      page: () => const CustomerDetailView(),
      binding: CustomerBinding(),
      middlewares: [AuthMiddleware()],
    ),

    // Pets
    GetPage(
      name: Routes.pets,
      page: () => const PetListView(),
      binding: PetBinding(),
      middlewares: [AuthMiddleware()],
    ),

    // Petshop
    GetPage(
      name: Routes.petshop,
      page: () => const PetshopView(),
      binding: PetshopBinding(),
      middlewares: [AuthMiddleware()],
    ),

    // Pharmacy
    GetPage(
      name: Routes.pharmacy,
      page: () => const PharmacyView(),
      binding: PharmacyBinding(),
      middlewares: [AuthMiddleware()],
    ),

    // Reports
    GetPage(
      name: Routes.reports,
      page: () => const ReportView(),
      binding: ReportBinding(),
      middlewares: [AuthMiddleware()],
    ),

    // Expenses
    GetPage(
      name: Routes.expenses,
      page: () => const ExpenseView(),
      binding: ExpenseBinding(),
      middlewares: [AuthMiddleware()],
    ),

    // Settings
    GetPage(
      name: Routes.settings,
      page: () => const SettingsView(),
      binding: SettingsBinding(),
      middlewares: [AuthMiddleware()],
    ),

    // Staff Management
    GetPage(
      name: Routes.staffManagement,
      page: () => const StaffManagementView(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => StaffManagementController());
      }),
      middlewares: [AuthMiddleware()],
    ),

    // Hospitalization
    GetPage(
      name: Routes.hospitalization,
      page: () => const HospitalizationView(),
      middlewares: [AuthMiddleware()],
    ),

    // Library (Import/Export)
    GetPage(
      name: Routes.library,
      page: () => const LibraryView(),
      binding: LibraryBinding(),
      middlewares: [AuthMiddleware()],
    ),
  ];
}
