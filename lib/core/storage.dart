import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

abstract class LocalStore {
  Future<void> open();
  Future<Map<String, dynamic>?> read(String key);
  Future<void> write(String key, Map<String, dynamic> value);
  Future<void> clear();
}

class DeviceStore implements LocalStore {
  Database? _db;
  SharedPreferences? _web;
  @override
  Future<void> open() async {
    if (kIsWeb) {
      _web = await SharedPreferences.getInstance();
      return;
    }
    _db = await openDatabase(
      p.join(await getDatabasesPath(), 'tausafe.db'),
      version: 2,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE records (id TEXT PRIMARY KEY, payload TEXT NOT NULL, updated_at INTEGER NOT NULL DEFAULT 0)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE records ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
          );
        }
      },
    );
  }

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    final String? raw;
    if (kIsWeb) {
      raw = _web!.getString('tausafe.$key');
    } else {
      final rows = await _db!.query(
        'records',
        where: 'id = ?',
        whereArgs: [key],
      );
      raw = rows.isEmpty ? null : rows.first['payload'] as String;
    }
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    final raw = jsonEncode(value);
    if (kIsWeb) {
      if (!await _web!.setString('tausafe.$key', raw)) {
        throw StateError('Не удалось сохранить данные');
      }
    } else {
      await _db!.insert('records', {
        'id': key,
        'payload': raw,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  @override
  Future<void> clear() async {
    if (kIsWeb) {
      for (final k in _web!.getKeys().where((k) => k.startsWith('tausafe.'))) {
        await _web!.remove(k);
      }
    } else {
      await _db!.delete('records');
    }
  }
}

class MemoryStore implements LocalStore {
  final values = <String, String>{};
  @override
  Future<void> open() async {}
  @override
  Future<Map<String, dynamic>?> read(String key) async => values[key] == null
      ? null
      : jsonDecode(values[key]!) as Map<String, dynamic>;
  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    values[key] = jsonEncode(value);
  }

  @override
  Future<void> clear() async => values.clear();
}
