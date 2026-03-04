-- ============================================
-- Create storage bucket for case attachments
-- Run this in Supabase Dashboard > SQL Editor
-- ============================================

-- 1. Create the bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'case-attachments',
  'case-attachments',
  true,
  10485760, -- 10MB
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'application/pdf']
)
ON CONFLICT (id) DO NOTHING;

-- 2. Allow authenticated users to upload files
CREATE POLICY "Authenticated users can upload attachments"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'case-attachments');

-- 3. Allow authenticated users to update (upsert) files
CREATE POLICY "Authenticated users can update attachments"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'case-attachments');

-- 4. Allow anyone to read/download (public bucket)
CREATE POLICY "Public read access for attachments"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'case-attachments');

-- 5. Allow authenticated users to delete their files
CREATE POLICY "Authenticated users can delete attachments"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'case-attachments');
