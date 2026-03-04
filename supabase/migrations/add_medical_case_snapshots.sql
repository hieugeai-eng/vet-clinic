-- Migration to add snapshot columns to medical_cases
-- This ensures that historical cases retain exact customer and pet information
-- even if the original record is deleted or modified.

ALTER TABLE medical_cases
  ADD COLUMN IF NOT EXISTS customer_name TEXT,
  ADD COLUMN IF NOT EXISTS customer_phone TEXT,
  ADD COLUMN IF NOT EXISTS pet_name TEXT,
  ADD COLUMN IF NOT EXISTS pet_species TEXT;
