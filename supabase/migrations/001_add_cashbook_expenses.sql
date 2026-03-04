-- Add type and payment_method to expenses table for Cashbook integration

ALTER TABLE public.expenses 
ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'expense',
ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'cash';

-- For existing records without type, they will default to 'expense' and 'cash' 
-- which correctly matches their historical behavior.
