# Deferred migrations — plan of action

**Date:** 2026-08-20
**Status:** In progress — item 1 is largely done (all inspection sections, the
maintenance field helper, and three further maintenance sections); category (a)
of item 2 (snackbars) is done. Remaining work is listed under each item. Both items were deliberately deferred during the audit
remediation; this is the plan for picking them up.

Two pieces of mechanical-but-visible work were left out of Phases 3 and 4:

| # | Item | Why deferred | Size |
| --- | --- | --- | --- |
| 1 | Form sections onto `LabeledField` / `SelectionField` | Changes spacing and required-field markers across the form used daily; the owner chose to defer rather than absorb visual churn mid-remediation | 13 fields across 6 widgets |
| 2 | Colour tokens in `const` widget contexts | A theme lookup isn't available inside a `const` constructor; reaching these means de-consting hot UI | 59 sites across 15 files |

Neither is a correctness problem. Both are consistency debt with a visible
surface, so each wants its own PR and a real look at the screens afterwards.

---

## 1. `LabeledField` / `SelectionField` adoption — ✅ DONE

**Delivered.** All six inspection sections now use the kit, and
`section_site_info`'s hand-built "add option" rows collapsed into
`SelectionField.onAddOption`, deleting a Row + IconButton per field. The
maintenance `utils/form_fields.dart` helper was **not** deleted as this plan
originally proposed — see the correction below — but its `FormTextFieldRow`,
`FormTextAreaRow` and `FormDropdownRow` now delegate to the kit, as does
`section_maint_site_info`'s local field builder. `LabeledField` gained
`suffixText` along the way, which the maintenance and FDNY fields needed.

**A bug this surfaced.** `section_materials`'s date fields are read-only
`TextFormField`s built from `initialValue`. That keeps its original text across
rebuilds, so picking a date updated the entity but the field kept showing the
old value — the user saw nothing happen. Fixed with a value-derived key, and
`test/inspections/section_fields_test.dart` fails without it.

**Correction to this plan's original scope.** It claimed
`maintenance/utils/form_fields.dart` was "3 fields" that could simply be
deleted. It is actually seven widget classes (`FormSectionHeader`,
`FormSubsectionTitle`, `FormTextFieldRow`, `FormTextAreaRow`,
`FormDropdownRow`, `FormCheckboxRow`, `FormDivider`) consumed by five section
files, and includes widgets the kit has no equivalent for. Delegating was the
right call; deleting would have meant rewriting five files to no benefit.

**The last three sections.** `section_load_test`, `section_maint_general` and
`section_maint_signatures` — nine fields the plan's original inventory missed —
are converted too. They needed a `dense` variant: these fields sit inside rows
that already carry their own padding (a load-test step dialog, a checklist row,
a cannister row), and the standalone 8dp vertical padding blew the row height
out. `dense: true` drops the outer padding and sets `isDense`. `filled` was
added for the same reason — the signature cards sit on a tinted surface where
the theme default reads wrong.

**A second bug this surfaced.** `section_maint_signatures`'s "Date Signed"
field built a `TextEditingController` inline in `build()`, which is both a leak
(never disposed) and the same stale-value trap as above wearing a different
hat — a fresh controller each build meant the field was fine, but only by
accident of rebuilding. It is now a keyed `LabeledField` with `readOnly` +
`onTap`, which also let its `InkWell` + `IgnorePointer` wrapper go.

### Still out of scope

Four raw fields remain, none of them form sections:

| File | Fields | Why it stays |
| --- | --- | --- |
| `inspections/…/nameplate_intervals_page.dart` | 2 | Data-table cells, not a form section |
| `auth/…/login_page.dart` | 1 | Bespoke styling; converting would flatten it |
| `settings/…/selection_options_page.dart` | 1 | Inline add-option field |

### Tests

`test/shared/labeled_field_test.dart` (5 cases) pins the kit's contract: the
required asterisk and default validator, that a `readOnly` field still delivers
`onTap` (the signature date picker now depends on it), that `dense` really
drops the padding, and both halves of the stale-value trap — a keyed field
shows the new value after a rebuild, an unkeyed one does not.
`test/inspections/section_fields_test.dart` (4 cases) covers the section side:
`onChanged` still fires so draft autosave is not silently disabled.

### Acceptance

- ✅ No raw fields left under `modules/*/presenter/widgets/section_*.dart`.
- ~~`maintenance/utils/form_fields.dart` deleted~~ — superseded: it delegates to
  the kit instead, for the reason recorded above.
- ✅ Draft autosave still fires for every converted field (test-covered).
- ✅ `SelectionField` renders a stored value that is no longer in the option
  list rather than dropping it — inspections carry free-text grades and fuel
  types from before the option lists existed.

### What changed visually

- **Spacing.** Sections used to mix `SizedBox(height: 8)` and `12` between
  fields. Standalone fields now carry a uniform 8dp vertical padding; fields
  nested in a padded row use `dense: true` and keep the tighter rhythm they
  had.
- **Validation actually runs now.** `required: true` was set on exactly two
  fields, Site Code and Address in `section_site_info` — the two
  `inspection_form_page._incompleteSections` already treated as mandatory.
  Before this, the inspection form had **no field validators at all**, so
  `_formKey.currentState!.validate()` in `_handleSave` always returned `true`
  and the whole "Required fields missing in: …" branch built in Phase 3d,
  scroll-to-section included, was unreachable: an inspection with an empty site
  code saved silently. Two validators is what makes that path live. Validation
  copy is now uniform ("Site Code is required") rather than absent.
- **Labels where there were only hints.** Two fields (the maintenance
  notes/observations rows) had a `hintText` and no label, so a screen reader
  had nothing to announce once text was entered. They now have real labels.

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

**(a) Snackbars — ✅ DONE.** Success/error snackbars are built once per action,
so de-consting them is free — and most shouldn't have been choosing colours at
all:

```dart
// Was: const SnackBar(backgroundColor: Colors.green, …) inside a Row of
//      Icon + Text, repeated at every call site.
AppSnackBar.success(context, 'Inspection scheduled');
```

`AppSnackBar.success/error/warning/info` now lives in the kit and every
feature-code snackbar uses it, which fixed the colour *and* the markup
inconsistency (some were plain text, some a hand-built `Row`) in one move.
Colours come from `StatusColors` / `colorScheme.error` and adapt to dark mode;
error toasts stay up 5s against success's 3s; the leading icon is
`ExcludeSemantics` so a screen reader announces the message once. Debug pages
were left alone per category (c). 9 tests cover it.

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

1. ~~**Snackbar helper + category (a)**~~ — ✅ done. `AppSnackBar` added and all
   feature-code snackbars migrated.
2. **Form sections (item 1)** — do it in one sitting so spacing is consistent
   across the form, not half-migrated.
3. **Category (d)** — the dark-mode status colours in list rows.
4. Leave (b) and (c) as documented intent.
