-- Product photos on catalog parts.
--
-- The photo itself is stored in the existing private bucket 'voltcore-files'
-- (the same one signatures, PDFs and photos already use) under
--   part-images/<tenant id>/<part id>.jpg
-- so no new bucket and no new storage policy is needed: the existing
-- 'voltcore_files_rw' policy on storage.objects already lets signed-in users
-- read and write that bucket. Only the catalog row needs to remember the path.
-- Safe to re-run.

begin;

alter table public.parts_catalog
  add column if not exists image_path text;

commit;
