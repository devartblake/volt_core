-- Daily summary email: per-user opt-out.
--
-- Run any time (no ordering dependency).
--
--   * public.user_profiles.daily_digest_opt_out boolean not null default false.
--     The daily-digest Edge Function already skips profiles where it is true
--     (digestRecipients in supabase/functions/daily-digest/digest_data.ts), and
--     the app's Settings page (admin, supervisor, dispatcher) writes it.
--   * No policy change. The existing policy user_profiles_self
--     (for all, user_id = auth.uid()) already lets a person read and update
--     their own row, so the new column is reachable by its owner and nobody
--     else; admin read access (user_profiles_tenant_admin_read) is select-only.
--     NOTE: that self policy is a row-level rule, not a column-level one, so it
--     has always let a person update any column of their own profile (email,
--     is_active, ...). This migration neither widens nor narrows that.
--
-- Idempotent: safe to run more than once.

begin;

alter table public.user_profiles
  add column if not exists daily_digest_opt_out boolean not null default false;

comment on column public.user_profiles.daily_digest_opt_out is
  'true = this person does not want the daily summary email (daily-digest function skips them).';

commit;
