import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/services/supabase_rest_client.dart';
import '../../../routes/app_routes.dart';

/// PIN-only login screen.
/// All staff (including owner) enter a 4-digit PIN.
/// Each PIN is unique → auto-identifies the user.
class StaffSelectView extends StatefulWidget {
  const StaffSelectView({super.key});

  @override
  State<StaffSelectView> createState() => _StaffSelectViewState();
}

class _StaffSelectViewState extends State<StaffSelectView> {
  final allStaff = <Map<String, dynamic>>[].obs;
  final isLoading = true.obs;
  final errorMsg = ''.obs;
  final pinDigits = <String>['', '', '', ''].obs;
  final focusNodes = List.generate(4, (_) => FocusNode());
  final controllers = List.generate(4, (_) => TextEditingController());
  final identifiedStaff = Rxn<Map<String, dynamic>>();

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  @override
  void dispose() {
    for (final n in focusNodes) n.dispose();
    for (final c in controllers) c.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    isLoading.value = true;
    try {
      final clinicId = AuthService.to.currentClinic.value?.id;
      debugPrint('🔐 PINLogin: clinicId=$clinicId');
      if (clinicId == null) {
        _skipToHome();
        return;
      }

      // Fetch owner profile
      List<dynamic> profiles = [];
      try {
        profiles = await SupabaseRestClient.to.get(
          'profiles',
          query: {
            'clinic_id': 'eq.$clinicId',
            'select': 'id,full_name,role,avatar_url,pin_hash,specialization',
          },
        );
      } catch (e) {
        debugPrint('🔐 PINLogin: profiles query failed ($e)');
        try {
          profiles = await SupabaseRestClient.to.get(
            'profiles',
            query: {
              'clinic_id': 'eq.$clinicId',
              'select': 'id,full_name,role,avatar_url',
            },
          );
        } catch (_) {}
      }

      // Fetch clinic staff
      List<dynamic> clinicStaff = [];
      try {
        clinicStaff = await SupabaseRestClient.to.get(
          'clinic_staff',
          query: {
            'clinic_id': 'eq.$clinicId',
            'is_active': 'eq.true',
            'select':
                'id,full_name,role,avatar_url,pin_hash,specialization,custom_modules',
          },
        );
      } catch (e) {
        debugPrint('🔐 PINLogin: clinic_staff query failed ($e)');
      }

      // Build merged list: owner first, then staff
      final merged = <Map<String, dynamic>>[];

      for (final p in profiles) {
        merged.add({
          ...Map<String, dynamic>.from(p),
          'role': 'owner',
          '_is_owner': true,
        });
      }

      for (final s in clinicStaff) {
        merged.add({...Map<String, dynamic>.from(s), '_is_owner': false});
      }

      debugPrint(
        '🔐 PINLogin: ${merged.length} staff loaded (${profiles.length} owners + ${clinicStaff.length} staff)',
      );

      // If no one has PIN set → skip to home as owner (first-time setup)
      final anyoneHasPin = merged.any(
        (s) => s['pin_hash'] != null && (s['pin_hash'] as String).isNotEmpty,
      );

      if (merged.isEmpty || !anyoneHasPin) {
        debugPrint('🔐 PINLogin: No PINs set → skip as owner');
        _skipToHome();
        return;
      }

      allStaff.value = merged;
    } catch (e) {
      debugPrint('🔐 PINLogin Error: $e');
      _skipToHome();
    } finally {
      isLoading.value = false;
    }
  }

  void _skipToHome() {
    final profile = AuthService.to.currentProfile.value;
    if (Get.isRegistered<PermissionService>()) {
      PermissionService.to.setStaff(
        id: profile?.id ?? '',
        name: profile?.fullName ?? 'Admin',
        role: 'owner',
      );
    }
    Get.offAllNamed(Routes.home);
  }

  void _onPinDigitChanged(int index, String value) {
    errorMsg.value = '';
    identifiedStaff.value = null;

    if (value.isNotEmpty) {
      pinDigits[index] = value;

      // Move to next field
      if (index < 3) {
        focusNodes[index + 1].requestFocus();
      } else {
        // All 4 digits entered → verify
        focusNodes[index].unfocus();
        _verifyPin();
      }
    } else {
      pinDigits[index] = '';
      // Move to previous field on delete
      if (index > 0) {
        focusNodes[index - 1].requestFocus();
      }
    }
  }

