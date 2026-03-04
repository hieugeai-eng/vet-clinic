# Hướng Dẫn Apply Migration Lên Supabase

## Bước 1: Truy cập Supabase Dashboard

1. Mở browser và vào: https://supabase.com/dashboard
2. Đăng nhập vào tài khoản
3. Chọn project: **iasmrzpojtvxfsvskexc**

## Bước 2: Mở SQL Editor

1. Ở sidebar bên trái, click **SQL Editor**
2. Click **New query**

## Bước 3: Copy và Chạy Migration

1. Mở file: `supabase/migrations/001_tenant_schema_setup.sql`
2. Copy toàn bộ nội dung
3. Paste vào SQL Editor
4. Click **Run** (hoặc Ctrl+Enter)

## Bước 4: Verify

Sau khi chạy xong, kiểm tra:

### Tables được tạo:
```sql
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;
```

Expected: `clinics`, `profiles`, `subscription_plans`

### Functions được tạo:
```sql
SELECT proname FROM pg_proc 
WHERE pronamespace = 'public'::regnamespace;
```

Expected: `create_tenant_schema`, `create_tenant_tables`, `create_version_triggers`, `handle_new_user`

## Bước 5: Tạo Tenant Schema Đầu Tiên

Sau khi đã có clinic trong bảng `clinics`, chạy:

```sql
-- Thay 'YOUR_CLINIC_ID' bằng ID thực
SELECT public.create_tenant_schema('YOUR_CLINIC_ID'::uuid);
```

Hoặc nếu chưa có clinic, tạo mới:

```sql
-- Tạo clinic mới
INSERT INTO public.clinics (name, owner_id)
VALUES ('OKADA Vet Clinic', NULL)
RETURNING id, schema_name;

-- Sau đó tạo schema với ID vừa nhận được
SELECT public.create_tenant_schema('ID_VỪA_NHẬN_ĐƯỢC'::uuid);
```

## Bước 6: Verify Tenant Schema

```sql
-- Xem các schemas đã tạo
SELECT schema_name FROM information_schema.schemata
WHERE schema_name LIKE 'tenant_%';

-- Xem tables trong tenant schema
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'tenant_XXXXX'; -- thay tên schema
```

---

## Troubleshooting

### Lỗi "function already exists"
Chạy trước:
```sql
DROP FUNCTION IF EXISTS public.create_tenant_schema(uuid);
DROP FUNCTION IF EXISTS public.create_tenant_tables(text);
DROP FUNCTION IF EXISTS public.create_version_triggers(text);
```

### Lỗi "permission denied"
Đảm bảo đang dùng user có quyền superuser hoặc owner của database.

### Xóa và tạo lại schema
```sql
DROP SCHEMA IF EXISTS tenant_XXXXX CASCADE;
SELECT public.create_tenant_schema('clinic_id_here'::uuid);
```
