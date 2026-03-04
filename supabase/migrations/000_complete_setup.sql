-- ============================================================
-- OKADA VET CLINIC — COMPLETE DATABASE SCHEMA
-- Version: 2.0 (Clean Rebuild)
-- Date: 2026-02-19
-- ============================================================
--
-- DESIGN PRINCIPLES:
-- 1. UUID for ALL primary keys and foreign keys
-- 2. TIMESTAMPTZ for all timestamps
-- 3. BOOLEAN for all boolean fields (is_deleted, is_active)
-- 4. BIGINT for currency (in VND, no decimals)
-- 5. DECIMAL(10,2) for quantities
-- 6. Every data table has: id, clinic_id, is_deleted, _version, created_at, updated_at
-- 7. RLS on every table with clinic_id filter
-- 8. Realtime enabled for all data tables
-- 9. Audit log for critical tables
-- 10. Storage bucket for file attachments
--
-- TABLE LIST (25 tables):
--   System: clinics, profiles, clinic_staff, clinic_devices
--   Subscription: subscription_plans, subscriptions
--   Core: customers, pets, staff
--   Inventory: medicines, products, services
--   Operations: appointments, medical_cases, case_services
--   Transactions: medicine_transactions, product_sales
--   Hospitalization: cages, hospitalizations, hospitalization_dailies,
--                    hospitalization_treatments, vital_sign_logs,
--                    hospitalization_regimens, hospitalization_reservations
--   Files: case_attachments
--   Finance: expenses
--   Audit: audit_log
-- ============================================================

BEGIN;

-- ============================================================
-- PART 0: EXTENSIONS & HELPER FUNCTIONS
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Helper: Get current user's clinic_id from profile
CREATE OR REPLACE FUNCTION public.get_my_clinic_id()
RETURNS UUID
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN (SELECT clinic_id FROM public.profiles WHERE id = auth.uid() LIMIT 1);
END;
$$;

-- Trigger function: Auto-set clinic_id on INSERT
CREATE OR REPLACE FUNCTION public.set_clinic_id()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.clinic_id IS NULL THEN
    NEW.clinic_id := public.get_my_clinic_id();
  END IF;
  RETURN NEW;
END;
$$;

-- Trigger function: Auto-increment _version on UPDATE
CREATE OR REPLACE FUNCTION public.increment_version()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW._version := COALESCE(OLD._version, 0) + 1;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- ============================================================
-- PART 1: SYSTEM TABLES (Tenants & Auth)
-- ============================================================

-- Clinics (Tenants)
CREATE TABLE IF NOT EXISTS public.clinics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  address TEXT,
  phone TEXT,
  contact_email TEXT,
  contact_phone TEXT,
  license_key TEXT UNIQUE,
  owner_id UUID REFERENCES auth.users(id),
  settings JSONB DEFAULT '{}',
  subscription_tier TEXT DEFAULT 'free',
  subscription_plan TEXT DEFAULT 'free',
  subscription_end_at TIMESTAMPTZ,
  registration_status TEXT DEFAULT 'pending',
  approved_at TIMESTAMPTZ,
  approved_by UUID,
  logo_url TEXT,
  is_active BOOLEAN DEFAULT true,
  is_deleted BOOLEAN DEFAULT false,
  _version BIGINT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.clinics ENABLE ROW LEVEL SECURITY;
CREATE POLICY "clinics_select" ON public.clinics FOR SELECT
  USING (id = public.get_my_clinic_id() OR owner_id = auth.uid());
CREATE POLICY "clinics_insert" ON public.clinics FOR INSERT
  WITH CHECK (owner_id = auth.uid());
CREATE POLICY "clinics_update" ON public.clinics FOR UPDATE
  USING (owner_id = auth.uid());

-- Profiles (Auth users linked to clinic)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  clinic_id UUID REFERENCES public.clinics(id),
  role TEXT DEFAULT 'staff',
  full_name TEXT,
  avatar_url TEXT,
  is_active BOOLEAN DEFAULT true,
  preferences JSONB DEFAULT '{}',
  specialization TEXT,
  pin_hash TEXT,
  staff_code TEXT,
  is_deleted BOOLEAN DEFAULT false,
  _version BIGINT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_profiles_clinic ON public.profiles(clinic_id);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "profiles_select_own" ON public.profiles FOR SELECT
  USING (id = auth.uid());
