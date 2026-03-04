import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../routes/app_routes.dart';
import '../../../../core/services/zalo_service.dart';
import '../../controllers/customer_controller.dart';
import '../../../../data/models/customer_model.dart';
import '../../../../data/models/pet_model.dart';
import '../../../../data/models/medical_case_model.dart';
import '../../widgets/customer_form_dialog.dart';
import '../../widgets/pet_form_dialog.dart';

class CustomerDesktopDetailView extends GetView<CustomerController> {
  final CustomerModel customer;

  const CustomerDesktopDetailView({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20, color: AppColors.textSecondary),
                  onPressed: () => Get.back(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  customer.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Khách quen', style: TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => showCustomerFormDialog(context, customer: customer), // TODO: Show edit form
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('Sửa', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: const Color(0xFF475569),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    minimumSize: const Size(0, 28),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Customer Info
                Container(
                  width: 280,
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: AppColors.border)),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFFEC4899), Color(0xFFF472B6)],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(customer.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('KH-${customer.id.substring(0, 6).toUpperCase()} • Từ ${DateFormat('MM/yyyy').format(customer.createdAt)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text('LIÊN HỆ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.5)),
                        const SizedBox(height: 8),
                        _buildContactRow(Icons.phone, Formatters.formatPhone(customer.phone)),
                        const SizedBox(height: 8),
                        _buildContactRow(Icons.location_on, customer.address ?? 'Chưa cập nhật'),
                        const SizedBox(height: 24),
                        const Text('THỐNG KÊ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.5)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Text('${controller.customerStatsMap[customer.id]?['caseCount'] ?? 0}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
                                    const Text('Ca khám', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Column(
                                  children: [
                                    Text('0', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF16A34A))), // Mock Revenue
                                    Text('Chi tiêu', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Right Column: Pets + History
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Pets Section
                        Row(
                          children: [
                            const Icon(Icons.pets, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Obx(() => Text('Thú Cưng (${controller.customerPets.length})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                            const Spacer(),
                            ElevatedButton.icon(
                              onPressed: () => showPetFormDialog(context, customer), // TODO: Show add pet form
                              icon: const Icon(Icons.add, size: 14),
                              label: const Text('Thêm', style: TextStyle(fontSize: 11)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                minimumSize: const Size(0, 24),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Obx(() {
                          if (controller.customerPets.isEmpty) {
                            return _buildEmptyPets();
                          }
                          return SizedBox(
                            height: 80,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: controller.customerPets.length,
                              separatorBuilder: (context, index) => const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                return SizedBox(
                                  width: 200,
                                  child: _buildPetCardDesktop(controller.customerPets[index]),
                                );
                              },
                            ),
                          );
                        }),
                        
                        const SizedBox(height: 24),
                        // History Section
                        const Row(
                          children: [
                            Icon(Icons.history, size: 16, color: Color(0xFF2563EB)),
                            SizedBox(width: 6),
                            Text('Lịch sử khám', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Obx(() {
                              if (controller.isHistoryLoading.value) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (controller.petHistory.isEmpty) {
                                return const Center(child: Text('Chưa có lịch sử', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)));
                              }
                              return ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: controller.petHistory.length,
                                separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1, color: AppColors.border),
                                itemBuilder: (context, index) {
                                  return _buildHistoryRow(controller.petHistory[index]);
                                },
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary))),
      ],
    );
  }

  Widget _buildPetCardDesktop(PetModel pet) {
    bool isCat = pet.species.toLowerCase() == 'mèo' || pet.species.toLowerCase() == 'meo';
    bool isDog = pet.species.toLowerCase() == 'chó' || pet.species.toLowerCase() == 'cho';
    Color iconColor = isCat ? const Color(0xFFEAB308) : (isDog ? const Color(0xFF2563EB) : AppColors.primary);
    Color bgColor = isCat ? const Color(0xFFFEF3C7) : (isDog ? const Color(0xFFDBEAFE) : AppColors.primaryLight);
    String iconStr = isCat ? '🐈' : (isDog ? '🐕' : '🐾');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(iconStr, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pet.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${pet.species} • ${pet.gender ?? "?"} • ${pet.displayAge}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${pet.weight ?? "?"}kg', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          )
        ],
      ),
    );
  }
  
  Widget _buildEmptyPets() {
     return Container(
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFFF8FAFC)
        ),
        child: const Text('Không có thú cưng nào', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
     );
  }

  Widget _buildHistoryRow(Map<String, dynamic> history) {
    bool isTreatment = (history['diagnosis'] != null && history['diagnosis'].toString().isNotEmpty) || (history['reason'] != null && history['reason'].toString().toLowerCase().contains('khám'));
    bool isVaccine = history['reason'] != null && history['reason'].toString().toLowerCase().contains('vaccine');

    Color iconColor = isVaccine ? const Color(0xFF16A34A) : (isTreatment ? const Color(0xFF2563EB) : const Color(0xFFD97706));
    Color bgColor = isVaccine ? const Color(0xFFDCFCE7) : (isTreatment ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7));
    IconData icon = isVaccine ? Icons.vaccines : (isTreatment ? Icons.medical_services : Icons.local_hospital);

    // Try finding pet name based on ID
    String petName = "?";
    if (history['pet_id'] != null) {
      final match = controller.customerPets.firstWhereOrNull((p) => p.id == history['pet_id']);
      if (match != null) petName = match.name;
    }

    return InkWell(
      onTap: () {
         // Convert Map to Model for passing arguments
          MedicalCaseModel? caseModel;
          try {
            caseModel = MedicalCaseModel.fromJson(history);
            Get.toNamed(Routes.caseCreate, arguments: caseModel);
          } catch (e) {
            debugPrint('Error parsing case model: $e');
          }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ca #${history['case_code']} — $petName', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  Text(history['diagnosis'] ?? history['reason'] ?? 'Không rõ', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Formatters.formatCurrency((history['total_estimate'] as num).toDouble()), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: iconColor)),
                const SizedBox(height: 2),
                Text(Formatters.formatDate(DateTime.parse(history['admission_date'])), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
