import 'package:flutter_test/flutter_test.dart';

import 'package:finflow_flutter/zainnoto/logic/period_generator.dart';
import 'package:finflow_flutter/zainnoto/models/entities.dart';

void main() {
  test('weekly due_day: start Senin 2026-01-05 dueDay 1', () {
    final drafts = planPeriods(
      frequency: DuesFrequency.weekly,
      dueDay: 1,
      startDate: DateTime(2026, 1, 5),
      upTo: DateTime(2026, 1, 20),
      amount: 20000,
    );
    expect(drafts[0].dueDate, DateTime(2026, 1, 5));
    expect(drafts[1].dueDate, DateTime(2026, 1, 12));
  });

  test('weekly due_day: start Rabu 2026-01-07 dueDay 1/3/7', () {
    // blok 07-13 Jan: dueDay1=12 Jan, 3=07 Jan, 7=11 Jan
    // blok 14-20 Jan: dueDay1=19 Jan, 3=14 Jan, 7=18 Jan
    final cases = <int, List<DateTime>>{
      1: [DateTime(2026, 1, 12), DateTime(2026, 1, 19)],
      3: [DateTime(2026, 1, 7), DateTime(2026, 1, 14)],
      7: [DateTime(2026, 1, 11), DateTime(2026, 1, 18)],
    };
    for (final dd in [1, 3, 7]) {
      final drafts = planPeriods(
        frequency: DuesFrequency.weekly,
        dueDay: dd,
        startDate: DateTime(2026, 1, 7),
        upTo: DateTime(2026, 1, 21),
        amount: 20000,
      );
      expect(drafts[0].dueDate, cases[dd]![0]);
      expect(drafts[1].dueDate, cases[dd]![1]);
    }
  });

  test('weekly due_day: start Senin 2026-12-28 dueDay 7', () {
    final drafts = planPeriods(
      frequency: DuesFrequency.weekly,
      dueDay: 7,
      startDate: DateTime(2026, 12, 28),
      upTo: DateTime(2027, 1, 20),
      amount: 20000,
    );
    expect(drafts[0].dueDate, DateTime(2027, 1, 3));
    expect(drafts[1].dueDate, DateTime(2027, 1, 10));
    expect(drafts[2].dueDate, DateTime(2027, 1, 17));
  });

  test('weekly due_day: start Rabu 2028-02-23 dueDay 7', () {
    final drafts = planPeriods(
      frequency: DuesFrequency.weekly,
      dueDay: 7,
      startDate: DateTime(2028, 2, 23),
      upTo: DateTime(2028, 3, 15),
      amount: 20000,
    );
    expect(drafts[0].dueDate, DateTime(2028, 2, 27));
    expect(drafts[1].dueDate, DateTime(2028, 3, 5));
    expect(drafts[2].dueDate, DateTime(2028, 3, 12));
  });
}
