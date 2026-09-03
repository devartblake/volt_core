# VoltCore FieldOps — Phase 3 Closeout, Remaining Roadmap, and Retention Enforcement Plan

**Project:** A&S Electric / VoltCore FieldOps  
**Repository:** `devartblake/volt_core`  
**Status baseline:** `main` through merged PR #68; Phase 3 platform work through PR #64 is complete.  
**Live pilot state verified 3 September 2026:** both generator templates are installed and published at revision 1; no template responses exist yet.  
**Purpose:** Define the remaining Phase 3 exit work, the Phase 4–6 roadmap, and the staged retention-enforcement track without risking compliance evidence.

---

## 1. Executive summary

VoltCore has completed the major Phase 3 engineering build-out: versioned templates, management UI, generic rendering, offline response lifecycle, generator packs/adapters, generic reports, Documents integration, downstream links, technician execution runtime, rollback gating, tenant-authoritative RBAC, persistent settings, export/cache controls, retention-policy configuration, and privacy-aware logging.

Post-Phase-3 hardening also fixed unsaved-form navigation, stale queued tenant IDs, tenant-admin member/role management, and inspection address/checklist-conclusion capture.

Phase 3 is **not production-certified yet** because no template-driven generator response has been executed in the controlled A&S Electric pilot. The remaining work is certification, not another major foundation build.

After Phase 3 certification:

- **Phase 4:** first electrical template packs;
- **Phase 5:** operations and commercial tools;
- **Phase 6:** additional vertical expansion.

Retention enforcement remains a cross-cutting evidence-lifecycle track. The policy UI exists, but destructive deletion stays disabled until dependency-safe, storage-safe, auditable purge execution is certified.

---

# 2. Current delivered state

## Phase 1 — Complete

- tenant-safe scheduling;
- authenticated Supabase access;
- generic asset vocabulary;
- local-first persistence;
- durable sync conventions.

## Phase 2 — Complete / rollout validation

- customer/site directory;
- generic asset registration/reassignment;
- QR/barcode search and history;
- work-order lifecycle;
- technician assignment and dispatch views;
- schedule details and maintenance handoff;
- database-owned audit events;
- legacy maintenance/archive access;
- schedule-deletion tombstones preventing stale remote rehydration.

## Phase 3 — Automated implementation complete / manual pilot pending

Delivered:

- `form_templates`, revisions, sections, fields, options, responses, report artifacts;
- exact revision pinning and completed-response immutability;
- role-gated Template Management;
- draft clone/edit/publish/archive;
- generic renderer for text, number, reading, date, select, boolean, checklist, photo, signature;
- conditional visibility and validation;
- local-first autosave, restart recovery, completion locking;
- exact-revision Hive cache with no-newer-substitution protection;
- `generator-inspection` and `generator-maintenance` packs;
- legacy adapters preserving semantic values, `_legacyPayload`, provenance, boolean ambiguity, load-test/photo evidence;
- generic PDF renderer;
- native/web report persistence and Documents integration;
- durable report-artifact links;
- technician runtime at `/field-forms/:templateSlug` behind a default-off build flag;
- tenant-authoritative RBAC and last-admin protection;
- persistent app settings, export/cache controls, retention-policy settings, advanced logging privacy controls.

Additional hardening through PR #68:

- safe unsaved-form navigation;
- stale-tenant queued-sync healing;
- tenant-admin user/role management;
- split inspection address with legacy one-line compatibility;
- explicit YES/NO checklist presentation;
- per-item inspection conclusions carried into the PDF.

---

# 3. Live A&S Electric Phase 3 pilot state

Verified against the connected VoltCore Supabase project:

- [x] `generator-inspection` installed;
- [x] `generator-inspection` published revision 1;
- [x] `generator-maintenance` installed;
- [x] `generator-maintenance` published revision 1;
- [ ] any `form_responses` for either generator template — **none yet**.

Therefore the next step is to **start the pilot**, not install the packs.

Pilot build:

```bash
flutter run -d edge \
  --dart-define=VOLTCORE_GENERATOR_TEMPLATE_PILOT=true
```

or:

```bash
flutter build web \
  --dart-define=VOLTCORE_GENERATOR_TEMPLATE_PILOT=true
```

---

# 4. What remains in Phase 3

## 4.1 Pilot readiness

- [ ] Confirm the pilot build reports `VOLTCORE_GENERATOR_TEMPLATE_PILOT=true`.
- [ ] Confirm the active tenant is A&S Electric.
- [ ] Confirm both generator templates are visible and published.
- [ ] Confirm the signed-in operator can execute published field forms.
- [ ] Start the first generator-inspection response while online.

## 4.2 Generator inspection pilot

