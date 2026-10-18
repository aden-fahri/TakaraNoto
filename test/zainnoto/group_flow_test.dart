import 'package:flutter_test/flutter_test.dart';

import 'package:finflow_flutter/zainnoto/providers/zainnoto_provider.dart';
import 'package:finflow_flutter/zainnoto/repositories/zainnoto_repository.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('provider bisa create grup dan auto-select', () async {
    await openTestDatabase();

    final provider = ZainNotoProvider(repository: ZainNotoRepository());

    await provider.loadGroups();
    expect(provider.groups, isEmpty);
    expect(provider.error, isNull);

    final group = await provider.createGroup(name: 'Kas Futsal');
    expect(provider.error, isNull);
    expect(group, isNotNull);
    expect(provider.groups.length, 1);
    expect(provider.selectedGroup?.id, group?.id);
  });
}
