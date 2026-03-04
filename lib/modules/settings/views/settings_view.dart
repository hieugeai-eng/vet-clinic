import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/main_layout.dart';
import '../../../core/widgets/pro_widgets.dart';
import '../controllers/settings_controller.dart';
import '../submodules/services/views/service_list_view.dart';
import 'device_management_view.dart';
import '../../../routes/app_routes.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/widgets/permission_guard.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Cài Đặt Hệ Thống',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Clinic Info
          _buildClinicInfoCard(context),
          const SizedBox(height: 24),

          const Text(
            'QUẢN LÝ DANH MỤC',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          // Services Management
          _buildSettingsCard(
            context,
            title: 'Quản lý dịch vụ',
            subtitle: 'Thêm, sửa, xóa dịch vụ và đơn giá',
            icon: Icons.medical_services_outlined,
            color: Colors.blue,
            onTap: () => Get.to(() => const ServiceListView()),
          ),
          const SizedBox(height: 12),

          // Staff Management (unified: list + permissions + PIN)
          _buildSettingsCard(
            context,
            title: 'Quản lý nhân viên',
            subtitle: 'Danh sách, vai trò, mã PIN & quyền truy cập',
            icon: Icons.people_outline,
            color: Colors.orange,
            onTap: () => Get.toNamed(Routes.staffManagement),
          ),
          const SizedBox(height: 12),

          // Data Library
          _buildSettingsCard(
            context,
            title: 'Thư viện dữ liệu',
            subtitle: 'Nhập xuất Excel, đồng bộ & quản lý dữ liệu',
            icon: Icons.library_books_rounded,
            color: Colors.indigo,
            onTap: () => Get.toNamed(Routes.library),
          ),
          const SizedBox(height: 24),
          const Text(
            'HỆ THỐNG',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          // Language
          _buildSettingsCard(
            context,
            title: 'Ngôn ngữ',
            subtitle: Get.locale?.languageCode == 'vi'
                ? 'Tiếng Việt'
                : 'English',
            icon: Icons.language,
            color: Colors.purple,
            onTap: () => _showLanguageDialog(context),
          ),
          const SizedBox(height: 12),

          // Device Management
          _buildSettingsCard(
            context,
            title: 'Quản lý thiết bị',
            subtitle: 'Phê duyệt đăng nhập thiết bị mới',
            icon: Icons.phonelink_setup,
            color: Colors.teal,
            onTap: () => Get.to(() => const DeviceManagementView()),
          ),
          const SizedBox(height: 12),

          // Theme
          _buildSettingsCard(
            context,
            title: 'Giao diện',
            subtitle: Get.isDarkMode ? 'Tối' : 'Sáng',
            icon: Icons.palette_outlined,
            color: Colors.teal,
            trailing: Switch(
              value: Get.isDarkMode,
              onChanged: (value) {
                Get.changeThemeMode(value ? ThemeMode.dark : ThemeMode.light);
              },
            ),
          ),

          const SizedBox(height: 24),

          // About
          _buildSettingsCard(
            context,
            title: 'Về ứng dụng',
            subtitle: 'PetClinic v1.0.0',
            icon: Icons.info_outline,
            color: Colors.grey,
            onTap: () => _showAboutDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade900, fontSize: 13),
          ),
          trailing:
              trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildClinicInfoCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Save button - always visible
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Obx(
                  () => controller.isLoading.value
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : ElevatedButton.icon(
                          onPressed: controller.saveSettings,
                          icon: const Icon(Icons.save, size: 18),
                          label: const Text('Lưu'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          // Clinic Info - Collapsible
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: false,
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.store_mall_directory_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              title: const Text(
                'Thông tin phòng khám',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 500;

                    if (isMobile) {
                      return Column(
                        children: [
                          // Logo
                          GestureDetector(
                            onTap: controller.pickLogo,
                            child: Obx(() {
                              final path = controller.clinicLogoPath.value;
                              return Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: path != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Image.file(
                                          File(path),
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_a_photo_outlined,
                                            color: Colors.grey,
                                            size: 28,
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Logo',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                              );
                            }),
                          ),
                          const SizedBox(height: 16),
                          // Fields
                          ProTextField(
                            label: 'Tên phòng khám',
                            controller: controller.clinicNameController,
                            prefixIcon: Icons.store_outlined,
                          ),
                          const SizedBox(height: 12),
                          ProTextField(
                            label: 'Địa chỉ',
                            controller: controller.clinicAddressController,
                            prefixIcon: Icons.location_on_outlined,
                          ),
                          const SizedBox(height: 12),
                          ProTextField(
                            label: 'Số điện thoại',
                            controller: controller.clinicPhoneController,
                            prefixIcon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Logo
                        GestureDetector(
                          onTap: controller.pickLogo,
                          child: Obx(() {
                            final path = controller.clinicLogoPath.value;
                            return Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: path != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Image.file(
                                        File(path),
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : const Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_a_photo_outlined,
                                          color: Colors.grey,
                                          size: 32,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Logo',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                            );
                          }),
                        ),
                        const SizedBox(width: 24),

                        Expanded(
                          child: Column(
                            children: [
                              ProTextField(
                                label: 'Tên phòng khám',
                                controller: controller.clinicNameController,
                                prefixIcon: Icons.store_outlined,
                              ),
                              const SizedBox(height: 16),
                              ProTextField(
                                label: 'Địa chỉ',
                                controller: controller.clinicAddressController,
                                prefixIcon: Icons.location_on_outlined,
                              ),
                              const SizedBox(height: 16),
                              ProTextField(
                                label: 'Số điện thoại',
                                controller: controller.clinicPhoneController,
                                prefixIcon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          // Zalo Config - Collapsible
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: false,
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.api_outlined,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
              title: const Text(
                'Cấu hình Zalo OA API',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      ProTextField(
                        label: 'App ID',
                        controller: controller.zaloAppIdController,
                        prefixIcon: Icons.perm_identity,
                      ),
                      const SizedBox(height: 12),
                      ProTextField(
                        label: 'Secret Key',
                        controller: controller.zaloSecretKeyController,
                        prefixIcon: Icons.vpn_key_outlined,
                        obscureText: true,
                      ),
                      const SizedBox(height: 12),
                      ProTextField(
                        label: 'OA ID',
                        controller: controller.zaloOaIdController,
                        prefixIcon: Icons.confirmation_number_outlined,
                      ),
                      const SizedBox(height: 12),
                      ProTextField(
                        label: 'Refresh Token',
                        controller: controller.zaloRefreshTokenController,
                        prefixIcon: Icons.refresh_outlined,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 350,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Chọn Ngôn Ngữ',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              _buildLanguageOption(
                context,
                title: 'Tiếng Việt',
                code: 'vi',
                flag: '🇻🇳',
              ),
              const SizedBox(height: 12),
              _buildLanguageOption(
                context,
                title: 'English',
                code: 'en',
                flag: '🇺🇸',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context, {
    required String title,
    required String code,
    required String flag,
  }) {
    final isSelected = Get.locale?.languageCode == code;
    return InkWell(
      onTap: () {
        Get.updateLocale(Locale(code, code == 'vi' ? 'VN' : 'US'));
        Get.back();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primary : AppColors.text,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'O',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'PetClinic',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Text('v1.0.0', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              const Text(
                'Hệ thống quản lý phòng khám thú y toàn diện. Được phát triển để tối ưu hóa quy trình vận hành.',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.5),
              ),
              const SizedBox(height: 32),
              const Text(
                '© 2025 PetClinic',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Đóng'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
