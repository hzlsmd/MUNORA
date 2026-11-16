import 'dart:math';

import 'package:sqflite/sqflite.dart';

/// A SQLite transaction arbitrates delivery across Firebase's background isolate
/// and the UI isolate. SharedPreferences and Dart queues cannot do that atomically.
class NotificationDeliveryGate {
  final Database _database;
  NotificationDeliveryGate._(this._database);
  static Future<NotificationDeliveryGate>? _shared;
  static Future<NotificationDeliveryGate> open({
    DatabaseFactory? factory,
    String? path,
    bool singleInstance = true,
  }) async {
    final provider = factory ?? databaseFactory;
    final database = await provider.openDatabase(
      path ?? '${await provider.getDatabasesPath()}/notification_delivery.db',
      options: OpenDatabaseOptions(
        version: 1,
        singleInstance: singleInstance,
        onCreate: (db, _) => db.execute(
          'CREATE TABLE delivery_lease (id INTEGER PRIMARY KEY, owner TEXT NOT NULL, until_ms INTEGER NOT NULL)',
        ),
      ),
    );
    return NotificationDeliveryGate._(database);
  }

  Future<bool> claim(String owner, DateTime now) async {
    try {
      return await _database.transaction((txn) async {
        await txn.rawInsert(
          'INSERT OR IGNORE INTO delivery_lease(id,owner,until_ms) VALUES(1,?,0)',
          [''],
        );
        return await txn.rawUpdate(
              'UPDATE delivery_lease SET owner=?,until_ms=? WHERE id=1 AND until_ms<=?',
              [
                owner,
                now.add(const Duration(minutes: 2)).millisecondsSinceEpoch,
                now.millisecondsSinceEpoch,
              ],
            ) ==
            1;
      });
    } on DatabaseException catch (error) {
      // A separate connection/isolate can already hold the write transaction.
      // Treat SQLite BUSY/LOCKED as an unclaimed lease and retry, not a crash.
      final code = error.getResultCode();
      if (code != null && ((code & 255) == 5 || (code & 255) == 6)) {
        return false;
      }
      rethrow;
    }
  }

  Future<void> release(String owner) async {
    await _database.delete(
      'delivery_lease',
      where: 'id=1 AND owner=?',
      whereArgs: [owner],
    );
  }

  Future<void> close() => _database.close();
  static Future<void> run(Future<void> Function() display) async {
    final gate = await (_shared ??= open());
    final owner =
        '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    for (var attempt = 0; attempt < 20; attempt++) {
      if (await gate.claim(owner, DateTime.now().toUtc())) {
        try {
          await display();
        } finally {
          await gate.release(owner);
        }
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    // Another handler is still delivering. Let the next server check reassess;
    // never bypass the shared lease to force an overlapping alert.
  }
}
