# VoltCore FieldOps — Phase 3 Closeout, Remaining Roadmap, and Retention Enforcement Plan

**Project:** A&S Electric / VoltCore FieldOps  
**Repository:** `devartblake/volt_core`  
**Status baseline:** `main` through merged PR #68, with the Phase 3 platform work through PR #64 complete.  
**Purpose:** Define the remaining Phase 3 exit work, the Phase 4–6 roadmap, and the staged retention-enforcement track to implement without risking compliance evidence.

> This plan is the current execution reference. Historical audit documents remain useful as snapshots, but the roadmap and this file are authoritative for current sequencing.

---

## 1. Executive summary

VoltCore has completed the major engineering build-out for Phase 3: versioned templates, template management, generic rendering, offline response lifecycle, generator template packs and legacy adapters, generic reports, Documents integration, downstream report links, technician execution runtime, rollback gating, tenant-authoritative RBAC, persistent settings, export/cache controls, retention-policy configuration, and privacy-aware advanced logging.

Subsequent merged hardening also repaired unsaved-form navigation, stale queued tenant IDs, tenant-admin member/role management, and the legacy inspection form's address/checklist-conclusion capture.

Phase 3 is **not yet production-certified**. The remaining gate is the controlled A&S Electric generator pilot. That pilot must prove exact-revision offline execution, restart recovery, synchronization, PDF parity, immutable completion, and rollback to the legacy workflow.

After Phase 3 certification:

- **Phase 4:** first electrical template packs;
- **Phase 5:** operations and commercial tools;
- **Phase 6:** further vertical expansion.

Retention enforcement is a cross-cutting evidence-lifecycle track. The retention-policy UI exists today, but automatic destructive deletion remains disabled until dependency-safe, storage-safe, auditable purge execution is certified.

---

# 2. Current delivered state

## Phase 1 — Complete

Delivered:

- tenant-safe scheduling;
- authenticated Supabase/Data API access;
- generic equipment/asset vocabulary;
- asset metadata mapping;
- local-first persistence;
- durable synchronization conventions.

Remaining: environment-by-environment operational verification only.

## Phase 2 — Complete / rollout validation

Delivered:

- customer/site directory;
- customer-to-site ownership;
- generic asset registration and reassignment;
- QR/barcode lookup and asset history;
- work-order create/edit/list/detail;
- one-way work-order lifecycle transitions;
- technician assignment, priority, and schedule;
- customer/site/asset links;
- database-owned audit events;
- workload summary;
- inspection-to-maintenance handoff;
- legacy maintenance record access;
- shared schedule-deletion tombstones so a stale remote refresh cannot resurrect a deleted task.

Remaining: real-user rollout verification.

---

# 3. Phase 3 — Template engine and generator migration

## Objective

Replace generator-specific form/PDF branching with a versioned, tenant-safe engine while preserving legacy generator records and reports through controlled cutover and rollback.

## Delivered architecture

### Template/data contract

Delivered tables and relationships include:

- `form_templates`
- `form_template_revisions`
- `form_template_sections`
- `form_template_fields`
- `form_template_field_options`
- `form_responses`
- `form_response_report_artifacts`

Key guarantees:

- every response is pinned to the exact template revision used;
- completed responses are immutable;
- report links derive from the completed response rather than trusting client-supplied relationship IDs;
- tenant authorization remains database-owned through RLS.

### Template management

Delivered:

- role-gated template list and revision history;
- clone-as-draft;
- draft editing for sections, fields, options, validation, visibility, and order;
- atomic draft graph save;
- atomic publish and prior-revision archival;
- draft archival;
- non-destructive built-in generator template installation.

### Generic renderer

Supported field types:

- text;
- number;
- reading with unit;
- date;
- select;
- boolean;
- checklist;
- photo;
- signature.

Capabilities include conditional visibility, validation, editable/read-only rendering, and pluggable evidence capture.

### Offline response lifecycle

Delivered:

- local-first response writes;
- durable sync enqueue;
- debounced autosave;
- serialized saves;
- retryable save failures;
- exact-revision pinning;
- completion validation;
- mutation lock after completion;
- restart recovery;
- exact-revision Hive definition cache;
- no-newer-revision substitution.

