import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:munora/services/notification_delivery_gate.dart';

Future<bool> Function() otherIsolateClaim(String path, DateTime now) =>
    () async {
      sqfliteFfiInit();
      final gate = await NotificationDeliveryGate.open(
        factory: databaseFactoryFfi,
        path: path,
        singleInstance: false,
      );
      try {
        return await gate.claim('other-isolate', now);
      } finally {
        await gate.close();
      }
    };

void main() {
  test('independent connections atomically claim and recover an expired delivery lease', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('munora-gate-test');
    addTearDown(() => dir.delete(recursive: true));
    final first = await NotificationDeliveryGate.open(
      factory: databaseFactoryFfi,
      path: '${dir.path}/delivery.db',
      singleInstance: false,
    );
    final second = await NotificationDeliveryGate.open(
      factory: databaseFactoryFfi,
      path: '${dir.path}/delivery.db',
      singleInstance: false,
    );
    addTearDown(first.close);
    addTearDown(second.close);
    final now = DateTime.utc(2026, 11, 16, 5);
    final results = await Future.wait([
      first.claim('a', now),
      second.claim('b', now),
    ]);
    expect(results.where((v) => v), hasLength(1));
    expect(
      await Isolate.run(otherIsolateClaim('${dir.path}/delivery.db', now)),
      isFalse,
    );
    final owner = results.first ? 'a' : 'b';
    await first.release('not-owner');
    expect(await second.claim('c', now), isFalse);
    expect(
      await second.claim('c', now.add(const Duration(minutes: 3))),
      isTrue,
    );
    await first.release(owner);
    expect(
      await first.claim('d', now.add(const Duration(minutes: 3))),
      isFalse,
    );
    await second.release('c');
    expect(await first.claim('d', now.add(const Duration(minutes: 3))), isTrue);
  });
}
