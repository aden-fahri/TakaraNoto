import 'package:flutter_test/flutter_test.dart';

import 'package:finflow_flutter/zainnoto/utils/whatsapp.dart';

import 'helpers.dart';

void main() {
  group('B6b: warna & ikon grup', () {
    test('createGroup menyimpan iconIndex & colorHex pilihan', () async {
      final ctx = await seedWeekly();

      final id = await ctx.repo.createGroup(
        name: 'Kas RT',
        iconIndex: 5,
        colorHex: '#9b59b6',
      );

      final groups = await ctx.repo.getGroups();
      final created = groups.firstWhere((g) => g.id == id);
      expect(created.iconIndex, 5);
      expect(created.colorHex, '#9b59b6');
    });

    test('updateGroup mengubah iconIndex & colorHex', () async {
      final ctx = await seedWeekly();

      await ctx.repo.updateGroup(
        id: ctx.groupId,
        name: 'Kas Futsal',
        iconIndex: 3,
        colorHex: '#3498db',
      );

      final groups = await ctx.repo.getGroups();
      final updated = groups.firstWhere((g) => g.id == ctx.groupId);
      expect(updated.iconIndex, 3);
      expect(updated.colorHex, '#3498db');
    });
  });

  group('B6c: audit log', () {
    test('createGroup & updateGroup tercatat di audit_log', () async {
      final ctx = await seedWeekly();

      await ctx.repo.updateGroup(
        id: ctx.groupId,
        name: 'Kas Futsal Baru',
        iconIndex: 4,
        colorHex: '#e74c3c',
      );

      final entries = await ctx.repo.getAuditLog(entity: 'group');
      final actions = entries.map((e) => e.action).toList();
      expect(actions, contains('insert'));
      expect(actions, contains('update'));

      final updateEntry = entries.firstWhere((e) => e.action == 'update');
      expect(updateEntry.entity, 'group');
      expect(updateEntry.entityId, ctx.groupId);
      expect(updateEntry.oldJson, isNotNull);
      expect(updateEntry.newJson, isNotNull);
      expect(updateEntry.newJson, contains('#e74c3c'));
    });

    test('filter entity hanya mengembalikan entity terkait', () async {
      final ctx = await seedWeekly();

      await ctx.repo.updateMember(id: ctx.aliceId, name: 'Alice Putri');

      final memberEntries = await ctx.repo.getAuditLog(entity: 'member');
      expect(memberEntries, isNotEmpty);
      expect(memberEntries.every((e) => e.entity == 'member'), isTrue);

      final groupEntries = await ctx.repo.getAuditLog(entity: 'group');
      expect(groupEntries.every((e) => e.entity == 'group'), isTrue);
    });
  });

  group('B6a: nomor WhatsApp', () {
    test('normalkan variasi nomor Indonesia ke awalan 62', () {
      expect(whatsappDigits('0812-3456-7890'), '6281234567890');
      expect(whatsappDigits('+62 812 3456 7890'), '6281234567890');
      expect(whatsappDigits('81234567890'), '6281234567890');
      expect(whatsappDigits('62 812 3456 7890'), '6281234567890');
      expect(whatsappDigits(null), isNull);
      expect(whatsappDigits('abc'), isNull);
      expect(whatsappDigits(''), isNull);
    });

    test('whatsappUri menyertakan pesan terenkode', () {
      final uri = whatsappUri('0812-3456-7890', message: 'Halo kamu');
      expect(uri, isNotNull);
      expect(uri!.host, 'wa.me');
      expect(uri.path, '/6281234567890');
      expect(uri.query, 'text=Halo%20kamu');

      expect(whatsappUri(null), isNull);
      expect(whatsappUri('abc'), isNull);
    });
  });
}
