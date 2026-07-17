-- Voltcore: align Supabase schema with the app's flat sync payloads
--
-- WHY: the app's offline sync engine upserts FLAT snake_case columns into
-- public.inspections and public.maintenance_records (see the Dart serializers
-- InspectionRemoteDatasource.toSupabaseJson and maintenanceRecordToSupabaseJson).
-- The consolidated schema stored these as jsonb (inspections.payload,
-- maintenance_records.data), so columns like air_filter_date don't exist ->
-- PostgREST error PGRST204 ("Could not find the '<col>' column ... in schema cache").
--
-- This migration adds every column the app sends (idempotent), and relaxes the
-- NOT NULL constraints the flat, tenant-less payload can't satisfy yet.
-- Run it in the Supabase SQL editor. Safe to re-run.
--
-- NOTE: this keeps the flat single-table approach the app currently uses. See
-- the end of this file for the RLS / tenant_id / storage-bucket follow-ups that
-- become the next blockers once the columns exist.

begin;

-- === inspections: add flat columns the app upserts ===
alter table public.inspections add column if not exists created_at timestamptz;
alter table public.inspections add column if not exists site_code text not null default '';
alter table public.inspections add column if not exists site_grade text not null default '';
alter table public.inspections add column if not exists address text not null default '';
alter table public.inspections add column if not exists service_date timestamptz;
alter table public.inspections add column if not exists technician_name text not null default '';
alter table public.inspections add column if not exists generator_make text not null default '';
alter table public.inspections add column if not exists generator_model text not null default '';
alter table public.inspections add column if not exists generator_serial text not null default '';
alter table public.inspections add column if not exists generator_kw text not null default '';
alter table public.inspections add column if not exists engine_hours text not null default '';
alter table public.inspections add column if not exists fuel_type text not null default '';
alter table public.inspections add column if not exists voltage_rating text not null default '';
alter table public.inspections add column if not exists loc_indoors boolean not null default false;
alter table public.inspections add column if not exists loc_outdoors boolean not null default false;
alter table public.inspections add column if not exists loc_roof boolean not null default false;
alter table public.inspections add column if not exists loc_basement boolean not null default false;
alter table public.inspections add column if not exists loc_other text not null default '';
alter table public.inspections add column if not exists dedicated_room_2hr boolean not null default false;
alter table public.inspections add column if not exists separate_from_main_service boolean not null default false;
alter table public.inspections add column if not exists area_clear boolean not null default false;
alter table public.inspections add column if not exists labels_estop_visible boolean not null default false;
alter table public.inspections add column if not exists extinguisher_present boolean not null default false;
alter table public.inspections add column if not exists fuel_stored_type text not null default '';
alter table public.inspections add column if not exists fuel_qty_gallons text not null default '';
alter table public.inspections add column if not exists fdny_permit text not null default '';
alter table public.inspections add column if not exists c92_on_site text not null default '';
alter table public.inspections add column if not exists gas_cutoff_valve text not null default '';
alter table public.inspections add column if not exists dep_size_kw text not null default '';
alter table public.inspections add column if not exists dep_registered_cats text not null default '';
alter table public.inspections add column if not exists dep_certificate_operate text not null default '';
alter table public.inspections add column if not exists tier4_compliant text not null default '';
alter table public.inspections add column if not exists smoke_or_stack_test text not null default '';
alter table public.inspections add column if not exists records_kept_5_years boolean not null default false;
alter table public.inspections add column if not exists emergency_only boolean not null default false;
alter table public.inspections add column if not exists estimated_annual_runtime_hours text not null default '';
alter table public.inspections add column if not exists fuel_for_6hrs text not null default '';
alter table public.inspections add column if not exists notes text not null default '';
alter table public.inspections add column if not exists genset_runs_under_load boolean not null default false;
alter table public.inspections add column if not exists voltage_frequency_ok boolean not null default false;
alter table public.inspections add column if not exists exhaust_ok boolean not null default false;
alter table public.inspections add column if not exists grounding_bonding_ok boolean not null default false;
alter table public.inspections add column if not exists control_panel_ok boolean not null default false;
alter table public.inspections add column if not exists safety_devices_ok boolean not null default false;
alter table public.inspections add column if not exists deficiencies_documented boolean not null default false;
alter table public.inspections add column if not exists loadbank_done boolean not null default false;
alter table public.inspections add column if not exists ats_verified boolean not null default false;
alter table public.inspections add column if not exists fuel_stored_over_1yr boolean not null default false;
alter table public.inspections add column if not exists last_service_date text not null default '';
alter table public.inspections add column if not exists oil_filter_change_date text not null default '';
alter table public.inspections add column if not exists fuel_filter_date text not null default '';
alter table public.inspections add column if not exists coolant_flush_date text not null default '';
alter table public.inspections add column if not exists battery_replace_date text not null default '';
alter table public.inspections add column if not exists air_filter_date text not null default '';
alter table public.inspections add column if not exists technician_signature_path text not null default '';
alter table public.inspections add column if not exists technician_sig_date timestamptz;
alter table public.inspections add column if not exists customer_signature_path text not null default '';
alter table public.inspections add column if not exists customer_sig_date timestamptz;
alter table public.inspections add column if not exists customer_name text not null default '';
alter table public.inspections add column if not exists pdf_path text not null default '';

