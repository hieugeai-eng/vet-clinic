import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../controllers/device_management_controller.dart';

class DeviceManagementView extends StatelessWidget {
  const DeviceManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DeviceManagementController());

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quản Lý Thiết Bị'),
          bottom: const TabBar(
            tabs: [
              Tab(
                text: 'Chờ Phê Duyệt',
                icon: Icon(Icons.verified_user_outlined),
              ),
              Tab(text: 'Đã Kết Nối', icon: Icon(Icons.devices)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPendingList(controller),
            _buildApprovedList(controller),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingList(DeviceManagementController controller) {
    return Obx(() {
      if (controller.isLoading.value)
        return const Center(child: CircularProgressIndicator());
      if (controller.pendingDevices.isEmpty)
        return const Center(child: Text('Không có thiết bị chờ duyệt'));

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: controller.pendingDevices.length,
        itemBuilder: (context, index) {
          final device = controller.pendingDevices[index];
          return Card(
            color: Colors.orange.shade50,
            child: ListTile(
              leading: const Icon(Icons.phonelink_lock, color: Colors.orange),
              title: Text(
                device['device_name'] ?? 'Unknown Device',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'IP: ${device['last_ip'] ?? 'N/A'}\nActive: ${_formatDate(device['last_active_at'])}',
              ),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => controller.approveDevice(device['id']),
                    tooltip: 'Phê duyệt',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => controller.removeDevice(device['id']),
                    tooltip: 'Từ chối',
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildApprovedList(DeviceManagementController controller) {
    return Obx(() {
      if (controller.isLoading.value)
        return const Center(child: CircularProgressIndicator());
      if (controller.approvedDevices.isEmpty)
        return const Center(child: Text('Chưa có thiết bị nào'));

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: controller.approvedDevices.length,
        itemBuilder: (context, index) {
          final device = controller.approvedDevices[index];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: Text(device['device_name'] ?? 'Unknown Device'),
              subtitle: Text('Approved: ${_formatDate(device['created_at'])}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => controller.removeDevice(device['id']),
              ),
            ),
          );
        },
      );
    });
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return 'N/A';
    try {
      final date = DateTime.parse(isoString).toLocal();
      return DateFormat('dd/MM HH:mm').format(date);
    } catch (_) {
      return isoString;
    }
  }
}
