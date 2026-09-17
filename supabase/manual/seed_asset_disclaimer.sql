-- Publish version 1 of the asset disclaimer.
--
-- Transcribed verbatim from the A&S Electric paper receipt in use as of
-- September 2026. READ IT AGAINST THE PAPER before anyone signs against it —
-- this is liability wording, and a misread word here is a misread word on
-- every receipt signed afterwards.
--
-- HOW TO RUN
--   1. Replace <TENANT_ID> below with the tenant's uuid.
--   2. Run it once, as a user who is an admin of that tenant (the
--      fleet_disclaimers_publish policy requires it).
--
-- A PUBLISHED VERSION IS NEVER EDITED. There is deliberately no update
-- statement here and `authenticated` holds no UPDATE or DELETE privilege on
-- this table: a stored signature has to keep pointing at the exact text that
-- was accepted. To revise the wording, insert version 2 with the same shape.
-- Receipts signed under version 1 keep printing version 1.
--
-- The same five clauses are also compiled into the app as
-- kBuiltInDisclaimerClauses, so a device that has never synced can still show
-- a driver the terms. test/fleet/asset_disclaimer_test.dart fails if this file
-- and that constant ever disagree.

insert into public.fleet_disclaimers (
  tenant_id,
  version,
  title,
  intro,
  clauses,
  closing
)
values (
  '<TENANT_ID>'::uuid,
  1,
  'Asset Disclaimer',
  'By signing this receipt, the undersigned acknowledges receipt of the listed assets and agrees to the following terms:',
  jsonb_build_array(
    jsonb_build_object(
      'heading', 'Responsibility',
      'body', 'The employee assumes full responsibility for the care, use, and return of all assets listed herein. Assets must be used solely for work-related purposes and in accordance with company policies.'
    ),
    jsonb_build_object(
      'heading', 'Condition',
      'body', 'All assets are issued in serviceable condition unless otherwise noted. The employee is responsible for reporting any damage, malfunction, or missing items immediately to their supervisor or dispatch personnel.'
    ),
    jsonb_build_object(
      'heading', 'Loss or Damage',
      'body', 'The employee may be held accountable for any loss, theft, or damage resulting from negligence, misuse, or failure to follow proper handling procedures.'
    ),
    jsonb_build_object(
      'heading', 'Return of Assets',
      'body', 'All assets must be returned in the same condition as issued (excluding normal wear and tear) upon completion of the job, reassignment, or termination of employment.'
    ),
    jsonb_build_object(
      'heading', 'Inspection',
      'body', 'A&S Electric INC. reserves the right to inspect assets at any time and to request their immediate return if deemed necessary.'
    )
  ),
  'By signing below, the employee confirms understanding and acceptance of the above terms.'
)
on conflict (tenant_id, version) do nothing;
