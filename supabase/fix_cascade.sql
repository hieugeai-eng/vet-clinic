-- This script fixes the missing ON DELETE CASCADE for hospitalizations
-- Run this in your Supabase SQL Editor to allow deleting medical cases

ALTER TABLE public.hospitalizations
DROP CONSTRAINT IF EXISTS hospitalizations_case_id_fkey,
ADD CONSTRAINT hospitalizations_case_id_fkey 
  FOREIGN KEY (case_id) 
  REFERENCES public.medical_cases(id) 
  ON DELETE CASCADE;

-- Also verify if anything else is missing cascades that block medical_cases
-- (e.g. medicine_transactions has ON DELETE SET NULL, which is fine)

-- Fix case_services that missed 'created_at' and 'updated_at' causing sync engine to ignore them
UPDATE public.case_services SET created_at = now() WHERE created_at IS NULL;
UPDATE public.case_services SET updated_at = created_at WHERE updated_at IS NULL;
