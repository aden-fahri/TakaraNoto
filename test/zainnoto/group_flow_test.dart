import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:finflow_flutter/zainnoto/db/zainnoto_database.dart';
import 'package:finflow_flutter/zainnoto/providers/zainnoto_provider.dart';
import 'package:finflow_flutter/zainnoto/repositories/zainnoto_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('provider bisa create grup dan auto-select', () async {
    sqfliteFfiInit();
    final database = ZainNotoDatabase();
    await database.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(database.close);

    final provider =
        ZainNotoProvider(repository: ZainNotoRepository(database));

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