### Generator packs and compatibility

Canonical packs:

- `generator-inspection`
- `generator-maintenance`

Legacy adapters preserve:

- stable semantic values;
- the complete JSON-safe legacy payload under `_legacyPayload`;
- provenance metadata;
- legacy boolean ambiguity rather than guessing;
- load-test/photo evidence links;
- draft/completed state;
- legacy source/revision provenance.

### PDF/report and Documents path

Delivered:

- exact revision validation before rendering;
- Noto Sans, US Letter, multi-page output;
- metadata, grade, deficiencies, readings, units, photos, signatures, pagination, provenance;
- native report storage;
- web/IndexedDB report persistence;
- Documents discovery/open/share/delete;
- durable upload enqueue;
- immutable report-artifact metadata and downstream lookup indexes.

### Technician execution runtime

Route:

```text
/field-forms/:templateSlug
```

Pilot build flag:

```bash
flutter run -d edge \
  --dart-define=VOLTCORE_GENERATOR_TEMPLATE_PILOT=true
```

or:

```bash
flutter build web \
  --dart-define=VOLTCORE_GENERATOR_TEMPLATE_PILOT=true
```

Without the define, the template execution path is not registered and the legacy generator workflow remains active.

---

# 4. Additional Phase 3 hardening already merged

Supporting work completed around the Phase 3 platform includes:

- Template Management navigation discoverability;
- change-password and sign-out controls;
- persisted theme, notification, auto-sync, language, and date-format settings;
- cross-platform export and safe cache cleanup;
- `tenant_members` as the authoritative role model;
- last-active-admin protection;
- tenant role-change audit;
- tenant retention-policy configuration;
- privacy-aware advanced network logging;
- credential/query-secret redaction;
- removal of audited production-facing Settings/Admin “Coming soon” placeholders;
- safe navigation guards for unsaved forms;
- queued sync-row healing when an old record was stamped with a stale tenant ID;
- tenant-admin member/role management for registered users;
- split inspection address fields with legacy one-line-address compatibility;
- explicit YES/NO checklist presentation and per-item inspection conclusions.

---

# 5. What remains in Phase 3

Phase 3 is now primarily certification and controlled rollout.

## 5.1 A&S Electric pilot setup

- [ ] Sign in with the active A&S Electric admin account.
- [ ] Open **Template Management**.
- [ ] Install the built-in generator template pack.
- [ ] Confirm published templates:
  - [ ] `generator-inspection`
  - [ ] `generator-maintenance`
- [ ] Run/build with `VOLTCORE_GENERATOR_TEMPLATE_PILOT=true`.

## 5.2 Generator inspection pilot

- [ ] Open `/field-forms/generator-inspection`.
- [ ] Create a response while online so the exact published revision is cached.
- [ ] Disconnect networking.
- [ ] Enter inspection data and verify autosave continues.
- [ ] Restart the app/browser.
- [ ] Reopen the response and verify values plus exact revision recovery.
- [ ] Complete the response.
- [ ] Confirm it becomes immutable.
- [ ] Generate the customer-ready PDF.
- [ ] Confirm the PDF appears in Documents.
- [ ] Reconnect.
- [ ] Confirm response and file synchronization succeed.

## 5.3 Revision immutability

- [ ] Publish a newer generator-inspection revision.
- [ ] Reopen the completed response.
- [ ] Confirm it still resolves the original revision.
- [ ] Confirm its report remains reproducible.

## 5.4 Legacy vs template PDF parity

Compare equivalent evidence:

- [ ] generator identity;
- [ ] site/customer identity;
- [ ] address;
- [ ] compliance/checklist answers;
- [ ] per-item conclusions;
- [ ] readings and grade;
- [ ] deficiencies;
- [ ] load-test evidence;
- [ ] signatures/photos;
- [ ] pagination/readability;
- [ ] provenance.

Classify every difference as:

- intentional improvement;
- equivalent representation;
- missing data;
- migration limitation;
- blocking regression.

