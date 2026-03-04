import 'package:get/get.dart';

import '../../data/providers/local/database_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/excel_service.dart';
import '../../services/pdf_service.dart';
import '../../services/global_settings_service.dart';
import '../services/zalo_service.dart';
import '../services/zalo_api_service.dart';
import '../services/supabase_service.dart';
import '../services/supabase_rest_client.dart';
import '../services/realtime_service.dart';
import '../services/auth_service.dart';
import '../services/tenant_manager.dart';
import '../services/data_migration_service.dart';
import '../services/supabase_storage_service.dart';
import '../services/attachment_service.dart';
import '../services/update_service.dart';
import '../sync/sync_engine.dart';
import '../services/permission_service.dart';
import '../../services/return_service.dart';
import '../../data/repositories/case_attachment_repository.dart';

/// Initial bindings - loaded at app start
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // Database
    Get.putAsync<DatabaseProvider>(() async {
      final db = DatabaseProvider.instance;
      await db.database; // Initialize database
      return db;
    }, permanent: true);

    // Services
    if (!Get.isRegistered<GlobalSettingsService>()) {
      Get.put<GlobalSettingsService>(GlobalSettingsService(), permanent: true);
    }
    Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
    Get.put<PermissionService>(PermissionService(), permanent: true);
    Get.put<ExcelService>(ExcelService(), permanent: true);
    Get.put<PdfService>(PdfService(), permanent: true);
    Get.put<ReturnService>(ReturnService(), permanent: true);
    Get.put<ZaloService>(ZaloService(), permanent: true);
    Get.put<ZaloApiService>(ZaloApiService(), permanent: true);

    // Cloud Sync Services (Hybrid REST + WebSocket)
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
    if (!Get.isRegistered<SupabaseRestClient>()) {
      Get.put<SupabaseRestClient>(SupabaseRestClient(), permanent: true);
    }
    Get.put<RealtimeService>(RealtimeService(), permanent: true);
    Get.lazyPut<SupabaseService>(() => SupabaseService(), fenix: true);

    // Tenant Manager
    if (!Get.isRegistered<TenantManager>()) {
      Get.put<TenantManager>(TenantManager(), permanent: true);
    }

    // Sync Engine (single unified sync system)
    if (!Get.isRegistered<SyncEngine>()) {
      Get.lazyPut<SyncEngine>(() => SyncEngine(), fenix: true);
    }

    // Data Migration Service (for one-time migration)
    if (!Get.isRegistered<DataMigrationService>()) {
      Get.lazyPut<DataMigrationService>(
        () => DataMigrationService(),
        fenix: true,
      );
    }

    // Storage & Attachment Services
    if (!Get.isRegistered<SupabaseStorageService>()) {
      Get.put<SupabaseStorageService>(
        SupabaseStorageService(),
        permanent: true,
      );
    }
    if (!Get.isRegistered<CaseAttachmentRepository>()) {
      Get.put<CaseAttachmentRepository>(
        CaseAttachmentRepository(),
        permanent: true,
      );
    }
    if (!Get.isRegistered<AttachmentService>()) {
      Get.put<AttachmentService>(AttachmentService(), permanent: true);
    }

    // Auto-Update Service (Windows only)
    if (!Get.isRegistered<UpdateService>()) {
      Get.put<UpdateService>(UpdateService(), permanent: true);
    }
  }
}
