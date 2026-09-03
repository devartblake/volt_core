# VoltCore Phase 3 — A&S Electric Generator Pilot Certification Runbook

**Scope:** Final controlled certification of the template-driven generator inspection and maintenance workflows.  
**Baseline:** `main` after PR #75.  
**Pilot flag:** `VOLTCORE_GENERATOR_TEMPLATE_PILOT=true`.  
**Rollback rule:** legacy generator workflows remain available and the pilot UI disappears when the flag is disabled.

## 1. What CI certifies automatically

The `Phase 3 Pilot Certification` workflow is the automated precondition for field signoff. It runs with the pilot flag enabled and certifies:

- technician pilot launch authorization;
- generator inspection and maintenance launch paths;
- local draft discovery/resume behavior;
- durable sync operation serialization;
- local-first immutable report-artifact registration;
- correct inspection/maintenance report categorization;
- real generator inspection pack autosave and simulated restart recovery;
- real generator maintenance pack autosave and simulated restart recovery;
- validation and immutable completion;
- customer PDF generation from the completed response;
- publication of revision 2 while a completed revision-1 response remains pinned to revision 1;
- legacy inspection adapter rendering through the generic report path;
- legacy maintenance adapter rendering through the generic report path;
- a complete flag-enabled Flutter web build.

The workflow uploads `voltcore-phase3-pilot-web` as a 14-day GitHub Actions artifact. It also supports manual `workflow_dispatch` and runs after relevant changes reach `main`.

## 2. Preconditions for the live A&S Electric run

Before entering field data:

- [ ] Use a `Phase 3 Pilot Certification` run that is fully green.
- [ ] Use the `voltcore-phase3-pilot-web` artifact from the exact commit being certified, or run Flutter locally with the same commit.
- [ ] Confirm the active tenant is A&S Electric.
- [ ] Confirm `generator-inspection` has exactly one published revision.
- [ ] Confirm `generator-maintenance` has exactly one published revision.
- [ ] Sign in as the technician/operator who will perform the test.
- [ ] Open **My Workload** and confirm **Generator Template Pilot** is visible.
- [ ] Confirm the legacy **New Inspection** and **New Maintenance Job** workflows are still available.

Local pilot command:

```bash
flutter run -d edge \
  --dart-define=VOLTCORE_GENERATOR_TEMPLATE_PILOT=true
```

Production-style web build:

```bash
flutter build web \
  --no-tree-shake-icons \
  --dart-define=VOLTCORE_GENERATOR_TEMPLATE_PILOT=true
```

## 3. Generator inspection field certification

### Online start

- [ ] From **My Workload**, select **Start inspection pilot**.
- [ ] Confirm the generator-inspection form opens.
- [ ] Enter the site/customer/generator identity used for the certification record.
- [ ] Enter enough data to create a meaningful report baseline, including grade/readings, checklist state, deficiencies, signatures/photos where available.
- [ ] Wait for local autosave.

Record the response ID and published revision number in the signoff notes.

### Offline and restart

- [ ] Disable network connectivity.
- [ ] Change multiple inspection values while offline.
- [ ] Return to **My Workload** and confirm the response appears under **Saved pilot drafts**.
- [ ] Close/restart the app or browser.
- [ ] Remain offline.
- [ ] Open **My Workload**.
- [ ] Confirm pilot controls remain usable even if workload statistics cannot refresh.
- [ ] Select **Resume** for the saved inspection draft.
- [ ] Confirm the response ID is unchanged.
- [ ] Confirm the revision is unchanged.
- [ ] Confirm the offline edits survived restart.

### Completion and PDF

- [ ] Complete all required inspection fields.
- [ ] Complete the response while still offline.
- [ ] Confirm the response becomes read-only/immutable.
- [ ] Confirm a PDF is generated without requiring Supabase connectivity.
- [ ] Confirm the report is categorized under **Inspections**, not generic template responses.
- [ ] Confirm the PDF can be opened from Documents on the current device/browser.

### Reconnect and convergence

