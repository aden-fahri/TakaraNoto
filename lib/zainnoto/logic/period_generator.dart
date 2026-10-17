import 'dart:math' as math;

import '../models/entities.dart';
import '../utils/dates.dart';

/// A period that should exist for a dues plan, before persistence.
class PeriodDraft {
  const PeriodDraft({
    required this.label,
    required this.startDate,
    required this.endDate,
    required this.dueDate,
    required this.amountSnapshot,
  });

  final String label;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime dueDate;
  final int amountSnapshot;
}

/// Pure, idempotent period planner.
///
/// Generates every period from the plan start date up to and including the
/// period that contains [upTo]. Persistence layers must skip drafts whose
/// `(dues_plan_id, start_date)` already exists, which makes repeated calls
/// safe.
///
/// Weekly: 7-day blocks starting exactly at [startDate]; [dueDay] is the day
/// within the block (1-7).
///
/// Monthly: calendar months starting from the month of [startDate]; [dueDay]
/// is the day of month (1-28, clamped to the month length).
List<PeriodDraft> planPeriods({
  required DuesFrequency frequency,
  required int dueDay,
  required DateTime startDate,
  required DateTime upTo,
  required int amount,
}) {
  final start = dateOnly(startDate);
  final target = dateOnly(upTo);
  if (target.isBefore(start)) return const [];

  final drafts = <PeriodDraft>[];

  if (frequency == DuesFrequency.weekly) {
    var blockStart = start;
    while (!blockStart.isAfter(target)) {
      final blockEnd = blockStart.add(const Duration(days: 6));
      final offset = dueDay.clamp(1, 7) - 1;
      drafts.add(PeriodDraft(
        label: 'Minggu ${((blockStart.day - 1) ~/ 7) + 1} '
            '${monthNamesId[blockStart.month - 1]} ${blockStart.year}',
        startDate: blockStart,
        endDate: blockEnd,
        dueDate: blockStart.add(Duration(days: offset)),
        amountSnapshot: amount,
      ));
      blockStart = blockStart.add(const Duration(days: 7));
    }
    return drafts;
  }

  var year = start.year;
  var month = start.month;
  while (true) {
    final monthStart = DateTime(year, month, 1);
    if (monthStart.isAfter(target)) break;
    final monthEnd = DateTime(year, month + 1, 0);
    final due = DateTime(
      year,
      month,
      math.min(dueDay.clamp(1, 28), monthEnd.day),
    );
    drafts.add(PeriodDraft(
      label: '${monthNamesId[month - 1]} $year',
      startDate: monthStart,
      endDate: monthEnd,
      dueDate: due,
      amountSnapshot: amount,
    ));
    month++;
    if (month > 12) {
      month = 1;
      year++;
    }
  }
  return drafts;
}
