-- ==============================================================================
-- OKADA VET CLINIC: AUTO-SWEEPER FOR SOFT DELETED RECORDS (30 DAYS)
-- ==============================================================================
-- Description: This script sets up an automated daily job to permanently delete
-- any records where `is_deleted = true` AND the deletion happened more than 
-- 30 days ago. This keeps database storage clean while allowing a generous 
-- window for offline devices to sync the deleted status.
-- ==============================================================================

-- 1. Enable the pg_cron extension (Required for scheduled jobs)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 2. Create a generic function to sweep clean deleted records
CREATE OR REPLACE FUNCTION clean_soft_deleted_records()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER -- Runs with elevated privileges to bypass RLS limitations during cleanup
AS $$
DECLARE
    -- The threshold: records deleted before this date will be hard-deleted
    threshold_date timestamp with time zone := now() - interval '30 days';
BEGIN
    -- [!IMPORTANT] You must run this sequentially so Foreign Key constraints apply properly.
    -- Delete order should be from children/junctions up to parents to avoid FK violations.

    -- 1. Delete dependent logs and treatments
    DELETE FROM vital_sign_logs WHERE is_deleted = true AND updated_at < threshold_date;
    DELETE FROM hospitalization_treatments WHERE is_deleted = true AND updated_at < threshold_date;
    DELETE FROM hospitalization_dailies WHERE is_deleted = true AND updated_at < threshold_date;
    DELETE FROM hospitalization_reservations WHERE is_deleted = true AND updated_at < threshold_date;
    
    -- 2. Delete medicine transactions & attachments
    DELETE FROM medicine_transactions WHERE is_deleted = true AND updated_at < threshold_date;
    DELETE FROM case_attachments WHERE is_deleted = true AND updated_at < threshold_date;
    
    -- 3. Delete case_services
    DELETE FROM case_services WHERE is_deleted = true AND updated_at < threshold_date;

    -- 4. Delete sales and expenses
    DELETE FROM product_sales WHERE is_deleted = true AND updated_at < threshold_date;
    DELETE FROM expenses WHERE is_deleted = true AND updated_at < threshold_date;

    -- 5. Delete medical_cases and hospitalizations (Parents of treatments/services)
    DELETE FROM hospitalizations WHERE is_deleted = true AND updated_at < threshold_date;
    DELETE FROM medical_cases WHERE is_deleted = true AND updated_at < threshold_date;

    -- 6. Delete Pets and Appointments
    DELETE FROM appointments WHERE is_deleted = true AND updated_at < threshold_date;
    DELETE FROM pets WHERE is_deleted = true AND updated_at < threshold_date;

    -- 7. Delete Customers (Parent of Pets/Cases/Appointments)
    DELETE FROM customers WHERE is_deleted = true AND updated_at < threshold_date;

    -- 8. Delete Dictionary/Configuration tables 
    DELETE FROM services WHERE is_deleted = true AND updated_at < threshold_date;
    DELETE FROM medicines WHERE is_deleted = true AND updated_at < threshold_date;
    DELETE FROM products WHERE is_deleted = true AND updated_at < threshold_date;
    DELETE FROM staff WHERE is_deleted = true AND updated_at < threshold_date;
    DELETE FROM cages WHERE is_deleted = true AND updated_at < threshold_date;
    DELETE FROM hospitalization_regimens WHERE is_deleted = true AND updated_at < threshold_date;

    -- Log to postgres logs to confirm the job ran
    RAISE LOG 'Soft-deleted records older than 30 days were permanently wiped at %', now();
END;
$$;

-- 3. Unschedule any existing duplicate cron job (prevents stacking)
-- Suppresses errors if the job doesn't exist yet
DO $$
BEGIN
    PERFORM cron.unschedule('daily_soft_delete_sweeper');
EXCEPTION WHEN OTHERS THEN
    -- do nothing
END;
$$;


-- 4. Schedule the cron job to run every day at 02:00 AM (UTC)
-- The cron expression '0 2 * * *' means:
-- Minute = 0, Hour = 2, Day of Month = *, Month = *, Day of Week = *
SELECT cron.schedule(
    'daily_soft_delete_sweeper',  -- job name
    '0 2 * * *',                  -- run at 2:00 AM every single day
    'SELECT clean_soft_deleted_records();'
);

-- ==============================================================================
-- DONE. Once you execute this in Supabase SQL Editor, it will run silently
-- in the background forever!
-- ==============================================================================
