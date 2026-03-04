/// App Permissions & Role definitions for RBAC
///
/// Usage:
///   PermissionService.to.can(AppPermission.casesEdit)
///   PermissionService.to.canAccessModule(AppModule.pharmacy)
library;

/// All modules in the app
enum AppModule {
  home,
  appointments,
  cases,
  customers,
  pharmacy,
  petshop,
  hospitalization,
  reports,
  expenses,
  library,
  settings,
  staffManagement,
}

/// Granular permissions per module
enum AppPermission {
  // Dashboard
  homeView,
  homeViewRevenue,

  // Appointments
  appointmentsView,
  appointmentsCreate,
  appointmentsEdit,
  appointmentsDelete,

  // Medical Cases
  casesView,
  casesCreate,
  casesEdit,
  casesDelete,

  // Customers & Pets
  customersView,
  customersCreate,
  customersEdit,
  customersDelete,

  // Pharmacy
  pharmacyView,
  pharmacyCreate,
  pharmacyEdit,
  pharmacyDelete,
  pharmacyPrescribe, // Doctors can prescribe
  // Petshop
  petshopView,
  petshopCreate,
  petshopEdit,
  petshopDelete,
  petshopSell, // Receptionist can sell
  // Hospitalization
  hospitalizationView,
  hospitalizationCreate,
  hospitalizationEdit,
  hospitalizationDelete,
  hospitalizationCare, // Assistants can log daily care
  // Reports
  reportsView,

  // Expenses
  expensesView,
  expensesCreate,
  expensesEdit,
  expensesDelete,

  // Library (Import/Export)
  libraryView,
  libraryImport,
  libraryExport,

  // Settings
  settingsView,
  settingsEdit,

  // Staff Management
  staffView,
  staffCreate,
  staffEdit,
  staffDelete,

  // Sync
  syncView, // Can see and use sync button
}

/// Staff roles ordered by privilege level
enum AppRole {
  owner,
  admin,
  doctor,
  receptionist,
  assistant;

  String get displayName {
    switch (this) {
      case AppRole.owner:
        return 'Chủ phòng khám';
      case AppRole.admin:
        return 'Quản lý';
      case AppRole.doctor:
        return 'Bác sĩ';
      case AppRole.receptionist:
        return 'Lễ tân';
      case AppRole.assistant:
        return 'Trợ lý';
    }
  }

  /// Parse from string (stored in DB)
  static AppRole fromString(String? value) {
    switch (value) {
      case 'owner':
        return AppRole.owner;
      case 'admin':
        return AppRole.admin;
      case 'doctor':
      case 'vet':
        return AppRole.doctor;
      case 'receptionist':
        return AppRole.receptionist;
      case 'assistant':
        return AppRole.assistant;
      default:
        return AppRole.assistant; // Safest default = least privilege
    }
  }
}

/// Module access map: which roles can see which modules
const Map<AppRole, Set<AppModule>> moduleAccess = {
  AppRole.owner: {
    AppModule.home,
    AppModule.appointments,
    AppModule.cases,
    AppModule.customers,
    AppModule.pharmacy,
    AppModule.petshop,
    AppModule.hospitalization,
    AppModule.reports,
    AppModule.expenses,
    AppModule.library,
    AppModule.settings,
    AppModule.staffManagement,
  },
  AppRole.admin: {
    AppModule.home,
    AppModule.appointments,
    AppModule.cases,
    AppModule.customers,
    AppModule.pharmacy,
    AppModule.petshop,
    AppModule.hospitalization,
    AppModule.reports,
    AppModule.expenses,
    AppModule.library,
    AppModule.settings,
    AppModule.staffManagement,
  },
  AppRole.doctor: {
    AppModule.home,
    AppModule.appointments,
    AppModule.cases,
    AppModule.customers,
    AppModule.pharmacy,
    AppModule.hospitalization,
    AppModule.reports,
  },
  AppRole.receptionist: {
    AppModule.home,
    AppModule.appointments,
    AppModule.cases,
    AppModule.customers,
    AppModule.petshop,
    AppModule.hospitalization,
  },
  AppRole.assistant: {
    AppModule.home,
    AppModule.appointments,
    AppModule.hospitalization,
  },
};