Blocking regressions must be repaired before broader rollout.

## 5.5 Generator maintenance pilot

Repeat the lifecycle for:

```text
/field-forms/generator-maintenance
```

Verify battery, filters, coolant, hoses, service actions, parts/materials, post-service checks, signatures, follow-up state, PDF output, synchronization, offline recovery, and revision immutability.

## 5.6 Rollback certification

- [ ] Disable `VOLTCORE_GENERATOR_TEMPLATE_PILOT`.
- [ ] Confirm legacy inspection remains usable.
- [ ] Confirm legacy maintenance remains usable.
- [ ] Confirm legacy reports remain visible.
- [ ] Confirm template responses/PDFs remain intact.

## Phase 3 exit criterion

Phase 3 is production-certified when a technician can complete generator inspection and maintenance offline from a published revision, recover after restart, synchronize safely, generate customer-ready reports, and reopen immutable responses against their original revisions after newer revisions exist—while the legacy workflow remains a verified rollback path.

---

# 6. Phase 4 — First electrical template packs

Begin only after Phase 3 pilot signoff.

## ATS / transfer switch

- [ ] ATS inspection template;
- [ ] ATS maintenance template;
- [ ] transfer-position/source checks;
- [ ] exercise/transfer test;
- [ ] mechanical/contact/connection condition;
- [ ] readings;
- [ ] deficiencies;
- [ ] photos/signatures;
- [ ] signed report.

## Switchgear / panels / transformers

- [ ] equipment identity/nameplate;
- [ ] physical condition;
- [ ] applicable electrical/thermal observations;
- [ ] voltage/current readings;
- [ ] grounding/bonding observations;
- [ ] deficiencies/evidence;
- [ ] signed customer report.

## Emergency lighting / exit signs

- [ ] recurring compliance template;
- [ ] fixture identity/location;
- [ ] function/illumination;
- [ ] battery/emergency runtime;
- [ ] obstruction/damage;
- [ ] corrective action;
- [ ] recurring schedule handoff;
- [ ] signed compliance report.

**Rule:** prefer reusable template-engine capabilities over one-off feature screens.

---

# 7. Phase 5 — Operations and commercial tools

## Parts and truck inventory

- [ ] parts catalog;
- [ ] truck/technician stock;
- [ ] issue/consume parts;
- [ ] replenishment/low-stock alerts;
- [ ] work-order and maintenance linkage;
- [ ] cost tracking and inventory audit.

## Estimates and approvals

- [ ] estimates from deficiencies/work orders;
- [ ] labor and materials;
- [ ] customer estimate PDF;
- [ ] approval/rejection;
- [ ] revision history;
- [ ] conversion to authorized work.

## Customer portal

- [ ] secure customer access;
- [ ] sites/assets;
- [ ] reports and deficiencies;
- [ ] estimates/approvals;
- [ ] document download;
- [ ] service history.

## Reliability/service dashboards

- [ ] failure trends;
- [ ] recurring deficiencies;
- [ ] compliance and maintenance completion;
- [ ] technician workload;
- [ ] site reliability;
- [ ] response/report metrics.

---

# 8. Phase 6 — Further vertical expansion

Planned verticals:

- UPS;
- EV charging;
- battery energy storage;
- solar;
- selected facilities assets;
- additional tenant-configurable packs.

Shared architecture remains:

```text
Customer
  -> Site
    -> Asset
      -> Work Order / Schedule
        -> Published Template Revision
          -> Immutable Response
            -> Evidence
              -> Signed Report
```

---

# 9. Retention enforcement — current distinction

VoltCore now stores tenant retention policy intent for archived maintenance and generated reports, including indefinite, 1, 3, 5, 7, and 10 year targets.

Those values do **not** currently trigger automatic deletion.

## Archive is not deletion eligibility

**Archive** means remove a record from normal active workflow while keeping its evidence.

**Retention eligibility** means a record has passed every prerequisite for controlled disposition.

Recommended rule:

```text
eligible =
    explicitly archived
    AND retention age expired
    AND no legal/compliance hold
    AND dependency inventory complete
    AND evidence relationships valid
    AND deletion class certified
```