- [ ] Open `/field-forms/generator-inspection`.
- [ ] Create the response online so the published definition is cached.
- [ ] Disconnect networking.
- [ ] Enter inspection data and confirm autosave continues.
- [ ] Restart the app/browser.
- [ ] Reopen the response and confirm values plus exact revision recover.
- [ ] Complete the response.
- [ ] Confirm it becomes immutable.
- [ ] Generate the customer-ready PDF.
- [ ] Confirm the PDF appears in Documents.
- [ ] Reconnect.
- [ ] Confirm response sync succeeds.
- [ ] Confirm file/report sync succeeds.

## 4.3 Revision immutability

- [ ] Publish generator-inspection revision 2.
- [ ] Reopen the completed revision-1 response.
- [ ] Confirm it still resolves revision 1.
- [ ] Confirm the revision-1 report remains reproducible.

## 4.4 Legacy vs template PDF parity

Compare:

- generator identity;
- site/customer identity;
- split/composed address;
- compliance/checklist YES/NO answers;
- checklist conclusions;
- readings and grade;
- deficiencies;
- load-test evidence;
- signatures/photos;
- pagination/readability;
- provenance.

Classify differences as:

- intentional improvement;
- equivalent representation;
- missing data;
- migration limitation;
- blocking regression.

Blocking regressions must be repaired before broader rollout.

## 4.5 Generator maintenance pilot

Repeat the same lifecycle for:

```text
/field-forms/generator-maintenance
```

Verify battery, filters, coolant, hoses, service actions, parts/materials, post-service checks, signatures, follow-up state, PDF output, synchronization, offline recovery, and revision immutability.

## 4.6 Rollback certification

- [ ] Disable `VOLTCORE_GENERATOR_TEMPLATE_PILOT`.
- [ ] Confirm legacy inspection remains usable.
- [ ] Confirm legacy maintenance remains usable.
- [ ] Confirm legacy reports remain visible.
- [ ] Confirm template responses/PDFs remain intact.

## Phase 3 exit criterion

Phase 3 is production-certified when a technician can complete generator inspection and maintenance offline from published revisions, recover after restart, synchronize safely, generate customer-ready reports, and reopen immutable responses against their original revisions after newer revisions exist, while the legacy workflow remains a verified rollback path.

---

# 5. Phase 4 — First electrical template packs

Begin only after Phase 3 pilot signoff.

## ATS / transfer switch

- ATS inspection template;
- ATS maintenance template;
- source/position checks;
- transfer/exercise testing;
- mechanical/contact/connection condition;
- readings;
- deficiencies;
- photos/signatures;
- signed report.

## Switchgear / panels / transformers

- identity/nameplate;
- physical condition;
- applicable electrical/thermal observations;
- voltage/current readings;
- grounding/bonding observations;
- deficiencies/evidence;
- signed report.

## Emergency lighting / exit signs

- recurring compliance template;
- fixture location/identity;
- function/illumination;
- battery/emergency runtime;
- obstruction/damage;
- corrective action;
- recurring schedule handoff;
- signed report.

**Rule:** improve the generic template engine rather than creating one-off screens unless a field truly cannot be modeled generically.

---

# 6. Phase 5 — Operations and commercial tools

## Parts and truck inventory

- parts catalog;
- truck/technician stock;
- issue/consume parts;
- replenishment/low-stock alerts;
- work-order/maintenance linkage;
- cost tracking and inventory audit.

## Estimates and approvals

- estimates from deficiencies/work orders;
- labor/materials;
- customer estimate PDF;
- approval/rejection;
- revision history;
- conversion to authorized work.

## Customer portal

- secure access;
- sites/assets;
- inspection/maintenance reports;
- deficiencies;
- estimates/approvals;
- document download;
- service history.

## Reliability/service dashboards

- failure trends;
- recurring deficiencies;
- compliance and maintenance completion;
- technician workload;
- site reliability;
- response/report metrics.

---

# 7. Phase 6 — Further vertical expansion

- UPS;
- EV charging;
- battery energy storage;
- solar;
- selected facilities assets;
- additional tenant-configurable packs.

Shared architecture:

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

# 8. Retention enforcement — critical distinction

VoltCore stores tenant retention-policy intent for archived maintenance and generated reports, with indefinite, 1, 3, 5, 7, and 10 year choices.

Those values do **not** automatically delete evidence.

## Archive is not deletion eligibility

Archive means remove a record from the normal active workflow while preserving evidence.

Retention eligibility requires all of:

```text
explicitly archived
AND retention age expired
AND no legal/compliance hold
AND dependency inventory complete
AND evidence relationships valid
AND deletion class certified
```

Age alone is never sufficient.

`maintenance_jobs` is the first viable enforcement class because it has `is_archived` and `archived_at`. Completed template responses, legacy records, reports, photos, signatures, and inspections do not yet have equally safe disposition semantics.

Never implement retention as a generic `DELETE WHERE created_at < cutoff` job.

---

# 9. Retention Enforcement Phase 1 — Safe preview

**No destructive behavior.**

## Eligibility engine

