import 'package:sado_mobile/l10n/app_localizations.dart';

/// Localized "human" relative-time formatter used in list rows where we
/// want a glanceable summary like "today", "yesterday", "3 days ago",
/// "2 weeks ago", or "5 months ago". Falls back to numeric `dd.MM.yyyy`
/// for anything older than 12 months.
String formatRelativeDate(L l, DateTime when, {DateTime? now}) {
  final today = _atMidnight(now ?? DateTime.now());
  final then = _atMidnight(when);
  final days = today.difference(then).inDays;

  if (days <= 0) return l.dateRelativeToday;
  if (days == 1) return l.dateRelativeYesterday;
  if (days < 7) return l.dateRelativeDaysAgo(days);
  if (days < 30) return l.dateRelativeWeeksAgo((days / 7).floor());
  if (days < 365) return l.dateRelativeMonthsAgo((days / 30).floor());

  // > 1 year: explicit numeric date.
  final dd = when.day.toString().padLeft(2, '0');
  final mm = when.month.toString().padLeft(2, '0');
  return '$dd.$mm.${when.year}';
}

DateTime _atMidnight(DateTime d) => DateTime(d.year, d.month, d.day);
