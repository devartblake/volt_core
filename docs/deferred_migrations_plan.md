# Deferred migrations — plan of action

**Date:** 2026-08-20
**Status:** Not started. Both items were deliberately deferred during the audit
remediation; this is the plan for picking them up.

Two pieces of mechanical-but-visible work were left out of Phases 3 and 4:

| # | Item | Why deferred | Size |
| --- | --- | --- | --- |
| 1 | Form sections onto `LabeledField` / `SelectionField` | Changes spacing and required-field markers across the form used daily; the owner chose to defer rather than absorb visual churn mid-remediation | 13 fields across 6 widgets |
| 2 | Colour tokens in `const` widget contexts | A theme lookup isn't available inside a `const` constructor; reaching these means de-consting hot UI | 59 sites across 15 files |

Neither is a correctness problem. Both are consistency debt with a visible
surface, so each wants its own PR and a real look at the screens afterwards.

---

## 1. `LabeledField` / `SelectionField` adoption

### What exists

`lib/shared/widgets/form_fields/` holds both widgets, implemented and tested in
Phase 3b. They wrap `TextFormField` / `DropdownButtonFormField` with consistent
vertical padding (8dp), a required-field asterisk plus default validator, and
an optional "Add…" affordance for user-managed option lists.

Nothing uses them yet. The sections still build raw fields:

| File | Text fields | Dropdowns |
| --- | --- | --- |
| `inspections/…/section_site_info.dart` | 4 | 2 |
| `inspections/…/section_fdny_dep.dart` | 1 | 1 |
| `inspections/…/section_operational_use.dart` | 1 | 1 |
| `inspections/…/section_location_safety.dart` | 1 | – |
| `inspections/…/section_materials.dart` | 1 | – |
| `inspections/…/section_signatures.dart` | 1 | – |
| `maintenance/…/utils/form_fields.dart` | 2 | 1 |

### What will visibly change

- **Spacing.** Sections currently mix `SizedBox(height: 8)` and `12` between
  fields; the kit applies a uniform 8dp vertical padding per field. Expect
  sections to get slightly tighter and more even.
- **Required markers.** `LabeledField(required: true)` appends ` *` to the
  label and installs a default "X is required" validator. Sections that are
  required today but unmarked will start showing the asterisk — check against
  what the paper form actually mandates before flipping each flag.
- **Validation copy** becomes uniform ("Site code is required") instead of the
  current mix.

### Approach

1. **Start with `section_materials.dart`** (one field, no validation). Convert,
   run the app, and compare against the current build side by side. This
   calibrates whether the spacing change is acceptable before touching the
   busier sections.
2. **Then `section_site_info.dart`** — the biggest and the one with the
   "Add option" dialogs, which is exactly what `SelectionField.onAddOption`
   exists for. Its `_promptAdd` helper can be deleted in favour of the shared
   affordance.
3. Convert the remaining four inspection sections.
4. **`maintenance/utils/form_fields.dart` last.** It is itself a local field
   helper — the migration there is to delete it and point its three call sites
   at the shared kit, so it is a deletion rather than a rewrite.

### Guardrails

- Keep `onChanged` semantics exactly as they are: the sections feed
  `_onSectionChanged`, which marks the form dirty and drives draft autosave.
  A field that stops firing `onChanged` silently disables autosave for that
  value — worth an explicit check per converted field.
- `SelectionField` renders a stored value that is no longer in the option list
  rather than dropping it. Confirm this against real data — inspections carry
  free-text grades and fuel types from before the option lists existed.
- Add a widget test per converted section asserting that editing a field emits
  `onChanged` with the expected entity change. There is no such coverage today.

### Acceptance

- No raw `TextFormField` / `DropdownButtonFormField` left under
  `modules/*/presenter/widgets/section_*.dart`.
- `maintenance/utils/form_fields.dart` deleted.
- Draft autosave still fires for every field (test-covered).
- Screenshots of each section before/after attached to the PR.

