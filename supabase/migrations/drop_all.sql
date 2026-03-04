-- ============================================================
-- DROP ALL TABLES — Chạy trước khi tạo schema mới
-- ⚠️ XÓA TOÀN BỘ DỮ LIỆU — KHÔNG THỂ HOÀN TÁC
-- ============================================================

-- Storage bucket: không cần xóa, 000_complete_setup.sql dùng ON CONFLICT DO NOTHING

-- Xóa tất cả bảng (thứ tự ngược theo FK dependency)
DROP TABLE IF EXISTS public.audit_log CASCADE;
DROP TABLE IF EXISTS public.subscriptions CASCADE;
DROP TABLE IF EXISTS public.subscription_plans CASCADE;
DROP TABLE IF EXISTS public.clinic_devices CASCADE;
DROP TABLE IF EXISTS public.clinic_invites CASCADE;
DROP TABLE IF EXISTS public.clinic_staff CASCADE;
DROP TABLE IF EXISTS public.case_attachments CASCADE;
DROP TABLE IF EXISTS public.vital_sign_logs CASCADE;
DROP TABLE IF EXISTS public.hospitalization_treatments CASCADE;
DROP TABLE IF EXISTS public.hospitalization_dailies CASCADE;
DROP TABLE IF EXISTS public.hospitalization_reservations CASCADE;
DROP TABLE IF EXISTS public.hospitalization_regimens CASCADE;
DROP TABLE IF EXISTS public.hospitalizations CASCADE;
DROP TABLE IF EXISTS public.cages CASCADE;
DROP TABLE IF EXISTS public.product_sales CASCADE;
DROP TABLE IF EXISTS public.medicine_transactions CASCADE;
DROP TABLE IF EXISTS public.case_services CASCADE;
DROP TABLE IF EXISTS public.expenses CASCADE;
DROP TABLE IF EXISTS public.appointments CASCADE;
DROP TABLE IF EXISTS public.medical_cases CASCADE;
DROP TABLE IF EXISTS public.services CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.medicines CASCADE;
DROP TABLE IF EXISTS public.pets CASCADE;
DROP TABLE IF EXISTS public.customers CASCADE;
DROP TABLE IF EXISTS public.staff CASCADE;
DROP TABLE IF EXISTS public.treatment_activities CASCADE;
DROP TABLE IF EXISTS public.treatment_days CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;
DROP TABLE IF EXISTS public.clinics CASCADE;

-- Xóa functions
DROP FUNCTION IF EXISTS public.get_my_clinic_id() CASCADE;
DROP FUNCTION IF EXISTS public.set_clinic_id() CASCADE;
DROP FUNCTION IF EXISTS public.increment_version() CASCADE;
DROP FUNCTION IF EXISTS public.audit_trigger_func() CASCADE;
DROP FUNCTION IF EXISTS public.protect_clinic_approval() CASCADE;

-- Done
SELECT 'All tables dropped successfully' AS status;