  void _verifyPin() {
    final pin = pinDigits.join();
    if (pin.length != 4) return;

    final pinHash = sha256.convert(utf8.encode(pin)).toString();

    // Find matching staff
    Map<String, dynamic>? matched;
    for (final staff in allStaff) {
      if (staff['pin_hash'] == pinHash) {
        matched = staff;
        break;
      }
    }

    if (matched != null) {
      identifiedStaff.value = matched;

      // Brief delay to show who was identified, then navigate
      Future.delayed(const Duration(milliseconds: 600), () {
        _loginAsStaff(matched!);
      });
    } else {
      errorMsg.value = 'Mã PIN không đúng';
      // Clear and refocus
      _clearPin();
    }
  }

  void _loginAsStaff(Map<String, dynamic> staff) {
    if (Get.isRegistered<PermissionService>()) {
      final isOwner = staff['_is_owner'] == true;
      final role = isOwner ? 'owner' : (staff['role'] ?? 'assistant');

      // Parse custom permissions
      List<String>? perms;
      if (!isOwner && staff['custom_modules'] != null) {
        try {
          final decoded = staff['custom_modules'];
          if (decoded is String) {
            perms = List<String>.from(jsonDecode(decoded));
          } else if (decoded is List) {
            perms = List<String>.from(decoded);
          }
        } catch (_) {}
      }

      PermissionService.to.setStaff(
        id: staff['id'] ?? '',
        name: staff['full_name'] ?? 'Staff',
        role: role,
        permissions: perms,
      );
      debugPrint(
        '🔐 PINLogin: ✅ Logged in as "${staff['full_name']}" role=$role',
      );
    }
    Get.offAllNamed(Routes.home);
  }

  void _clearPin() {
    for (int i = 0; i < 4; i++) {
      controllers[i].clear();
      pinDigits[i] = '';
    }
    focusNodes[0].requestFocus();
  }

  // --- UI Layouts ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return _buildDesktopLayout(context);
          } else {
            return _buildMobileLayout(context);
          }
        },
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        // Left side - Branding
        Expanded(
          flex: 3,
          child: Container(
            color: Theme.of(context).primaryColor,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.pets, size: 100, color: Colors.white),
                const SizedBox(height: 20),
                const Text(
                  'PETCLINIC',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Hệ thống quản lý phòng khám thú y',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),

        // Right side - Form
        Expanded(
          flex: 2,
          child: Container(
            color: Colors.grey[50],
            padding: const EdgeInsets.all(40),
            child: Center(child: _buildPinFormContent(context)),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Theme.of(context).primaryColor),
      child: Stack(
        children: [
          // Top Branding
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 250,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.pets, size: 60, color: Colors.white),
                const SizedBox(height: 16),
                const Text(
                  'PETCLINIC',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Quản lý phòng khám chuyên nghiệp',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),

          // Bottom Sheet Form
          Positioned(
            top: 220,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: SingleChildScrollView(
                child: _buildPinFormContent(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinFormContent(BuildContext context) {
    return Obx(() {
      if (isLoading.value) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Đang tải...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        );
      }

      return Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Đăng nhập Hệ thống',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AuthService.to.currentClinic.value?.name ?? 'Phòng khám',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            const Text(
              'Nhập mã PIN để tiếp tục',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),

            // PIN Input
            _buildPinInput(),
            const SizedBox(height: 24),

            // Error or identified staff
            Obx(() {
              if (identifiedStaff.value != null) {
                final staff = identifiedStaff.value!;
                final role = AppRole.fromString(staff['role']);
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Xin chào, ${staff['full_name']}!',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getRoleColor(role).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          role.displayName,
                          style: TextStyle(
                            color: _getRoleColor(role),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (errorMsg.value.isNotEmpty) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorMsg.value,
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return const SizedBox.shrink();
            }),

            const SizedBox(height: 32),

            // Staff count hint
            Obx(
              () => Text(
                '${allStaff.length} nhân viên đang hoạt động',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textLight,
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Logout
            TextButton.icon(
              onPressed: () {
                AuthService.to.signOut();
                Get.offAllNamed(Routes.login);
              },
              icon: Icon(Icons.logout, size: 18, color: Colors.grey[600]),
              label: Text(
                'Quay lại màn hình chính',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildPinInput() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        return Flexible(
          child: Container(
            width: 56, // Base width constraint
            height: 64,
            margin: const EdgeInsets.symmetric(
              horizontal: 6,
            ), // Margin applied proportionally
            child: TextField(
              controller: controllers[i],
              focusNode: focusNodes[i],
              textAlign: TextAlign.center,
              maxLength: 1,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                contentPadding: EdgeInsets.zero,
                counterText: '',
                filled: true,
                fillColor: Colors.grey[50],
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
              ),
              onChanged: (v) => _onPinDigitChanged(i, v),
            ),
          ),
        );
      }),
    );
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
}
