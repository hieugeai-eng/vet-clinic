-- Chạy đoạn script này trong mục "SQL Editor" trên bảng điều khiển Supabase của bạn.

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

-- Tạo Index
CREATE INDEX IF NOT EXISTS idx_case_logs_clinic ON public.case_logs(clinic_id);
CREATE INDEX IF NOT EXISTS idx_case_logs_case ON public.case_logs(case_id);

-- Cấu hình Row Level Security (RLS)
ALTER TABLE public.case_logs ENABLE ROW LEVEL SECURITY;
    
DROP POLICY IF EXISTS "case_logs_select" ON public.case_logs;
DROP POLICY IF EXISTS "case_logs_insert" ON public.case_logs;
DROP POLICY IF EXISTS "case_logs_update" ON public.case_logs;
DROP POLICY IF EXISTS "case_logs_delete" ON public.case_logs;

CREATE POLICY "case_logs_select" ON public.case_logs FOR SELECT USING (clinic_id = public.get_my_clinic_id());
CREATE POLICY "case_logs_insert" ON public.case_logs FOR INSERT WITH CHECK (clinic_id = public.get_my_clinic_id());
CREATE POLICY "case_logs_update" ON public.case_logs FOR UPDATE USING (clinic_id = public.get_my_clinic_id());
CREATE POLICY "case_logs_delete" ON public.case_logs FOR DELETE USING (clinic_id = public.get_my_clinic_id());

-- Triggers tự động (Clinic ID & Versioning)
DROP TRIGGER IF EXISTS trg_case_logs_clinic ON public.case_logs;
CREATE TRIGGER trg_case_logs_clinic BEFORE INSERT ON public.case_logs FOR EACH ROW EXECUTE FUNCTION public.set_clinic_id();

DROP TRIGGER IF EXISTS trg_case_logs_version ON public.case_logs;
CREATE TRIGGER trg_case_logs_version BEFORE UPDATE ON public.case_logs FOR EACH ROW EXECUTE FUNCTION public.increment_version();

-- Bật Realtime trên bảng này
alter publication supabase_realtime add table public.case_logs;
