import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/widgets/main_layout.dart';
import '../controllers/staff_management_controller.dart';

class StaffManagementView extends GetView<StaffManagementController> {
  const StaffManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Quản Lý Nhân Viên',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Quản lý chức danh, quyền hạn và mã PIN cho nhân viên',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showStaffDialog(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Thêm'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Staff list
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (controller.staffList.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FaIcon(
                          FontAwesomeIcons.userSlash,
                          size: 48,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Chưa có nhân viên nào',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => _showStaffDialog(context),
                          child: const Text('+ Thêm nhân viên đầu tiên'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: controller.staffList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final staff = controller.staffList[index];
                    return _buildStaffCard(context, staff);
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffCard(BuildContext context, Map<String, dynamic> staff) {
    final role = AppRole.fromString(staff['role']);
    final roleColor = _getRoleColor(role);
    final name = staff['full_name'] ?? 'Chưa đặt tên';
    final isFromProfiles = staff['_source'] == 'profiles';
    final isInactive = staff['is_active'] == false;
    final hasPinHash =
        staff['pin_hash'] != null && (staff['pin_hash'] as String).isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isInactive ? Colors.grey[100] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isInactive
              ? Colors.grey[300]!
              : roleColor.withValues(alpha: 0.3),
        ),
        boxShadow: [
          if (!isInactive)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 28,
            backgroundColor: roleColor.withValues(alpha: 0.15),
            child: Text(
              _getInitials(name),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isInactive ? Colors.grey : roleColor,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isInactive ? Colors.grey : null,
                    decoration: isInactive ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        role.displayName,
                        style: TextStyle(
                          color: roleColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isFromProfiles)
                      Icon(Icons.verified, size: 14, color: Colors.blue[400]),
                    if (hasPinHash)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, size: 14, color: Colors.grey[500]),
                          Text(
                            ' PIN',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    if (isInactive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Vô hiệu',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                  ],
                ),
                if (staff['specialization'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    staff['specialization'],
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
                if (staff['phone'] != null || staff['email'] != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (staff['phone'] != null) ...[
                        Icon(Icons.phone, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          staff['phone'],
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (staff['email'] != null) ...[
                        Icon(Icons.email, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            staff['email'],
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Actions
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            color: Colors.blue[600],
            tooltip: 'Sửa',
            onPressed: () => _showStaffDialog(context, staff: staff),
          ),
          if (!isFromProfiles)
            IconButton(
              icon: const Icon(Icons.person_off_outlined, size: 20),
              color: Colors.red[400],
              tooltip: 'Vô hiệu hóa',
              onPressed: () => controller.deactivateStaff(staff),
            ),
        ],
      ),
    );
  }

  void _showStaffDialog(BuildContext context, {Map<String, dynamic>? staff}) {
    final isEdit = staff != null;
    final nameCtrl = TextEditingController(text: staff?['full_name'] ?? '');
    final specCtrl = TextEditingController(
      text: staff?['specialization'] ?? '',
    );
    final phoneCtrl = TextEditingController(text: staff?['phone'] ?? '');
    final emailCtrl = TextEditingController(text: staff?['email'] ?? '');
    final pinCtrl = TextEditingController();
    final selectedRole = (staff?['role'] ?? 'assistant').toString().obs;

    // Parse existing custom permissions (stored in custom_modules field)
    List<String>? existingPerms;
    if (staff?['custom_modules'] != null) {
      try {
        final decoded = staff!['custom_modules'];
        if (decoded is String) {
          existingPerms = List<String>.from(jsonDecode(decoded));
        } else if (decoded is List) {
          existingPerms = List<String>.from(decoded);
        }
      } catch (_) {}
    }

    final useCustom = (existingPerms != null).obs;

    // Permission toggle states — one per AppPermission
    final permToggles = <String, RxBool>{};
    final roleDefaults =
        permissionMatrix[AppRole.fromString(selectedRole.value)] ?? {};
    for (final p in AppPermission.values) {
      final isEnabled = existingPerms != null
          ? existingPerms.contains(p.name)
          : roleDefaults.contains(p);
      permToggles[p.name] = isEnabled.obs;
    }

    // When role changes, reset toggles to role defaults (only if not using custom)
    ever(selectedRole, (newRole) {
      if (!useCustom.value) {
        final defaults = permissionMatrix[AppRole.fromString(newRole)] ?? {};
        for (final p in AppPermission.values) {
          permToggles[p.name]?.value = defaults.contains(p);
        }
      }
    });

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: ResponsiveHelper.dialogWidth(context, 500),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          padding: const EdgeInsets.all(28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'Sửa Nhân Viên' : 'Thêm Nhân Viên',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                // Full name
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Họ và tên *',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Role selector
                const Text(
                  'Chức danh *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Obx(
                  () => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppRole.values.map((role) {
                      final isSelected = selectedRole.value == role.name;
                      return ChoiceChip(
                        label: Text(role.displayName),
                        selected: isSelected,
                        selectedColor: _getRoleColor(
                          role,
                        ).withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? _getRoleColor(role)
                              : Colors.grey[700],
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        onSelected: (_) => selectedRole.value = role.name,
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Specialization
                TextField(
                  controller: specCtrl,
                  decoration: InputDecoration(
                    labelText: 'Chuyên khoa (tùy chọn)',
                    prefixIcon: const Icon(Icons.medical_services),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Phone
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Số điện thoại',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Email
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email (tùy chọn)',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // PIN
                TextField(
                  controller: pinCtrl,
                  obscureText: true,
                  maxLength: 4,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: isEdit
                        ? 'Đổi mã PIN (4 số, bỏ trống = giữ nguyên)'
                        : 'Mã PIN (4 số) *',
                    helperText:
                        'Mỗi nhân viên phải có mã PIN riêng, không trùng nhau',
                    helperStyle: TextStyle(
                      color: Colors.blue[400],
                      fontSize: 11,
                    ),
                    prefixIcon: const Icon(Icons.lock),
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ─── Granular Permission Section ───
                const Divider(),
                const SizedBox(height: 8),
                Obx(
                  () => Row(
                    children: [
                      const Icon(
                        Icons.tune,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Phân quyền tùy chỉnh',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: useCustom.value,
                        activeColor: AppColors.primary,
                        onChanged: (v) {
                          useCustom.value = v;
                          if (!v) {
                            // Reset to role defaults
                            final defaults =
                                permissionMatrix[AppRole.fromString(
                                  selectedRole.value,
                                )] ??
                                {};
                            for (final p in AppPermission.values) {
                              permToggles[p.name]?.value = defaults.contains(p);
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
                Obx(() {
                  if (!useCustom.value) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Text(
                        'Đang dùng quyền mặc định theo chức danh',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: Text(
                          'Chọn quyền chi tiết cho từng module',
                          style: TextStyle(
                            color: Colors.blue[600],
                            fontSize: 12,
                          ),
                        ),
                      ),
                      // Quick actions
                      Row(
                        children: [
                          TextButton.icon(
                            icon: const Icon(
                              Icons.check_box_outlined,
                              size: 16,
                            ),
                            label: const Text(
                              'Chọn tất cả',
                              style: TextStyle(fontSize: 12),
                            ),
                            onPressed: () {
                              for (final t in permToggles.values)
                                t.value = true;
                            },
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            icon: const Icon(
                              Icons.check_box_outline_blank,
                              size: 16,
                            ),
                            label: const Text(
                              'Bỏ tất cả',
                              style: TextStyle(fontSize: 12),
                            ),
                            onPressed: () {
                              for (final t in permToggles.values)
                                t.value = false;
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Per-module expandable sections
                      ...AppModule.values.where((m) => m != AppModule.home).map(
                        (module) {
                          final modulePerms =
                              PermissionService.getPermissionsForModule(module);
                          if (modulePerms.isEmpty)
                            return const SizedBox.shrink();
                          return _buildModulePermSection(
                            module,
                            modulePerms,
                            permToggles,
                          );
                        },
                      ),
                      // Standalone sync permission (not tied to any module)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[200]!),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Obx(
                          () => CheckboxListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            secondary: Icon(
                              Icons.sync,
                              size: 18,
                              color: permToggles['syncView']!.value
                                  ? AppColors.primary
                                  : Colors.grey[400],
                            ),
                            title: const Text(
                              'Đồng bộ dữ liệu',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Xem và sử dụng nút đồng bộ',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                            value: permToggles['syncView']!.value,
                            activeColor: AppColors.primary,
                            onChanged: (v) =>
                                permToggles['syncView']!.value = v ?? false,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                const Divider(),
                const SizedBox(height: 16),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Hủy'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          Get.snackbar('Lỗi', 'Vui lòng nhập họ tên');
                          return;
                        }
                        // PIN required for new staff
                        if (!isEdit && pinCtrl.text.length != 4) {
                          Get.snackbar(
                            'Lỗi',
                            'Mã PIN bắt buộc (4 số) cho nhân viên mới',
                          );
                          return;
                        }

                        // Build custom permissions list
                        List<String>? customPerms;
                        if (useCustom.value) {
                          customPerms = permToggles.entries
                              .where((e) => e.value.value)
                              .map((e) => e.key)
                              .toList();
                          // Always grant homeView
                          if (!customPerms.contains('homeView'))
                            customPerms.insert(0, 'homeView');
                        }

                        Navigator.pop(ctx);

                        if (isEdit) {
                          controller.updateStaff(
                            staff!,
                            fullName: name,
                            role: selectedRole.value,
                            specialization: specCtrl.text.trim().isNotEmpty
                                ? specCtrl.text.trim()
                                : null,
                            phone: phoneCtrl.text.trim().isNotEmpty
                                ? phoneCtrl.text.trim()
                                : null,
                            email: emailCtrl.text.trim().isNotEmpty
                                ? emailCtrl.text.trim()
                                : null,
                            newPin: pinCtrl.text.length == 4
                                ? pinCtrl.text
                                : null,
                            customModules: customPerms,
                          );
                        } else {
                          controller.createStaff(
                            fullName: name,
                            role: selectedRole.value,
                            specialization: specCtrl.text.trim().isNotEmpty
                                ? specCtrl.text.trim()
                                : null,
                            phone: phoneCtrl.text.trim().isNotEmpty
                                ? phoneCtrl.text.trim()
                                : null,
                            email: emailCtrl.text.trim().isNotEmpty
                                ? emailCtrl.text.trim()
                                : null,
                            pin: pinCtrl.text.length == 4 ? pinCtrl.text : null,
                            customModules: customPerms,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(isEdit ? 'Cập nhật' : 'Thêm'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getModuleDisplayName(AppModule module) {
    switch (module) {
      case AppModule.home:
        return 'Trang chủ';
      case AppModule.appointments:
        return 'Lịch hẹn';
      case AppModule.cases:
        return 'Ca khám';
      case AppModule.customers:
        return 'Khách hàng';
      case AppModule.pharmacy:
        return 'Kho thuốc';
      case AppModule.petshop:
        return 'Pet Shop';
      case AppModule.hospitalization:
        return 'Lưu viện';
      case AppModule.reports:
        return 'Báo cáo';
      case AppModule.expenses:
        return 'Thu chi';
      case AppModule.library:
        return 'Thư viện';
      case AppModule.settings:
        return 'Cài đặt';
      case AppModule.staffManagement:
        return 'Quản lý NV';
    }
  }

  IconData _getModuleIcon(AppModule module) {
    switch (module) {
      case AppModule.home:
        return Icons.home;
      case AppModule.appointments:
        return Icons.calendar_today;
      case AppModule.cases:
        return Icons.medical_services;
      case AppModule.customers:
        return Icons.people;
      case AppModule.pharmacy:
        return Icons.local_pharmacy;
      case AppModule.petshop:
        return Icons.storefront;
      case AppModule.hospitalization:
        return Icons.local_hospital;
      case AppModule.reports:
        return Icons.bar_chart;
      case AppModule.expenses:
        return Icons.account_balance_wallet;
      case AppModule.library:
        return Icons.menu_book;
      case AppModule.settings:
        return Icons.settings;
      case AppModule.staffManagement:
        return Icons.admin_panel_settings;
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Color _getRoleColor(AppRole role) {
    switch (role) {
      case AppRole.owner:
        return const Color(0xFFe67e22);
      case AppRole.admin:
        return const Color(0xFF2980b9);
      case AppRole.doctor:
        return const Color(0xFF27ae60);
      case AppRole.receptionist:
        return const Color(0xFF8e44ad);
      case AppRole.assistant:
        return const Color(0xFF7f8c8d);
    }
  }

  /// Expandable section per module with individual permission checkboxes
  Widget _buildModulePermSection(
    AppModule module,
    List<AppPermission> perms,
    Map<String, RxBool> toggles,
  ) {
    return Obx(() {
      final enabledCount = perms
          .where((p) => toggles[p.name]?.value == true)
          .length;
      final allEnabled = enabledCount == perms.length;
      final someEnabled = enabledCount > 0 && !allEnabled;
      final moduleColor = allEnabled
          ? AppColors.primary
          : someEnabled
          ? Colors.orange
          : Colors.grey[400]!;

      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.only(left: 16, right: 8, bottom: 8),
          leading: Icon(_getModuleIcon(module), size: 18, color: moduleColor),
          title: Row(
            children: [
              Text(
                _getModuleDisplayName(module),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Text(
                '$enabledCount/${perms.length}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
          trailing: SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: allEnabled ? true : (someEnabled ? null : false),
              tristate: true,
              activeColor: AppColors.primary,
              onChanged: (v) {
                final newVal = !allEnabled;
                for (final p in perms) {
                  toggles[p.name]?.value = newVal;
                }
              },
            ),
          ),
          children: perms.map((perm) {
            return Obx(
              () => CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                visualDensity: const VisualDensity(vertical: -3),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  PermissionService.getPermissionActionName(perm),
                  style: TextStyle(
                    fontSize: 13,
                    color: toggles[perm.name]!.value ? null : Colors.grey[500],
                  ),
                ),
                value: toggles[perm.name]!.value,
                activeColor: AppColors.primary,
                onChanged: (v) => toggles[perm.name]!.value = v ?? false,
              ),
            );
          }).toList(),
        ),
      );
    });
  }
}
