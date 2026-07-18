# Implementation Plan - Fix Supabase Sync Errors & Logger Warnings

The app has successfully moved past the UUID syntax error, but is now encountering Row Level Security (RLS) violations (`42501`) when attempting to sync data. Additionally, console noise from the uninitialized `NetworkLogger` persists.

## User Review Required

> [!IMPORTANT]
> The current RLS error (`new row violates row-level security policy`) usually means that the authenticated user is not a member of the tenant ID specified in the `.env` file. You must ensure that the user ID in `auth.users` has a corresponding entry in the `public.tenant_members` table for the tenant `7130c6ab-6cfe-4c78-b89d-e71716ab9477`.

### Required SQL Fix
Run this in your Supabase SQL Editor (replace `<USER_ID>` with your user's UID):
```sql
INSERT INTO public.tenant_members (tenant_id, user_id, role)
VALUES ('7130c6ab-6cfe-4c78-b89d-e71716ab9477', '<USER_ID>', 'technician')
ON CONFLICT (tenant_id, user_id) DO NOTHING;
```

## Proposed Changes

### Core Sync Services

#### [MODIFY] [sync_context.dart](file:///C:/Users/lmxbl/Documents/ASElectric/volt_core/lib/core/services/sync/sync_context.dart)
- Update `tenantId` to robustly strip leading/trailing quotes from `.env` values.

#### [MODIFY] [sync_service.dart](file:///C:/Users/lmxbl/Documents/ASElectric/volt_core/lib/core/services/sync/sync_service.dart)
- Update `_dispatch` to include detailed debug logging of the row being sent and the user ID.
- Ensure empty strings are stripped from JSON payloads before sending to Supabase to prevent type casting issues.

### App Initialization

#### [MODIFY] [main.dart](file:///C:/Users/lmxbl/Documents/ASElectric/volt_core/lib/main.dart)
- Initialize `NetworkLogger` using a `ProviderContainer` to resolve the "Logger not initialized" warnings.

## Verification Plan

### Manual Verification
- Verify `[Sync] Row details` logs appear in the console during sync attempts.
- Confirm `[NetworkLogger]` warnings are gone.
- Verify sync success once the `tenant_members` entry is added to the database.


### Manual Verification
- Verify that the `[Sync] upsert failed` logs in the console no longer show the `22P02` UUID syntax error.
- Check that the `SyncStatus` correctly reflects when sync is paused due to missing configuration.
- (Recommended for User) Update `assets/env/.env.staging` with a valid UUID from the `public.tenants` table to confirm successful end-to-end synchronization.
