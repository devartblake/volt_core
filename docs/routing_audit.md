# Routing audit

Findings from auditing menu/navigation against the GoRouter route table
(`lib/app/app_router.dart`), and what was done.

## Fixed

| Problem | Where | Fix |
| --- | --- | --- |
| Navigated to `/detail/:id` which is **not a route** (detail lives at `/inspections/detail/:id`) | `schedule_page.dart` (5×) | Point to `/inspections/detail/:id` |
| Navigated to `/options` which is **not a route** | `settings_page.dart` | Point to `/selection-management` |
| Navigated to `/inspection/new` (singular) which is **not a route** | `nameplate_list_page.dart` | Point to `/inspections/new` |
| Schedule sub-route path was `'/task'` — GoRouter sub-route paths must be **relative** (must not start with `/`) | `route_paths.dart` / `app_router.dart` | Changed to `'task'` (full path stays `/schedule/task`; navigation is name-based via `goNamed('schedule_task')`, so unaffected) |
| Badge map keyed by stale paths `'/options'`, `'/inspection/new'` that never matched drawer routes | `app_badges_controller.dart` | Re-keyed to `'/selection-management'`, `'/inspections/new'` |
| `Documents` and `Analytics` pages existed/added but weren't in the drawer | `app_drawer.dart` | Added both menu items |

These were **broken navigations**, not literal duplicate `GoRoute` entries —
every `GoRoute` path/name in the table is unique. The bugs were call sites
pointing at paths that don't exist, so they'd hit GoRouter's error page.

## Known redundancy — recommendation, not yet changed

**Two dashboards.** `/` → `DashboardPage` and `/tech-dashboard` →
`TechDashboardPage` both exist. `/tech-dashboard` is **orphaned**: nothing
navigates to it (no drawer entry, no `goNamed('tech_dashboard')`), and the home
`DashboardPage` already renders role-aware content.

Recommended solution (left for a follow-up so we don't delete a page that may be
intended for future use):

1. Confirm `TechDashboardPage` has no unique content worth keeping.
2. If not, remove its `GoRoute`, the `techDashboard` path/name constants, its
   `route_roles` entry, and the page file.
3. If it does, wire it into the drawer (role `tech`) so it's reachable, or fold
   its content into `DashboardPage`.

## Conventions confirmed working

- Name-based navigation (`goNamed('...')`) is used widely and matches
  `GoRoute.name` values — the most robust pattern; prefer it over string paths.
- `RouteRoles` gates by route **name**; unknown names default to allowed.
- New routes added this pass: `/analytics` (all roles), and `/documents` /
  `/analytics` now surfaced in the drawer.
