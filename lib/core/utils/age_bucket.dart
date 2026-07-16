import '../../l10n/app_localizations.dart';

/// API-side age-group tokens used by the `/exercises?age_group=…` filter.
///
/// Kept in sync with the buckets the backend actually serves and with the
/// `ageGroupNtoM` localization keys in the .arb files. Order is from
/// youngest to oldest so callers can iterate in display order.
const ageBucketTokens = <String>[
  '2-3',
  '3-4',
  '4-5',
  '5-6',
  '6-7',
];

/// Returns the bucket token that best matches the child's age in years.
///
/// Pure helper — does not depend on the system clock unless [now] is
/// omitted. Returning `null` for ages strictly outside the supported range
/// lets the caller fall back to "all ages" rather than mis-recommending an
/// unrelated bucket. We deliberately treat 8-year-olds as out-of-range
/// instead of bucketing them with 6–7-year-olds: the brief targets ages
/// 2–10, but the API only carries content up to 6–7 today, so the safe
/// thing is to surface unfiltered exercises rather than show stale
/// "6-7 yosh" content for an older child.
///
/// Calculation rounds DOWN — a child who is 4 years and 11 months old is
/// still 4, which puts them in the `4-5` bucket. This matches the way
/// kindergartens themselves group ages in Uzbekistan.
String? recommendedAgeBucket(DateTime birth, {DateTime? now}) {
  final reference = (now ?? DateTime.now()).toUtc();
  final birthUtc = birth.toUtc();
  int years = reference.year - birthUtc.year;
  // Subtract a year if the birthday hasn't happened yet this calendar year.
  final hadBirthdayThisYear = reference.month > birthUtc.month ||
      (reference.month == birthUtc.month && reference.day >= birthUtc.day);
  if (!hadBirthdayThisYear) years--;

  if (years < 2 || years > 7) return null;
  // age N falls in bucket "N - (N+1)" — e.g. 4yo → "4-5".
  return '$years-${years + 1}';
}

/// Of all the children in [birthDates], pick the youngest one and return
/// the bucket token that best fits them. Returns `null` if the list is
/// empty or no child falls inside the supported range.
///
/// We pick the youngest deliberately: younger children need the most
/// scaffolding, so the home recommendations are biased toward the most
/// vulnerable speech-development window.
String? recommendedAgeBucketForChildren(Iterable<DateTime> birthDates,
    {DateTime? now}) {
  if (birthDates.isEmpty) return null;
  // Youngest = most recent birth date.
  final youngest = birthDates.reduce((a, b) => a.isAfter(b) ? a : b);
  return recommendedAgeBucket(youngest, now: now);
}

/// Localized human-readable label for one of [ageBucketTokens]. Returns
/// `null` for unknown tokens so callers can fall back to the bucket
/// string itself rather than rendering an empty pill.
String? localizedAgeBucket(L l, String? token) {
  switch (token) {
    case '2-3':
      return l.ageGroup2to3;
    case '3-4':
      return l.ageGroup3to4;
    case '4-5':
      return l.ageGroup4to5;
    case '5-6':
      return l.ageGroup5to6;
    case '6-7':
      return l.ageGroup6to7;
    default:
      return null;
  }
}