/// Permission matrix: which roles have which permissions
const Map<AppRole, Set<AppPermission>> permissionMatrix = {
  // Owner: full access
  AppRole.owner: {...AppPermission.values},

  // Admin: almost full (cannot delete original data easily, but still has delete)
  AppRole.admin: {
    AppPermission.homeView,
    AppPermission.homeViewRevenue,
    AppPermission.appointmentsView,
    AppPermission.appointmentsCreate,
    AppPermission.appointmentsEdit,
    AppPermission.appointmentsDelete,
    AppPermission.casesView,
    AppPermission.casesCreate,
    AppPermission.casesEdit,
    AppPermission.casesDelete,
    AppPermission.customersView,
    AppPermission.customersCreate,
    AppPermission.customersEdit,
    AppPermission.customersDelete,
    AppPermission.pharmacyView,
    AppPermission.pharmacyCreate,
    AppPermission.pharmacyEdit,
    AppPermission.pharmacyDelete,
    AppPermission.petshopView,
    AppPermission.petshopCreate,
    AppPermission.petshopEdit,
    AppPermission.petshopDelete,
    AppPermission.petshopSell,
    AppPermission.hospitalizationView,
    AppPermission.hospitalizationCreate,
    AppPermission.hospitalizationEdit,
    AppPermission.hospitalizationDelete,
    AppPermission.hospitalizationCare,
    AppPermission.reportsView,
    AppPermission.expensesView,
    AppPermission.expensesCreate,
    AppPermission.expensesEdit,
    AppPermission.expensesDelete,
    AppPermission.libraryView,
    AppPermission.libraryImport,
    AppPermission.libraryExport,
    AppPermission.settingsView,
    AppPermission.settingsEdit,
    AppPermission.staffView,
    AppPermission.syncView,
  },

  // Doctor: medical focus
  AppRole.doctor: {
    AppPermission.homeView,
    AppPermission.appointmentsView,
    AppPermission.appointmentsCreate,
    AppPermission.appointmentsEdit,
    AppPermission.appointmentsDelete,
    AppPermission.casesView,
    AppPermission.casesCreate,
    AppPermission.casesEdit,
    AppPermission.casesDelete,
    AppPermission.customersView,
    AppPermission.customersCreate,
    AppPermission.customersEdit,
    AppPermission.customersDelete,
    AppPermission.pharmacyView,
    AppPermission.pharmacyPrescribe,
    AppPermission.hospitalizationView,
    AppPermission.hospitalizationCreate,
    AppPermission.hospitalizationEdit,
    AppPermission.hospitalizationDelete,
    AppPermission.hospitalizationCare,
    AppPermission.reportsView,
  },

  // Receptionist: front desk
  AppRole.receptionist: {
    AppPermission.homeView,
    AppPermission.appointmentsView,
    AppPermission.appointmentsCreate,
    AppPermission.appointmentsEdit,
    AppPermission.appointmentsDelete,
    AppPermission.casesView,
    AppPermission.casesCreate,
    AppPermission.customersView,
    AppPermission.customersCreate,
    AppPermission.customersEdit,
    AppPermission.customersDelete,
    AppPermission.petshopView,
    AppPermission.petshopSell,
    AppPermission.hospitalizationView,
  },

  // Assistant: limited
  AppRole.assistant: {
    AppPermission.homeView,
    AppPermission.appointmentsView,
    AppPermission.casesView,
    AppPermission.customersView,
    AppPermission.hospitalizationView,
    AppPermission.hospitalizationCare,
  },
};

/// Map route paths to modules for sidebar filtering
const Map<String, AppModule> routeToModule = {
  '/home': AppModule.home,
  '/appointments': AppModule.appointments,
  '/cases': AppModule.cases,
  '/customers': AppModule.customers,
  '/pharmacy': AppModule.pharmacy,
  '/petshop': AppModule.petshop,
  '/hospitalization': AppModule.hospitalization,
  '/reports': AppModule.reports,
  '/expenses': AppModule.expenses,
  '/library': AppModule.library,
  '/settings': AppModule.settings,
};