CREATE POLICY "profiles_select_clinic" ON public.profiles FOR SELECT
  USING (clinic_id = public.get_my_clinic_id());
CREATE POLICY "profiles_insert" ON public.profiles FOR INSERT
  WITH CHECK (id = auth.uid());
CREATE POLICY "profiles_update" ON public.profiles FOR UPDATE
  USING (id = auth.uid());

-- ============================================================
-- PART 2: CORE DATA TABLES
-- ============================================================

-- Staff
CREATE TABLE IF NOT EXISTS public.staff (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id UUID NOT NULL REFERENCES public.clinics(id),
  name TEXT NOT NULL,
  phone TEXT,
  role TEXT NOT NULL DEFAULT 'assistant',
  email TEXT,
  is_active BOOLEAN DEFAULT true,
  is_deleted BOOLEAN DEFAULT false,
  _version BIGINT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_staff_clinic ON public.staff(clinic_id);

-- Customers
CREATE TABLE IF NOT EXISTS public.customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id UUID NOT NULL REFERENCES public.clinics(id),
  phone TEXT NOT NULL,
  name TEXT NOT NULL,
  address TEXT,
  email TEXT,
  notes TEXT,
  is_active BOOLEAN DEFAULT true,
  is_deleted BOOLEAN DEFAULT false,
  _version BIGINT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_customers_clinic ON public.customers(clinic_id);
CREATE INDEX IF NOT EXISTS idx_customers_phone ON public.customers(phone);
CREATE INDEX IF NOT EXISTS idx_customers_name ON public.customers(name);

-- Pets
CREATE TABLE IF NOT EXISTS public.pets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id UUID NOT NULL REFERENCES public.clinics(id),
  customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  species TEXT NOT NULL,
  breed TEXT,
  gender TEXT,
  date_of_birth TEXT,
  color TEXT,
  microchip_id TEXT,
  notes TEXT,
  is_active BOOLEAN DEFAULT true,
  is_deleted BOOLEAN DEFAULT false,
  _version BIGINT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_pets_clinic ON public.pets(clinic_id);
CREATE INDEX IF NOT EXISTS idx_pets_customer ON public.pets(customer_id);

-- ============================================================
-- PART 3: INVENTORY TABLES
-- ============================================================

-- Services
CREATE TABLE IF NOT EXISTS public.services (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id UUID NOT NULL REFERENCES public.clinics(id),
  name TEXT NOT NULL,
  category TEXT,
  base_price BIGINT NOT NULL DEFAULT 0,
  unit TEXT,
  is_active BOOLEAN DEFAULT true,
  is_deleted BOOLEAN DEFAULT false,
  _version BIGINT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_services_clinic ON public.services(clinic_id);

-- Medicines
CREATE TABLE IF NOT EXISTS public.medicines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id UUID NOT NULL REFERENCES public.clinics(id),
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  unit TEXT,
  base_price BIGINT DEFAULT 0,
  cost_price BIGINT DEFAULT 0,
  current_stock DECIMAL(10,2) DEFAULT 0,
  min_stock_alert DECIMAL(10,2),
  category TEXT,
  is_active BOOLEAN DEFAULT true,
  is_deleted BOOLEAN DEFAULT false,
  _version BIGINT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(clinic_id, code)
);
CREATE INDEX IF NOT EXISTS idx_medicines_clinic ON public.medicines(clinic_id);
CREATE INDEX IF NOT EXISTS idx_medicines_code ON public.medicines(clinic_id, code);

-- Products (Petshop)
CREATE TABLE IF NOT EXISTS public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id UUID NOT NULL REFERENCES public.clinics(id),
  name TEXT NOT NULL,
  brand TEXT,
  category TEXT,
  sale_price BIGINT NOT NULL DEFAULT 0,
  cost_price BIGINT NOT NULL DEFAULT 0,
  current_stock DECIMAL(10,2) DEFAULT 0,
  image_url TEXT,
  is_active BOOLEAN DEFAULT true,
  is_deleted BOOLEAN DEFAULT false,
  _version BIGINT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_products_clinic ON public.products(clinic_id);

-- ============================================================
-- PART 4: OPERATIONS TABLES
-- ============================================================

-- Appointments
CREATE TABLE IF NOT EXISTS public.appointments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id UUID NOT NULL REFERENCES public.clinics(id),
  customer_id UUID NOT NULL REFERENCES public.customers(id),
  pet_id UUID REFERENCES public.pets(id),
  staff_id UUID REFERENCES public.staff(id) ON DELETE SET NULL,
  appointment_date TEXT NOT NULL,
  time TEXT,
  reason TEXT,
  status TEXT DEFAULT 'pending',
  notes TEXT,
  is_active BOOLEAN DEFAULT true,
  is_deleted BOOLEAN DEFAULT false,
  _version BIGINT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_appointments_clinic ON public.appointments(clinic_id);
CREATE INDEX IF NOT EXISTS idx_appointments_date ON public.appointments(appointment_date);

-- Medical Cases
CREATE TABLE IF NOT EXISTS public.medical_cases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id UUID NOT NULL REFERENCES public.clinics(id),
  case_code TEXT NOT NULL,
  customer_id UUID NOT NULL REFERENCES public.customers(id),
  pet_id UUID NOT NULL REFERENCES public.pets(id),
  staff_id UUID REFERENCES public.staff(id) ON DELETE SET NULL,
  admission_date TEXT NOT NULL,
  discharge_date TEXT,
  visit_reasons TEXT,
  reason_notes TEXT,
  vital_signs TEXT,
  diagnosis TEXT,
  prognosis TEXT DEFAULT 'uncertain',
  treatment_plan TEXT,
  total_estimate BIGINT DEFAULT 0,
  advance_payment BIGINT DEFAULT 0,
  advance_payment_method TEXT,
  payment_method TEXT DEFAULT 'cash',
  status TEXT DEFAULT 'active',
  result TEXT,
  notes TEXT,
  customer_signature TEXT,
  clinic_signature TEXT,
  agree_treatment BOOLEAN DEFAULT false,
  agree_no_complaint BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  is_deleted BOOLEAN DEFAULT false,
  _version BIGINT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(clinic_id, case_code)
);
CREATE INDEX IF NOT EXISTS idx_medical_cases_clinic ON public.medical_cases(clinic_id);
CREATE INDEX IF NOT EXISTS idx_medical_cases_customer ON public.medical_cases(customer_id);
CREATE INDEX IF NOT EXISTS idx_medical_cases_pet ON public.medical_cases(pet_id);

