import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/widgets/pro_widgets.dart';
import '../../../core/widgets/main_layout.dart';
import '../../../routes/app_routes.dart';
import '../controllers/pet_controller.dart';

class PetListView extends GetView<PetController> {
  const PetListView({super.key});

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Quản Lý Thú Cưng',
      actions: [
        ElevatedButton.icon(
          onPressed: () => _showPetForm(context),
          icon: const Icon(Icons.add_circle, size: 20),
          label: const Text('Thêm Mới'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 4,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
      child: Column(
        children: [
          _buildSearchAndFilters(context),
          const SizedBox(height: 24),
          _buildStats(),
          const SizedBox(height: 24),
          Expanded(child: _buildPetList()),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          if (isMobile) {
            return Column(
              children: [
                TextField(
                  onChanged: controller.setSearchQuery,
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm theo tên, loài, giống...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Obx(
                        () => DropdownButtonFormField<String>(
                          value: controller.selectedSpecies.value.isEmpty
                              ? null
                              : controller.selectedSpecies.value,
                          decoration: InputDecoration(
                            labelText: 'Loài',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('Tất cả'),
                            ),
                            ...controller.speciesList.map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            ),
                          ],
                          onChanged: (value) =>
                              controller.setSpeciesFilter(value ?? ''),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: controller.clearFilters,
                        icon: const Icon(
                          Icons.filter_list_off,
                          color: Colors.grey,
                        ),
                        tooltip: 'Xóa bộ lọc',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: controller.loadPets,
                        icon: const Icon(
                          Icons.refresh,
                          color: AppColors.primary,
                        ),
                        tooltip: 'Tải lại',
                      ),
                    ),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  onChanged: controller.setSearchQuery,
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm theo tên, loài, giống...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Obx(
                  () => DropdownButtonFormField<String>(
                    value: controller.selectedSpecies.value.isEmpty
                        ? null
                        : controller.selectedSpecies.value,
                    decoration: InputDecoration(
                      labelText: 'Loài',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Tất cả')),
                      ...controller.speciesList.map(
                        (s) => DropdownMenuItem(value: s, child: Text(s)),
                      ),
                    ],
                    onChanged: (value) =>
                        controller.setSpeciesFilter(value ?? ''),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: controller.clearFilters,
                  icon: const Icon(Icons.filter_list_off, color: Colors.grey),
                  tooltip: 'Xóa bộ lọc',
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: controller.loadPets,
                  icon: const Icon(Icons.refresh, color: AppColors.primary),
                  tooltip: 'Tải lại',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStats() {
    return Obx(() {
      final stats = controller.speciesStats;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildStatCard(
              'Tổng Thú Cưng',
              controller.totalPets.toString(),
              Icons.pets,
              AppColors.primary,
            ),
            const SizedBox(width: 16),
            ...stats.entries
                .take(4)
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _buildStatCard(
                      e.key,
                      e.value.toString(),
                      _getSpeciesIcon(e.key),
                      _getSpeciesColor(e.key),
                    ),
                  ),
                ),
          ],
        ),
      );
    });
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade900,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getSpeciesIcon(String species) {
    switch (species.toLowerCase()) {
      case 'cho':
        return Icons.pets;
      case 'meo':
        return Icons.catching_pokemon; // Or cat icon if available in material
      case 'tho':
        return Icons.cruelty_free;
      case 'hamster':
        return Icons.pest_control_rodent;
      case 'chim':
        return Icons.flutter_dash;
      default:
        return Icons.pets_outlined;
    }
  }

  Color _getSpeciesColor(String species) {
    switch (species.toLowerCase()) {
      case 'cho':
        return Colors.brown;
      case 'meo':
        return Colors.orange;
      case 'tho':
        return Colors.pink;
      case 'hamster':
        return Colors.amber;
      case 'chim':
        return Colors.blue;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _buildPetList() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      final pets = controller.filteredPets;
      if (pets.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.pets_outlined, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 24),
              Text(
                controller.searchQuery.value.isNotEmpty
                    ? 'Không tìm thấy thú cưng nào'
                    : 'Chưa có dữ liệu thú cưng',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _showPetForm(Get.context!),
                icon: const Icon(Icons.add),
                label: const Text('Thêm Thú Cưng Mới'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = constraints.maxWidth > 1200
                    ? 3
                    : (constraints.maxWidth > 800 ? 2 : 1);

                if (crossAxisCount == 1) {
                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: pets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) => _buildPetCard(pets[index]),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 1.8,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    mainAxisExtent: 220,
                  ),
                  itemCount: pets.length,
                  itemBuilder: (context, index) => _buildPetCard(pets[index]),
                );
              },
            ),
          ),
          _buildPagination(),
        ],
      );
    });
  }

  Widget _buildPagination() {
    return Obx(() {
      if (controller.totalPages.value <= 1) return const SizedBox.shrink();

      final int currentPage = controller.currentPage.value;
      final int totalPages = controller.totalPages.value;

      List<Widget> pageButtons = [];

      for (int i = 1; i <= totalPages; i++) {
        // Show max 5 pages around the current page
        if (i == 1 ||
            i == totalPages ||
            (i >= currentPage - 2 && i <= currentPage + 2)) {
          pageButtons.add(
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Material(
                color: currentPage == i
                    ? AppColors.primary
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => controller.goToPage(i),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    child: Text(
                      i.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: currentPage == i ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        } else if (i == currentPage - 3 || i == currentPage + 3) {
          pageButtons.add(
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '...',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          );
        }
      }

      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: currentPage > 1
                    ? () => controller.goToPage(currentPage - 1)
                    : null,
              ),
              ...pageButtons,
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: currentPage < totalPages
                    ? () => controller.goToPage(currentPage + 1)
                    : null,
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildPetCard(pet) {
    final speciesColor = _getSpeciesColor(pet.species);
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
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _showPetDetail(pet),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: speciesColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getSpeciesIcon(pet.species),
                        color: speciesColor,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pet.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${pet.species} • ${pet.breed ?? 'N/A'}',
                            style: TextStyle(
                              color: Colors.grey.shade900,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildPetMenu(pet),
                  ],
                ),
                const Spacer(),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoBadge(
                      Icons.person_outline,
                      controller.getCustomerName(pet.customerId),
                    ),
                    Row(
                      children: [
                        if (pet.gender != null)
                          Icon(
                            pet.gender == 'Duc' ? Icons.male : Icons.female,
                            size: 18,
                            color: pet.gender == 'Duc'
                                ? Colors.blue
                                : Colors.pink,
                          ),
                        if (pet.gender != null) const SizedBox(width: 8),
                        Text(
                          pet.displayAge,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade900,
                          ),
                        ),
                      ],
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

  Widget _buildInfoBadge(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade900),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 100),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade900,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildPetMenu(pet) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.grey),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            _showPetForm(Get.context!, pet: pet);
            break;
          case 'delete':
            _confirmDelete(pet);
            break;
          case 'case':
            Get.toNamed(Routes.caseCreate, arguments: {'pet': pet});
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'case',
          child: Row(
            children: [
              Icon(
                Icons.medical_services_outlined,
                size: 20,
                color: AppColors.primary,
              ),
              SizedBox(width: 12),
              Text(
                'Tạo Ca Bệnh',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
              SizedBox(width: 12),
              Text('Chỉnh Sửa', style: TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 20, color: AppColors.error),
              SizedBox(width: 12),
              Text(
                'Xóa',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showPetDetail(pet) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: ResponsiveHelper.dialogWidth(Get.context!, 500),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _getSpeciesColor(pet.species).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getSpeciesIcon(pet.species),
                      color: _getSpeciesColor(pet.species),
                      size: 40,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pet.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${pet.species}${pet.breed != null ? ' - ${pet.breed}' : ''}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 24),
              _buildDetailRow(
                'Chủ sở hữu',
                controller.getCustomerName(pet.customerId),
              ),
              _buildDetailRow(
                'Số điện thoại',
                controller.getCustomerPhone(pet.customerId),
              ),
              _buildDetailRow(
                'Giới tính',
                pet.gender == 'Duc'
                    ? 'Đực'
                    : (pet.gender == 'Cai' ? 'Cái' : (pet.gender ?? 'Chưa rõ')),
              ),
              _buildDetailRow('Tuổi', pet.displayAge),
              _buildDetailRow(
                'Cân nặng',
                pet.weight != null ? '${pet.weight} kg' : 'Chưa rõ',
              ),
              if (pet.notes != null && pet.notes!.isNotEmpty)
                _buildDetailRow('Ghi chú', pet.notes!),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Get.back();
                      _showPetForm(Get.context!, pet: pet);
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Chỉnh Sửa'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Get.back();
                      Get.toNamed(Routes.caseCreate, arguments: {'pet': pet});
                    },
                    icon: const Icon(Icons.medical_services_outlined, size: 18),
                    label: const Text('Tạo Ca Bệnh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(pet) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc muốn xóa thú cưng ${pet.name}?\nHành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.deletePet(pet);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa Vĩnh Viễn'),
          ),
        ],
      ),
    );
  }

  void _showPetForm(BuildContext context, {pet}) {
    if (pet != null) {
      controller.setupFormForEdit(pet);
    } else {
      controller.resetForm();
    }

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: ResponsiveHelper.dialogWidth(context, 550),
          padding: const EdgeInsets.all(32),
          child: Form(
            key: controller.formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          pet != null ? Icons.edit : Icons.add,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        pet != null ? 'Sửa Thú Cưng' : 'Thêm Thú Cưng Mới',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Get.back(),
                        icon: const Icon(Icons.close),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey.shade100,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Customer dropdown
                  ProTextField(
                    label: 'Chủ sở hữu',
                    hint:
                        'Chọn khách hàng', // Actually we should use a Dropdown or Autocomplete here.
                    // ProTextField is for text. Let's stick with Dropdown for now but styled.
                    readOnly:
                        true, // Just to satisfy the widget if needed, but below is dropdown
                  ),
                  // Replacing ProTextField dummy with real Dropdown
                  const SizedBox(height: 8),
                  Obx(
                    () => DropdownButtonFormField<String>(
                      value: controller.selectedCustomerId.value.isEmpty
                          ? null
                          : controller.selectedCustomerId.value,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      items: controller.customers
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text('${c.name} - ${c.phone}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          controller.selectedCustomerId.value = value ?? '',
                      validator: (value) => value == null || value.isEmpty
                          ? 'Vui lòng chọn chủ sở hữu'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Name
                  ProTextField(
                    label: 'Tên thú cưng',
                    controller: controller.nameController,
                    hint: 'Nhập tên...',
                    prefixIcon: Icons.pets,
                    validator: (value) => value == null || value.isEmpty
                        ? 'Vui lòng nhập tên'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Species and Breed row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Loài',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Obx(
                              () => DropdownButtonFormField<String>(
                                value: controller.formSpecies.value.isEmpty
                                    ? null
                                    : controller.formSpecies.value,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.category_outlined,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                                items: controller.speciesList
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(s),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) =>
                                    controller.formSpecies.value = value ?? '',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ProTextField(
                          label: 'Giống',
                          controller: controller.breedController,
                          hint: 'VD: Poodle...',
                          prefixIcon: Icons.pets_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Gender, Age, Weight row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Giới tính',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Obx(
                              () => DropdownButtonFormField<String>(
                                value: controller.selectedGender.value.isEmpty
                                    ? null
                                    : controller.selectedGender.value,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: const Icon(Icons.wc),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                                items: controller.genderList.map((
                                  String value,
                                ) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(
                                      value == 'Duc'
                                          ? 'Đực'
                                          : (value == 'Cai' ? 'Cái' : value),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) =>
                                    controller.selectedGender.value =
                                        value ?? '',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: ProTextField(
                                label: 'Tuổi',
                                controller: controller.ageController,
                                hint: '0',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Đơn vị',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Obx(
                                    () => DropdownButtonFormField<String>(
                                      value: controller.ageUnit.value,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 14,
                                            ),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'Tháng',
                                          child: Text('Tháng'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Năm',
                                          child: Text('Năm'),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val != null)
                                          controller.ageUnit.value = val;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ProTextField(
                          label: 'Cân nặng',
                          controller: controller.weightController,
                          hint: '0.0',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          suffixText: 'kg',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  ProTextField(
                    label: 'Ghi chú',
                    controller: controller.notesController,
                    hint: 'Ghi chú thêm về sức khỏe...',
                    maxLines: 3,
                    prefixIcon: Icons.note_alt_outlined,
                  ),
                  const SizedBox(height: 32),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Get.back(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                        child: const Text('Hủy Bỏ'),
                      ),
                      const SizedBox(width: 16),
                      Obx(
                        () => ElevatedButton.icon(
                          onPressed: controller.isLoading.value
                              ? null
                              : () async {
                                  if (await controller.savePet()) {
                                    Get.back();
                                  }
                                },
                          icon: controller.isLoading.value
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle),
                          label: Text(
                            pet != null ? 'Cập Nhật' : 'Lưu Thú Cưng',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