-- === maintenance_records: add flat columns the app upserts ===
alter table public.maintenance_records add column if not exists inspection_id text;
alter table public.maintenance_records add column if not exists site_code text not null default '';
alter table public.maintenance_records add column if not exists address text not null default '';
alter table public.maintenance_records add column if not exists date_of_service timestamptz;
alter table public.maintenance_records add column if not exists technician_name text not null default '';
alter table public.maintenance_records add column if not exists generator_make text not null default '';
alter table public.maintenance_records add column if not exists generator_model text not null default '';
alter table public.maintenance_records add column if not exists generator_serial text not null default '';
alter table public.maintenance_records add column if not exists generator_kw text not null default '';
alter table public.maintenance_records add column if not exists engine_hours text not null default '';
alter table public.maintenance_records add column if not exists fuel_type text not null default '';
alter table public.maintenance_records add column if not exists last_fuel_delivery_date text not null default '';
alter table public.maintenance_records add column if not exists voltage_rating text not null default '';
alter table public.maintenance_records add column if not exists generator_location text not null default '';
alter table public.maintenance_records add column if not exists generator_location_other text not null default '';
alter table public.maintenance_records add column if not exists enclosure_damaged boolean not null default false;
alter table public.maintenance_records add column if not exists enclosure_intact boolean not null default false;
alter table public.maintenance_records add column if not exists no_enclosure boolean not null default false;
alter table public.maintenance_records add column if not exists visible_damage_or_leaks boolean not null default false;
alter table public.maintenance_records add column if not exists area_clear_of_hazards boolean not null default false;
alter table public.maintenance_records add column if not exists warning_labels_visible boolean not null default false;
alter table public.maintenance_records add column if not exists fire_extinguisher_present boolean not null default false;
alter table public.maintenance_records add column if not exists battery_needs_replace boolean not null default false;
alter table public.maintenance_records add column if not exists battery_recently_replaced boolean not null default false;
alter table public.maintenance_records add column if not exists battery_mfg_date text not null default '';
alter table public.maintenance_records add column if not exists battery_part_no text not null default '';
alter table public.maintenance_records add column if not exists battery_type text not null default '';
alter table public.maintenance_records add column if not exists air_filter_needs_replace boolean not null default false;
alter table public.maintenance_records add column if not exists air_filter_recently_replaced boolean not null default false;
alter table public.maintenance_records add column if not exists air_filter_last_replaced_date text not null default '';
alter table public.maintenance_records add column if not exists air_filter_part_no text not null default '';
alter table public.maintenance_records add column if not exists coolant_level text not null default '';
alter table public.maintenance_records add column if not exists coolant_color text not null default '';
alter table public.maintenance_records add column if not exists coolant_hoses_compromised boolean not null default false;
alter table public.maintenance_records add column if not exists coolant_hoses_recommend_change boolean not null default false;
alter table public.maintenance_records add column if not exists coolant_hoses_info text not null default '';
alter table public.maintenance_records add column if not exists fuel_hoses_compromised boolean not null default false;
alter table public.maintenance_records add column if not exists fuel_hoses_recommend_change boolean not null default false;
alter table public.maintenance_records add column if not exists fuel_hoses_info text not null default '';
alter table public.maintenance_records add column if not exists air_intake_hoses_compromised boolean not null default false;
alter table public.maintenance_records add column if not exists air_intake_hoses_recommend_change boolean not null default false;
alter table public.maintenance_records add column if not exists air_intake_hoses_info text not null default '';
alter table public.maintenance_records add column if not exists oil_hoses_compromised boolean not null default false;
alter table public.maintenance_records add column if not exists oil_hoses_recommend_change boolean not null default false;
alter table public.maintenance_records add column if not exists oil_hoses_info text not null default '';
alter table public.maintenance_records add column if not exists additional_hoses_compromised boolean not null default false;
alter table public.maintenance_records add column if not exists additional_hoses_recommend_change boolean not null default false;
alter table public.maintenance_records add column if not exists additional_hoses_info text not null default '';
alter table public.maintenance_records add column if not exists can_lube boolean not null default false;
alter table public.maintenance_records add column if not exists can_lube_part_no text not null default '';
alter table public.maintenance_records add column if not exists can_fuel boolean not null default false;
alter table public.maintenance_records add column if not exists can_fuel_part_no text not null default '';
alter table public.maintenance_records add column if not exists can_water_sep boolean not null default false;
alter table public.maintenance_records add column if not exists can_water_sep_part_no text not null default '';
alter table public.maintenance_records add column if not exists can_oil boolean not null default false;
alter table public.maintenance_records add column if not exists can_oil_part_no text not null default '';
alter table public.maintenance_records add column if not exists can_other1 boolean not null default false;
alter table public.maintenance_records add column if not exists can_other1_label text not null default '';
alter table public.maintenance_records add column if not exists can_other1_part_no text not null default '';
alter table public.maintenance_records add column if not exists can_other2 boolean not null default false;
alter table public.maintenance_records add column if not exists can_other2_label text not null default '';
alter table public.maintenance_records add column if not exists can_other2_part_no text not null default '';
alter table public.maintenance_records add column if not exists oil_filter_changed boolean not null default false;
alter table public.maintenance_records add column if not exists oil_filter_notes text not null default '';
alter table public.maintenance_records add column if not exists fuel_filter_replaced boolean not null default false;
alter table public.maintenance_records add column if not exists fuel_filter_notes text not null default '';
alter table public.maintenance_records add column if not exists coolant_flushed boolean not null default false;
alter table public.maintenance_records add column if not exists coolant_notes text not null default '';
alter table public.maintenance_records add column if not exists battery_replaced boolean not null default false;
alter table public.maintenance_records add column if not exists battery_notes text not null default '';
alter table public.maintenance_records add column if not exists air_filter_replaced boolean not null default false;
alter table public.maintenance_records add column if not exists air_filter_notes text not null default '';
alter table public.maintenance_records add column if not exists belts_hoses_replaced boolean not null default false;
alter table public.maintenance_records add column if not exists belts_hoses_notes text not null default '';
alter table public.maintenance_records add column if not exists block_heater_tested boolean not null default false;
alter table public.maintenance_records add column if not exists block_heater_notes text not null default '';
alter table public.maintenance_records add column if not exists racor_serviced boolean not null default false;
alter table public.maintenance_records add column if not exists racor_notes text not null default '';
alter table public.maintenance_records add column if not exists ats_controller_inspected boolean not null default false;
alter table public.maintenance_records add column if not exists ats_controller_notes text not null default '';
alter table public.maintenance_records add column if not exists cdvr_programmed boolean not null default false;
alter table public.maintenance_records add column if not exists cdvr_notes text not null default '';
alter table public.maintenance_records add column if not exists undervoltage_repaired boolean not null default false;
alter table public.maintenance_records add column if not exists undervoltage_notes text not null default '';
alter table public.maintenance_records add column if not exists hazmat_removed boolean not null default false;
alter table public.maintenance_records add column if not exists hazmat_notes text not null default '';
alter table public.maintenance_records add column if not exists service_observations text not null default '';
alter table public.maintenance_records add column if not exists post_verify_runs_under_load boolean not null default false;
alter table public.maintenance_records add column if not exists post_check_volt_freq boolean not null default false;
alter table public.maintenance_records add column if not exists post_inspect_exhaust boolean not null default false;
alter table public.maintenance_records add column if not exists post_verify_grounding boolean not null default false;
alter table public.maintenance_records add column if not exists post_check_control_panel boolean not null default false;
alter table public.maintenance_records add column if not exists post_ensure_safety_devices boolean not null default false;
alter table public.maintenance_records add column if not exists post_document_deficiencies boolean not null default false;
alter table public.maintenance_records add column if not exists post_loadbank_test boolean not null default false;
alter table public.maintenance_records add column if not exists post_ats_functionality boolean not null default false;
alter table public.maintenance_records add column if not exists fuel_stored_long boolean not null default false;
alter table public.maintenance_records add column if not exists parts_oil_type_qty text not null default '';
alter table public.maintenance_records add column if not exists parts_coolant_type_qty text not null default '';
alter table public.maintenance_records add column if not exists parts_filter_types text not null default '';
alter table public.maintenance_records add column if not exists parts_battery_type_date text not null default '';
alter table public.maintenance_records add column if not exists parts_belts_hoses_replaced text not null default '';
alter table public.maintenance_records add column if not exists parts_block_heater_wattage text not null default '';
alter table public.maintenance_records add column if not exists parts_cdvr_serial text not null default '';
alter table public.maintenance_records add column if not exists technician_signature_name text not null default '';
alter table public.maintenance_records add column if not exists technician_signature_date timestamptz;
alter table public.maintenance_records add column if not exists customer_signature_name text not null default '';
alter table public.maintenance_records add column if not exists customer_signature_date timestamptz;
alter table public.maintenance_records add column if not exists general_notes text;
alter table public.maintenance_records add column if not exists completed boolean not null default false;
alter table public.maintenance_records add column if not exists requires_follow_up boolean not null default false;
alter table public.maintenance_records add column if not exists follow_up_notes text;
alter table public.maintenance_records add column if not exists technician_signature_path text not null default '';
alter table public.maintenance_records add column if not exists customer_signature_path text not null default '';
alter table public.maintenance_records add column if not exists created_at timestamptz;
alter table public.maintenance_records add column if not exists updated_at timestamptz;