- [ ] Restore networking.
- [ ] Trigger/allow synchronization.
- [ ] Confirm the sync indicator reaches a clean state with no failed operations.
- [ ] Confirm the completed `form_responses` row exists remotely.
- [ ] Confirm the PDF file upload exists remotely.
- [ ] Confirm the immutable `form_response_report_artifacts` row exists and links to the completed response.
- [ ] Confirm the artifact resolves the expected tenant/revision/site/customer/asset/work-order/inspection links where those relationships were supplied.

## 4. Revision immutability certification

After the inspection response above is synchronized:

- [ ] Clone generator-inspection revision 1 into a draft revision 2.
- [ ] Make a harmless, visible revision-2 change suitable for certification.
- [ ] Publish revision 2.
- [ ] Confirm revision 1 is archived as the former published revision.
- [ ] Reopen the completed certification response.
- [ ] Confirm it still loads revision 1 exactly.
- [ ] Confirm it remains immutable.
- [ ] Regenerate/open its report and confirm revision-1 evidence remains reproducible.
- [ ] Start a new inspection pilot and confirm the new response uses revision 2.

Do not delete revision 1; completed responses depend on immutable historical definitions.

## 5. Legacy-vs-template inspection PDF parity

Generate/open the legacy inspection report for an equivalent generator/site record and compare it with the template report.

Check:

- [ ] site/customer/generator identity;
- [ ] split/composed address;
- [ ] service date and technician;
- [ ] compliance/checklist YES/NO answers;
- [ ] checklist conclusions;
- [ ] readings and site grade;
- [ ] deficiencies and notes;
- [ ] load-test evidence where present;
- [ ] signatures/photos where present;
- [ ] pagination and readability;
- [ ] provenance/revision identification.

Classify every material difference as one of:

- **intentional improvement**;
- **equivalent representation**;
- **missing data**;
- **migration limitation**;
- **blocking regression**.

Any blocking regression stops the rollout.

## 6. Generator maintenance field certification

Repeat the same online → offline → restart → resume → complete → PDF → reconnect → revision test using **Start maintenance pilot**.

The maintenance record should exercise representative data from each major section:

- [ ] battery condition/replacement;
- [ ] air filter;
- [ ] coolant level/color;
- [ ] coolant/fuel/air/oil/additional hoses;
- [ ] filter/canister part numbers;
- [ ] oil/fuel/coolant/battery/air-filter service actions;
- [ ] belts/hoses, block heater, Racor, ATS controller, CDVR, undervoltage, hazmat as applicable;
- [ ] post-service operational checks;
- [ ] parts/materials;
- [ ] technician/customer signatures;
- [ ] follow-up required state and notes.

Confirm the generated report is categorized under **Maintenance**.

## 7. Rollback certification

Build/run the same commit with the pilot flag omitted or explicitly false:

```bash
flutter run -d edge \
  --dart-define=VOLTCORE_GENERATOR_TEMPLATE_PILOT=false
```

Verify:

- [ ] **Generator Template Pilot** is not shown on My Workload.
- [ ] legacy generator inspection is still usable;
- [ ] legacy generator maintenance is still usable;
- [ ] legacy reports remain visible;
- [ ] previously completed template responses remain stored;
- [ ] previously generated template PDFs remain visible;
- [ ] disabling the flag does not delete or mutate template evidence.

Rollback means disabling new template execution, not deleting historical template data.

## 8. Production signoff

Phase 3 may be marked production-certified only when all of the following are true:

- [ ] normal repository CI is green on the certified commit;
- [ ] `Phase 3 Pilot Certification` is green on the certified commit;
- [ ] inspection offline/restart/completion/PDF/sync checks pass;
- [ ] inspection revision-immutability check passes;
- [ ] inspection legacy PDF parity has no blocking regression;
- [ ] maintenance offline/restart/completion/PDF/sync checks pass;
- [ ] maintenance revision-immutability check passes;
- [ ] maintenance legacy PDF parity has no blocking regression;
- [ ] rollback check passes;
- [ ] no unresolved sync failures or RLS errors remain.

After signoff, Phase 4 reusable electrical template packs may begin. Until signoff, keep the pilot default-off for normal builds.
