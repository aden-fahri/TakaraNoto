import 'package:flutter_test/flutter_test.dart';

import 'package:finflow_flutter/zainnoto/logic/period_generator.dart';
import 'package:finflow_flutter/zainnoto/models/entities.dart';

void main() {
  test('weekly due_day: startDate Senin 2026-01-05 dueDay 1', () {
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

  test('weekly due_day: startDate Rabu 2026-01-07 dueDay 1/3/7', () {
    for (final dd in [1, 3, 7]) {
      final drafts = planPeriods(
        frequency: DuesFrequency.weekly,
        dueDay: dd,
        startDate: DateTime(2026, 1, 7),
        upTo: DateTime(2026, 1, 21),
        amount: 20000,
      );
      if (dd == 1) {
        expect(drafts[0].dueDate, DateTime(2026, 1, 7));
        expect(drafts[1].dueDate, DateTime(2026, 1, 14));
      } else if (dd == 3) {
        expect(drafts[0].dueDate, DateTime(2026, 1, 9));
        expect(drafts[1].dueDate, DateTime(2026, 1, 16));
      } else {
        expect(drafts[0].dueDate, DateTime(2026, 1, 13));
        expect(drafts[1].dueDate, DateTime(2026, 1, 20));
      }
    }
  });

  test('weekly due_day: lintas bulan dan tahun 2026-12-28', () {
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

  test('weekly due_day: tahun kabisat 2028-02-23', () {
    final drafts = planPeriods(
      frequency: DuesFrequency.weekly,
      dueDay: 7,
      startDate: DateTime(2028, 2, 23),
      upTo: DateTime(2028, 3, 15),
      amount: 20000,
    );
    expect(drafts[0].dueDate, DateTime(2028, 2, 29));
    expect(drafts[1].dueDate, DateTime(2028, 3, 7));
    expect(drafts[2].dueDate, DateTime(2028, 3, 14));
  });
}
