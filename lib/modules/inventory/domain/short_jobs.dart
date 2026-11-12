import 'job_needs.dart';

/// How many jobs have at least one part the warehouse cannot cover (short,
/// partly in stock, or not in the catalog). Jobs already reserved or issued in
/// full do not count.
int jobsShortOfParts(Iterable<JobNeeds> needs) =>
    needs.where((j) => j.shortCount > 0).length;