For archived maintenance:

```text
retention_start = archived_at
eligible_at = archived_at + configured_retention_period
```

Deliver:

- retention eligibility domain model;
- policy resolver;
- retention-start resolver;
- eligible timestamp;
- exclusion reason;
- tenant isolation;
- indefinite-policy and boundary tests.

## Legal/compliance holds

Recommended model:

```text
retention_hold
hold_reason
hold_created_at
hold_created_by
hold_until
```

Possible reasons: dispute, regulatory audit, warranty/insurance case, investigation, contractual requirement.

An active hold always overrides expiration.

## Dependency/evidence manifest

Inventory before any purge:

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

## Retention Queue / Preview UI

Suggested path:

```text
Admin
  -> Data Retention
    -> Retention Queue
```

Show entity/site/customer, archive date, policy, eligible date, hold status, dependency count, storage-object count, and state.

Initial actions:

- View Manifest;
- Place Hold;
- Remove Hold;
- Exclude;
- Recalculate.

**No “Delete Now” action in Phase 1.**

Exit criterion: administrators can accurately see what would become eligible and what would be affected without deleting evidence.

---

# 10. Retention Enforcement Phase 2 — Controlled disposition

Add:

- `pending_purge`;
- configurable grace period;
- cancel disposition;
- hold during grace period;
- frozen manifest/checksum;
- execution audit;
- dry-run worker.

Recommended initial grace period: **30 days**.

State model:

```text
eligible
  -> pending_purge
  -> storage_cleanup
  -> database_cleanup
  -> purged
```

Failures enter a retryable `failed` state.

Exit criterion: the full state machine can be simulated and audited without destroying evidence.

---

# 11. Retention Enforcement Phase 3 — Certified purge execution

Start with one class only:

```text
archived maintenance jobs
```

Requirements:

- storage cleanup;
- database cleanup;
- cascade verification;
- idempotent retry;
- failure recovery;
- metrics/alerting;
- immutable purge audit;
- staging certification;
- controlled A&S Electric test data;
- explicit production enablement flag.

Because Supabase Storage deletion and Postgres deletion are not one ACID transaction, storage cleanup must succeed and be verified before destructive database cleanup. If storage cleanup fails, source database evidence remains and the job retries.

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

Do not store deleted evidence payloads inside the purge audit.

---

# 12. Recommended retention behavior by data class

| Data class | Recommended behavior |
| --- | --- |
| Active maintenance jobs | Never retention purge |
| Completed, not archived maintenance | Retain |
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

# 13. Recommended execution sequence

## Immediate

1. Add pilot-readiness diagnostics/guided launch tooling.
2. Start the A&S Electric generator-inspection pilot.
3. Repair pilot regressions.
4. Run generator-maintenance pilot.
5. Sign off Phase 3 production certification.

## Next

6. Begin Phase 4 ATS inspection/maintenance.
7. Add switchgear/panel/transformer packs.
8. Add emergency-lighting/exit-sign recurring compliance.

## Parallel architecture work

9. Implement Retention Enforcement Phase 1 as a non-destructive preview system.
10. Keep purge execution disabled while new verticals expose evidence-model gaps.

## Then

11. Proceed into Phase 5 operations/commercial tools.
12. Advance retention into controlled disposition when evidence relationships are mature.
13. Certify purge execution one evidence class at a time.

## Later

14. Phase 6 vertical expansion.
15. Add retention classes only after each vertical has explicit lifecycle semantics.

---

# 14. Guardrails

- Never place service-role credentials in Flutter.
- `tenant_members` is authoritative for roles.
- UI gating never replaces RLS.
- New routes are default-deny until explicitly registered.
- Never substitute a newer template revision for a pinned response.
- Never invent missing legacy evidence.
- Keep legacy generator data/PDFs through pilot and rollback.
- Use web-safe storage abstractions on web.
- Archive is not delete.
- Age alone does not make evidence safe to delete.
- Holds override retention expiration.
- Photos/signatures/reports are purged only as part of their evidence graph.
- Storage cleanup must succeed before destructive database cleanup.
- Every permanent purge must be auditable.
- Purge audit must not retain deleted payloads.
- Destructive retention requires explicit enablement and separate certification.

---

# 15. Milestone checklist

## Phase 3

- [x] Generator packs installed/published in A&S Electric.
- [ ] Pilot-readiness diagnostics/guided launch.
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

# 16. Definition of overall success

VoltCore reaches the intended FieldOps architecture when multiple field-service verticals operate through one tenant-safe platform while preserving offline execution, exact revision history, immutable completed records, traceable evidence, signed reports, scheduling, service history, secure authorization, safe rollout/rollback, explicit retention policy, and controlled auditable eventual disposition.

**Next implementation action:** pilot-readiness diagnostics and guided launch, followed by the first A&S Electric generator-inspection response. Destructive retention enforcement remains deferred.
