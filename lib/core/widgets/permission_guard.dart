import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/permission_service.dart';
import '../constants/permissions.dart';

/// Widget that shows/hides children based on permission
///
/// Usage:
///   PermissionGuard(
///     permission: AppPermission.casesEdit,
///     child: ElevatedButton(onPressed: editCase, child: Text('Sửa')),
///   )
///
///   PermissionGuard(
///     module: AppModule.pharmacy,
///     child: PharmacySection(),
///   )
class PermissionGuard extends StatelessWidget {
  final AppPermission? permission;
  final AppModule? module;
  final Widget child;
  final Widget? fallback; // Show instead when no permission

  const PermissionGuard({
    super.key,
    this.permission,
    this.module,
    required this.child,
    this.fallback,
  }) : assert(permission != null || module != null);

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<PermissionService>()) return child;

    return Obx(() {
      final ps = PermissionService.to;
      // Trigger reactivity
      final _ = ps.currentRole.value;

      bool allowed = true;
      if (permission != null) {
        allowed = ps.can(permission!);
      } else if (module != null) {
        allowed = ps.canAccessModule(module!);
      }

      if (allowed) return child;
      return fallback ?? const SizedBox.shrink();
    });
  }
}

/// A button that is disabled (greyed out) when user lacks permission
/// Shows tooltip explaining why it's disabled
class GuardedIconButton extends StatelessWidget {
  final AppPermission permission;
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final double? size;
  final Color? color;

  const GuardedIconButton({
    super.key,
    required this.permission,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<PermissionService>()) {
      return IconButton(
        icon: Icon(icon, size: size, color: color),
        onPressed: onPressed,
        tooltip: tooltip,
      );
    }

    return Obx(() {
      final allowed = PermissionService.to.can(permission);
      return IconButton(
        icon: Icon(icon, size: size, color: allowed ? color : Colors.grey[400]),
        onPressed: allowed ? onPressed : null,
        tooltip: allowed ? tooltip : 'Không có quyền',
      );
    });
  }
}
