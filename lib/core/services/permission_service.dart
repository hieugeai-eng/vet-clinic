import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import '../constants/permissions.dart';

/// Central permission checking service
///
/// Supports both role-based AND custom per-staff permission overrides.
/// Custom permissions store granular AppPermission names (e.g. "casesView", "casesEdit").
/// When custom permissions are set, they REPLACE role-based checks entirely.
///
/// Usage:
///   PermissionService.to.can(AppPermission.casesEdit)
///   PermissionService.to.canAccessModule(AppModule.pharmacy)
class PermissionService extends GetxService {
  static PermissionService get to => Get.find<PermissionService>();

  /// Current staff role (reactive)
  final currentRole = Rx<AppRole>(AppRole.assistant);

  /// Current staff profile ID
  final currentStaffId = RxnString();

  /// Current staff name
  final currentStaffName = RxnString();

  /// Custom permission overrides — stores AppPermission.name strings
  /// When set, these REPLACE role-based permission checks
  final customPermissions = Rxn<List<String>>();

  /// Set role from profile data
  void setRole(String? roleStr) {
    debugPrint('🔐 PermissionService.setRole: roleStr="$roleStr"');
    currentRole.value = AppRole.fromString(roleStr);
    customPermissions.value = null;
    debugPrint(
      '🔐 PermissionService.setRole: resolved to ${currentRole.value}',
    );
  }

  /// Set current staff info after PIN login
  void setStaff({
    required String id,
    required String name,
    required String role,
    List<String>? permissions,
  }) {
    debugPrint(
      '🔐 PermissionService.setStaff: id=$id, name=$name, role=$role, customPerms=${permissions?.length}',
    );
    currentStaffId.value = id;
    currentStaffName.value = name;
    currentRole.value = AppRole.fromString(role);

    if (permissions != null && permissions.isNotEmpty) {
      customPermissions.value = permissions;
      debugPrint(
        '🔐 PermissionService: Using CUSTOM permissions (${permissions.length} items)',
      );
    } else {
      customPermissions.value = null;
      debugPrint(
        '🔐 PermissionService: Using ROLE-BASED permissions for ${currentRole.value}',
      );
    }
  }

  /// Clear staff info on logout
  void clearStaff() {
    currentStaffId.value = null;
    currentStaffName.value = null;
    currentRole.value = AppRole.assistant;
    customPermissions.value = null;
  }

  // ─── Permission Checks ───

  /// Check if current staff has a specific permission
  bool can(AppPermission permission) {
    // Owner always has all permissions
    if (currentRole.value == AppRole.owner) return true;

    // Custom permissions override role-based checks
    if (customPermissions.value != null) {
      return customPermissions.value!.contains(permission.name);
    }

    // Fall back to role-based matrix
    final permissions = permissionMatrix[currentRole.value];
    return permissions?.contains(permission) ?? false;
  }

  /// Check if current staff can access a module (for sidebar filtering)
  bool canAccessModule(AppModule module) {
    // Owner always has access to everything
    if (currentRole.value == AppRole.owner) return true;

    // Custom permissions: check if ANY permission for this module is granted
    if (customPermissions.value != null) {
      final modulePerms = getPermissionsForModule(module);
      return modulePerms.any((p) => customPermissions.value!.contains(p.name));
    }

    // Role-based
    final modules = moduleAccess[currentRole.value];
    return modules?.contains(module) ?? false;
  }

  /// Check if current role can access a route path
  bool canAccessRoute(String route) {
    final module = routeToModule[route];
    if (module == null) return true;
    return canAccessModule(module);
  }

  /// Guard an action — execute onAllowed if permitted, onDenied otherwise
  void guardAction(
    AppPermission permission, {
    required Function() onAllowed,
    Function()? onDenied,
  }) {
    if (can(permission)) {
      onAllowed();
    } else {
      if (onDenied != null) {
        onDenied();
      } else {
        Get.snackbar(
          'Không có quyền',
          'Bạn không được phép thực hiện thao tác này',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  /// Check if current role is at least the given level
  bool isAtLeast(AppRole minRole) {
    return currentRole.value.index <= minRole.index;
  }

  /// Convenience getters
  bool get isOwner => currentRole.value == AppRole.owner;
  bool get isAdmin => isAtLeast(AppRole.admin);
  bool get isDoctor => currentRole.value == AppRole.doctor;
  bool get isReceptionist => currentRole.value == AppRole.receptionist;
  bool get isAssistant => currentRole.value == AppRole.assistant;

  // ─── Static Helpers ───

  /// Get all permissions that belong to a module
  static List<AppPermission> getPermissionsForModule(AppModule module) {
    final prefix = _modulePrefix(module);
    return AppPermission.values
        .where((p) => p.name.startsWith(prefix))
        .toList();
  }

  /// Get Vietnamese display name for a permission action
  static String getPermissionActionName(AppPermission perm) {
    final name = perm.name;
    if (name.endsWith('View')) return 'Xem';
    if (name.endsWith('ViewRevenue')) return 'Xem doanh thu';
    if (name.endsWith('Create')) return 'Tạo mới';
    if (name.endsWith('Edit')) return 'Chỉnh sửa';
    if (name.endsWith('Delete')) return 'Xóa';
    if (name.endsWith('Prescribe')) return 'Kê đơn';
    if (name.endsWith('Sell')) return 'Bán hàng';
    if (name.endsWith('Care')) return 'Chăm sóc';
    if (name.endsWith('Import')) return 'Nhập dữ liệu';
    if (name.endsWith('Export')) return 'Xuất dữ liệu';
    if (name == 'syncView') return 'Xem đồng bộ';
    return name;
  }

  /// Module name prefix for matching permissions
  static String _modulePrefix(AppModule module) {
    switch (module) {
      case AppModule.home:
        return 'home';
      case AppModule.appointments:
        return 'appointments';
      case AppModule.cases:
        return 'cases';
      case AppModule.customers:
        return 'customers';
      case AppModule.pharmacy:
        return 'pharmacy';
      case AppModule.petshop:
        return 'petshop';
      case AppModule.hospitalization:
        return 'hospitalization';
      case AppModule.reports:
        return 'reports';
      case AppModule.expenses:
        return 'expenses';
      case AppModule.library:
        return 'library';
      case AppModule.settings:
        return 'settings';
      case AppModule.staffManagement:
        return 'staff';
    }
  }
}
