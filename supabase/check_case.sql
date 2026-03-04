-- Fetch the latest case to see if things are stored correctly
SELECT * FROM medical_cases ORDER BY updated_at DESC LIMIT 1;