-- === Relax NOT NULLs the flat sync payload does not provide ===
-- The app does not send tenant_id (no multi-tenant wiring in sync yet), and
-- maintenance_records rows are keyed by their own id (not job_id).
alter table public.inspections         alter column tenant_id drop not null;
alter table public.maintenance_records alter column tenant_id drop not null;
alter table public.maintenance_records alter column job_id    drop not null;

-- === Storage bucket the app backs files up to ===
-- The app uploads PDFs / signatures / photos to the bucket named by
-- SUPABASE_STORAGE_BUCKET (default 'voltcore-files'); the base schema only
-- created 'maintenance_assets'.
insert into storage.buckets(id, name, public)
values ('voltcore-files', 'voltcore-files', false)
on conflict (id) do nothing;

commit;

-- ============================================================================
-- NEXT BLOCKERS (decide before production) — NOT executed automatically
-- ============================================================================
--
-- 1) ROW LEVEL SECURITY. RLS is enabled on these tables and the write policies
--    require can_manage_tenant_work(tenant_id) / is_assigned_technician(...).
--    The app currently syncs rows with a NULL tenant_id (and may not carry a
--    Supabase auth session), so those policies will REJECT inserts/updates even
--    after the columns exist. Choose one:
--
--    (a) RECOMMENDED: wire tenant_id + Supabase auth into the app's sync
--        payloads, so rows carry a real tenant and the existing policies apply.
--
--    (b) BRING-UP ONLY (insecure — anyone with the anon key can read/write):
--        -- alter table public.inspections         disable row level security;
--        -- alter table public.maintenance_records disable row level security;
--
--    (c) Add explicit policies that fit your auth model (e.g. authenticated
--        users only). Example (adjust to taste):
--        -- create policy inspections_rw_authenticated on public.inspections
--        --   for all to authenticated using (true) with check (true);
--        -- create policy maintenance_records_rw_authenticated on public.maintenance_records
--        --   for all to authenticated using (true) with check (true);
--
-- 2) STORAGE POLICIES. Uploads to 'voltcore-files' also need storage.objects
--    RLS policies allowing the authenticated user to insert/select their files.
--
-- 3) ARCHITECTURE. This migration commits to the app's flat single-table shape
--    and leaves the jsonb design (inspections.payload, maintenance_records.data,
--    maintenance_jobs / _parts_used / _attachments) unused for sync. The cleaner
--    long-term alternative is to change the app serializers to write
--    { id, tenant_id, <identity cols>, payload: { ...everything } } and keep the
--    normalized schema. Pick one direction so they don't drift again.
