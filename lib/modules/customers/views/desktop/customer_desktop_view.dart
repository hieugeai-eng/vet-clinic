import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../routes/app_routes.dart';
import '../../../../core/services/zalo_service.dart';
import '../../controllers/customer_controller.dart';
import '../../../../data/models/customer_model.dart';
import '../../../../data/models/pet_model.dart';
import '../../widgets/customer_form_dialog.dart';

class CustomerDesktopView extends GetView<CustomerController> {
  const CustomerDesktopView({super.key});

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
                const Icon(Icons.people, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Khách Hàng & Thú Cưng',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                // Search Input inside header
                Container(
                  height: 32,
                  width: 240,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: TextField(
                    onChanged: controller.setSearchQuery,
                    decoration: const InputDecoration(
                      hintText: 'Tìm KH / thú cưng...',
                      hintStyle: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      prefixIcon: Icon(Icons.search, size: 16, color: AppColors.textSecondary),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _showCustomerForm(context),
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('Thêm KH', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    minimumSize: const Size(0, 32),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
          ),
          
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 2)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text('Khách hàng', style: _headerStyle)),
                Expanded(flex: 2, child: Text('Liên hệ', style: _headerStyle)),
                Expanded(flex: 3, child: Text('Thú cưng', style: _headerStyle)),
                Expanded(flex: 1, child: Text('Số ca khám', style: _headerStyle)),
                Expanded(flex: 2, child: Text('Lần khám gần nhất', style: _headerStyle)),
                SizedBox(width: 32), // actions
              ],
            ),
          ),
          
          // Table Body
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              final customers = controller.filteredCustomers;
              if (customers.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: customers.length,
                separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1, color: AppColors.border),
                itemBuilder: (context, index) {
                  final customer = customers[index];
                  final pets = controller.customerPetsMap[customer.id];
                  final stats = controller.customerStatsMap[customer.id];
                  return _buildCustomerRow(customer, pets, stats);
                },
              );
            }),
          ),
          
          // Pagination
          Obx(() {
            if (controller.totalPages.value <= 1) return const SizedBox.shrink();
            return _buildPaginationBar();
          }),
        ],
      ),
    );
  }

  Widget _buildCustomerRow(CustomerModel customer, List<PetModel>? pets, Map<String, dynamic>? stats) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Get.toNamed(Routes.customerDetail, arguments: customer),
        hoverColor: const Color(0xFFF8FAFC),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Khách hàng
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'KH-${customer.id.substring(0, 8).toUpperCase()}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              // Liên hệ
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Formatters.formatPhone(customer.phone),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customer.address ?? '—',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Thú cưng
              Expanded(
                flex: 3,
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: pets == null || pets.isEmpty
                      ? <Widget>[const Text('—', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))]
                      : pets.map<Widget>((pet) {
                          Color badgeColor = const Color(0xFFDBEAFE);
                          Color textColor = const Color(0xFF2563EB);
                          if (pet.gender?.toLowerCase() == 'cái') {
                            badgeColor = const Color(0xFFFCE7F3);
                            textColor = const Color(0xFFDB2777);
                          }
                          String speciesPrefix = pet.species.toLowerCase() == 'mèo' ? '🐈 ' : (pet.species.toLowerCase() == 'chó' ? '🐕 ' : '');

                          return _buildPetBadge('$speciesPrefix${pet.name}${pet.breed != null && pet.breed!.isNotEmpty ? " (${pet.breed})" : ""}', badgeColor, textColor);
                        }).toList(),
                ),
              ),
              // Số ca khám
              Expanded(
                flex: 1,
                child: Text(
                  stats != null ? '${stats['caseCount'] ?? 0}' : '0',
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                ),
              ),
              // Lần khám gần nhất
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                       stats != null && stats['lastVisit'] != null 
                        ? Formatters.formatDate(stats['lastVisit'] as DateTime) 
                        : '—',
                       style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                       stats != null && stats['lastVisit'] != null 
                        ? Formatters.formatTime(stats['lastVisit'] as DateTime)
                        : '—',
                       style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              // Actions
              const SizedBox(
                width: 32,
                child: Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPetBadge(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildPaginationBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Trang ${controller.currentPage.value} / ${controller.totalPages.value}',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 18),
                onPressed: controller.currentPage.value > 1
                    ? () => controller.goToPage(controller.currentPage.value - 1)
                    : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                splashRadius: 16,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 18),
                onPressed: controller.currentPage.value < controller.totalPages.value
                    ? () => controller.goToPage(controller.currentPage.value + 1)
                    : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                splashRadius: 16,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Chưa có khách hàng nào', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ],
      ),
    );
  }

  static const _headerStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  void _showCustomerForm(BuildContext context) {
    showCustomerFormDialog(context);
  }
}

