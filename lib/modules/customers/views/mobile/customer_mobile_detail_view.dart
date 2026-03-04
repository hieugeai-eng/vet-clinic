import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../routes/app_routes.dart';
import '../../controllers/customer_controller.dart';
import '../../../../data/models/customer_model.dart';
import '../../../../data/models/pet_model.dart';
import '../../../../data/models/medical_case_model.dart';
import '../../widgets/customer_form_dialog.dart';
import '../../widgets/pet_form_dialog.dart';
import '../../widgets/pet_form_dialog.dart';

class CustomerMobileDetailView extends GetView<CustomerController> {
  final CustomerModel customer;

  const CustomerMobileDetailView({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Scrollable content
        Expanded(
          child: Container(
            color: const Color(0xFFF1F5F9), // Light background
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Info Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEC4899), Color(0xFFF472B6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(customer.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          'KH-${customer.id.substring(0, 6).toUpperCase()} • ${Formatters.formatPhone(customer.phone)}', 
                          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))
                        ),
                        const SizedBox(height: 8),
                         Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Column(
                                  children: [
                                    Text('${controller.customerStatsMap[customer.id]?['caseCount'] ?? 0}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
                                    const Text('Ca khám', style: TextStyle(fontSize: 8, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Column(
                                  children: [
                                    Text('0', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF16A34A))), // Mock Revenue
                                    Text('Chi tiêu', style: TextStyle(fontSize: 8, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 2. Pets Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: Text('THÚ CƯNG', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B), letterSpacing: 0.5)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, size: 20, color: Color(0xFF2563EB)),
                        onPressed: () => showPetFormDialog(context, customer),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  Obx(() {
                    if (controller.customerPets.isEmpty) {
                      return _buildEmptyPets();
                    }
                    
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 6,
                        childAspectRatio: 3, 
                      ),
                      itemCount: controller.customerPets.length,
                      itemBuilder: (context, index) {
                         return _buildPetCardMobile(controller.customerPets[index]);
                      },
                    );
                  }),
                  
                  const SizedBox(height: 10),

                  // 3. History Section
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text('LỊCH SỬ KHÁM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B), letterSpacing: 0.5)),
                  ),
                  Container(
                     decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                     child: Obx(() {
                        if (controller.isHistoryLoading.value) {
                            return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                        }
                        if (controller.petHistory.isEmpty) {
                            return const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Chưa có lịch sử', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))));
                        }
                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          itemCount: controller.petHistory.length,
                          separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            return _buildHistoryRowMobile(controller.petHistory[index]);
                          },
                        );
                      }),
                  )

                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildEmptyPets() {
     return Container(
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white
        ),
        child: const Text('Không có thú cưng nào', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
     );
  }

  Widget _buildPetCardMobile(PetModel pet) {
    bool isCat = pet.species.toLowerCase() == 'mèo' || pet.species.toLowerCase() == 'meo';
    bool isDog = pet.species.toLowerCase() == 'chó' || pet.species.toLowerCase() == 'cho';
    Color iconColor = isCat ? const Color(0xFFEAB308) : (isDog ? const Color(0xFF2563EB) : AppColors.primary);
    Color bgColor = isCat ? const Color(0xFFFEF3C7) : (isDog ? const Color(0xFFDBEAFE) : AppColors.primaryLight);
    String iconStr = isCat ? '🐈' : (isDog ? '🐕' : '🐾');

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(iconStr, style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(pet.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${pet.species} ${pet.gender != null ? (pet.gender!.toLowerCase() == 'cái' ? '♀' : '♂') : ""}', style: const TextStyle(fontSize: 8, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHistoryRowMobile(Map<String, dynamic> history) {
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
          MedicalCaseModel? caseModel;
          try {
            caseModel = MedicalCaseModel.fromJson(history);
            Get.toNamed(Routes.caseCreate, arguments: caseModel);
          } catch (e) {
            debugPrint('Error parsing case model: $e');
          }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
              child: Icon(icon, size: 14, color: iconColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$petName — ${history['diagnosis'] ?? history['reason'] ?? 'Không rõ'}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${DateFormat('dd/MM').format(DateTime.parse(history['admission_date']))} • ${Formatters.formatCurrency((history['total_estimate'] as num).toDouble())}', style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
