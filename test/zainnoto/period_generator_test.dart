import 'package:flutter_test/flutter_test.dart';

import 'package:finflow_flutter/zainnoto/logic/period_generator.dart';
import 'package:finflow_flutter/zainnoto/models/entities.dart';

void main() {
  group('planPeriods weekly', () {
    test('membuat blok 7 hari dari start date sampai upTo', () {
      final drafts = planPeriods(
        frequency: DuesFrequency.weekly,
        dueDay: 7,
        startDate: DateTime(2026, 1, 5),
        upTo: DateTime(2026, 1, 19),
        amount: 20000,
      );

      expect(drafts, hasLength(3));
      expect(drafts[0].startDate, DateTime(2026, 1, 5));
      expect(drafts[0].endDate, DateTime(2026, 1, 11));
      expect(drafts[0].dueDate, DateTime(2026, 1, 11));
      expect(drafts[0].amountSnapshot, 20000);
      expect(drafts[1].startDate, DateTime(2026, 1, 12));
      expect(drafts[2].startDate, DateTime(2026, 1, 19));
      expect(drafts[0].label, 'Minggu 1 Januari 2026');
      expect(drafts[2].label, 'Minggu 3 Januari 2026');
    });

    test('dueDay adalah hari ke-N di dalam blok', () {
      final drafts = planPeriods(
        frequency: DuesFrequency.weekly,
        dueDay: 1,
        startDate: DateTime(2026, 1, 5),
        upTo: DateTime(2026, 1, 5),
        amount: 1000,
      );

      expect(drafts.single.dueDate, DateTime(2026, 1, 5));
    });

    test('kosong jika upTo sebelum start date', () {
      final drafts = planPeriods(
        frequency: DuesFrequency.weekly,
        dueDay: 7,
        startDate: DateTime(2026, 2, 1),
        upTo: DateTime(2026, 1, 31),
        amount: 1000,
      );

      expect(drafts, isEmpty);
    });
  });

  group('planPeriods monthly', () {
    test('membuat periode bulan kalender dari bulan start date', () {
      final drafts = planPeriods(
        frequency: DuesFrequency.monthly,
        dueDay: 5,
        startDate: DateTime(2026, 1, 15),
        upTo: DateTime(2026, 3, 10),
        amount: 50000,
      );

      expect(drafts, hasLength(3));
      expect(drafts[0].startDate, DateTime(2026, 1, 1));
      expect(drafts[0].endDate, DateTime(2026, 1, 31));
      expect(drafts[0].dueDate, DateTime(2026, 1, 5));
      expect(drafts[0].label, 'Januari 2026');
      expect(drafts[1].startDate, DateTime(2026, 2, 1));
      expect(drafts[1].endDate, DateTime(2026, 2, 28));
      expect(drafts[2].label, 'Maret 2026');
      expect(drafts[2].dueDate, DateTime(2026, 3, 5));
      expect(drafts[2].amountSnapshot, 50000);
    });

    test('due day dibatasi panjang bulan', () {
      final drafts = planPeriods(
        frequency: DuesFrequency.monthly,
        dueDay: 28,
        startDate: DateTime(2026, 2, 1),
        upTo: DateTime(2026, 2, 28),
        amount: 1000,
      );

      expect(drafts.single.dueDate, DateTime(2026, 2, 28));
    });
  });
}