Age alone is never sufficient.

---

# 10. Why automatic purge remains disabled

`maintenance_jobs` has explicit `is_archived` and `archived_at`, making it the first viable retention class.

Other evidence is not yet equally safe:

- completed template responses are immutable evidence but lack a separate disposition lifecycle;
- legacy maintenance records may be children of a maintenance job;
- report metadata and underlying storage files are separate resources;
- photos/signatures are primary evidence and may exist independently in storage;
- inspections may require different business/regulatory rules.

Do not implement a generic `DELETE WHERE created_at < cutoff` job.

---

# 11. Retention Enforcement Phase 1 — Safe preview

No destructive behavior.

## Eligibility engine

For archived maintenance:

```text
retention_start = archived_at
eligible_at = archived_at + configured_retention_period
```

Deliver:

- [ ] retention eligibility domain model;
- [ ] policy resolver;
- [ ] retention-start resolver;
- [ ] eligible timestamp;
- [ ] exclusion reason;
- [ ] tenant isolation;
- [ ] tests for indefinite policies and boundaries.

## Legal/compliance holds

Add a tenant-safe hold model such as:

```text
retention_hold
hold_reason
hold_created_at
hold_created_by
hold_until
```

Possible reasons include disputes, regulatory audits, warranty/insurance cases, internal investigations, or customer contractual requirements.

An active hold always overrides expiration.

## Dependency/evidence manifest

Before any purge, inventory:

- maintenance job;
- maintenance records;
- parts used;
- attachments;
- linked inspection;
- linked form responses;
- generated reports;
- artifact metadata;
- PDFs;
- photos;
- signatures;
- storage objects.

Example:

```json
{
  "sourceType": "maintenance_job",
  "sourceId": "...",
  "databaseRows": 12,
  "reports": 2,
  "photos": 8,
  "signatures": 1,
  "storageObjects": 11,
  "holds": [],
  "eligible": true
}
```

## Retention Queue / Preview UI

Suggested navigation:

```text
Admin
  -> Data Retention
    -> Retention Queue
```

Display:

- entity/site/customer;
- archive date;
- policy;
- eligible date;
- hold status;
- dependency count;
- storage-object count;
- state.

Initial actions:

- View Manifest;
- Place Hold;
- Remove Hold;
- Exclude;
- Recalculate.

**Do not add Delete Now in this phase.**

### Phase 1 exit criterion

Admins can accurately see what would become eligible and exactly what would be affected without deleting any evidence.

---

# 12. Retention Enforcement Phase 2 — Controlled disposition queue

Add:

- [ ] `pending_purge`;
- [ ] configurable grace period;
- [ ] cancel disposition;
- [ ] hold during grace period;
- [ ] frozen manifest/checksum;
- [ ] execution audit;
- [ ] dry-run worker.

Recommended initial grace period: **30 days**.

State flow:

```text
eligible
  -> pending_purge
  -> storage_cleanup
  -> database_cleanup
  -> purged
```

Failures enter a retryable `failed` state.

### Phase 2 exit criterion

The entire purge state machine can be simulated and audited without destroying evidence.

---

# 13. Retention Enforcement Phase 3 — Certified purge execution

Start with one evidence class only:

```text
archived maintenance jobs
```

Requirements:

- [ ] storage cleanup;
- [ ] database cleanup;
- [ ] cascade verification;
- [ ] idempotent retry;
- [ ] failure recovery;
- [ ] metrics/alerting;
- [ ] immutable purge audit;
- [ ] staging certification;
- [ ] controlled A&S Electric test data;
- [ ] explicit production enablement flag.

Storage deletion and Postgres deletion cannot be one native ACID transaction. Therefore the purge worker must delete/verify storage first and only then perform destructive database cleanup. If storage cleanup fails, source database evidence stays intact and the job retries.

Recommended purge-audit metadata:

```text
id
tenant_id
source_type
source_id
policy_days
eligible_at
purge_started_at
purged_at
executed_by
database_row_count
storage_object_count
result
error_code
manifest_checksum
```

Do not store the deleted evidence payload inside the purge audit.