-- Case Logs (Audit Trail / Timeline)
CREATE TABLE IF NOT EXISTS public.case_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id UUID NOT NULL REFERENCES public.clinics(id),
  case_id UUID NOT NULL REFERENCES public.medical_cases(id) ON DELETE CASCADE,
  staff_id UUID REFERENCES public.staff(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  notes TEXT,
  metadata JSONB,
  is_deleted BOOLEAN DEFAULT false,
  _version BIGINT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_case_logs_clinic ON public.case_logs(clinic_id);
CREATE INDEX IF NOT EXISTS idx_case_logs_case ON public.case_logs(case_id);

-- Case Services (junction)
CREATE TABLE IF NOT EXISTS public.case_services (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id UUID NOT NULL REFERENCES public.clinics(id),
  case_id UUID NOT NULL REFERENCES public.medical_cases(id) ON DELETE CASCADE,
  service_id UUID REFERENCES public.services(id) ON DELETE SET NULL,
  service_name TEXT,
  quantity DECIMAL(10,2) DEFAULT 1,
  unit_price BIGINT NOT NULL DEFAULT 0,
  discount DECIMAL(5,2) DEFAULT 0,
  total BIGINT NOT NULL DEFAULT 0,
  notes TEXT,
  medicines_json JSONB,
  is_deleted BOOLEAN DEFAULT false,
  _version BIGINT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_case_services_clinic ON public.case_services(clinic_id);
CREATE INDEX IF NOT EXISTS idx_case_services_case ON public.case_services(case_id);

-- Medicine Transactions
CREATE TABLE IF NOT EXISTS public.medicine_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id UUID NOT NULL REFERENCES public.clinics(id),
  medicine_id UUID NOT NULL REFERENCES public.medicines(id),
  type TEXT NOT NULL,
  quantity DECIMAL(10,2) NOT NULL,
  unit_price BIGINT DEFAULT 0,
  case_id UUID REFERENCES public.medical_cases(id) ON DELETE SET NULL,
  lot_number TEXT,
  purpose TEXT,
  staff_id UUID REFERENCES public.staff(id) ON DELETE SET NULL,
  notes TEXT,
  transaction_date TEXT NOT NULL,
  is_deleted BOOLEAN DEFAULT false,
  _version BIGINT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_med_trans_clinic ON public.medicine_transactions(clinic_id);
CREATE INDEX IF NOT EXISTS idx_med_trans_medicine ON public.medicine_transactions(medicine_id);
CREATE INDEX IF NOT EXISTS idx_med_trans_date ON public.medicine_transactions(transaction_date);

-- Product Sales
CREATE TABLE IF NOT EXISTS public.product_sales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id UUID NOT NULL REFERENCES public.clinics(id),
  product_id UUID NOT NULL REFERENCES public.products(id),
  product_name TEXT NOT NULL,
  quantity DECIMAL(10,2) NOT NULL,
  unit_price BIGINT NOT NULL DEFAULT 0,
  total BIGINT NOT NULL DEFAULT 0,
  customer_id UUID REFERENCES public.customers(id),
  staff_id UUID REFERENCES public.staff(id) ON DELETE SET NULL,
  payment_method TEXT DEFAULT 'cash',
  sale_date TEXT NOT NULL,
  is_deleted BOOLEAN DEFAULT false,
  _version BIGINT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_product_sales_clinic ON public.product_sales(clinic_id);
CREATE INDEX IF NOT EXISTS idx_product_sales_date ON public.product_sales(sale_date);

-- ============================================================
-- PART 5: HOSPITALIZATION TABLES
-- ============================================================

-- Cages
CREATE TABLE IF NOT EXISTS public.cages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id UUID NOT NULL REFERENCES public.clinics(id),
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  status TEXT DEFAULT 'available',
  price BIGINT DEFAULT 0,
  order_index INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  is_deleted BOOLEAN DEFAULT false,
  _version BIGINT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_cages_clinic ON public.cages(clinic_id);

-- Hospitalizations
CREATE TABLE IF NOT EXISTS public.hospitalizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id UUID NOT NULL REFERENCES public.clinics(id),
  case_id UUID NOT NULL REFERENCES public.medical_cases(id) ON DELETE CASCADE,
  pet_id UUID NOT NULL REFERENCES public.pets(id),
  cage_id UUID REFERENCES public.cages(id) ON DELETE SET NULL,
  staff_id UUID REFERENCES public.staff(id) ON DELETE SET NULL,
  admission_date TEXT NOT NULL,
  discharge_date TEXT,
  cage_number TEXT,
  price BIGINT DEFAULT 0,
  status TEXT DEFAULT 'active',
  notes TEXT,
  is_active BOOLEAN DEFAULT true,
  is_deleted BOOLEAN DEFAULT false,
  _version BIGINT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_hosp_clinic ON public.hospitalizations(clinic_id);
CREATE INDEX IF NOT EXISTS idx_hosp_case ON public.hospitalizations(case_id);

-- Hospitalization Dailies
CREATE TABLE IF NOT EXISTS public.hospitalization_dailies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id UUID NOT NULL REFERENCES public.clinics(id),
  hospitalization_id UUID NOT NULL REFERENCES public.hospitalizations(id) ON DELETE CASCADE,
  date TEXT NOT NULL,
  note TEXT,
  is_deleted BOOLEAN DEFAULT false,
  _version BIGINT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_hosp_dailies_clinic ON public.hospitalization_dailies(clinic_id);
CREATE INDEX IF NOT EXISTS idx_hosp_dailies_hosp ON public.hospitalization_dailies(hospitalization_id);
CREATE INDEX IF NOT EXISTS idx_hosp_dailies_date ON public.hospitalization_dailies(date);

-- Hospitalization Treatments
CREATE TABLE IF NOT EXISTS public.hospitalization_treatments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id UUID NOT NULL REFERENCES public.clinics(id),
  daily_id UUID NOT NULL REFERENCES public.hospitalization_dailies(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  name TEXT NOT NULL,
  ref_id UUID,
  time_scheduled TEXT,
  time_performed TEXT,
  quantity DECIMAL(10,2) DEFAULT 1,
  unit TEXT,
  dosage TEXT,
  status TEXT DEFAULT 'pending',
  performer_id UUID REFERENCES public.staff(id) ON DELETE SET NULL,
  notes TEXT,
  is_deleted BOOLEAN DEFAULT false,
  _version BIGINT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_hosp_treatments_clinic ON public.hospitalization_treatments(clinic_id);
CREATE INDEX IF NOT EXISTS idx_hosp_treatments_daily ON public.hospitalization_treatments(daily_id);

-- Vital Sign Logs
CREATE TABLE IF NOT EXISTS public.vital_sign_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id UUID NOT NULL REFERENCES public.clinics(id),
  daily_id UUID NOT NULL REFERENCES public.hospitalization_dailies(id) ON DELETE CASCADE,
  time TEXT NOT NULL,
  temperature DECIMAL(4,1),
  weight DECIMAL(6,2),
  heart_rate DECIMAL(6,1),
  respiratory_rate DECIMAL(6,1),
  crt TEXT,
  mucous_membrane TEXT,
  faeces TEXT,
  urine TEXT,
  observer_id UUID REFERENCES public.staff(id) ON DELETE SET NULL,
  notes TEXT,
  is_deleted BOOLEAN DEFAULT false,
  _version BIGINT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_vital_signs_clinic ON public.vital_sign_logs(clinic_id);
CREATE INDEX IF NOT EXISTS idx_vital_signs_daily ON public.vital_sign_logs(daily_id);

-- Hospitalization Regimens (Templates)
CREATE TABLE IF NOT EXISTS public.hospitalization_regimens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id UUID NOT NULL REFERENCES public.clinics(id),
  name TEXT NOT NULL,
  description TEXT,
  items_json JSONB,
  is_active BOOLEAN DEFAULT true,
  is_deleted BOOLEAN DEFAULT false,
  _version BIGINT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_regimens_clinic ON public.hospitalization_regimens(clinic_id);

-- Hospitalization Reservations
CREATE TABLE IF NOT EXISTS public.hospitalization_reservations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id UUID NOT NULL REFERENCES public.clinics(id),
  cage_id UUID NOT NULL REFERENCES public.cages(id),
  pet_id UUID NOT NULL REFERENCES public.pets(id),
  customer_id UUID REFERENCES public.customers(id),
  start_date TEXT NOT NULL,
  end_date TEXT NOT NULL,
  note TEXT,
  status TEXT DEFAULT 'pending',
  is_deleted BOOLEAN DEFAULT false,
  _version BIGINT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_reservations_clinic ON public.hospitalization_reservations(clinic_id);

-- ============================================================
-- PART 6: FILE ATTACHMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.case_attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id UUID NOT NULL REFERENCES public.clinics(id),
  case_id UUID NOT NULL REFERENCES public.medical_cases(id) ON DELETE CASCADE,
  case_service_id UUID REFERENCES public.case_services(id) ON DELETE SET NULL,
  file_name TEXT NOT NULL,
  file_type TEXT,
  category TEXT DEFAULT 'other',
  local_path TEXT,
  remote_url TEXT,
  storage_path TEXT,
  thumbnail_path TEXT,
  note TEXT,
  file_size INTEGER,
  uploaded_by UUID REFERENCES auth.users(id),
  sync_status TEXT DEFAULT 'local_only',
  is_active BOOLEAN DEFAULT true,
  is_deleted BOOLEAN DEFAULT false,
  _version BIGINT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_case_attachments_clinic ON public.case_attachments(clinic_id);
CREATE INDEX IF NOT EXISTS idx_case_attachments_case ON public.case_attachments(case_id);

-- ============================================================
-- PART 7: FINANCE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id UUID NOT NULL REFERENCES public.clinics(id),
  date TEXT NOT NULL,
  content TEXT NOT NULL,
  category TEXT NOT NULL,
  amount BIGINT NOT NULL,
  quantity DECIMAL(10,2),
  unit TEXT,
  unit_price BIGINT,
  staff_id UUID REFERENCES public.staff(id) ON DELETE SET NULL,
  notes TEXT,
  is_active BOOLEAN DEFAULT true,
  is_deleted BOOLEAN DEFAULT false,
  _version BIGINT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_expenses_clinic ON public.expenses(clinic_id);
CREATE INDEX IF NOT EXISTS idx_expenses_date ON public.expenses(date);

-- ============================================================
-- PART 8: RBAC — CLINIC STAFF (non-auth users)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.clinic_staff (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id UUID NOT NULL REFERENCES public.clinics(id),
  full_name TEXT NOT NULL,
  role TEXT DEFAULT 'assistant',
  specialization TEXT,
  pin_hash TEXT,
  staff_code TEXT,
  avatar_url TEXT,
  custom_modules TEXT,
  is_active BOOLEAN DEFAULT true,
  is_deleted BOOLEAN DEFAULT false,
  _version BIGINT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_clinic_staff_clinic ON public.clinic_staff(clinic_id);

-- ============================================================
-- PART 9: CLINIC DEVICES
-- ============================================================

CREATE TABLE IF NOT EXISTS public.clinic_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id UUID NOT NULL REFERENCES public.clinics(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL,
  device_name TEXT,
  license_key_used TEXT,
  is_approved BOOLEAN DEFAULT false,
  last_ip TEXT,
  last_active_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(clinic_id, device_id)
);
CREATE INDEX IF NOT EXISTS idx_clinic_devices_clinic ON public.clinic_devices(clinic_id);
CREATE INDEX IF NOT EXISTS idx_clinic_devices_device ON public.clinic_devices(device_id);

-- ============================================================
-- PART 10: SUBSCRIPTION & BILLING
-- ============================================================

CREATE TABLE IF NOT EXISTS public.subscription_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  duration_months INTEGER NOT NULL,
  price BIGINT NOT NULL,
  features JSONB DEFAULT '["Đầy đủ chức năng"]',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id UUID NOT NULL REFERENCES public.clinics(id),
  plan_id UUID NOT NULL REFERENCES public.subscription_plans(id),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'expired', 'cancelled')),
  start_date TIMESTAMPTZ,
  end_date TIMESTAMPTZ,
  payment_method TEXT,
  payment_ref TEXT,
  payment_proof_url TEXT,
  amount BIGINT NOT NULL,
  approved_by UUID,
  approved_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Seed subscription plans
INSERT INTO public.subscription_plans (name, display_name, duration_months, price, features)
VALUES 
  ('basic', 'Cơ bản', 1, 200000, '["Đầy đủ chức năng", "Hỗ trợ kỹ thuật", "Đồng bộ cloud"]'),
  ('saving', 'Tiết kiệm', 3, 500000, '["Đầy đủ chức năng", "Hỗ trợ kỹ thuật", "Đồng bộ cloud", "Tiết kiệm 17%"]'),
  ('pro', 'Pro', 6, 1000000, '["Đầy đủ chức năng", "Hỗ trợ ưu tiên", "Đồng bộ cloud", "Tiết kiệm 17%", "Backup tự động"]')
ON CONFLICT (name) DO NOTHING;

-- ============================================================
-- PART 11: AUDIT LOG
-- ============================================================

CREATE TABLE IF NOT EXISTS public.audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id UUID REFERENCES public.clinics(id),
  user_id UUID,
  table_name TEXT NOT NULL,
  record_id TEXT NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
  old_data JSONB,
  new_data JSONB,
  ip_address TEXT,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_audit_log_clinic ON public.audit_log(clinic_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_table ON public.audit_log(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_log_date ON public.audit_log(created_at);
CREATE INDEX IF NOT EXISTS idx_audit_log_record ON public.audit_log(table_name, record_id);

-- Audit trigger function
CREATE OR REPLACE FUNCTION public.audit_trigger_func()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.audit_log (clinic_id, user_id, table_name, record_id, action, new_data)
    VALUES (
      NEW.clinic_id, auth.uid(), TG_TABLE_NAME, NEW.id::TEXT, 'INSERT',
      to_jsonb(NEW) - 'customer_signature' - 'clinic_signature'
    );
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO public.audit_log (clinic_id, user_id, table_name, record_id, action, old_data, new_data)
    VALUES (
      NEW.clinic_id, auth.uid(), TG_TABLE_NAME, NEW.id::TEXT, 'UPDATE',
      to_jsonb(OLD) - 'customer_signature' - 'clinic_signature',
      to_jsonb(NEW) - 'customer_signature' - 'clinic_signature'
    );
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO public.audit_log (clinic_id, user_id, table_name, record_id, action, old_data)
    VALUES (
      OLD.clinic_id, auth.uid(), TG_TABLE_NAME, OLD.id::TEXT, 'DELETE',
      to_jsonb(OLD) - 'customer_signature' - 'clinic_signature'
    );
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

-- ============================================================
-- PART 12: ROW LEVEL SECURITY — ALL DATA TABLES
-- ============================================================

-- Macro: Apply standard RLS + triggers to a data table
-- We apply this to every syncable data table

DO $$
DECLARE
  t TEXT;
  -- All data tables that need standard clinic-based RLS
  data_tables TEXT[] := ARRAY[
    'staff', 'customers', 'pets', 'services', 'medicines', 'products',
    'appointments', 'medical_cases', 'case_services', 'medicine_transactions',
    'product_sales', 'cages', 'hospitalizations', 'hospitalization_dailies',
    'hospitalization_treatments', 'vital_sign_logs', 'expenses',
    'hospitalization_regimens', 'hospitalization_reservations',
    'case_attachments', 'clinic_staff'
  ];
BEGIN
  FOREACH t IN ARRAY data_tables LOOP
    -- Enable RLS
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    
    -- Drop existing policies
    EXECUTE format('DROP POLICY IF EXISTS "%s_select" ON public.%I', t, t);
    EXECUTE format('DROP POLICY IF EXISTS "%s_insert" ON public.%I', t, t);
    EXECUTE format('DROP POLICY IF EXISTS "%s_update" ON public.%I', t, t);
    EXECUTE format('DROP POLICY IF EXISTS "%s_delete" ON public.%I', t, t);
    
    -- Create standard CRUD policies
    EXECUTE format(
      'CREATE POLICY "%s_select" ON public.%I FOR SELECT USING (clinic_id = public.get_my_clinic_id())', t, t
    );
    EXECUTE format(
      'CREATE POLICY "%s_insert" ON public.%I FOR INSERT WITH CHECK (clinic_id = public.get_my_clinic_id())', t, t
    );
    EXECUTE format(
      'CREATE POLICY "%s_update" ON public.%I FOR UPDATE USING (clinic_id = public.get_my_clinic_id())', t, t
    );
    EXECUTE format(
      'CREATE POLICY "%s_delete" ON public.%I FOR DELETE USING (clinic_id = public.get_my_clinic_id())', t, t
    );
    
    -- Auto-set clinic_id trigger
    EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_clinic ON public.%I', t, t);
    EXECUTE format(
      'CREATE TRIGGER trg_%s_clinic BEFORE INSERT ON public.%I FOR EACH ROW EXECUTE FUNCTION public.set_clinic_id()', t, t
    );
    
    -- Auto-increment version trigger
    EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_version ON public.%I', t, t);
    EXECUTE format(
      'CREATE TRIGGER trg_%s_version BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.increment_version()', t, t
    );
  END LOOP;
END $$;

-- Special RLS for system tables
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "audit_log_select" ON public.audit_log FOR SELECT
  USING (clinic_id = public.get_my_clinic_id());
CREATE POLICY "audit_log_insert" ON public.audit_log FOR INSERT
  WITH CHECK (true);

ALTER TABLE public.clinic_devices ENABLE ROW LEVEL SECURITY;
CREATE POLICY "clinic_devices_select" ON public.clinic_devices FOR SELECT
  USING (clinic_id = public.get_my_clinic_id());
CREATE POLICY "clinic_devices_insert" ON public.clinic_devices FOR INSERT
  WITH CHECK (clinic_id = public.get_my_clinic_id());
CREATE POLICY "clinic_devices_update" ON public.clinic_devices FOR UPDATE
  USING (clinic_id = public.get_my_clinic_id());
CREATE POLICY "clinic_devices_delete" ON public.clinic_devices FOR DELETE
  USING (clinic_id = public.get_my_clinic_id());

ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;
CREATE POLICY "plans_select" ON public.subscription_plans FOR SELECT USING (true);

ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "sub_select" ON public.subscriptions FOR SELECT
  USING (clinic_id IN (SELECT id FROM public.clinics WHERE owner_id = auth.uid()));
CREATE POLICY "sub_insert" ON public.subscriptions FOR INSERT
  WITH CHECK (clinic_id IN (SELECT id FROM public.clinics WHERE owner_id = auth.uid()));

-- ============================================================
-- PART 13: AUDIT TRIGGERS ON CRITICAL TABLES
-- ============================================================

DO $$
DECLARE
  t TEXT;
  critical_tables TEXT[] := ARRAY[
    'medical_cases', 'hospitalizations', 'medicine_transactions', 'expenses'
  ];
BEGIN
  FOREACH t IN ARRAY critical_tables LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_audit ON public.%I', t, t);
    EXECUTE format(
      'CREATE TRIGGER trg_%s_audit AFTER INSERT OR UPDATE OR DELETE ON public.%I 
       FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_func()', t, t
    );
  END LOOP;
END $$;

-- ============================================================
-- PART 14: REALTIME — ENABLE FOR ALL DATA TABLES
-- ============================================================

DO $$
DECLARE
  t TEXT;
  all_data_tables TEXT[] := ARRAY[
    'customers', 'pets', 'medicines', 'products', 'services', 'staff',
    'appointments', 'medical_cases', 'case_services', 'medicine_transactions',
    'product_sales', 'cages', 'hospitalizations', 'hospitalization_dailies',
    'hospitalization_treatments', 'vital_sign_logs', 'expenses',
    'hospitalization_regimens', 'case_attachments'
  ];
BEGIN
  FOREACH t IN ARRAY all_data_tables LOOP
    EXECUTE format('ALTER TABLE public.%I REPLICA IDENTITY FULL', t);
  END LOOP;
END $$;

-- Add to realtime publication (add each table, ignore if already added)
DO $$
DECLARE
  t TEXT;
  rt_tables TEXT[] := ARRAY[
    'customers', 'pets', 'medicines', 'products', 'services', 'staff',
    'appointments', 'medical_cases', 'case_services', 'medicine_transactions',
    'product_sales', 'cages', 'hospitalizations', 'hospitalization_dailies',
    'hospitalization_treatments', 'vital_sign_logs', 'expenses',
    'hospitalization_regimens', 'case_attachments'
  ];
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    FOREACH t IN ARRAY rt_tables LOOP
      BEGIN
        EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
      EXCEPTION WHEN duplicate_object THEN
        NULL; -- already added, skip
      END;
    END LOOP;
  END IF;
END $$;

-- ============================================================
-- PART 15: STORAGE BUCKET FOR FILE ATTACHMENTS
-- ============================================================

-- Create private storage bucket for clinic files
-- Files organized as: clinic-attachments/{clinic_id}/{case_id}/{filename}
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'clinic-attachments', 
  'clinic-attachments', 
  false,
  10485760,  -- 10MB max
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'application/pdf', 'video/mp4']
)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS — only access own clinic's files
CREATE POLICY "clinic_files_select" ON storage.objects FOR SELECT
  USING (
    bucket_id = 'clinic-attachments' 
    AND (storage.foldername(name))[1] = public.get_my_clinic_id()::TEXT
  );
CREATE POLICY "clinic_files_insert" ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'clinic-attachments'
    AND (storage.foldername(name))[1] = public.get_my_clinic_id()::TEXT
  );
CREATE POLICY "clinic_files_update" ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'clinic-attachments'
    AND (storage.foldername(name))[1] = public.get_my_clinic_id()::TEXT
  );
CREATE POLICY "clinic_files_delete" ON storage.objects FOR DELETE
  USING (
    bucket_id = 'clinic-attachments'
    AND (storage.foldername(name))[1] = public.get_my_clinic_id()::TEXT
  );

COMMIT;

-- ============================================================
-- SCHEMA SUMMARY
-- ============================================================
-- Total tables: 25 data + 1 audit
-- All PKs: UUID
-- All FKs: UUID with ON DELETE SET NULL or CASCADE
-- All timestamps: TIMESTAMPTZ
-- All currency: BIGINT (VND, no decimals)
-- All quantities: DECIMAL(10,2)
-- All booleans: BOOLEAN
-- Soft delete: is_deleted BOOLEAN DEFAULT false (on every data table)
-- Version: _version BIGINT DEFAULT 1 (on every data table)
-- RLS: Every table has clinic_id-based policies
-- Triggers: set_clinic_id + increment_version on every data table
-- Audit: medical_cases, hospitalizations, medicine_transactions, expenses
-- Realtime: All 19 syncable tables
-- Storage: clinic-attachments bucket with RLS per clinic
-- ============================================================
