# Generator management systems: ideas to borrow

Researched 2026-11-06 from public product pages. Almost every source is vendor marketing, so these are *features vendors advertise*, not verified results. Statistics on those pages (for example "30% of standby failures come from missed maintenance") have no cited source and are not used here. Check NFPA 110 itself before relying on any inspection interval.

## What the products have in common

| Area | What vendors offer | Where it came from |
|---|---|---|
| Asset record | One record per generator: commissioning data, specs, parts used, warranty and service history | [Commusoft](https://www.commusoft.com/en-us/?p=15863) |
| Compliance schedule | NFPA 110 weekly visual check, monthly loaded test and annual load-bank test pre-loaded as recurring tasks, with alerts before the deadline | [OxMaint: hospital](https://oxmaint.com/industries/healthcare/hospital-generator-maintenance-software), [OxMaint: power plant](https://oxmaint.com/industries/power-plant/emergency-diesel-generator-maintenance-tracking) |
| Inspection evidence | Timestamps, technician signatures and photos on every inspection | OxMaint pages above |
| Failure to work order | A failed checklist item opens a corrective work order, assigned to a technician or vendor | [OxMaint: readiness dashboard](https://oxmaint.com/industries/facility-management/backup-generator-readiness-dashboard-for-facility-managers) |
| Usage-based service | Maintenance due by run hours (for example every 250 h for oil and filters), not only by date | OxMaint readiness dashboard |
| Parts by location | Warehouse, truck and customer-site stock; reorder alerts below a minimum | [FieldProxy](https://www.fieldproxy.ai/blog/generator-service-software-solutions-guide), [Ply](https://www.getply.com/blog/generator-companies-inventory-management/) |
| Purchasing | Approved-vendor list; purchase orders raised from a job | Commusoft |
| Job costing | Parts cost linked to the work order, for billing and margin | FieldProxy |
| Remote monitoring | Run hours, fuel level and fuel-theft alerts from controller data, fleet map and dashboard | [Datoms](https://datoms.io/dg-monitoring/) |
| Wider field-service suites | Dispatch, scheduling, invoicing and inventory in one product | [Field Services](https://fieldservio.com/industries/generators/), [Field Squared](https://fieldsquared.com/solutions/generator-service-providers) (listed in results; not read in detail) |

## What Volt Core already has

| Idea | State in the app |
|---|---|
| Per-generator record | Equipment registry plus a **parts profile** per generator (make, model, serial), now filled from the Queens and Bronx trackers (50 generators) |
| Inspection evidence | Signatures, photos and PDFs on inspections and maintenance |
| Parts catalog, stock ledger, reorder minimums | Done (catalog, ledger, Low / Out, Shortages page) |
| Job needs and reservations | Done (inspection "needs replacement" flows to Job Needs; reserve / issue / return) |
| Vendors and prices | Built, waiting on the Supabase migration and your vendor list |
| Manufacturer view of stock | Done (group by manufacturer, maker filter) |

## What to borrow, ranked for A&S Electric

1. **Job costing from prices.** Prices per vendor now exist, so each job's parts cost (issued quantity x last price paid) can show on the job and in reports. Small build, high value.
2. **Purchase orders from Shortages.** Turn the Shortages list into a draft PO per vendor, using each part's best current price. Needs the vendor list first.
3. **Truck stock.** A second location type (`truck`) is already allowed by the database. Add per-technician stock and transfers from the warehouse.
4. **Run-hour or date maintenance triggers.** Record engine hours at each service and flag generators due by hours as well as by date. The trackers already hold engine hours for some Bronx units.
5. **Failed item opens a follow-up.** Inspections already flag "needs replacement"; extend this so any failed checklist item can create a follow-up job automatically.
6. **Compliance calendar.** Pre-built weekly / monthly / annual recurrence for emergency generators, with reminders ahead of the due date. Confirm the intervals against NFPA 110 and your customers' contracts first.
7. **Fleet readiness dashboard.** One screen of generators by next-service date, last test result and open follow-ups.
8. **Remote monitoring.** Needs controller data and hardware. Not recommended unless customers ask for it.

## Suggested order

Vendors and prices live, then purchase orders and job costing (they share the same data), then truck stock, then run-hour triggers and the compliance calendar.