---

# 14. Recommended retention behavior by data class

| Data class | Recommended behavior |
| --- | --- |
| Active maintenance jobs | Never retention purge |
| Completed but not archived maintenance | Retain |
| Archived maintenance jobs | First enforceable class |
| Maintenance records/parts/attachments | Purge only with owning job |
| Inspections | Add separate lifecycle before purge |
| Completed form responses | Add archive/disposition semantics first |
| Generator legacy payloads | Preserve through rollback period |
| Generated reports | Purge only via manifest + storage cleanup |
| Photos/signatures | Never purge independently |
| RBAC/security audit | Separate long retention policy |
| Purge audit | Long/indefinite retention |

---

# 15. Recommended execution sequence

## Immediate

1. Complete the A&S Electric Phase 3 generator pilot.
2. Repair pilot regressions.
3. Sign off Phase 3 production certification.

## Next

4. Begin Phase 4 ATS inspection/maintenance.
5. Add switchgear/panel/transformer packs.
6. Add emergency-lighting/exit-sign recurring compliance.

## Parallel architecture work

7. Implement Retention Enforcement Phase 1 as a **non-destructive preview system**.
8. Do not enable purge execution while new template verticals are still exposing evidence-model gaps.

## Then

9. Proceed into Phase 5 operations/commercial tools.
10. Advance retention into controlled disposition when evidence relationships are mature.
11. Certify purge execution one evidence class at a time.

## Later

12. Phase 6 vertical expansion.
13. Add retention classes only after each vertical gets explicit lifecycle semantics.

---

# 16. Guardrails

- Never place service-role credentials in Flutter.
- `tenant_members` is authoritative for roles.
- UI role gating never replaces RLS.
- New routes are default-deny until explicitly registered.
- Never substitute a newer template revision for a pinned response.
- Never invent missing legacy evidence.
- Keep legacy generator data and PDFs available through pilot/rollback.
- Use web-safe storage abstractions on web.
- Archive is not delete.
- Age alone does not make evidence safe to delete.
- Holds override retention expiration.
- Photos/signatures/reports are purged only as part of their evidence graph.
- Storage cleanup must succeed before destructive database cleanup.
- Every permanent purge must be auditable.
- Purge audit must not retain the deleted payload.
- Destructive retention requires explicit enablement and separate certification.

---

# 17. Milestone checklist

## Phase 3

- [ ] Install generator packs in A&S Electric tenant.
- [ ] Inspection pilot.
- [ ] Maintenance pilot.
- [ ] Offline/restart certification.
- [ ] Exact-revision certification.
- [ ] PDF parity.
- [ ] Sync certification.
- [ ] Rollback certification.
- [ ] Phase 3 signoff.

## Phase 4

- [ ] ATS pack.
- [ ] Switchgear/panel/transformer packs.
- [ ] Emergency lighting/exit-sign pack.
- [ ] Phase 4 pilot/signoff.

## Retention Enforcement

- [ ] Eligibility engine.
- [ ] Holds.
- [ ] Dependency manifests.
- [ ] Preview queue.
- [ ] Dry-run disposition.
- [ ] Grace-period queue.
- [ ] First certified purge class.
- [ ] Storage/DB idempotency certification.
- [ ] Purge audit.

## Phase 5

- [ ] Parts/truck inventory.
- [ ] Estimates/approvals.
- [ ] Customer portal.
- [ ] Reliability/service dashboards.

## Phase 6

- [ ] UPS.
- [ ] EV charging.
- [ ] Energy storage/solar.
- [ ] Selected facilities assets.
- [ ] Additional template verticals.

---

# 18. Definition of overall success

VoltCore reaches the intended FieldOps architecture when multiple field-service verticals can operate through one tenant-safe platform while preserving offline execution, exact revision history, immutable completed records, traceable evidence, signed reports, scheduling, asset/service history, secure authorization, safe rollout/rollback, explicit retention policy, and controlled auditable eventual disposition.

**Next implementation action:** finish the Phase 3 controlled generator pilot and supporting readiness tooling. Do not begin destructive retention enforcement yet.