**Estimate:** half a day, most of it verification rather than typing.

---

## 2. Colour tokens in `const` contexts

### What exists

Phase 4 added the `StatusColors` theme extension (`success` / `warning` /
`info`, light and dark) and migrated 39 call sites. 59 raw `Colors.*` uses
remain, concentrated here:

| File | Sites |
| --- | --- |
| `debug/pages/network_debug_page.dart` | 10 |
| `debug/pages/hive_debug_page.dart` | 7 |
| `auth/presenter/pages/login_page.dart` | 7 |
| `equipment/…/equipment_search_page.dart` | 6 |
| `inspections/…/inspection_detail_page.dart` | 5 |
| 10 further files | 1–4 each |

Every one of them sits inside a `const` constructor — typically
`const SnackBar(backgroundColor: Colors.green)` or a `const Icon(…, color:
Colors.white)` — where `Theme.of(context)` cannot be called.

### Why it isn't just a find-and-replace

Attempting it wholesale during Phase 4 produced **78 compile errors** in one
pass. Removing `const` fixes compilation but costs a rebuild of that subtree on
every parent rebuild. For a `SnackBar` built once per user action that cost is
irrelevant; for something inside a `ListView.builder` row it is not.

### Approach — by category, not by file

**(a) Snackbars — do these first, ~20 sites.** Success/error snackbars are
built once per action; de-consting is free. Better still, most should not be
choosing colours at all:

```dart
// Instead of: const SnackBar(backgroundColor: Colors.green, …)
ScaffoldMessenger.of(context).showSnackBar(
  AppSnackBar.success('Inspection scheduled'),   // to be added to the kit
);
```

Adding `AppSnackBar.success/error/warning` to `shared/widgets` fixes the colour
*and* the copy inconsistency (some use `Row(Icon, Text)`, some plain text) in
one move. This is the highest-value slice.

**(b) Icons on coloured surfaces — leave alone, ~15 sites.**
`const Icon(Icons.check, color: Colors.white)` sitting on a filled primary
button is correct: it is an *on-colour*, not a semantic status. Converting
these to `colorScheme.onPrimary` is right in principle but changes nothing
visually and costs the `const`. Not worth it — document the intent instead.

**(c) Debug pages — leave alone, 17 sites.** `network_debug_page` and
`hive_debug_page` are `kDebugMode`-only and never ship. Lowest possible value.

**(d) Genuine status colours in list rows — the careful ~7.** Grade dots,
status chips inside `ListView.builder` items. These are the ones that actually
look wrong in dark mode. Handle by lifting the colour out of the `const` child
and into the parent that already has `theme` in scope, rather than de-consting
the leaf.

### Guardrails

- Do **not** run a blanket regex. The Phase 4 attempt is recorded above; it
  failed for a structural reason that has not changed.
- After each category, run `flutter analyze --fatal-infos` and look at the
  screens in both light and dark mode. The tokens are deliberately darker in
  light mode and lighter in dark mode than the raw Material swatches, so
  every converted site *will* shift shade.

### Acceptance

- `AppSnackBar` in the kit, with all success/error snackbars using it.
- No `Colors.green` / `Colors.orange` / `Colors.amber` outside `debug/`.
- Remaining `Colors.white` / `Colors.black` uses are on-colour only, with a
  short comment at each explaining why they are not tokens.

**Estimate:** category (a) is 2–3 hours and delivers most of the value.
Categories (b) and (c) are explicitly *not* recommended. Category (d) is
another 1–2 hours.

---

## Suggested order

1. **Snackbar helper + category (a)** — best value-to-risk in the whole
   document; also removes duplicated snackbar markup.
2. **Form sections (item 1)** — do it in one sitting so spacing is consistent
   across the form, not half-migrated.
3. **Category (d)** — the dark-mode status colours in list rows.
4. Leave (b) and (c) as documented intent.
